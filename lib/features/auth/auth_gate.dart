import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/shop_profile_service.dart';
import '../shop_profile/shop_profile_screen.dart';
import 'login_screen.dart';
import 'setup_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<_StartupState> _startupFuture;

  @override
  void initState() {
    super.initState();
    _startupFuture = _getStartupState();
  }

  Future<_StartupState> _getStartupState() async {
    final hasUsers = await AuthService.instance.hasUsers();

    if (!hasUsers) {
      return _StartupState.setupAccount;
    }

    final hasShopProfile = await ShopProfileService.instance.hasProfile();

    if (!hasShopProfile) {
      return _StartupState.setupShop;
    }

    return _StartupState.login;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StartupState>(
      future: _startupFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('යෙදුම ආරම්භ කිරීමේදී දෝෂයක් ඇතිවිය.')),
          );
        }

        switch (snapshot.data) {
          case _StartupState.setupAccount:
            return const SetupScreen();

          case _StartupState.setupShop:
            return const ShopProfileScreen(firstSetup: true);

          case _StartupState.login:
            return const LoginScreen();

          case null:
            return const LoginScreen();
        }
      },
    );
  }
}

enum _StartupState { setupAccount, setupShop, login }
