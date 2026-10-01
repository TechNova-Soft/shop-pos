import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import 'login_screen.dart';
import 'setup_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<bool> _hasUsersFuture;

  @override
  void initState() {
    super.initState();
    _hasUsersFuture = AuthService.instance.hasUsers();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasUsersFuture,
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

        final hasUsers = snapshot.data ?? false;

        return hasUsers ? const LoginScreen() : const SetupScreen();
      },
    );
  }
}
