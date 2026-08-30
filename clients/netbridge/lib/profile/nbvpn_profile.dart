/// NbVpnProfile v1 — frozen payload from `03-contract.md`.
class NbVpnProfile {
  const NbVpnProfile({
    required this.v,
    required this.name,
    required this.client,
    required this.server,
    this.obfs,
  });

  final int v;
  final String name;
  final ClientSection client;
  final ServerSection server;

  /// Optional obfs2 transport section (absent for plain WG profiles).
  final ObfsSection? obfs;

  static const supportedVersion = 1;

  Map<String, dynamic> toJson() => {
        'v': v,
        'name': name,
        'client': client.toJson(),
        'server': server.toJson(),
        if (obfs != null) 'obfs': obfs!.toJson(),
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
      obfs: json['obfs'] is Map
          ? ObfsSection.fromJson((json['obfs'] as Map).cast<String, dynamic>())
          : null,
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

/// obfs2 transport section: WireGuard rides a disguised HTTPS tunnel pool.
class ObfsSection {
  const ObfsSection({
    required this.type,
    required this.psk,
    required this.entries,
    this.localUdp = 51822,
    this.insecure = false,
    this.channels = 4,
  });

  /// Transport type, currently `obfs2`.
  final String type;

  /// Hex-encoded pre-shared key (authenticates to the obfs2 server).
  final String psk;

  /// Entry pool: "domain:port" / "ip:port", picked at random per tunnel.
  final List<String> entries;

  /// Local UDP port the obfs2 bridge listens on (WG Endpoint = 127.0.0.1:this).
  final int localUdp;

  /// True when the server uses a self-signed cert (client skips verify).
  final bool insecure;

  /// Parallel tunnel count.
  final int channels;

  bool get isObfs2 => type == 'obfs2' && psk.trim().isNotEmpty && entries.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'type': type,
        'psk': psk,
        'entries': entries,
        if (localUdp > 0) 'localUDP': localUdp,
        if (insecure) 'insecure': true,
        if (channels > 0) 'channels': channels,
      };

  factory ObfsSection.fromJson(Map<String, dynamic> json) {
    return ObfsSection(
      type: json['type']?.toString() ?? '',
      psk: json['psk']?.toString() ?? '',
      entries: _stringList(json['entries']),
      localUdp: json['localUDP'] is num
          ? (json['localUDP'] as num).toInt()
          : 51822,
      insecure: json['insecure'] == true,
      channels: json['channels'] is num ? (json['channels'] as num).toInt() : 4,
    );
  }
}
