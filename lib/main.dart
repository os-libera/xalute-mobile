import 'package:flutter/material.dart';
import 'screens/main_navigation.dart';

void main() {
  runApp(const HealthApp());
}

class HealthApp extends StatelessWidget {
  const HealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xalute',
      theme: ThemeData(
        fontFamily: "SeoulNam" , // 앱 폰트
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainNavigation(), // 앱 시작 시 첫 화면
      debugShowCheckedModeBanner: false,
    );
  }
}
