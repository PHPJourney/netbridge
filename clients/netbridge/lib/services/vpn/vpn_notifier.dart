import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'vpn_logger.dart';

/// System notifications for tunnel lifecycle events (connected / failed /
/// disconnected). Best-effort: notification permission denial or platform
/// quirks never break the tunnel itself.
class VpnNotifier {
  VpnNotifier._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static const _channelId = 'netbridge_tunnel';
  static const _channelName = 'NetBridge tunnel';

  static Future<void> init() async {
    if (_initialized) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings();
      const settings =
          InitializationSettings(android: android, iOS: darwin, macOS: darwin);
      await _plugin.initialize(settings);
      _initialized = true;
      VpnLog.info('notifier initialized');
    } catch (e) {
      VpnLog.error('notifier init failed: $e');
    }
  }

  static Future<bool> _requestPermissionIfNeeded() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final impl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (impl == null) return false;
      final granted = await impl.requestNotificationsPermission();
      return granted ?? false;
    } catch (e) {
      VpnLog.error('notifier permission request failed: $e');
      return false;
    }
  }

  static Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;
    try {
      if (!await _requestPermissionIfNeeded()) return;
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'NetBridge tunnel lifecycle events',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      );
      await _plugin.show(id, title, body, details);
    } catch (e) {
      VpnLog.error('notify failed: $e');
    }
  }

  static Future<void> connected(String serverName) {
    return _show(
      id: 1001,
      title: 'NetBridge',
      body: 'Connected to $serverName',
    );
  }

  static Future<void> failed(String reason) {
    return _show(
      id: 1002,
      title: 'NetBridge connection failed',
      body: reason.length > 120 ? '${reason.substring(0, 117)}…' : reason,
    );
  }

  static Future<void> disconnected() {
    return _show(id: 1003, title: 'NetBridge', body: 'Tunnel disconnected');
  }
}
