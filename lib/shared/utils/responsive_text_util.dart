// ============================================================================
// 導入依賴 (Imports)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
// import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // 取消註解以啟用多語系

// ============================================================================
// 配置層 (Configuration Layer)
// ============================================================================

/// 全域響應式文字配置
class GlobalResponsiveTextConfig {
  // 字體大小縮放因子配置
  static const Map<String, double> screenScaleFactors = {
    'extraSmall': 0.8,  // < 360px
    'small': 0.9,       // 360-374px
    'medium': 1.0,      // 375-413px
    'large': 1.1,       // 414-479px
    'extraLarge': 1.2,  // ≥ 480px
  };

  // 字體大小範圍預設值
  static const Map<String, Map<String, double>> defaultFontRanges = {
    'heading1': {'max': 32.0, 'min': 20.0},  // 頁面主標題
    'heading2': {'max': 28.0, 'min': 18.0},  // 區塊標題
    'heading3': {'max': 24.0, 'min': 16.0},  // 小標題
    'title': {'max': 22.0, 'min': 16.0},     // 對話框標題
    'subtitle': {'max': 18.0, 'min': 14.0},  // 副標題
    'body': {'max': 16.0, 'min': 12.0},      // 正文內容
    'caption': {'max': 14.0, 'min': 10.0},   // 提示文字
    'small': {'max': 12.0, 'min': 9.0},      // 小字
    'button': {'max': 18.0, 'min': 14.0},    // 按鈕文字
  };

  // 行數限制預設值
  static const Map<String, int> defaultMaxLines = {
    'heading1': 2, 'heading2': 2, 'heading3': 2,
    'title': 2, 'subtitle': 2, 'body': 3,
    'caption': 2, 'small': 2, 'button': 1,
  };

  static const String defaultFontFamily = 'Roboto';
  static const double stepGranularity = 0.5;

  // 多語系配置
  static bool enableGlobalL10n = false;  // 全域多語系開關
}

// ============================================================================
// 服務層 (Services Layer)
// ============================================================================

/// 多語系處理服務
class L10nService {
  /// 處理文字的多語系轉換
  static String processText(BuildContext context, String text, {bool useL10n = false}) {
    if (!useL10n || !GlobalResponsiveTextConfig.enableGlobalL10n) {
      return text;
    }

    // 🎯 這裡是多語系處理邏輯
    // 取消下方註解以啟用多語系功能：

    // final l10n = AppLocalizations.of(context);
    // return _getLocalizedText(l10n, text);

    // 暫時返回原文字（未啟用多語系時）
    return text;
  }

/// 根據 key 獲取本地化文字（需要根據你的 l10n 設定調整）
/*
  static String _getLocalizedText(AppLocalizations l10n, String key) {
    // 根據 key 返回對應的多語系文字
    switch (key) {
      case 'wifi_qr_scanner_title':
        return l10n.wifiQrScannerTitle;
      case 'back_button':
        return l10n.backButton;
      case 'next_button':
        return l10n.nextButton;
      case 'wifi_detected_title':
        return l10n.wifiDetectedTitle;
      case 'tap_to_focus':
        return l10n.tapToFocus;
      default:
        return key; // 找不到對應翻譯時返回原 key
    }
  }
  */
}

/// 響應式文字計算服務
class ResponsiveTextService {
  /// 計算螢幕縮放因子
  static double calculateScreenScaleFactor(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth < 360) return GlobalResponsiveTextConfig.screenScaleFactors['extraSmall']!;
    if (screenWidth < 375) return GlobalResponsiveTextConfig.screenScaleFactors['small']!;
    if (screenWidth < 414) return GlobalResponsiveTextConfig.screenScaleFactors['medium']!;
    if (screenWidth < 480) return GlobalResponsiveTextConfig.screenScaleFactors['large']!;
    return GlobalResponsiveTextConfig.screenScaleFactors['extraLarge']!;
  }

  /// 計算響應式字體大小範圍
  static Map<String, double> calculateFontRange(
      BuildContext context, {
        double? maxSize,
        double? minSize,
        String? presetType,
      }) {
    final scaleFactor = calculateScreenScaleFactor(context);

    double finalMaxSize;
    double finalMinSize;

    if (presetType != null && GlobalResponsiveTextConfig.defaultFontRanges.containsKey(presetType)) {
      final preset = GlobalResponsiveTextConfig.defaultFontRanges[presetType]!;
      finalMaxSize = maxSize ?? preset['max']!;
      finalMinSize = minSize ?? preset['min']!;
    } else {
      finalMaxSize = maxSize ?? 16.0;
      finalMinSize = minSize ?? 12.0;
    }

    return {
      'maxSize': finalMaxSize * scaleFactor,
      'minSize': finalMinSize * scaleFactor,
    };
  }

  /// 判斷是否需要響應式處理
  static bool shouldUseResponsiveText(BuildContext context, String text) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth < 414 || text.length > 15 || text.contains('\n');
  }

  /// 🎯 新增：檢測是否在 AlertDialog 中
  static bool isInAlertDialog(BuildContext context) {
    return context.findAncestorWidgetOfExactType<AlertDialog>() != null;
  }

  /// 獲取預設最大行數
  static int getDefaultMaxLines(String? presetType) {
    return presetType != null && GlobalResponsiveTextConfig.defaultMaxLines.containsKey(presetType)
        ? GlobalResponsiveTextConfig.defaultMaxLines[presetType]!
        : 1;
  }
}

// ============================================================================
// 工具模組 (Utils Layer) - 主要工具類
// ============================================================================

/// 響應式文字工具 - 支援多語系
class ResponsiveTextUtil {
  /// 創建響應式文字 Widget
  static Widget create(
      BuildContext context,
      String text, {
        TextStyle? style,
        double? maxFontSize,
        double? minFontSize,
        int? maxLines,
        TextAlign? textAlign,
        TextOverflow? overflow,
        String? presetType,
        bool? forceResponsive,
        bool useL10n = false,  // 🎯 新增：多語系開關
      }) {
    // 🎯 處理多語系轉換
    final localizedText = L10nService.processText(context, text, useL10n: useL10n);

    // 🎯 新增：檢查是否在 AlertDialog 中，如果是就用安全模式
    final isInDialog = ResponsiveTextService.isInAlertDialog(context);

    if (isInDialog) {
      // AlertDialog 安全模式：使用計算後的固定字體大小
      final fontRange = ResponsiveTextService.calculateFontRange(
        context,
        maxSize: maxFontSize ?? style?.fontSize,
        minSize: minFontSize,
        presetType: presetType,
      );

      final finalMaxLines = maxLines ?? ResponsiveTextService.getDefaultMaxLines(presetType);
      final finalStyle = (style ?? const TextStyle()).copyWith(
        fontSize: fontRange['maxSize'],  // 使用計算後的字體大小
        fontFamily: style?.fontFamily ?? GlobalResponsiveTextConfig.defaultFontFamily,
      );

      return Text(
        localizedText,
        style: finalStyle,
        textAlign: textAlign ?? TextAlign.start,
        maxLines: finalMaxLines,
        overflow: overflow ?? TextOverflow.ellipsis,
      );
    }

    // 原有的響應式邏輯
    final useResponsive = forceResponsive ?? ResponsiveTextService.shouldUseResponsiveText(context, localizedText);

    if (!useResponsive) {
      return Text(
        localizedText,
        style: style,
        textAlign: textAlign ?? TextAlign.start,
        maxLines: maxLines,
        overflow: overflow ?? TextOverflow.ellipsis,
      );
    }

    final fontRange = ResponsiveTextService.calculateFontRange(
      context,
      maxSize: maxFontSize ?? style?.fontSize,
      minSize: minFontSize,
      presetType: presetType,
    );

    final finalMaxLines = maxLines ?? ResponsiveTextService.getDefaultMaxLines(presetType);
    final finalStyle = (style ?? const TextStyle()).copyWith(
      fontFamily: style?.fontFamily ?? GlobalResponsiveTextConfig.defaultFontFamily,
    );

    return AutoSizeText(
      localizedText,
      style: finalStyle,
      textAlign: textAlign ?? TextAlign.start,
      maxLines: finalMaxLines,
      minFontSize: fontRange['minSize']!,
      maxFontSize: fontRange['maxSize']!,
      overflow: overflow ?? TextOverflow.ellipsis,
      stepGranularity: GlobalResponsiveTextConfig.stepGranularity,
    );
  }

  /// 快捷函數：預設類型的響應式文字（支援多語系）
  static Widget heading1(BuildContext context, String text, {TextStyle? style, bool useL10n = false}) {
    return create(context, text, style: style, presetType: 'heading1', forceResponsive: true, useL10n: useL10n);
  }

  static Widget heading2(BuildContext context, String text, {TextStyle? style, bool useL10n = false}) {
    return create(context, text, style: style, presetType: 'heading2', forceResponsive: true, useL10n: useL10n);
  }

  static Widget heading3(BuildContext context, String text, {TextStyle? style, bool useL10n = false}) {
    return create(context, text, style: style, presetType: 'heading3', forceResponsive: true, useL10n: useL10n);
  }

  static Widget title(BuildContext context, String text, {TextStyle? style, bool useL10n = false}) {
    return create(context, text, style: style, presetType: 'title', forceResponsive: true, useL10n: useL10n);
  }

  static Widget subtitle(BuildContext context, String text, {TextStyle? style, bool useL10n = false}) {
    return create(context, text, style: style, presetType: 'subtitle', forceResponsive: true, useL10n: useL10n);
  }

  static Widget body(BuildContext context, String text, {TextStyle? style, bool useL10n = false}) {
    return create(context, text, style: style, presetType: 'body', useL10n: useL10n);
  }

  static Widget caption(BuildContext context, String text, {TextStyle? style, bool useL10n = false}) {
    return create(context, text, style: style, presetType: 'caption', useL10n: useL10n);
  }

  static Widget button(BuildContext context, String text, {TextStyle? style, bool useL10n = false}) {
    return create(context, text, style: style, presetType: 'button', forceResponsive: true, useL10n: useL10n);
  }

  /// 🎯 多語系專用函數：使用 l10n key 而非直接文字
  static Widget l10nHeading1(BuildContext context, String l10nKey, {TextStyle? style}) {
    return create(context, l10nKey, style: style, presetType: 'heading1', forceResponsive: true, useL10n: true);
  }

  static Widget l10nHeading2(BuildContext context, String l10nKey, {TextStyle? style}) {
    return create(context, l10nKey, style: style, presetType: 'heading2', forceResponsive: true, useL10n: true);
  }

  static Widget l10nHeading3(BuildContext context, String l10nKey, {TextStyle? style}) {
    return create(context, l10nKey, style: style, presetType: 'heading3', forceResponsive: true, useL10n: true);
  }

  static Widget l10nTitle(BuildContext context, String l10nKey, {TextStyle? style}) {
    return create(context, l10nKey, style: style, presetType: 'title', forceResponsive: true, useL10n: true);
  }

  static Widget l10nSubtitle(BuildContext context, String l10nKey, {TextStyle? style}) {
    return create(context, l10nKey, style: style, presetType: 'subtitle', forceResponsive: true, useL10n: true);
  }

  static Widget l10nButton(BuildContext context, String l10nKey, {TextStyle? style}) {
    return create(context, l10nKey, style: style, presetType: 'button', forceResponsive: true, useL10n: true);
  }

  static Widget l10nBody(BuildContext context, String l10nKey, {TextStyle? style}) {
    return create(context, l10nKey, style: style, presetType: 'body', useL10n: true);
  }

  static Widget l10nCaption(BuildContext context, String l10nKey, {TextStyle? style}) {
    return create(context, l10nKey, style: style, presetType: 'caption', useL10n: true);
  }

  /// 自定義參數的響應式文字
  static Widget custom(
      BuildContext context,
      String text, {
        required double maxFontSize,
        required double minFontSize,
        TextStyle? style,
        int maxLines = 1,
        TextAlign textAlign = TextAlign.start,
        bool forceResponsive = true,
        bool useL10n = false,  // 🎯 新增：多語系支援
      }) {
    return create(
      context, text,
      style: style, maxFontSize: maxFontSize, minFontSize: minFontSize,
      maxLines: maxLines, textAlign: textAlign, forceResponsive: forceResponsive,
      useL10n: useL10n,
    );
  }

  /// 直接替換現有的 Text Widget（最小修改方式）
  static Widget replace(
      BuildContext context,
      String text, {
        TextStyle? style,
        TextAlign? textAlign,
        int? maxLines,
        TextOverflow? overflow,
        String? presetType,
        bool useL10n = false,  // 🎯 新增：多語系支援
      }) {
    return create(
      context, text,
      style: style, textAlign: textAlign, maxLines: maxLines,
      overflow: overflow, presetType: presetType, useL10n: useL10n,
    );
  }
}