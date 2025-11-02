import 'package:flutter/material.dart';
import 'screens/main_screen.dart';

void main() {
  runApp(const YamScoreApp());
}

class YamScoreApp extends StatelessWidget {
  const YamScoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Yam's Scores",
      theme: ThemeData(
        colorSchemeSeed: const Color.fromARGB(255, 25, 103, 203),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}