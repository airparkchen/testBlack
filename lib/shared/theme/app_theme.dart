// lib/shared/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'dart:ui';

/// 應用程式顏色常量
class AppColors {
  // 主要顏色
  static const Color primary = Color(0xFF9747FF);
  static const Color primaryDark = Color(0xFF162140);

  // 背景顏色
  static const Color background = Color(0xFFD9D9D9);
  static const Color cardBackground = Color(0xFFEEEEEE);
  static const Color backgroundOverlay = Color(0x40000000); // 背景圖上的半透明覆蓋層

  // 文字顏色
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textLight = Color(0xFFFFFFFF);

  // 狀態顏色
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // 漸層顏色組合
  static const List<Color> purpleBlueGradient = [
    Color(0xFF162140),
    Color(0xFF9747FF),
  ];
}

/// 應用程式背景常量
class AppBackgrounds {
  // 背景圖片路徑
  static const String mainBackground = 'assets/images/background.png';
  static const String background2x = 'assets/images/background_2x.png';
  static const String background3x = 'assets/images/background_3x.png';
  static const String background4x = 'assets/images/background_4x.png';
  static const String background5x = 'assets/images/background_5x.png';
}

/// 背景裝飾器類 - 用於創建各種背景效果
class BackgroundDecorator {
  /// 創建圖片背景
  static BoxDecoration imageBackground({
    required String imagePath,
    BoxFit fit = BoxFit.cover,
    Color? overlayColor,
    double? opacity,
  }) {
    return BoxDecoration(
      image: DecorationImage(
        image: AssetImage(imagePath),
        fit: fit,
        colorFilter: overlayColor != null
            ? ColorFilter.mode(
          overlayColor.withOpacity(opacity ?? 0.5),
          BlendMode.srcOver,
        )
            : null,
      ),
    );
  }

  /// 創建使用適合螢幕大小的背景圖
  static String getResponsiveBackground(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1920) return AppBackgrounds.background5x;
    if (width > 1440) return AppBackgrounds.background4x;
    if (width > 1080) return AppBackgrounds.background3x;
    if (width > 720) return AppBackgrounds.background2x;
    return AppBackgrounds.mainBackground;
  }
}

/// 應用程式文字樣式常量
class AppTextStyles {
  // 標題樣式
  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  // 內文樣式
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  // 特殊樣式
  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.textLight,
  );

  static const TextStyle cardTitleLight = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textLight,
  );
}

/// 應用程式尺寸常量
class AppDimensions {
  // 間距
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;

  // 圓角
  static const double radiusXS = 2.0;
  static const double radiusS = 4.0;
  static const double radiusM = 8.0;
  static const double radiusL = 12.0;
  static const double radiusXL = 16.0;

  // 邊框寬度
  static const double borderWidthThin = 0.5;
  static const double borderWidthRegular = 1.0;
  static const double borderWidthThick = 2.0;

  // 元素高度
  static const double buttonHeight = 48.0;
  static const double inputHeight = 56.0;
  static const double cardHeightSmall = 120.0;
  static const double cardHeightMedium = 180.0;
  static const double cardHeightLarge = 240.0;
}

/// 漸層卡片主題實現
class WhiteBoxTheme {
  // 預設的透明度和模糊設定
  static const double defaultOpacity = 0.6; // 提高透明度（降低不透明度），使背景更容易看到
  static const double defaultBlurRadius = 3.0; // 降低模糊程度，讓背景更清晰

  /// 建立標準漸層卡片
  Widget buildStandardCard({
    required double width,
    required double height,
    Widget? child,
    BorderRadius? borderRadius,
  }) {
    return buildCustomCard(
      width: width,
      height: height,
      borderRadius: borderRadius ?? BorderRadius.circular(AppDimensions.radiusS),
      blurRadius: defaultBlurRadius,
      gradientColors: AppColors.purpleBlueGradient,
      borderColor: AppColors.primary,
      opacity: defaultOpacity,
      child: child,
    );
  }

  /// 建立純色按鈕卡片 - 使用主題色填充
  Widget buildPrimaryColorCard({
    required double width,
    required double height,
    Widget? child,
    BorderRadius? borderRadius,
  }) {
    return buildCustomCard(
      width: width,
      height: height,
      borderRadius: borderRadius ?? BorderRadius.circular(AppDimensions.radiusS),
      blurRadius: defaultBlurRadius,
      gradientColors: [AppColors.primary, AppColors.primary], // 使用純色填充
      borderColor: AppColors.primary,
      opacity: defaultOpacity,
      child: child,
    );
  }
  /// 建立簡單純色按鈕 - 沒有模糊效果和透明度
  Widget buildSimpleColorButton({
    required double width,
    required double height,
    BorderRadius? borderRadius,
    Color backgroundColor = AppColors.primary,
    Widget? child,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius ?? BorderRadius.circular(AppDimensions.radiusS),
      ),
      child: child,
    );
  }
  /// 建立一個帶有外邊距的漸層卡片
  Widget buildCustomCardWithMargin({
    required double width,
    required double height,
    BorderRadius? borderRadius,
    double blurRadius = defaultBlurRadius,
    List<Color> gradientColors = const [
      Color(0xFF162140),
      Color(0xFF9747FF),
    ],
    double gradientAngle = 0.75,
    double opacity = defaultOpacity,
    Color borderColor = const Color(0xFF9747FF),
    double borderOpacity = 0.7,
    double borderWidth = 1.0,
    EdgeInsetsGeometry? margin,
    Widget? child,
  }) {
    // 計算漸層的起點和終點
    final double endX = width + (width * 0.18 * gradientAngle.abs());
    final double endY = height - (height * 0.26 * gradientAngle.abs());

    final BorderRadius finalBorderRadius = borderRadius ?? BorderRadius.circular(AppDimensions.radiusS);

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: finalBorderRadius,
        // 使用Box裝飾器確保支持透明度
        color: Colors.transparent,
      ),
      child: Stack(
        children: [
          // 背景模糊層 - 確保此層有透明效果
          Positioned.fill(
            child: ClipRRect(
              borderRadius: finalBorderRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: blurRadius,
                  sigmaY: blurRadius,
                ),
                child: Container(
                  // 這里使用低透明度的顏色
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
          ),

          // 漸層層 - 使用透明漸層
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: finalBorderRadius,
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment(endX / width, endY / height),
                  colors: gradientColors.map((color) => color.withOpacity(opacity)).toList(),
                ),
                border: Border.all(
                  color: borderColor.withOpacity(borderOpacity),
                  width: borderWidth,
                ),
              ),
            ),
          ),

          // 內容層
          if (child != null) Positioned.fill(child: Center(child: child)),
        ],
      ),
    );
  }

  /// 建立自定義漸層卡片
  Widget buildCustomCard({
    required double width,
    required double height,
    BorderRadius? borderRadius,
    double blurRadius = defaultBlurRadius,
    List<Color> gradientColors = const [
      Color(0xFF162140),
      Color(0xFF9747FF),
    ],
    double gradientAngle = 0.75,
    double opacity = defaultOpacity,
    Color borderColor = const Color(0xFF9747FF),
    double borderOpacity = 0.7,
    double borderWidth = 1.0,
    Widget? child,
  }) {
    // 計算漸層的起點和終點
    final double endX = width + (width * 0.18 * gradientAngle.abs());
    final double endY = height - (height * 0.26 * gradientAngle.abs());

    final BorderRadius finalBorderRadius = borderRadius ?? BorderRadius.circular(AppDimensions.radiusS);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: finalBorderRadius,
        // 使用Box裝飾器確保支持透明度
        color: Colors.transparent,
      ),
      child: Stack(
        children: [
          // 背景模糊層 - 確保此層有透明效果
          Positioned.fill(
            child: ClipRRect(
              borderRadius: finalBorderRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: blurRadius,
                  sigmaY: blurRadius,
                ),
                child: Container(
                  // 這里使用低透明度的顏色
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
          ),

          // 漸層層 - 使用透明漸層
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: finalBorderRadius,
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment(endX / width, endY / height),
                  colors: gradientColors.map((color) => color.withOpacity(opacity)).toList(),
                ),
                border: Border.all(
                  color: borderColor.withOpacity(borderOpacity),
                  width: borderWidth,
                ),
              ),
            ),
          ),

          // 內容層
          if (child != null) Positioned.fill(child: Center(child: child)),
        ],
      ),
    );
  }
}

/// 應用程式主題管理類
///
/// 提供統一的主題管理，包含顏色、文字樣式、尺寸和各種元件主題
class AppTheme {
  // 懶漢式單例模式
  static final AppTheme _instance = AppTheme._internal();

  factory AppTheme() => _instance;

  AppTheme._internal() {
    // 初始化元件主題
    whiteBoxTheme = WhiteBoxTheme(); // 名稱已變更
    // 未來可以在這裡初始化更多元件主題
  }

  // 元件主題實例
  late final WhiteBoxTheme whiteBoxTheme; // 名稱已變更
  // 未來可以在這裡添加更多元件主題
  // late final CustomButtonTheme customButton;

  /// 獲取全局主題數據
  ThemeData getThemeData() {
    return ThemeData(
      primarySwatch: Colors.grey,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Segoe UI',
      textTheme: const TextTheme(
        displayLarge: AppTextStyles.heading1,
        displayMedium: AppTextStyles.heading2,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
      ),
      // 其他主題配置...
    );
  }
}