import 'dart:convert';

import 'nbvpn_profile.dart';
import 'profile_errors.dart';
import 'split_tunnel.dart';

const uriScheme = 'nbvpn';
const uriPrefix = 'nbvpn:1?';
const defaultKeepalive = 25;

/// Parse / encode NbVpnProfile per contract (URI + JSON).
class ProfileCodec {
  ProfileCodec._();

  static void validate(NbVpnProfile p) {
    if (p.v == 0) {
      throw ProfileException(
        ProfileErrorCode.profileInvalid,
        detail: '缺少版本字段 v',
      );
    }
    if (p.v < 1) {
      throw ProfileException(
        ProfileErrorCode.profileInvalid,
        detail: '不支持的版本 v=${p.v}',
      );
    }
    if (p.v > NbVpnProfile.supportedVersion) {
      throw ProfileException(ProfileErrorCode.profileUnsupported);
    }
    if (p.v != NbVpnProfile.supportedVersion) {
      throw ProfileException(
        ProfileErrorCode.profileInvalid,
        detail: '不支持的版本 v=${p.v}',
      );
    }
    if (p.name.trim().isEmpty) {
      throw ProfileException(
        ProfileErrorCode.profileInvalid,
        detail: 'name 必填',
      );
    }
    _validateKey(p.client.privateKey, 'client.privateKey');
    if (p.client.address.isEmpty) {
      throw ProfileException(
        ProfileErrorCode.profileInvalid,
        detail: 'client.address 不能为空',
      );
    }
    if (p.client.dns.isEmpty) {
      throw ProfileException(
        ProfileErrorCode.profileInvalid,
        detail: 'client.dns 不能为空',
      );
    }
    _validateKey(p.server.publicKey, 'server.publicKey');
    _validateEndpoint(p.server.endpoint, field: 'server.endpoint');
    final v6 = p.server.endpointV6?.trim() ?? '';
    if (v6.isNotEmpty) {
      _validateEndpoint(v6, field: 'server.endpointV6');
    }
    if (p.server.allowedIPs.isEmpty) {
      throw ProfileException(
        ProfileErrorCode.profileInvalid,
        detail: 'server.allowedIPs 不能为空',
      );
    }
  }

  static void _validateKey(String k, String field) {
    final trimmed = k.trim();
    if (trimmed.isEmpty) {
      throw ProfileException(
        ProfileErrorCode.profileInvalid,
        detail: '$field 必填',
      );
    }
    try {
      final raw = base64.decode(trimmed);
      if (raw.length != 32) {
        throw ProfileException(
          ProfileErrorCode.profileInvalid,
          detail: '$field 须为 32 字节 WireGuard 密钥（base64）',
        );
      }
    } on FormatException {
      throw ProfileException(
        ProfileErrorCode.profileInvalid,
        detail: '$field 须为 32 字节 WireGuard 密钥（base64）',
      );
    } on ProfileException {
      rethrow;
    }
  }

  static void _validateEndpoint(String ep, {String field = 'server.endpoint'}) {
    final trimmed = ep.trim();
    if (trimmed.isEmpty) {
      throw ProfileException(
        ProfileErrorCode.profileInvalid,
        detail: '$field 必填',
      );
    }
    final parts = _splitHostPort(trimmed);
    if (parts == null || parts.$1.isEmpty || parts.$2.isEmpty) {
      throw ProfileException(
        ProfileErrorCode.profileInvalid,
        detail: '$field 须为 host:port（IPv6 为 [addr]:port）',
      );
    }
  }

  /// Returns (host, port) or null. IPv6 must be bracketed: `[addr]:port`.
  static (String, String)? _splitHostPort(String ep) {
    if (ep.startsWith('[')) {
      final idx = ep.lastIndexOf(']:');
      if (idx < 0) return null;
      final host = ep.substring(0, idx + 1);
      final port = ep.substring(idx + 2);
      if (host.length < 3 || port.isEmpty) return null;
      return (host, port);
    }
    // Reject bare IPv6 (multiple colons) — require [addr]:port.
    final colonCount = ':'.allMatches(ep).length;
    if (colonCount != 1) return null;
    final idx = ep.indexOf(':');
    if (idx <= 0 || idx == ep.length - 1) return null;
    return (ep.substring(0, idx), ep.substring(idx + 1));
  }

  static String encodeUri(NbVpnProfile p) {
    validate(p);
    final jsonBytes = utf8.encode(jsonEncode(p.toJson()));
    final payload = base64Url.encode(jsonBytes).replaceAll('=', '');
    return '$uriPrefix$payload';
  }

  /// Normalize pasted/scanned URI: trim, strip wrapping quotes, drop whitespace,
  /// extract `nbvpn:` from multi-line SSH / messenger pastes (WARNING lines, fences).
  static String sanitizeUriInput(String raw) {
    var s = raw.trim();
    if (s.startsWith('\uFEFF')) {
      s = s.substring(1).trim();
    }
    // Markdown fences often wrap pasted URIs
    s = s.replaceAll(RegExp(r'^```[\w-]*\s*', multiLine: true), '');
    s = s.replaceAll(RegExp(r'\s*```\s*$'), '');
    s = s.trim();

    if ((s.startsWith('"') && s.endsWith('"')) ||
        (s.startsWith("'") && s.endsWith("'"))) {
      s = s.substring(1, s.length - 1).trim();
    }

    // Prefer the substring that starts with nbvpn:
    final lower = s.toLowerCase();
    final marker = lower.indexOf('nbvpn:');
    if (marker >= 0) {
      final from = s.substring(marker);
      if (from.contains('\n') || from.contains('\r')) {
        s = from.split(RegExp(r'[\r\n]+')).first.trim();
      } else {
        s = from.trim();
      }
    }

    // Trailing quote/punctuation sometimes left after extracting from prose
    s = s.replaceAll(RegExp(r'''["'`]+$'''), '');

    // SSH / messengers often wrap long URIs across lines
    s = s.replaceAll(RegExp(r'\s+'), '');
    return s;
  }

  /// Accepts a raw paste: `nbvpn:` URI **or** NbVpnProfile JSON object.
  static NbVpnProfile parseFlexibleImport(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw ProfileException(
        ProfileErrorCode.uriDecode,
        detail: '内容为空',
      );
    }
    final look = sanitizeUriInput(trimmed);
    if (look.toLowerCase().startsWith('$uriScheme:')) {
      return decodeUri(look);
    }
    // JSON profile (optionally with surrounding noise stripped to first `{`…`}`)
    var jsonText = trimmed;
    final brace = jsonText.indexOf('{');
    final last = jsonText.lastIndexOf('}');
    if (brace >= 0 && last > brace) {
      jsonText = jsonText.substring(brace, last + 1);
    }
    return parseJsonString(jsonText);
  }

  static NbVpnProfile decodeUri(String uri) {
    final trimmed = sanitizeUriInput(uri);
    if (!trimmed.startsWith('$uriScheme:')) {
      throw ProfileException(ProfileErrorCode.uriScheme);
    }
    final rest = trimmed.substring(uriScheme.length + 1);
    final q = rest.indexOf('?');
    if (q < 0) {
      throw ProfileException(
        ProfileErrorCode.uriDecode,
        detail: "缺少 '?' 载荷",
      );
    }
    final verPart = rest.substring(0, q);
    final payload = rest.substring(q + 1);
    if (verPart != '1') {
      throw ProfileException(ProfileErrorCode.uriVersion);
    }
    late List<int> raw;
    try {
      raw = _decodeBase64Url(payload);
    } catch (_) {
      throw ProfileException(ProfileErrorCode.uriDecode);
    }
    late Map<String, dynamic> map;
    try {
      final decoded = jsonDecode(utf8.decode(raw));
      if (decoded is! Map) {
        throw ProfileException(ProfileErrorCode.uriDecode);
      }
      map = decoded.cast<String, dynamic>();
    } catch (e) {
      if (e is ProfileException) rethrow;
      throw ProfileException(ProfileErrorCode.uriDecode);
    }
    final profile = NbVpnProfile.fromJson(map);
    validate(profile);
    return profile;
  }

  static NbVpnProfile parseJsonBytes(List<int> data) {
    late Map<String, dynamic> map;
    try {
      final decoded = jsonDecode(utf8.decode(data));
      if (decoded is! Map) {
        throw ProfileException(ProfileErrorCode.uriDecode);
      }
      map = decoded.cast<String, dynamic>();
    } catch (e) {
      if (e is ProfileException) rethrow;
      throw ProfileException(ProfileErrorCode.uriDecode);
    }
    final profile = NbVpnProfile.fromJson(map);
    validate(profile);
    return profile;
  }

  static NbVpnProfile parseJsonString(String text) =>
      parseJsonBytes(utf8.encode(text));

  static List<int> _decodeBase64Url(String payload) {
    var s = payload.replaceAll('-', '+').replaceAll('_', '/');
    final pad = (4 - s.length % 4) % 4;
    s = s.padRight(s.length + pad, '=');
    return base64.decode(s);
  }

  /// wg-quick compatible client config.
  ///
  /// When [excludePrivateNetworks] is true (and [forceFullTunnel] is false),
  /// `0.0.0.0/0` / `::/0` in the profile are rewritten to the official WireGuard
  /// exclude-private CIDR decomposition so LAN / car / Bluetooth traffic stays
  /// off the tunnel.
  ///
  /// [forceFullTunnel] (leak protection) wins over exclude-private.
  /// [bypassCidrs] are IPv4 ranges removed from AllowedIPs (direct / whitelist).
  /// [endpointOverride] replaces the Endpoint line (used by obfs2: the WG
  /// endpoint becomes the local bridge, not the public server address).
  static String toWireGuardConf(
    NbVpnProfile p, {
    bool excludePrivateNetworks = false,
    bool forceFullTunnel = false,
    Iterable<String> bypassCidrs = const [],
    String? endpointOverride,
  }) {
    validate(p);
    final allowedIPs = SplitTunnel.resolveAllowedIPs(
      p.server.allowedIPs,
      excludePrivate: excludePrivateNetworks,
      forceFullTunnel: forceFullTunnel,
      bypassCidrs: bypassCidrs,
    );
    final ka = (p.server.persistentKeepalive == null ||
            p.server.persistentKeepalive == 0)
        ? defaultKeepalive
        : p.server.persistentKeepalive!;
    final endpoint = endpointOverride ?? p.server.activeEndpoint;
    final buf = StringBuffer()
      ..writeln('[Interface]')
      ..writeln('PrivateKey = ${p.client.privateKey}')
      ..writeln('Address = ${p.client.address.join(', ')}')
      ..writeln('DNS = ${p.client.dns.join(', ')}');
    if (p.client.mtu != null && p.client.mtu! > 0) {
      buf.writeln('MTU = ${p.client.mtu}');
    }
    buf
      ..writeln()
      ..writeln('[Peer]')
      ..writeln('PublicKey = ${p.server.publicKey}')
      ..writeln('Endpoint = $endpoint')
      ..writeln('AllowedIPs = ${allowedIPs.join(', ')}')
      ..writeln('PersistentKeepalive = $ka');
    final psk = p.server.presharedKey;
    if (psk != null && psk.isNotEmpty) {
      buf.writeln('PresharedKey = $psk');
    }
    // obfs2: expose the transport server host(s) to the provider so it can
    // exclude them from the tunnel routes (avoids the bridge loop). The WG
    // parser treats `#` as a comment; PacketTunnelProvider reads this marker.
    final obfs = p.obfs;
    if (obfs != null && obfs.isObfs2) {
      final hosts = obfs.entries
          .map((e) => e.split(':').first.trim())
          .where((h) => h.isNotEmpty && h != '127.0.0.1' && h != 'localhost')
          .join(',');
      if (hosts.isNotEmpty) {
        buf.writeln('# obfs-servers=$hosts');
      }
    }
    return buf.toString();
  }
}
