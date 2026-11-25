import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ticketapp/app_locale.dart';
import 'package:ticketapp/auth.dart';
import 'package:ticketapp/l10n/generated/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.current.value = const Locale('en');
  });

  testWidgets('sign-in form validates without sending an empty request', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: LoginPage()),
      ),
    );
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Enter email'), findsOneWidget);
    expect(find.text('Enter a password'), findsOneWidget);
  });

  test('language choice persists only supported locale codes', () async {
    await AppLocale.setLocale('ru');
    expect(AppLocale.current.value.languageCode, 'ru');
    expect(
      (await SharedPreferences.getInstance()).getString('preferred_language'),
      'ru',
    );
    await AppLocale.setLocale('invalid');
    expect(AppLocale.current.value.languageCode, 'ru');
    await AppLocale.setLocale('kk');
    await AppLocale.load();
    expect(AppLocale.current.value.languageCode, 'kk');
  });
}
