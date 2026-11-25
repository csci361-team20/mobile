// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'BiletFlow';

  @override
  String get login => 'Вход';

  @override
  String get register => 'Регистрация';

  @override
  String get email => 'Электронная почта';

  @override
  String get password => 'Пароль';

  @override
  String get confirmPassword => 'Подтвердите пароль';

  @override
  String get fullName => 'Полное имя';

  @override
  String get forgotPassword => 'Забыли пароль?';

  @override
  String get noAccount => 'Нет аккаунта?';

  @override
  String get alreadyHaveAccount => 'Уже есть аккаунт?';

  @override
  String get loginButton => 'Войти';

  @override
  String get registerButton => 'Создать аккаунт';

  @override
  String get or => 'ИЛИ';

  @override
  String get welcomeBack => 'С возвращением!';

  @override
  String get createAccountTitle => 'Создайте аккаунт';

  @override
  String get preferredLanguage => 'Предпочитаемый язык';

  @override
  String get languageEnglish => 'Английский';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageKazakh => 'Казахский';

  @override
  String get passwordTooShort => 'Пароль должен содержать минимум 8 символов';

  @override
  String get passwordMismatch => 'Пароли не совпадают';

  @override
  String get registrationSuccess => 'Регистрация прошла успешно';

  @override
  String get loginSuccess => 'Вход выполнен успешно';

  @override
  String get invalidCredentials => 'Неверная почта или пароль';

  @override
  String get somethingWentWrong => 'Что-то пошло не так. Попробуйте ещё раз.';

  @override
  String get loading => 'Пожалуйста, подождите...';

  @override
  String get repeatPassword => 'Повторите пароль';

  @override
  String get name => 'Имя';

  @override
  String get enterEmail => 'Введите электронную почту';

  @override
  String get invalidEmail => 'Неверный адрес электронной почты';

  @override
  String get enterValidEmail => 'Введите корректный адрес электронной почты';

  @override
  String get enterPassword => 'Введите пароль';

  @override
  String get passwordMinLength => 'Минимум 8 символов';

  @override
  String get loginFailed => 'Не удалось войти';

  @override
  String get registrationFailed => 'Не удалось зарегистрироваться';

  @override
  String get requestFailed => 'Не удалось выполнить запрос';

  @override
  String get connectionError =>
      'Ошибка подключения. Проверьте интернет-соединение.';

  @override
  String get accountCreated => 'Аккаунт создан! Проверьте свою почту.';

  @override
  String get checkEmailReset =>
      'Проверьте свою почту - ссылка для сброса пароля отправлена.';

  @override
  String get recoverPassword => 'Восстановить пароль';

  @override
  String get loginTab => 'Вход';

  @override
  String get registrationTab => 'Регистрация';

  @override
  String get forgotPasswordTab => 'Забыли пароль';

  @override
  String get emailRequired => 'Введите электронную почту';

  @override
  String get passwordRequired => 'Введите пароль';

  @override
  String get nameRequired => 'Введите имя';

  @override
  String get passwordRecoveryTitle => 'Восстановление пароля';

  @override
  String get repeatPasswordRequired => 'Повторите пароль';

  @override
  String get passwordsDoNotMatch => 'Пароли не совпадают';
}
