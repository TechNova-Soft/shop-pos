import 'package:flutter/material.dart';

import 'features/auth/auth_gate.dart';
import 'services/auto_backup_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AutoBackupService.instance.start();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TechNova Shop POS',
      theme: ThemeData(useMaterial3: true),
      home: const AuthGate(),
    );
  }
}
