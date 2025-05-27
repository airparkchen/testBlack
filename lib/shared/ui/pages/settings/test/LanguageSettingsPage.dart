import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whitebox/shared/providers/locale_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final appLocalizations = AppLocalizations.of(context)!;

    // 獲取當前語言
    final currentLocale = localeProvider.locale;

    return Scaffold(
      appBar: AppBar(
        title: Text(appLocalizations.languageSelector),
        backgroundColor: Colors.grey[300],
      ),
      body: Column(
        children: [
          // 頁面標題
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              appLocalizations.languageSelector,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // 語言列表
          Expanded(
            child: ListView(
              children: [
                // 英文選項
                _buildLanguageTile(
                  context,
                  'English',
                  'en',
                  '🇺🇸',
                  currentLocale,
                ),

                // 繁體中文選項
                _buildLanguageTile(
                  context,
                  '繁體中文',
                  'zh_TW',
                  '🇹🇼',
                  currentLocale,
                ),

                // 阿拉伯文選項
                _buildLanguageTile(
                  context,
                  'العربية',
                  'ar',
                  '🇸🇦',
                  currentLocale,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 構建語言選項列表項
  Widget _buildLanguageTile(
      BuildContext context,
      String label,
      String languageCode,
      String flag,
      Locale currentLocale,
      ) {
    // 檢查是否是當前選中的語言
    final isSelected = (languageCode == 'zh_TW')
        ? (currentLocale.languageCode == 'zh' && currentLocale.countryCode == 'TW')
        : (currentLocale.languageCode == languageCode);

    return ListTile(
      leading: Text(
        flag,
        style: const TextStyle(fontSize: 24),
      ),
      title: Text(
        label,
        style: const TextStyle(fontSize: 18),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: Colors.green)
          : null,
      tileColor: isSelected ? Colors.grey[200] : null,
      onTap: () {
        // 設置新語言
        Locale newLocale;
        if (languageCode == 'zh_TW') {
          newLocale = const Locale('zh', 'TW');
        } else {
          newLocale = Locale(languageCode);
        }

        // 更新語言設定
        Provider.of<LocaleProvider>(context, listen: false)
            .setLocale(newLocale);
      },
    );
  }
}