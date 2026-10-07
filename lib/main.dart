import 'package:flutter/material.dart';

import 'features/auth/auth_gate.dart';
import 'services/auto_backup_service.dart';
import 'services/google_drive_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restore previously connected Google account silently.
  // If no saved session exists, the app continues normally.
  try {
    await GoogleDriveService.instance.restoreSavedSignIn();
  } catch (_) {
    // Do not prevent the app from starting if Google sign-in restore fails.
  }

  // Start automatic local + Google Drive backup service.
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
