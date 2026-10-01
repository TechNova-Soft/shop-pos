import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('මුල් පිටුව')),
      body: const Center(
        child: Text(
          'TechNova Shop POS\n\nගිණුම සාර්ථකව සාදා ඇත.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}
