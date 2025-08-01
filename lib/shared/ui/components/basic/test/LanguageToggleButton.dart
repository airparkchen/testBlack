import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:whitebox/shared/providers/locale_provider.dart';
import 'package:whitebox/shared/theme/app_theme.dart';

/// 語言功能配置 - 暫時內嵌在此文件中
class LanguageFeatureConfig {
  /// 是否啟用語言切換功能
  /// 記得也要去language_test_wrapper中開啟
  /// true: 顯示所有語言切換按鈕  false: 隱藏所有語言切換按鈕  開關按鈕
  static const bool enableLanguageSwitch = true;

  /// 是否在登入頁面顯示語言切換按鈕
  static const bool showLanguageToggleInLogin = true;

  /// 是否在初始化頁面顯示語言切換按鈕
  static const bool showLanguageToggleInInitialization = true;

  /// 是否在設定頁面顯示語言切換按鈕
  static const bool showLanguageToggleInSettings = true;

  /// 是否在其他頁面顯示語言切換按鈕
  static const bool showLanguageToggleInOtherPages = true;

  /// 檢查是否應該在指定頁面顯示語言切換按鈕
  static bool shouldShowLanguageToggle({required String pageName}) {
    if (!enableLanguageSwitch) return false;

    switch (pageName.toLowerCase()) {
      case 'login':
      case 'loginpage':
        return showLanguageToggleInLogin;
      case 'initialization':
      case 'initializationpage':
        return showLanguageToggleInInitialization;
      case 'settings':
      case 'settingspage':
        return showLanguageToggleInSettings;
      default:
        return showLanguageToggleInOtherPages;
    }
  }

  static bool get isLanguageSwitchEnabled => enableLanguageSwitch;
}

class LanguageToggleButton extends StatelessWidget {
  final double? size;
  final EdgeInsetsGeometry? margin;
  final String? pageName;

  const LanguageToggleButton({
    Key? key,
    this.size,
    this.margin,
    this.pageName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 功能開關檢查
    if (pageName != null) {
      if (!LanguageFeatureConfig.shouldShowLanguageToggle(pageName: pageName!)) {
        return const SizedBox.shrink();
      }
    } else {
      if (!LanguageFeatureConfig.isLanguageSwitchEnabled) {
        return const SizedBox.shrink();
      }
    }

    final localeProvider = Provider.of<LocaleProvider>(context);
    final localizations = AppLocalizations.of(context)!;
    final appTheme = AppTheme();

    // 計算按鈕大小
    double buttonSize = size ?? 45.0;

    // 判斷當前語言
    bool isEnglish = localeProvider.locale.languageCode == 'en';

    return Container(
      margin: margin ?? const EdgeInsets.all(8.0),
      child: GestureDetector(
        onTap: () => _toggleLanguage(context, localeProvider),
        child: appTheme.whiteBoxTheme.buildStandardCard(
          width: buttonSize,
          height: buttonSize,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.language,
                  color: Colors.white,
                  size: buttonSize * 0.4,
                ),
                SizedBox(height: 2),
                Text(
                  isEnglish ? 'EN' : 'AR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: buttonSize * 0.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleLanguage(BuildContext context, LocaleProvider localeProvider) {
    final currentLocale = localeProvider.locale;

    if (currentLocale.languageCode == 'en') {
      localeProvider.setLocale(const Locale('ar'));
    } else {
      localeProvider.setLocale(const Locale('en'));
    }

    final String message = currentLocale.languageCode == 'en'
        ? 'تم التبديل إلى العربية'
        : 'Switched to English';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.primary.withOpacity(0.8),
      ),
    );
  }
}