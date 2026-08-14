import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbridge/l10n/app_localizations.dart';
import 'package:netbridge/main.dart';
import 'package:netbridge/screens/home_screen.dart';
import 'package:netbridge/services/vpn/stub_vpn_tunnel.dart';
import 'package:netbridge/state/app_controller.dart';
import 'package:netbridge/theme.dart';

Widget wrapL10n(Widget home, {Locale locale = const Locale('zh')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildNbTheme(),
    home: home,
  );
}

void main() {
  testWidgets('empty server list shows CTA (zh)', (tester) async {
    final controller = AppController(tunnel: StubVpnTunnel());
    // Skip secure storage bootstrap in unit env — set empty manually.
    controller.loading = false;
    controller.servers = [];

    await tester.pumpWidget(
      wrapL10n(HomeScreen(controller: controller)),
    );
    await tester.pump();

    expect(find.text('网桥 VPN'), findsOneWidget);
    expect(find.text('还没有服务器'), findsOneWidget);
    expect(find.text('添加服务器'), findsWidgets);
    expect(find.textContaining('官方节点'), findsOneWidget);
  });

  testWidgets('empty server list shows CTA (en)', (tester) async {
    final controller = AppController(tunnel: StubVpnTunnel());
    controller.loading = false;
    controller.servers = [];

    await tester.pumpWidget(
      wrapL10n(
        HomeScreen(controller: controller),
        locale: const Locale('en'),
      ),
    );
    await tester.pump();

    expect(find.text('NetBridge VPN'), findsOneWidget);
    expect(find.text('No servers yet'), findsOneWidget);
    expect(find.text('Add server'), findsWidgets);
    expect(find.textContaining('official node'), findsOneWidget);
  });

  testWidgets('app builds', (tester) async {
    // Smoke: NetBridgeApp constructs (bootstrap may hit storage).
    await tester.pumpWidget(const NetBridgeApp());
    await tester.pump();
    // System locale may be en or zh; title is one of the two.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data == '网桥 VPN' || w.data == 'NetBridge VPN'),
      ),
      findsOneWidget,
    );
  });
}
