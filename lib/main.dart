import 'package:flutter/material.dart';
import 'package:whitebox/shared/ui/pages/initialization/WifiConnectionPage.dart';
import 'package:whitebox/shared/ui/pages/initialization/QrCodeScannerPage.dart';
import 'package:whitebox/shared/ui/pages/initialization/InitializationPage.dart';
import 'package:whitebox/shared/ui/pages/initialization/WifiSettingFlowPage.dart';
import 'package:whitebox/shared/ui/pages/initialization/LoginPage.dart';
import 'package:whitebox/shared/ui/pages/test/TestPage.dart';
import 'package:whitebox/shared/ui/pages/test/TestPasswordPage.dart';
import 'package:whitebox/shared/ui/pages/test/SrpLoginTestPage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhiteBox App',
      theme: ThemeData(
        primarySwatch: Colors.grey,
        scaffoldBackgroundColor: const Color(0xFFD9D9D9),
        fontFamily: 'Segoe UI', // 設定全局字體為 Segoe UI
      ),
      home: const TestPasswordPage(),
    );
  }
}