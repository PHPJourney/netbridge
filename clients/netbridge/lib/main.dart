import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'services/settings_store.dart';
import 'state/app_controller.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NetBridgeApp());
}

class NetBridgeApp extends StatefulWidget {
  const NetBridgeApp({super.key});

  @override
  State<NetBridgeApp> createState() => _NetBridgeAppState();
}

class _NetBridgeAppState extends State<NetBridgeApp> {
  late final AppController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AppController();
    _controller.bootstrap();
  }

  @override
  void dispose() {
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
