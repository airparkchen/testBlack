import 'package:flutter/material.dart';

/// 應用程式主題設定檔
///
/// 此檔案定義了整個應用程式的視覺風格，包括顏色、字體、間距等
/// 所有UI元件應使用此處定義的常量，以確保視覺一致性

// 顏色系統
class AppColors {
  // 主要背景顏色
  static const Color mainBackgroundColor = Colors.white;

  // 次要背景顏色 (淺灰色，用於表單區域)
  static const Color secondaryBackgroundColor = Color(0xFFEFEFEF);

  // 輸入區域背景色
  static const Color inputBackgroundColor = Colors.white;

  // 按鈕背景色
  static const Color buttonBackgroundColor = Color(0xFFDDDDDD);

  // 按鈕邊框色
  static const Color buttonBorderColor = Color(0xFFD0D0D0);

  // 文字顏色
  static const Color primaryTextColor = Colors.black;
  static const Color secondaryTextColor = Colors.grey;
  static const Color buttonTextColor = Colors.black;

  // 邊框顏色
  static const Color primaryBorderColor = Color(0xFFBDBDBD); // Colors.grey[400]
  static const Color secondaryBorderColor = Color(0xFFE0E0E0); // Colors.grey[300]

  // 狀態顏色
  static const Color activeColor = Colors.black;
  static const Color inactiveColor = Color(0xFFEEEEEE); // Colors.grey[200]

  // 錯誤顏色
  static const Color errorColor = Colors.red;
}

// 文字樣式
class AppTextStyles {
  // 字體家族常量
  static const String fontFamily = 'Segoe UI';

  // 大標題 (例如頁面標題)
  static const TextStyle titleStyle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryTextColor,
    fontFamily: fontFamily,
  );

  // 中標題 (例如組件標題)
  static const TextStyle subtitleStyle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryTextColor,
    fontFamily: fontFamily,
  );

  // 小標題 (例如輸入區標籤)
  static const TextStyle labelStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.normal,
    color: AppColors.primaryTextColor,
    fontFamily: fontFamily,
  );

  // 正文文字
  static const TextStyle bodyStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.primaryTextColor,
    fontFamily: fontFamily,
  );

  // 小型文字 (例如次要資訊)
  static const TextStyle smallTextStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.secondaryTextColor,
    fontFamily: fontFamily,
  );

  // 微型文字 (例如MAC地址顯示)
  static const TextStyle microTextStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.normal,
    color: AppColors.secondaryTextColor,
    fontFamily: fontFamily,
  );

  // 按鈕文字
  static const TextStyle buttonTextStyle = TextStyle(
    fontSize: 18,
    color: AppColors.buttonTextColor,
    fontFamily: fontFamily,
  );

  // 錯誤提示文字
  static const TextStyle errorTextStyle = TextStyle(
    fontSize: 12,
    color: AppColors.errorColor,
    fontFamily: fontFamily,
  );
}

// 間距系統
class AppSpacing {
  // 頁面佈局間距
  static const double pagePadding = 20.0;
  static const double topMarginRatio = 0.05; // 螢幕高度的5%
  static const double componentSpacing = 20.0;

  // 元素內部間距
  static const double buttonPadding = 16.0;
  static const double inputFieldPadding = 16.0;
  static const double containerPadding = 25.0;

  // 元素間間距
  static const double smallElementSpacing = 8.0;
  static const double mediumElementSpacing = 16.0;
  static const double largeElementSpacing = 30.0;
  static const double buttonSpacing = 20.0;
}

// 元素尺寸
class AppSizes {
  // 按鈕尺寸
  static const double standardButtonHeight = 56.0;

  // 輸入框尺寸
  static const double standardInputHeight = 56.0;

  // 設備方塊尺寸
  static const double deviceBoxSize = 80.0;
  static const double deviceBoxSpacing = 20.0;

  // 步驟導航元件尺寸
  static const double stepperCircleSize = 60.0;
  static const double stepperLineHeight = 4.0;

  // Icon 尺寸
  static const double smallIconSize = 18.0;
  static const double mediumIconSize = 24.0;
  static const double largeIconSize = 30.0;
}

// 按鈕樣式
class AppButtonStyles {
  // 標準按鈕樣式
  static ButtonStyle standardButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.buttonBackgroundColor,
    foregroundColor: AppColors.buttonTextColor,
    elevation: 0,
    padding: const EdgeInsets.symmetric(
      vertical: AppSpacing.buttonPadding,
      horizontal: AppSpacing.buttonPadding,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(0),
      side: BorderSide(color: AppColors.primaryBorderColor),
    ),
    minimumSize: const Size(100, AppSizes.standardButtonHeight),
    textStyle: const TextStyle(
      fontFamily: AppTextStyles.fontFamily,
      fontSize: 18,
    ),
  );

  // 禁用按鈕樣式
  static ButtonStyle disabledButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.inactiveColor,
    foregroundColor: AppColors.secondaryTextColor,
    elevation: 0,
    padding: const EdgeInsets.symmetric(
      vertical: AppSpacing.buttonPadding,
      horizontal: AppSpacing.buttonPadding,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(0),
      side: BorderSide(color: AppColors.secondaryBorderColor),
    ),
    minimumSize: const Size(100, AppSizes.standardButtonHeight),
    textStyle: const TextStyle(
      fontFamily: AppTextStyles.fontFamily,
      fontSize: 18,
    ),
  );

  // 方形按鈕樣式 (用於設備選擇)
  static ButtonStyle squareButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.buttonBackgroundColor,
    foregroundColor: AppColors.buttonTextColor,
    elevation: 0,
    padding: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(0),
      side: BorderSide(color: AppColors.secondaryBorderColor),
    ),
    textStyle: const TextStyle(
      fontFamily: AppTextStyles.fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.bold,
    ),
  );
}

// 輸入框樣式
class AppInputDecorations {
  // 標準輸入框樣式
  static InputDecoration standardInputDecoration = InputDecoration(
    filled: true,
    fillColor: AppColors.inputBackgroundColor,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.inputFieldPadding,
      vertical: AppSpacing.inputFieldPadding,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(2),
      borderSide: BorderSide(color: AppColors.primaryBorderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(2),
      borderSide: BorderSide(color: AppColors.primaryBorderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(2),
      borderSide: BorderSide(color: AppColors.primaryTextColor),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(2),
      borderSide: BorderSide(color: AppColors.errorColor),
    ),
    errorStyle: AppTextStyles.errorTextStyle,
    hintStyle: TextStyle(
      fontFamily: AppTextStyles.fontFamily,
      color: Colors.grey[400],
    ),
  );

  // 下拉選單樣式
  static InputDecoration dropdownDecoration = InputDecoration(
    filled: true,
    fillColor: AppColors.inputBackgroundColor,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.inputFieldPadding,
      vertical: AppSpacing.inputFieldPadding,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(2),
      borderSide: BorderSide(color: AppColors.primaryBorderColor),
    ),
    hintStyle: TextStyle(
      fontFamily: AppTextStyles.fontFamily,
      color: Colors.grey[400],
    ),
  );
}

// 容器樣式
class AppContainerStyles {
  // 標準容器裝飾
  static BoxDecoration standardContainerDecoration = BoxDecoration(
    color: AppColors.secondaryBackgroundColor,
    borderRadius: BorderRadius.circular(0),
  );

  // 輸入表單容器
  static BoxDecoration formContainerDecoration = BoxDecoration(
    color: AppColors.secondaryBackgroundColor,
    borderRadius: BorderRadius.circular(0),
  );

  // 設備容器裝飾
  static BoxDecoration deviceBoxDecoration = BoxDecoration(
    color: AppColors.buttonBackgroundColor,
    border: Border.all(color: AppColors.secondaryBorderColor),
  );
}

// 應用程式主題設定
class AppTheme {
  // 獲取全局主題數據
  static ThemeData getThemeData() {
    return ThemeData(
      primarySwatch: Colors.grey,
      scaffoldBackgroundColor: AppColors.mainBackgroundColor,
      fontFamily: AppTextStyles.fontFamily, // 設置全局字體
      textTheme: TextTheme(
        // 使用新版的文字主題設定（Flutter 2.0以後）
        displayLarge: AppTextStyles.titleStyle,
        displayMedium: AppTextStyles.subtitleStyle,
        bodyLarge: AppTextStyles.bodyStyle,
        bodyMedium: AppTextStyles.smallTextStyle,
        // 添加更多文字樣式...
        labelLarge: AppTextStyles.labelStyle,
        titleMedium: AppTextStyles.subtitleStyle.copyWith(fontWeight: FontWeight.w500),
        titleSmall: AppTextStyles.labelStyle.copyWith(fontWeight: FontWeight.w500),
      ),
      // 按鈕主題
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: AppButtonStyles.standardButtonStyle,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: TextStyle(fontFamily: AppTextStyles.fontFamily),
        ),
      ),
      // 輸入框主題
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBackgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
        ),
        hintStyle: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          color: Colors.grey[400],
        ),
        // 確保所有輸入文字使用 Segoe UI
        labelStyle: TextStyle(fontFamily: AppTextStyles.fontFamily),
        helperStyle: TextStyle(fontFamily: AppTextStyles.fontFamily),
        errorStyle: TextStyle(fontFamily: AppTextStyles.fontFamily, color: AppColors.errorColor),
        // 確保輸入文字使用 Segoe UI
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.inputFieldPadding,
          vertical: AppSpacing.inputFieldPadding,
        ),
      ),
      // 對話框主題
      dialogTheme: DialogTheme(
        titleTextStyle: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: AppColors.primaryTextColor,
        ),
        contentTextStyle: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 16,
          color: AppColors.primaryTextColor,
        ),
      ),
      // 應用欄主題
      appBarTheme: AppBarTheme(
        titleTextStyle: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryTextColor,
        ),
      ),
      // 確保所有文字欄位都使用 Segoe UI
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primaryTextColor,
      ),
    );
  }
}