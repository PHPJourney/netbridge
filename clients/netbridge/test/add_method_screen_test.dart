import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbridge/l10n/app_localizations.dart';
import 'package:netbridge/screens/add/add_method_screen.dart';
import 'package:netbridge/theme.dart';

Widget wrapAddMethod({Locale locale = const Locale('zh')}) {
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
    home: const AddMethodScreen(),
  );
}

void main() {
  testWidgets('add method screen shows all import entries (zh)', (tester) async {
    await tester.pumpWidget(wrapAddMethod());
    await tester.pumpAndSettle();

    expect(find.text('添加服务器'), findsOneWidget);
    expect(find.text('选择导入方式'), findsOneWidget);
    expect(find.text('粘贴 URI / JSON'), findsOneWidget);
    expect(find.text('导入文件'), findsOneWidget);
    expect(find.text('扫描二维码'), findsOneWidget);
    expect(find.text('蓝牙接收'), findsOneWidget);
  });

  testWidgets('add method screen shows import entries (en)', (tester) async {
    await tester.pumpWidget(wrapAddMethod(locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Add server'), findsOneWidget);
    expect(find.text('Choose import method'), findsOneWidget);
    expect(find.text('Paste URI / JSON'), findsOneWidget);
    expect(find.text('Import file'), findsOneWidget);
    expect(find.text('Scan QR code'), findsOneWidget);
    expect(find.text('Bluetooth receive'), findsOneWidget);
  });
}
