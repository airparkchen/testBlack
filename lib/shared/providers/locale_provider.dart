import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider with ChangeNotifier {
  // 支援的語言列表
  static const List<Locale> supportedLocales = [
    Locale('en'),       // 英文
    Locale('ja'),       // 日文
  ];

  // 初始語言設為英文
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  // 構造函數，初始化時嘗試讀取存儲的語言設定
  LocaleProvider() {
    _loadSavedLocale();
  }

  // 修正成隨著系統更新
  Future<void> _loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString('languageCode');

      if (languageCode != null) {
        // 使用儲存的語言設定
        _locale = Locale(languageCode);
      } else {
        // 沒有儲存設定時，使用系統語言
        final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;

        // 檢查系統語言是否支援
        if (systemLocale.languageCode == 'ja') {
          _locale = const Locale('ja');
        } else {
          _locale = const Locale('en');  // 預設英文
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('載入語言設定時出錯: $e');
    }
  }
  // 設置新的語言並儲存
  Future<void> setLocale(Locale locale) async {
    // 檢查是否支援該語言
    if (!supportedLocales.contains(locale) &&
        !supportedLocales.any((supportedLocale) =>
        supportedLocale.languageCode == locale.languageCode)) {
      return;
    }

    _locale = locale;

    try {
      // 存儲到 SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('languageCode', locale.languageCode);
      if (locale.countryCode != null) {
        await prefs.setString('countryCode', locale.countryCode!);
      } else {
        await prefs.remove('countryCode');
      }
    } catch (e) {
      debugPrint('儲存語言設定時出錯: $e');
    }

    notifyListeners();
  }

  // 檢查是否是RTL語言 (如阿拉伯文)
  bool isRtl() {
    return _locale.languageCode == 'ar';
  }
}