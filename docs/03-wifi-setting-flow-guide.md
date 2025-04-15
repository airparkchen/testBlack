# Wi-Fi 設定流程實作指南

## 概述

本文檔介紹如何實現 Wi-Fi 設備的設定流程，包括用戶介面實現、組件交互和數據流設計。目前的實現已經包含了基本UI框架，但需要進一步完善數據流和 API 整合。

## 流程架構

整個 Wi-Fi 設定流程基於 JSON 配置文件定義的步驟來實現，主要包括以下步驟：

1. **帳戶設定** - 設置設備管理員帳戶和密碼
2. **連線類型選擇** - 選擇 DHCP、Static IP 或 PPPoE
3. **SSID 設定** - 配置 Wi-Fi 網絡名稱、安全選項和密碼
4. **設定完成** - 顯示設定摘要並完成流程

## 關鍵組件交互

### 數據流

![數據流圖](https://i.imgur.com/nDNN1mO.png)

數據在各組件間的流動方式如下：

```
WifiSettingFlowPage (Container)
├── 從 JSON 讀取步驟定義
├── 管理當前步驟狀態
│   └── StepperComponent (上層導航)
└── 管理表單數據
    └── 各步驟組件 (AccountPasswordComponent 等)
        └── 通過回調將數據傳回容器
```

### StepperComponent 與頁面內容同步

`StepperComponent` 和頁面內容需要保持同步，這通過以下方式實現：

```dart
// 在 WifiSettingFlowPage 中
void _updateCurrentStep(int stepIndex) {
  setState(() {
    currentStepIndex = stepIndex;
  });
  
  // 更新 PageView
  _pageController.animateToPage(
    stepIndex,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
  );
  
  // 同步 Stepper 控制器
  _stepperController.jumpToStep(stepIndex);
}

// PageView 更改頁面時
_pageController = PageController(initialPage: currentStepIndex);
_pageController.addListener(() {
  if (_pageController.page?.round() != currentStepIndex) {
    _updateCurrentStep(_pageController.page!.round());
  }
});
```

## 如何擴展和定制流程

### 添加新步驟

1. **更新 JSON 配置**

```json
{
  "models": {
    "A": {
      "steps": [
        // 現有步驟...
        {
          "id": 5,
          "name": "高級設定",
          "next": null,
          "components": ["AdvancedSettingsComponent"]
        }
      ]
    }
  }
}
```

2. **創建新組件**

```dart
class AdvancedSettingsComponent extends StatefulWidget {
  final Function(Map<String, dynamic>, bool)? onSettingsChanged;
  
  const AdvancedSettingsComponent({
    Key? key,
    this.onSettingsChanged,
  }) : super(key: key);
  
  @override
  State<AdvancedSettingsComponent> createState() => _AdvancedSettingsComponentState();
}

class _AdvancedSettingsComponentState extends State<AdvancedSettingsComponent> {
  // 實現組件...
}
```

3. **在 WifiSettingFlowPage 中註冊組件**

```dart
Widget? _createComponentByName(String componentName) {
  switch (componentName) {
    // 現有組件...
    case 'AdvancedSettingsComponent':
      return AdvancedSettingsComponent(
        onSettingsChanged: (settings, isValid) {
          setState(() {
            advancedSettings = settings;
            isCurrentStepComplete = isValid;
          });
        },
      );
    default:
      return null;
  }
}
```

### 修改現有步驟順序

只需在 JSON 配置中調整 `next` 屬性值即可更改步驟順序。

### 添加新的設備型號

在 JSON 配置中添加新的型號定義：

```json
{
  "models": {
    "A": { /* 現有配置 */ },
    "C": {
      "steps": [
        // 新型號的步驟定義
      ],
      "type": "JSON",
      "API": "WifiAPI"
    }
  }
}
```

## 表單驗證邏輯

各組件內的表單驗證邏輯應遵循以下原則：

### AccountPasswordComponent

```dart
bool _validateForm() {
  if (userName.isEmpty) {
    return false;
  }
  if (password.isEmpty || password.length < 6) {
    return false;
  }
  if (confirmPassword.isEmpty || confirmPassword != password) {
    return false;
  }
  return true;
}
```

### SetSSIDComponent

```dart
bool _validateForm() {
  if (ssid.isEmpty) {
    return false;
  }
  
  if (securityOption != 'no authentication' && 
      securityOption != 'Enhanced Open (OWE)' && 
      password.isEmpty) {
    return false;
  }
  
  return true;
}
```

## 與後端 API 整合

目前的實現還沒有實際與後端 API 整合。下一步的開發應該包括：

1. **創建 API 服務類**

```dart
class WifiApiService {
  Future<bool> setAdminAccount(String username, String password) async {
    // 實現 API 調用
  }
  
  Future<bool> setConnectionType(String connectionType) async {
    // 實現 API 調用
  }
  
  Future<bool> setWifiConfig(String ssid, String securityType, String password) async {
    // 實現 API 調用
  }
  
  Future<Map<String, dynamic>> applyConfig() async {
    // 實現 API 調用
  }
}
```

2. **在 WifiSettingFlowPage 中使用 API 服務**

```dart
final WifiApiService _apiService = WifiApiService();

void _handleNext() async {
  // 現有驗證邏輯...
  
  if (currentStepIndex == steps.length - 1) {
    // 最後一步，應用所有配置
    setState(() {
      isLoading = true;
    });
    
    try {
      final result = await _apiService.applyConfig();
      setState(() {
        isLoading = false;
        isLastStepCompleted = true;
      });
      
      _showCompletionDialog(result);
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      
      _showErrorDialog(e.toString());
    }
  } else {
    // 保存當前步驟數據到 API
    _saveCurrentStepData();
    
    // 跳到下一步
    setState(() {
      currentStepIndex++;
    });
    // 更新 UI...
  }
}

Future<void> _saveCurrentStepData() async {
  final componentNames = _getCurrentStepComponents();
  
  try {
    if (componentNames.contains('AccountPasswordComponent')) {
      await _apiService.setAdminAccount(userName, password);
    } else if (componentNames.contains('ConnectionTypeComponent')) {
      await _apiService.setConnectionType(connectionType);
    } else if (componentNames.contains('SetSSIDComponent')) {
      await _apiService.setWifiConfig(ssid, securityOption, wifiPassword);
    }
  } catch (e) {
    _showErrorDialog("儲存設定失敗: ${e.toString()}");
  }
}
```

## 下一步開發重點

1. **數據持久化**
    - 添加使用者偏好設定儲存
    - 添加設定草稿保存功能

2. **API 整合**
    - 創建 API 服務類
    - 實現與實際後端的通信

3. **錯誤處理**
    - 添加全面的錯誤處理
    - 實現重試機制

4. **UI 優化**
    - 添加加載和進度指示
    - 優化響應式布局
    - 添加動畫效果

5. **擴展功能**
    - 添加高級設定選項
    - 支持更複雜的網絡配置
    - 添加設備管理功能

## 總結

這個 Wi-Fi 設定流程的實現基於模組化和可配置的架構，通過 JSON 文件定義步驟和組件，使得系統能夠靈活地適應不同型號設備的需求。目前的實現已經包含了基本的 UI 框架和交互邏輯，但需要進一步完善 API 整合和數據持久化功能。