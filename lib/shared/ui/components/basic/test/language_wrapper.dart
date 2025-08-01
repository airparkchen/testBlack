import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // 確保這個引入正確
import 'package:whitebox/shared/providers/locale_provider.dart'; // 確保這個引入正確

// ==================== 配置層 ====================
/// 語言測試配置
class LanguageTestConfig {
  // 按鈕配置
  static const double buttonWidth = 50.0;
  static const double buttonHeight = 30.0;
  static const double topMargin = 10.0;
  static const double rightMargin = 15.0;

  // 顏色配置
  static const Color primaryColor = Color(0xFF9747FF);
  static const Color buttonTextColor = Colors.white;
  static const double buttonOpacity = 0.8;

  // 動畫配置
  static const Duration animationDuration = Duration(milliseconds: 200);
  static const double scaleDownRatio = 0.85;

  // 支援的語言標籤 (與 LocaleProvider 中的 Locale.languageCode 對應)
  static const Map<String, String> supportedLanguageTags = {
    'EN': 'en', // 英文
    'JP': 'ja', // 日文
  };

  // 預設語言標籤，用於按鈕顯示，實際語言由 LocaleProvider 管理
  static const String defaultLanguageDisplay = 'EN';
}

// ==================== 數據層 (簡化，主要透過 Provider 互動) ====================
/// 語言測試狀態管理 (現在它主要是一個與 LocaleProvider 互動的工具類)
class LanguageTestController {
  /// 切換語言
  /// 根據當前語言，切換到下一個支援的語言。
  static void toggleLanguage(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final currentLocaleCode = localeProvider.locale.languageCode;

    final List<String> languageCodes = LanguageTestConfig.supportedLanguageTags.values.toList();
    final currentIndex = languageCodes.indexOf(currentLocaleCode);
    final nextIndex = (currentIndex + 1) % languageCodes.length;
    final nextLanguageCode = languageCodes[nextIndex];

    final nextLocale = Locale(nextLanguageCode);
    localeProvider.setLocale(nextLocale); // 通知 LocaleProvider 改變 Locale

    print('🌐 語言切換至: ${nextLocale.languageCode.toUpperCase()}');
  }

  /// 獲取語言切換訊息
  /// 這個訊息應該來自 AppLocalizations，但為了符合你原有的邏輯，
  /// 我們也可以從這裡提供一個簡單的基於 Locale 的訊息。
  static String getSwitchMessage(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final currentLangCode = localeProvider.locale.languageCode;

    switch (currentLangCode) {
      case 'en':
        return 'Switched to English';
      case 'ja':
        return '日本語に切り替えました';
      default:
        return 'Language switched';
    }
  }
}

// ==================== 介面層 ====================
/// 語言測試包裝器主組件
/// 這個組件現在會監聽 LocaleProvider 的變化，並更新其 UI。
class LanguageTestWrapper extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const LanguageTestWrapper({
    Key? key,
    required this.child,
    this.enabled = false,  //多語系 開關 multi-Language button
  }) : super(key: key);

  @override
  State<LanguageTestWrapper> createState() => _LanguageTestWrapperState();
}

class _LanguageTestWrapperState extends State<LanguageTestWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: LanguageTestConfig.animationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: LanguageTestConfig.scaleDownRatio,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // 當 LocaleProvider 監聽到變化時，觸發 SnackBar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LocaleProvider>(context, listen: false).addListener(_onLocaleChanged);
    });
  }

  @override
  void dispose() {
    // 移除監聽器以避免記憶體洩漏
    Provider.of<LocaleProvider>(context, listen: false).removeListener(_onLocaleChanged);
    _animationController.dispose();
    super.dispose();
  }

  /// 當 LocaleProvider 的語言改變時呼叫
  void _onLocaleChanged() {
    // 確保在 widget 已經被 mount 到 tree 上的情況下才顯示 SnackBar
    if (mounted && widget.enabled) {
      _showLanguageSwitchedMessage();
    }
  }

  /// 顯示語言切換提示 SnackBar
  void _showLanguageSwitchedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.language,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              LanguageTestController.getSwitchMessage(context), // 獲取當前語言的切換訊息
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
        backgroundColor: LanguageTestConfig.primaryColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.1,
          left: 20,
          right: 20,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    // 🔥 透過 Consumer 或 Provider.of 來監聽 LocaleProvider 的變化
    // 這裡使用 Consumer 以便在 Locale 變化時只重建 Consumer 內部，而不需要整個 _LanguageTestWrapperState 重建
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: MediaQuery.of(context).padding.top + LanguageTestConfig.topMargin,
          right: LanguageTestConfig.rightMargin,
          child: Consumer<LocaleProvider>(
            builder: (context, localeProvider, child) {
              // 獲取當前語言的顯示名稱 (例如 'EN' 或 'JP')
              final String currentLanguageDisplay = LanguageTestConfig.supportedLanguageTags.entries
                  .firstWhere(
                    (entry) => entry.value == localeProvider.locale.languageCode,
                orElse: () => LanguageTestConfig.supportedLanguageTags.entries.first, // 預設值
              )
                  .key;

              return LanguageTestButton(
                currentLanguage: currentLanguageDisplay, // 將顯示名稱傳遞給按鈕
                animationController: _animationController,
                scaleAnimation: _scaleAnimation,
                onLanguageToggle: () => _handleLanguageToggle(context), // 傳遞 context 給處理函數
              );
            },
          ),
        ),
      ],
    );
  }

  /// 處理語言切換邏輯 (呼叫 LanguageTestController)
  void _handleLanguageToggle(BuildContext context) {
    LanguageTestController.toggleLanguage(context); // 傳遞 context
    print('🔄 執行語言切換邏輯並更新 Locale...');
  }
}

/// 語言測試按鈕組件
class LanguageTestButton extends StatelessWidget {
  final String currentLanguage; // 現在這個是顯示用的標籤 (EN/JP)
  final AnimationController animationController;
  final Animation<double> scaleAnimation;
  final VoidCallback onLanguageToggle;

  const LanguageTestButton({
    Key? key,
    required this.currentLanguage,
    required this.animationController,
    required this.scaleAnimation,
    required this.onLanguageToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => animationController.forward(),
      onTapUp: (_) {
        animationController.reverse();
        onLanguageToggle(); // 觸發語言切換
      },
      onTapCancel: () => animationController.reverse(),
      child: AnimatedBuilder(
        animation: scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: scaleAnimation.value,
            child: Container(
              width: LanguageTestConfig.buttonWidth,
              height: LanguageTestConfig.buttonHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    LanguageTestConfig.primaryColor,
                    LanguageTestConfig.primaryColor.withOpacity(
                      LanguageTestConfig.buttonOpacity,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: LanguageTestConfig.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.language,
                      color: LanguageTestConfig.buttonTextColor,
                      size: 14,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      currentLanguage, // 顯示當前語言標籤
                      style: const TextStyle(
                        color: LanguageTestConfig.buttonTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}