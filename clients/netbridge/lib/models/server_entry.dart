import '../profile/nbvpn_profile.dart';

/// Local server entry (contract §6). Does not ship built-in servers.
class ServerEntry {
  ServerEntry({
    required this.id,
    required this.localName,
    required this.profile,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  String localName;
  final NbVpnProfile profile;
  final DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'localName': localName,
        'profile': profile.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ServerEntry.fromJson(Map<String, dynamic> json) {
    return ServerEntry(
      id: json['id'] as String,
      localName: json['localName'] as String? ?? '',
      profile: NbVpnProfile.fromJson(
        (json['profile'] as Map).cast<String, dynamic>(),
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

enum VpnUiStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

extension VpnUiStatusLabel on VpnUiStatus {
  /// Kept for callers that lack BuildContext; prefer AppLocalizations in UI.
  String get labelZh => switch (this) {
        VpnUiStatus.disconnected => '未连接',
        VpnUiStatus.connecting => '连接中',
        VpnUiStatus.connected => '已连接',
        VpnUiStatus.reconnecting => '重连中',
        VpnUiStatus.error => '连接错误',
      };
}
