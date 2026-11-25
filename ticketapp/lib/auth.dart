import 'package:flutter/material.dart';

import 'current_user.dart';
import 'auth_token_storage.dart';
import 'app_locale.dart';
import 'l10n/generated/app_localizations.dart';
import 'homepage.dart';

import 'api_client.dart';

//--------------------------------
// My colors
//--------------------------------
class AppColors {
  static const Color primaryColor = Color(0xffFA6212);
  static const Color borderColor = Color(0xFF333333);
  static const Color accentColor = Color(0xFFFFFFFF);
  static const Color backgroundColor = Color(0xFFEEEEEE);
  static const Color textMain = Color(0xFF000000);
}

//--------------------------------
// My Validators
//--------------------------------
class Validators {
  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter your email';
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Enter a password';
    if (value.length < 8) return 'At least 8 characters';
    return null;
  }
}

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomePage();
  }
}

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);

    final currentLanguage = switch (locale.languageCode) {
      'ru' => 'RU',
      'kk' => 'KK',
      _ => 'EN',
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: PopupMenuButton<String>(
        onSelected: (languageCode) {
          AppLocale.setLocale(languageCode);
        },
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'en', child: Text('🇬🇧  English')),
          PopupMenuItem(value: 'ru', child: Text('🇷🇺  Русский')),
          PopupMenuItem(value: 'kk', child: Text('🇰🇿  Қазақша')),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.borderColor, width: 0.7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.language,
                size: 18,
                color: AppColors.primaryColor,
              ),
              const SizedBox(width: 7),
              Text(
                currentLanguage,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.borderColor,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: AppColors.borderColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Home Page with Bottom Navigation Bar
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;
  final PageController _pageController = PageController();

  final List<Widget> pages = [
    const LoginPage(),
    const RegistrationPage(),
    const ForgotPasswordPage(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        children: pages,
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          setState(() {
            selectedIndex = index;
          });
        },
        selectedItemColor: AppColors.primaryColor,
        unselectedItemColor: AppColors.borderColor,
        backgroundColor: AppColors.accentColor,
        type: BottomNavigationBarType.fixed,
        elevation: 10,

        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.login),
            label: AppLocalizations.of(context)!.loginTab,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_add_alt_1),
            label: AppLocalizations.of(context)!.registrationTab,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.lock_reset),
            label: AppLocalizations.of(context)!.forgotPasswordTab,
          ),
        ],
      ),
    );
  }
}

// Login Page
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      final data = await ApiClient.instance.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      final user = CurrentUser.fromJson(data);
      await AppLocale.setLocale(user.preferredLanguage);
      final token = await AuthTokenStorage().accessToken() ?? '';
      if (!mounted) return;
      _passwordController.clear();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => Homepage(accessToken: token, currentUser: user),
        ),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : AppLocalizations.of(context)!.connectionError,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const LanguageSelector(),
                const SizedBox(height: 70),
                Text(
                  AppLocalizations.of(context)!.welcomeBack,
                  style: const TextStyle(
                    fontSize: 35,
                    fontWeight: FontWeight.bold,
                    color: AppColors.borderColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.email,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    final l10n = AppLocalizations.of(context)!;

                    if (value == null || value.trim().isEmpty) {
                      return l10n.enterEmail;
                    }

                    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

                    if (!emailRegex.hasMatch(value.trim())) {
                      return l10n.enterValidEmail;
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 32),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.password,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    final l10n = AppLocalizations.of(context)!;

                    if (value == null || value.isEmpty) {
                      return l10n.enterPassword;
                    }

                    if (value.length < 8) {
                      return l10n.passwordMinLength;
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 32),

                SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            AppLocalizations.of(context)!.loginButton,
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Registration Page
class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      await ApiClient.instance.post(
        '/users/',
        authenticated: false,
        body: {
          'full_name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'preferred_language': AppLocale.current.value.languageCode,
        },
      );
      if (!mounted) return;
      _passwordController.clear();
      _confirmPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.accountCreated)),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : AppLocalizations.of(context)!.connectionError,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(title: const Text('Login')),
      body: SafeArea(
        // status bar avoiding
        child: SingleChildScrollView(
          // Keyboard avoiding
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const LanguageSelector(),
                const SizedBox(height: 24),
                Text(
                  AppLocalizations.of(context)!.createAccountTitle,
                  style: const TextStyle(
                    fontSize: 35,
                    fontWeight: FontWeight.bold,
                    color: AppColors.borderColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                TextFormField(
                  controller: _nameController,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.fullName,
                    prefixIcon: const Icon(Icons.person),
                  ),
                  validator: (value) {
                    final l10n = AppLocalizations.of(context)!;

                    if (value == null || value.trim().isEmpty) {
                      return l10n.nameRequired;
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 32),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.email,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    final l10n = AppLocalizations.of(context)!;

                    if (value == null || value.trim().isEmpty) {
                      return l10n.enterEmail;
                    }

                    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

                    if (!emailRegex.hasMatch(value.trim())) {
                      return l10n.enterValidEmail;
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 32),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.password,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    final l10n = AppLocalizations.of(context)!;

                    if (value == null || value.isEmpty) {
                      return l10n.enterPassword;
                    }

                    if (value.length < 8) {
                      return l10n.passwordMinLength;
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 32),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.confirmPassword,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    final l10n = AppLocalizations.of(context)!;

                    if (value == null || value.isEmpty) {
                      return l10n.repeatPasswordRequired;
                    }

                    if (value != _passwordController.text) {
                      return l10n.passwordsDoNotMatch;
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 32),

                SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            AppLocalizations.of(context)!.registerButton,
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Forgot Password Page
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      final data = await ApiClient.instance.post(
        '/auth/password-reset/request',
        authenticated: false,
        body: {'email': _emailController.text.trim()},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            data is Map && data['detail'] is String
                ? data['detail'] as String
                : 'If an account exists, a reset link has been sent.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : AppLocalizations.of(context)!.connectionError,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // status bar avoiding
        child: SingleChildScrollView(
          // Keyboard avoiding
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const LanguageSelector(),
                const SizedBox(height: 120),
                Text(
                  AppLocalizations.of(context)!.forgotPassword,
                  style: const TextStyle(
                    fontSize: 35,
                    fontWeight: FontWeight.bold,
                    color: AppColors.borderColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.email,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    final l10n = AppLocalizations.of(context)!;

                    if (value == null || value.trim().isEmpty) {
                      return l10n.enterEmail;
                    }

                    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

                    if (!emailRegex.hasMatch(value.trim())) {
                      return l10n.enterValidEmail;
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 32),

                SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(AppLocalizations.of(context)!.recoverPassword),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
