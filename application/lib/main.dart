import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const TfcApp());
}

class TfcApp extends StatelessWidget {
  const TfcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TFC Multicanal',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
      home: const HomeScreen(),
    );
  }
}
