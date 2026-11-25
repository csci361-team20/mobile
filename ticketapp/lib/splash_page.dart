import 'package:flutter/material.dart';

import 'auth.dart' show AppColors, AuthPage;
import 'auth_token_storage.dart';
import 'current_user.dart';
import 'homepage.dart';
import 'session_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _failed = false; 

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    setState(() => _failed = false);
    final storage = AuthTokenStorage();

    try {
      final saved = await storage.accessToken();
      if (saved == null) {
        _openAuth();
        return;
      }

      String accessToken = saved;
      CurrentUser user;

      try {
        user = await fetchCurrentUser(accessToken);
      } on UnauthorizedException {
        final newToken = await refreshSession();
        if (newToken == null) {
          await storage.clear();
          _openAuth();
          return;
        }
        accessToken = newToken;
        user = await fetchCurrentUser(newToken);
      }

      _openHome(accessToken, user);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _openAuth() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthPage()),
    );
  }

  void _openHome(String accessToken, CurrentUser user) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => Homepage(accessToken: accessToken, currentUser: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _failed
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off,
                    size: 64,
                    color: AppColors.borderColor,
                  ),
                  const SizedBox(height: 16),
                  const Text('Could not connect to the server'),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _restoreSession,
                    child: const Text('Try again'),
                  ),
                  TextButton(
                    onPressed: _openAuth,
                    child: const Text('Sign in again'),
                  ),
                ],
              )
            : const CircularProgressIndicator(color: AppColors.primaryColor),
      ),
    );
  }
}