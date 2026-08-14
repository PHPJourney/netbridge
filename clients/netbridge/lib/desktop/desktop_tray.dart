import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../models/server_entry.dart';
import '../state/app_controller.dart';

/// Windows (and other desktop) close-to-tray + context menu.
///
/// Close button hides the window; VPN stays connected.
/// Tray right-click: show / switch node / connect-disconnect / exit.
class DesktopTrayController with WindowListener, TrayListener {
  DesktopTrayController(this.controller);

  final AppController controller;
  bool _ready = false;
  bool _exiting = false;

  bool get isSupported =>
      !kIsWeb &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  Future<void> init() async {
    if (!isSupported) return;
    await windowManager.ensureInitialized();
    const opts = WindowOptions(
      size: Size(1100, 720),
      minimumSize: Size(800, 560),
      center: true,
      title: '网桥 VPN',
    );
    await windowManager.waitUntilReadyToShow(opts, () async {
      await windowManager.setPreventClose(true);
      await windowManager.show();
      await windowManager.focus();
    });

    windowManager.addListener(this);
    trayManager.addListener(this);
    await _initTrayIcon();
    await rebuildMenu();
    controller.addListener(_onControllerChanged);
    _ready = true;
  }

  Future<void> _initTrayIcon() async {
    // Prefer ICO on Windows; PNG works on others.
    final iconPath = Platform.isWindows
        ? 'assets/branding/tray_icon.ico'
        : 'assets/branding/netbridge_icon_1024.png';
    await trayManager.setIcon(iconPath);
    await trayManager.setToolTip('网桥 VPN');
  }

  void _onControllerChanged() {
    if (!_ready || _exiting) return;
    rebuildMenu();
  }

  Future<void> rebuildMenu() async {
    if (!isSupported) return;
    final items = <MenuItem>[
      MenuItem(key: 'show', label: '显示主窗口'),
      MenuItem.separator(),
    ];

    final servers = controller.servers;
    if (servers.isEmpty) {
      items.add(MenuItem(key: 'no_servers', label: '（尚无已保存节点）', disabled: true));
    } else {
      items.add(MenuItem(key: 'switch_hdr', label: '切换服务器', disabled: true));
      for (final s in servers.take(12)) {
        final active = controller.activeServerId == s.id &&
            controller.status == VpnUiStatus.connected;
        final mark = active ? '✓ ' : '   ';
        items.add(MenuItem(
          key: 'server:${s.id}',
          label: '$mark${_shortName(s)}',
        ));
      }
      if (servers.length > 12) {
        items.add(MenuItem(
          key: 'more',
          label: '…还有 ${servers.length - 12} 个，请打开主窗口',
          disabled: true,
        ));
      }
    }

    items.add(MenuItem.separator());
    final connected = controller.status == VpnUiStatus.connected ||
        controller.status == VpnUiStatus.connecting ||
        controller.status == VpnUiStatus.reconnecting;
    items.add(MenuItem(
      key: connected ? 'disconnect' : 'connect',
      label: connected ? '断开连接' : '连接（当前/首个节点）',
      disabled: !connected && controller.servers.isEmpty,
    ));
    items.add(MenuItem.separator());
    items.add(MenuItem(key: 'exit', label: '退出'));

    await trayManager.setContextMenu(Menu(items: items));
  }

  String _shortName(ServerEntry s) {
    final n = s.localName.trim().isEmpty ? s.profile.name : s.localName;
    if (n.length <= 28) return n;
    return '${n.substring(0, 26)}…';
  }

  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> hideToTray() async {
    await windowManager.hide();
  }

  Future<void> exitApp() async {
    _exiting = true;
    try {
      controller.removeListener(_onControllerChanged);
      await trayManager.destroy();
    } catch (_) {}
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  @override
  void onWindowClose() async {
    // Hide instead of quit — keep VPN session alive.
    await hideToTray();
  }

  @override
  void onTrayIconMouseDown() {
    // Left click: restore window (Windows).
    showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    // tray_manager on Windows/macOS only fires the event; menu must be popped
    // explicitly (setContextMenu alone does not show on right-click).
    if (Platform.isWindows || Platform.isMacOS) {
      trayManager.popUpContextMenu();
    }
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    final key = menuItem.key ?? '';
    if (key == 'show') {
      await showWindow();
      return;
    }
    if (key == 'exit') {
      await exitApp();
      return;
    }
    if (key == 'disconnect') {
      await controller.disconnect();
      await rebuildMenu();
      return;
    }
    if (key == 'connect') {
      final id = controller.activeServerId ??
          (controller.servers.isNotEmpty ? controller.servers.first.id : null);
      if (id != null) {
        await controller.connect(id);
      }
      await rebuildMenu();
      return;
    }
    if (key.startsWith('server:')) {
      final id = key.substring('server:'.length);
      await controller.connect(id);
      await rebuildMenu();
      return;
    }
  }

  Future<void> dispose() async {
    if (!_ready) return;
    controller.removeListener(_onControllerChanged);
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    try {
      await trayManager.destroy();
    } catch (_) {}
  }
}
