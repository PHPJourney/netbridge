import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'desktop/desktop_tray.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'services/settings_store.dart';
import 'state/app_controller.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
          home: HomeScreen(controller: _controller),
        );
      },
    );
  }
}
