import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whitebox/shared/providers/locale_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class LanguageSwitcherComponent extends StatelessWidget {
  // 設定組件類型: dropdown 或 buttons
  final bool useDropdown;

  // 外部間距
  final EdgeInsetsGeometry? padding;

  // 背景色
  final Color? backgroundColor;

  // 文字色
  final Color? textColor;

  const LanguageSwitcherComponent({
    Key? key,
    this.useDropdown = true,
    this.padding,
    this.backgroundColor,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final appLocalizations = AppLocalizations.of(context)!;

    // 獲取當前語言代碼
    String currentLanguage = _getLocaleString(localeProvider.locale);

    // 下拉選單樣式
    if (useDropdown) {
      return Container(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 8.0),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.grey[300],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey[400]!),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: currentLanguage,
            icon: const Icon(Icons.language, size: 20),
            elevation: 16,
            style: TextStyle(
              color: textColor ?? Colors.black,
              fontSize: 14,
            ),
            onChanged: (String? value) {
              if (value == null) return;
              _setLanguage(context, value);
            },
            items: [
              DropdownMenuItem<String>(
                value: 'en',
                child: Text(appLocalizations.english),
              ),
              DropdownMenuItem<String>(
                value: 'ar',
                child: Text(appLocalizations.arabic),
              ),
            ],
          ),
        ),
      );
    }

    // 按鈕樣式
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLanguageButton(
            context,
            'en',
            appLocalizations.english,
            currentLanguage == 'en',
          ),
          const SizedBox(width: 8),
          _buildLanguageButton(
            context,
            'ar',
            appLocalizations.arabic,
            currentLanguage == 'ar',
          ),
        ],
      ),
    );
  }

  // 構建語言選擇按鈕
  Widget _buildLanguageButton(
      BuildContext context,
      String localeCode,
      String label,
      bool isSelected,
      ) {
    return InkWell(
      onTap: () => _setLanguage(context, localeCode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? backgroundColor?.withOpacity(0.8) ?? Colors.grey[700]
              : backgroundColor?.withOpacity(0.3) ?? Colors.grey[300],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected
                ? Colors.grey[700]!
                : Colors.grey[400]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : textColor ?? Colors.black,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // 設置語言
  void _setLanguage(BuildContext context, String localeCode) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);

    // 轉換語言代碼到Locale
    Locale newLocale;
    if (localeCode == 'zh_TW') {
      newLocale = const Locale('zh', 'TW');
    } else {
      newLocale = Locale(localeCode);
    }

    // 設置新語言
    localeProvider.setLocale(newLocale);
  }

  // 將Locale轉為字符串表示
  String _getLocaleString(Locale locale) {
    if (locale.languageCode == 'zh' && locale.countryCode == 'TW') {
      return 'zh_TW';
    }
    return locale.languageCode;
  }
}