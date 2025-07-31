import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';   //幀數限制
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
import 'package:whitebox/shared/utils/jwt_auto_relogin.dart';
import 'package:whitebox/shared/ui/components/basic/test/language_test_wrapper.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:whitebox/shared/providers/locale_provider.dart';

class BackgroundSettings {
  static String currentBackground = AppBackgrounds.mainBackground;
  static double blurRadius = 0.0;
  static BackgroundMode backgroundMode = BackgroundMode.normal;
  static bool showBackground = true;
}

void main() async {
  // 確保 Flutter 綁定已初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 設定 60Hz 限制 (在所有其他設定之前) 幀數限制
  await _setDisplayModeTo60Hz();

  // 系統設定
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

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    JwtAutoRelogin.instance.initializeNavigator(
      navigatorKey,
      initialRouteName: '/', // 對應到 InitializationPage
    );

    // Provider 包裝
    return ChangeNotifierProvider(
      create: (context) => LocaleProvider(),
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'WhiteBox App',

            // 新增多語系支援
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: LocaleProvider.supportedLocales,
            locale: localeProvider.locale,  // 🔥 現在這個變數有定義了

            theme: ThemeData(
              primarySwatch: Colors.grey,
              scaffoldBackgroundColor: Colors.transparent,
              fontFamily: 'Segoe UI',
            ),
            builder: (context, child) {
              return AppBackgroundWrapper(
                child: LanguageTestWrapper(
                  child: child ?? Container(),
                ),
              );
            },
            home: const InitializationPage(),
          );
        },
      ),
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

//幀數限制
Future<void> _setDisplayModeTo60Hz() async {
  try {
    final modes = await FlutterDisplayMode.supported;
    DisplayMode? targetMode;
    double closestDiff = double.infinity;

    for (final mode in modes) {
      final diff = (mode.refreshRate - 60.0).abs();
      if (diff < closestDiff) {
        closestDiff = diff;
        targetMode = mode;
      }
    }

    if (targetMode != null) {
      await FlutterDisplayMode.setPreferredMode(targetMode);
      print('✅ 設定顯示模式為: ${targetMode.refreshRate}Hz');
    }
  } catch (e) {
    print('❌ 設定顯示模式失敗: $e');
  }
}
