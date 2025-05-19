# 修改pubspec.yaml 

添加 
	flutter_localizations:
    	  sdk: flutter
  	intl: ^0.19.0 #need 0.19.0 for multi-language
  	
  	# 語言切換
	flutter_intl:
	  enabled: true
	  class_name: AppLocalizations
	  main_locale: en
	  arb_dir: lib/l10n
	  output_dir: lib/generated
	  
# 添加arb 
需要添加第三方插件

# SOP
# Flutter多語系應用標準操作程序 (SOP)

以下是在現有Flutter專案中各頁面/元件應用多語系的標準流程，主要針對英語和阿拉伯語。

## 前置準備

### 1. 確認基礎設定已完成
- ARB語言文件已創建在 `lib/shared/config/language/` 目錄
- pubspec.yaml 已配置多語系支援
- LocaleProvider 已實現並在 main.dart 中配置
- 已執行 `flutter gen-l10n` 生成本地化代碼

### 2. 確認ARB文件內容
確保以下兩個ARB文件包含所有需要的文字：
- `app_en.arb` (英文)
- `app_ar.arb` (阿拉伯文)

## 單個頁面/元件應用多語系的步驟

### 步驟 1: 導入必要的套件

在頁面頂部添加：
```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

### 步驟 2: 獲取本地化實例

在 Widget 的 build 方法中添加：
```dart
final appLocalizations = AppLocalizations.of(context)!;
```

### 步驟 3: 替換硬編碼文字

將硬編碼文字替換為從本地化實例獲取的文字：
```dart
// 修改前
Text('Login')

// 修改後
Text(appLocalizations.login)
```

### 步驟 4: 處理RTL兼容性

確保使用相對方向詞，而不是絕對方向詞：
```dart
// 修改前
Padding(padding: EdgeInsets.only(left: 16.0))

// 修改後
Padding(padding: EdgeInsets.only(start: 16.0))
```

### 步驟 5: 確保構造函數支持Localizations

如果是自定義元件，確保能在Localizations環境中使用：
```dart
class MyCustomWidget extends StatelessWidget {
  const MyCustomWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 在這裡獲取本地化實例
    final appLocalizations = AppLocalizations.of(context)!;
    
    // 使用本地化文字
    return Text(appLocalizations.someText);
  }
}
```

## 頁面示例: StatefulWidget

以下是一個完整的StatefulWidget使用多語系的例子：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ExamplePage extends StatefulWidget {
  const ExamplePage({Key? key}) : super(key: key);

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  bool _isLoading = false;
  
  @override
  Widget build(BuildContext context) {
    // 獲取本地化實例
    final appLocalizations = AppLocalizations.of(context)!;
    
    return Scaffold(
      // 使用本地化標題
      appBar: AppBar(
        title: Text(appLocalizations.pageTitle),
        // 添加語言切換按鈕
        actions: [
          Padding(
            padding: const EdgeInsets.only(end: 16.0), // 使用end而非right
            child: LanguageSwitcherComponent(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          // 使用相對方向詞
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // 在RTL環境中會自動調整
            children: [
              // 使用本地化文字
              Text(
                appLocalizations.welcomeMessage,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(appLocalizations.instructionText),
              const SizedBox(height: 30),
              
              // 使用本地化按鈕文字
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () {
                    setState(() {
                      _isLoading = true;
                    });
                    // 處理邏輯...
                  },
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(appLocalizations.continueButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

## 自定義元件示例

以下是一個自定義元件使用多語系的例子：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class CustomCard extends StatelessWidget {
  final String itemId;
  final VoidCallback onTap;
  
  const CustomCard({
    Key? key,
    required this.itemId,
    required this.onTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // 獲取本地化實例
    final appLocalizations = AppLocalizations.of(context)!;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 使用本地化文字
              Text(
                appLocalizations.itemTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // 使用本地化文字 + 傳入參數
              Text(appLocalizations.itemIdLabel(itemId)),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerEnd, // 在RTL環境中會自動調整
                child: TextButton(
                  onPressed: onTap,
                  child: Text(appLocalizations.viewDetails),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

## 變數文字和複數文字處理

如果您需要在ARB文件中使用變數或處理複數形式，請按照以下方式：

### 在ARB文件中定義

```json
// app_en.arb
{
  "greeting": "Hello, {name}!",
  "itemCount": "{count, plural, =0{No items} =1{1 item} other{{count} items}}",
  "timeAgo": "{hours, plural, =0{Just now} =1{1 hour ago} other{{hours} hours ago}}"
}

// app_ar.arb
{
  "greeting": "مرحبًا، {name}!",
  "itemCount": "{count, plural, =0{لا توجد عناصر} =1{عنصر واحد} other{{count} عناصر}}",
  "timeAgo": "{hours, plural, =0{الآن} =1{منذ ساعة واحدة} other{منذ {hours} ساعات}}"
}
```

### 在代碼中使用

```dart
// 使用帶參數的字符串
Text(appLocalizations.greeting('John'));

// 使用複數形式
Text(appLocalizations.itemCount(items.length));
Text(appLocalizations.timeAgo(3)); // "3 hours ago" 或阿拉伯語對應文字
```

## 完整執行清單

當將多語系應用到現有頁面時，請確保執行以下操作：

1. ✅ 導入 `flutter_gen/gen_l10n/app_localizations.dart`
2. ✅ 在 build 方法中獲取 `AppLocalizations.of(context)!`
3. ✅ 替換所有硬編碼文字為本地化文字
4. ✅ 將 `left`/`right` 改為 `start`/`end` 
5. ✅ 將絕對位置 (如 `Alignment.centerLeft`) 改為相對位置 (如 `Alignment.centerStart`)
6. ✅ 檢查圖標是否需要根據文字方向調整
7. ✅ 測試在英語和阿拉伯語環境下的顯示效果

## 常見問題與解決方案

### 問題1: 本地化字串不顯示，顯示為null或默認值
**解決方案**: 確保已正確運行 `flutter gen-l10n` 並在ARB文件中定義了該字串。

### 問題2: 特定元素在RTL環境下顯示不正確
**解決方案**: 使用 `Directionality` Widget強制設置該元素的方向：
```dart
Directionality(
  textDirection: TextDirection.ltr, // 強制從左到右
  child: YourWidget(),
)
```

### 問題3: 找不到AppLocalizations類
**解決方案**: 確保導入了正確的路徑，如果生成目錄有變化，應該調整導入路徑。

### 問題4: 某些元素不應該在RTL環境下翻轉
**解決方案**: 使用特定的Widget包裝，如:
```dart
Transform(
  transform: Matrix4.identity(),
  transformHitTests: false,
  child: YourWidget(),
)
```

## 新增語言文字的流程

當需要添加新的文字字串時：

1. 在 `app_en.arb` 和 `app_ar.arb` 中添加新的鍵值對
2. 運行 `flutter gen-l10n` 生成更新的本地化代碼
3. 在代碼中使用 `appLocalizations.newKey` 訪問新添加的文字

## 結論

按照以上SOP，您可以系統地將多語系功能應用到整個應用的任何頁面或元件中。專注於英語和阿拉伯語的支持，特別是確保UI在RTL環境下正確顯示。

這種方法可以讓您逐步地將多語系功能應用到現有頁面，同時確保新開發的頁面從一開始就支持多語系。
