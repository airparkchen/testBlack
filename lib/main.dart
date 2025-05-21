import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:whitebox/shared/providers/locale_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:whitebox/shared/ui/pages/initialization/WifiConnectionPage.dart';
import 'package:whitebox/shared/ui/pages/initialization/QrCodeScannerPage.dart';
import 'package:whitebox/shared/ui/pages/initialization/InitializationPage.dart';
import 'package:whitebox/shared/ui/pages/initialization/WifiSettingFlowPage.dart';
import 'package:whitebox/shared/ui/pages/initialization/LoginPage.dart';
import 'package:whitebox/shared/ui/pages/test/TestPage.dart';
import 'package:whitebox/shared/ui/pages/test/TestPasswordPage.dart';
import 'package:whitebox/shared/ui/pages/test/SrpLoginTestPage.dart';
import 'package:whitebox/shared/ui/pages/test/SrpLoginModifiedTestPage.dart';
import 'package:whitebox/shared/ui/pages/test/theme_test_page.dart';
import 'package:whitebox/shared/ui/pages/test/NetworkTopoView.dart';
import 'package:whitebox/shared/theme/app_theme.dart'; // 導入主題
import 'package:whitebox/shared/ui/pages/test/SpeedAreaTestPage.dart';

// 全局背景設置，可以在應用的任何地方訪問
class BackgroundSettings {
  static String currentBackground = AppBackgrounds.mainBackground;
  static double blurRadius = 0.0;
  static BackgroundMode backgroundMode = BackgroundMode.normal;
  static bool showBackground = true;
}

void main() {
  // 除錯設定 (來自主分支)
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null && !message.contains('A RenderFlex overflowed')) {
      print(message);
    }
  };
  // 關閉調試標記和檢查
  debugPaintSizeEnabled = false;
  debugPaintBaselinesEnabled = false;
  debugPaintLayerBordersEnabled = false;
  debugPaintPointersEnabled = false;
  debugRepaintRainbowEnabled = false;

  // 從您的分支整合多語言支援
  runApp(
    // 使用Provider提供語言設定
    ChangeNotifierProvider(
      create: (context) => LocaleProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 獲取當前語言設定 (從您的分支整合)
    final localeProvider = Provider.of<LocaleProvider>(context);

    return MaterialApp(
      title: 'WhiteBox App',
      // 配置本地化代理 (從您的分支整合)
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // 支援的語言列表 (從您的分支整合)
      supportedLocales: LocaleProvider.supportedLocales,
      // 使用當前選擇的語言 (從您的分支整合)
      locale: localeProvider.locale,

      theme: ThemeData(
        primarySwatch: Colors.grey,
        scaffoldBackgroundColor: const Color(0xFFD9D9D9),
        fontFamily: 'Segoe UI', // 設定全局字體為 Segoe UI
      ),

      // 使用自定義的頁面路由構建器，為每個頁面套用背景 (從主分支整合)
      builder: (context, child) {
        // 首先套用RTL方向設定 (從您的分支整合)
        Widget directedChild = Directionality(
          textDirection: localeProvider.isRtl() ? TextDirection.rtl : TextDirection.ltr,
          child: child ?? Container(),
        );

        // 然後套用背景包裝器 (從主分支整合)
        return AppBackgroundWrapper(child: directedChild);
      },

      // 設置初始頁面為NetworkTopoView (根據您的需求)
      home: const NetworkTopoView(),
    );
  }
}



// 創建一個背景包裝器，用於套用全局背景 (從主分支保留)
class AppBackgroundWrapper extends StatelessWidget {
  final Widget child;

  const AppBackgroundWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // 如果不顯示背景，直接返回子組件
    if (!BackgroundSettings.showBackground) {
      return child;
    }

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(BackgroundSettings.currentBackground),
          fit: BoxFit.cover,
          // 根據背景模式應用適當的效果
          colorFilter: BackgroundSettings.backgroundMode != BackgroundMode.normal
              ? ColorFilter.mode(Colors.black.withOpacity(0.3), BlendMode.darken)
              : null,
        ),
      ),
      child: BackgroundSettings.blurRadius > 0
          ? BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: BackgroundSettings.blurRadius,
          sigmaY: BackgroundSettings.blurRadius,
        ),
        child: child,
      )
          : child,
    );
  }
}

// 如果需要為個別頁面關閉背景，可以創建一個無背景的頁面包裝器 (從主分支保留)
class NoBackgroundPage extends StatelessWidget {
  final Widget child;

  const NoBackgroundPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // 臨時關閉背景
    BackgroundSettings.showBackground = false;

    return Builder(
        builder: (context) {
          // 使用 addPostFrameCallback 確保在頁面離開時恢復背景設置
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // 設置一個延遲，確保在導航完成後恢復背景設置
            Future.delayed(Duration.zero, () {
              BackgroundSettings.showBackground = true;
            });
          });

          return child;
        }
    );
  }
}