import 'cidr_util.dart';

/// WireGuard "exclude private networks" AllowedIPs decomposition.
///
/// Matches the static CIDR list used by the official WireGuard Android app
/// when replacing `0.0.0.0/0` / `::/0` (see wireguard@lists.zx2c4.com, Jul 2018).
class SplitTunnel {
  SplitTunnel._();

  /// IPv4 public ranges = `0.0.0.0/0` minus RFC1918, link-local, loopback, etc.
  static const ipv4ExcludePrivate = [
    '0.0.0.0/5',
    '8.0.0.0/7',
    '11.0.0.0/8',
    '12.0.0.0/6',
    '16.0.0.0/4',
    '32.0.0.0/3',
    '64.0.0.0/2',
    '128.0.0.0/3',
    '160.0.0.0/5',
    '168.0.0.0/6',
    '172.0.0.0/12',
    '172.32.0.0/11',
    '172.64.0.0/10',
    '172.128.0.0/9',
    '173.0.0.0/8',
    '174.0.0.0/7',
    '176.0.0.0/4',
    '192.0.0.0/9',
    '192.128.0.0/11',
    '192.160.0.0/13',
    '192.169.0.0/16',
    '192.170.0.0/15',
    '192.172.0.0/14',
    '192.176.0.0/12',
    '192.192.0.0/10',
    '193.0.0.0/8',
    '194.0.0.0/7',
    '196.0.0.0/6',
    '200.0.0.0/5',
    '208.0.0.0/4',
  ];

  /// IPv6 public ranges = `::/0` minus ULA, link-local, multicast, etc.
  static const ipv6ExcludePrivate = [
    '::/1',
    '8000::/2',
    'c000::/3',
    'e000::/4',
    'f000::/5',
    'f800::/6',
    'fe00::/9',
    'fec0::/10',
    'ff00::/8',
  ];

  static const _ipv4Default = '0.0.0.0/0';
  static const _ipv6Default = '::/0';

  /// Whether [allowedIPs] looks like a full-tunnel default (`0.0.0.0/0` and/or `::/0`).
  static bool isFullTunnelDefault(Iterable<String> allowedIPs) {
    var v4 = false;
    var v6 = false;
    for (final raw in allowedIPs) {
      final cidr = raw.trim().toLowerCase();
      if (cidr == _ipv4Default) v4 = true;
      if (cidr == _ipv6Default) v6 = true;
    }
    return v4 || v6;
  }

  /// Rewrite full-tunnel defaults to exclude-private CIDR lists when [excludePrivate].
  ///
  /// When [bypassCidrs] is non-empty, those IPv4 ranges are carved out of the
  /// resulting AllowedIPs so traffic to them goes direct (whitelist).
  ///
  /// When [forceFullTunnel] is true (leak-protection mode), [excludePrivate] is
  /// ignored so LAN is not intentionally exposed via route exceptions.
  static List<String> resolveAllowedIPs(
    List<String> allowedIPs, {
    required bool excludePrivate,
    bool forceFullTunnel = false,
    Iterable<String> bypassCidrs = const [],
  }) {
    final useExclude = excludePrivate && !forceFullTunnel;
    List<String> out;
    if (!useExclude || allowedIPs.isEmpty) {
      out = List<String>.from(allowedIPs);
    } else {
      out = <String>[];
      for (final raw in allowedIPs) {
        final cidr = raw.trim();
        switch (cidr) {
          case _ipv4Default:
            out.addAll(ipv4ExcludePrivate);
          case _ipv6Default:
            out.addAll(ipv6ExcludePrivate);
          default:
            if (cidr.isNotEmpty) out.add(cidr);
        }
      }
    }
    final bypass = bypassCidrs
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && looksLikeIpv4Cidr(e))
        .toList();
    if (bypass.isEmpty) return out;
    return applyIpv4BypassCidrs(out, bypass);
  }
}
