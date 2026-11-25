import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'splash_page.dart';

import 'app_locale.dart';
import 'l10n/generated/app_localizations.dart';

import 'auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppLocale.load();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  SemanticsHandle? _webSemantics;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _webSemantics = WidgetsBinding.instance.ensureSemantics();
    }
  }

  @override
  void dispose() {
    _webSemantics?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: AppLocale.current,
      builder: (context, locale, child) {
        return MaterialApp(
          title: 'BiletFlow',
          debugShowCheckedModeBanner: false,

          locale: locale,

          theme: ThemeData(
            primaryColor: AppColors.primaryColor,
            scaffoldBackgroundColor: AppColors.backgroundColor,
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: AppColors.accentColor,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(
                  color: AppColors.borderColor,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(
                  color: AppColors.primaryColor,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(color: Colors.red, width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
            ),
          ),

          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          supportedLocales: AppLocalizations.supportedLocales,

          home: const SplashPage(),
        );
      },
    );
  }
}
