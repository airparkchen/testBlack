import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:whitebox/shared/ui/pages/initialization/WifiConnectionPage.dart';
import 'package:whitebox/shared/ui/pages/initialization/QrCodeScannerPage.dart';
import 'package:whitebox/shared/ui/pages/initialization/InitializationPage.dart';
import 'package:whitebox/shared/ui/pages/initialization/WifiSettingFlowPage.dart';
import 'package:whitebox/shared/ui/pages/initialization/LoginPage.dart';
import 'package:whitebox/shared/ui/pages/test/SpeedAreaTestPage.dart';
import 'package:whitebox/shared/ui/pages/test/TestPage.dart';
import 'package:whitebox/shared/ui/pages/test/MeshTopologyTestPage.dart';
import 'package:whitebox/shared/ui/pages/test/TestPasswordPage.dart';
import 'package:whitebox/shared/ui/pages/test/SrpLoginTestPage.dart';
import 'package:whitebox/shared/ui/pages/test/SrpLoginModifiedTestPage.dart';
import 'package:whitebox/shared/ui/pages/test/NetworkTopoView.dart';
import 'package:whitebox/shared/ui/pages/test/theme_test_page.dart';
import 'package:whitebox/shared/theme/app_theme.dart';
import 'package:whitebox/shared/ui/pages/home/DashboardPage.dart';

class BackgroundSettings {
  static String currentBackground = AppBackgrounds.mainBackground;
  static double blurRadius = 0.0;
  static BackgroundMode backgroundMode = BackgroundMode.normal;
  static bool showBackground = true;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // 添加這行代碼來限制應用方向只能為縱向
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent, // 數值方式確保透明
    systemNavigationBarDividerColor: Colors.transparent,
    statusBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null && !message.contains('A RenderFlex overflowed')) {
      print(message);
    }
  };
  debugPaintSizeEnabled = false;
  debugPaintBaselinesEnabled = false;
  debugPaintLayerBordersEnabled = false;
  debugPaintPointersEnabled = false;
  debugRepaintRainbowEnabled = false;
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
        scaffoldBackgroundColor: Colors.transparent,
        fontFamily: 'Segoe UI',
      ),
      builder: (context, child) {
        return AppBackgroundWrapper(child: child ?? Container());
      },
      home: const InitializationPage(),
    );
  }
}

class AppBackgroundWrapper extends StatelessWidget {
  final Widget child;

  const AppBackgroundWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!BackgroundSettings.showBackground) {
      return child;
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(BackgroundSettings.currentBackground),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
      ),
      child: BackgroundSettings.blurRadius > 0
          ? BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: BackgroundSettings.blurRadius,
          sigmaY: BackgroundSettings.blurRadius,
        ),
        child: Container(
          color: Colors.transparent,
          child: child,
        ),
      )
          : child,
    );
  }
}

class NoBackgroundPage extends StatelessWidget {
  final Widget child;

  const NoBackgroundPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    BackgroundSettings.showBackground = false;

    return Builder(
      builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(Duration.zero, () {
            BackgroundSettings.showBackground = true;
          });
        });
        return child;
      },
    );
  }
}