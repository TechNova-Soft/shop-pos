import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TechNova Shop POS',
      home: Scaffold(
        appBar: AppBar(title: const Text('TechNova Shop POS')),
        body: const Center(
          child: Text('TechNova Shop POS', style: TextStyle(fontSize: 24)),
        ),
      ),
    );
  }
}
