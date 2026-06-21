import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MumbaiNavApp());
}

class MumbaiNavApp extends StatelessWidget {
  const MumbaiNavApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MumbaiNav',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeScreen(),
    );
  }
}