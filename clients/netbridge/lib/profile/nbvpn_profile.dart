/// NbVpnProfile v1 — frozen payload from `03-contract.md`.
class NbVpnProfile {
  const NbVpnProfile({
    required this.v,
    required this.name,
    required this.client,
    required this.server,
  });

  final int v;
  final String name;
  final ClientSection client;
  final ServerSection server;

  static const supportedVersion = 1;

  Map<String, dynamic> toJson() => {
        'v': v,
        'name': name,
        'client': client.toJson(),
        'server': server.toJson(),
      };

  factory NbVpnProfile.fromJson(Map<String, dynamic> json) {
    return NbVpnProfile(
      v: _asInt(json['v']),
      name: json['name']?.toString() ?? '',
      client: ClientSection.fromJson(
        (json['client'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      server: ServerSection.fromJson(
        (json['server'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }

  /// Same WireGuard credentials (endpoint + keys), ignoring display name.
  /// Used for duplicate import detection after delete/re-scan.
  bool sameCredentialsAs(NbVpnProfile other) {
    return client.privateKey.trim() == other.client.privateKey.trim() &&
        server.publicKey.trim() == other.server.publicKey.trim() &&
        server.endpoint.trim() == other.server.endpoint.trim() &&
        (server.endpointV6?.trim() ?? '') ==
            (other.server.endpointV6?.trim() ?? '');
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}

class ClientSection {
  const ClientSection({
    required this.privateKey,
    required this.address,
    required this.dns,
    this.mtu,
  });

  final String privateKey;
  final List<String> address;
  final List<String> dns;
  final int? mtu;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'privateKey': privateKey,
      'address': address,
      'dns': dns,
    };
    if (mtu != null && mtu! > 0) {
      map['mtu'] = mtu;
    }
    return map;
  }

  factory ClientSection.fromJson(Map<String, dynamic> json) {
    return ClientSection(
      privateKey: json['privateKey']?.toString() ?? '',
      address: _stringList(json['address']),
      dns: _stringList(json['dns']),
      mtu: json['mtu'] is num ? (json['mtu'] as num).toInt() : null,
    );
  }
}

class ServerSection {
  const ServerSection({
    required this.publicKey,
    required this.endpoint,
    required this.allowedIPs,
    this.endpointV6,
    this.ipv6Enabled = false,
    this.persistentKeepalive,
    this.presharedKey,
  });

  final String publicKey;
  final String endpoint;

  /// Optional IPv6 (or alternate) endpoint; `host:port` / `[ipv6]:port`.
  final String? endpointV6;

  /// When true and [endpointV6] is set, connect via IPv6 endpoint.
  final bool ipv6Enabled;

  final List<String> allowedIPs;
  final int? persistentKeepalive;
  final String? presharedKey;

  /// WireGuard peer Endpoint used at connect time (single active endpoint).
  String get activeEndpoint {
    final v6 = endpointV6?.trim() ?? '';
    if (ipv6Enabled && v6.isNotEmpty) return v6;
    return endpoint.trim();
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'publicKey': publicKey,
      'endpoint': endpoint,
      'allowedIPs': allowedIPs,
      'presharedKey': presharedKey,
    };
    final v6 = endpointV6?.trim() ?? '';
    if (v6.isNotEmpty) {
      map['endpointV6'] = v6;
      if (ipv6Enabled) {
        map['ipv6Enabled'] = true;
      }
    }
    if (persistentKeepalive != null && persistentKeepalive! > 0) {
      map['persistentKeepalive'] = persistentKeepalive;
    }
    return map;
  }

  factory ServerSection.fromJson(Map<String, dynamic> json) {
    final psk = json['presharedKey'];
    final v6Raw = json['endpointV6']?.toString().trim();
    final v6 = (v6Raw == null || v6Raw.isEmpty) ? null : v6Raw;
    return ServerSection(
      publicKey: json['publicKey']?.toString() ?? '',
      endpoint: json['endpoint']?.toString() ?? '',
      endpointV6: v6,
      ipv6Enabled: json['ipv6Enabled'] == true,
      allowedIPs: _stringList(json['allowedIPs']),
      persistentKeepalive: json['persistentKeepalive'] is num
          ? (json['persistentKeepalive'] as num).toInt()
          : null,
      presharedKey: psk?.toString(),
    );
  }
}

List<String> _stringList(dynamic v) {
  if (v is! List) return const [];
  return v.map((e) => e.toString()).toList();
}
