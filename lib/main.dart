import 'package:flutter/material.dart';
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
import 'package:whitebox/shared/ui/pages/test/NetworkTopoView.dart';

void main() {
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
    // 獲取當前語言設定
    final localeProvider = Provider.of<LocaleProvider>(context);

    return MaterialApp(
      title: 'WhiteBox App',
      // 配置本地化代理
      localizationsDelegates: const [
        AppLocalizations.delegate,  // 暫時註釋，等生成後再啟用
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // 支援的語言列表
      supportedLocales: LocaleProvider.supportedLocales,
      // 使用當前選擇的語言
      locale: localeProvider.locale,
      // 根據語言方向設置textDirection
      builder: (context, child) {
        // 檢查是否為RTL語言
        return Directionality(
          textDirection: localeProvider.isRtl() ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        );
      },
      theme: ThemeData(
        primarySwatch: Colors.grey,
        scaffoldBackgroundColor: const Color(0xFFD9D9D9),
        fontFamily: 'Segoe UI', // 設定全局字體為 Segoe UI
      ),
      home: const InitializationPage(),
    );
  }
}