import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

import 'desktop/desktop_tray.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'services/settings_store.dart';
import 'state/app_controller.dart';
import 'theme.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows: second launch activates existing instance (incl. tray-hidden) then exits.
  if (!kIsWeb && Platform.isWindows) {
    await WindowsSingleInstance.ensureSingleInstance(
      args,
      'netbridge_vpn_client',
      bringWindowToFront: true,
      onSecondWindow: (_) async {
        try {
          await windowManager.show();
          await windowManager.focus();
        } catch (_) {}
      },
    );
  }

  final controller = AppController();
  await controller.bootstrap();

  DesktopTrayController? tray;
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    tray = DesktopTrayController(controller);
    await tray.init();
  }

  runApp(NetBridgeApp(controller: controller, tray: tray));
}

class NetBridgeApp extends StatefulWidget {
  const NetBridgeApp({super.key, required this.controller, this.tray});

  final AppController controller;
  final DesktopTrayController? tray;

  @override
  State<NetBridgeApp> createState() => _NetBridgeAppState();
}

class _NetBridgeAppState extends State<NetBridgeApp> {
  AppController get _controller => widget.controller;
  /// Keep a stable navigator across locale-driven MaterialApp rebuilds so
  /// add-server routes are not wiped when the server list notifies.
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  void dispose() {
    widget.tray?.dispose();
    _controller.dispose();
    super.dispose();
  }

  Locale? get _localeOverride => switch (_controller.localeMode) {
        AppLocaleMode.zh => const Locale('zh'),
        AppLocaleMode.en => const Locale('en'),
        AppLocaleMode.system => null,
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: _navKey,
          onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
          debugShowCheckedModeBanner: false,
          theme: buildNbTheme(),
          locale: _localeOverride,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          localeResolutionCallback: (deviceLocale, supported) {
            if (_localeOverride != null) return _localeOverride;
            if (deviceLocale == null) return const Locale('zh');
            for (final l in supported) {
              if (l.languageCode == deviceLocale.languageCode) return l;
            }
            return const Locale('zh');
          },
          // Home listens to controller itself; avoid depending on MaterialApp
          // recreation for list updates.
          home: HomeScreen(controller: _controller),
        );
      },
    );
  }
}
