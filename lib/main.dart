import 'package:flutter/material.dart';
import 'package:whitebox/shared/ui/pages/initialization/AddDevices.dart';
import 'package:whitebox/shared/ui/pages/initialization/WifiConnectionPage.dart';
import 'package:whitebox/shared/ui/pages/initialization/QrCodeScannerPage.dart';
// Fix the import path
import 'package:whitebox/shared/ui/pages/test/TestPage.dart';

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
      ),
      home: const StepperTestPage(),
    );
  }
}