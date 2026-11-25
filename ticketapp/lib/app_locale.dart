import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocale {
  static final ValueNotifier<Locale> current = ValueNotifier<Locale>(
    const Locale('en'),
  );

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('preferred_language') ?? 'en';

    current.value = Locale(languageCode);
  }

  static Future<void> setLocale(String languageCode) async {
    if (!['en', 'ru', 'kk'].contains(languageCode)) return;

    current.value = Locale(languageCode);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferred_language', languageCode);
  }
}
