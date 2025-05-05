# API 整合指南 - Wi-Fi 5G IOT APP

本文檔提供關於如何整合和使用框架中的API服務的詳細說明，特別是Wi-Fi設備初始化過程中需要的API呼叫。

## API 服務架構

本框架採用模組化API服務架構，主要通過 `WifiApiService` 類封裝所有與設備通信的功能。這種設計使得應用程式與後端API之間的通訊更加一致和可維護。

![API架構圖](https://i.imgur.com/nDcFbRI.png)

### 核心功能

- **動態端點配置**：通過JSON配置檔案定義API端點
- **自動方法生成**：為每個端點自動生成相應的HTTP方法
- **安全認證管理**：JWT令牌處理和初始密碼計算
- **統一錯誤處理**：標準化API錯誤處理機制

## 配置檔案結構

API服務通過 `lib/shared/config/api/wifi.json` 配置檔案初始化，該檔案定義了所有API端點及其屬性：

```json
{
  "baseUrl": "http://192.168.1.1",
  "apiVersion": "/api/v1",
  "timeoutSeconds": 10,
  "endpoints": {
    "configStart": {
      "path": "$apiVersion/config/start",
      "method": "post",
      "description": "開始設定流程"
    },
    "configFinish": {
      "path": "$apiVersion/config/finish",
      "method": "post",
      "description": "完成設定流程"
    },
    // 其他API端點...
  }
}
```

### 端點屬性

- **path**：API路徑，可使用 `$apiVersion` 變數
- **method**：HTTP方法（get, post, put, delete）
- **description**：端點描述（可選）
- **defaultData**：預設請求參數（可選）

## 使用方法

### 初始化服務

在使用API服務前，需要先初始化：

```dart
// 自動初始化（在首次呼叫時）
await WifiApiService.initialize();

// 或主動初始化
Future<void> initApiService() async {
  await WifiApiService.initialize();
  print('API服務初始化完成');
}
```

### 基本API調用

#### 1. 動態方法調用 (推薦)

```dart
// 獲取系統信息
final systemInfo = await WifiApiService.call('getSystemInfo');

// 更新無線設定
final wirelessConfig = {
  'ssid': 'MyNetwork',
  'security': 'WPA3',
  'password': 'SecurePassword'
};
await WifiApiService.call('updateWirelessBasic', wirelessConfig);
```

#### 2. 直接HTTP方法

```dart
// GET請求
final networkStatus = await WifiApiService.get(
  WifiApiService.getEndpoint('networkStatus')
);

// POST請求
final loginData = {'user': 'admin', 'password': 'password123'};
final loginResult = await WifiApiService.post(
  WifiApiService.getEndpoint('userLogin'),
  data: loginData
);
```

### 常用API操作

#### 獲取系統信息

```dart
Future<void> getDeviceInfo() async {
  try {
    final systemInfo = await WifiApiService.call('getSystemInfo');
    
    final modelName = systemInfo['model_name'];
    final firmwareVersion = systemInfo['firmware_version'];
    final serialNumber = systemInfo['serial_number'];
    
    print('設備型號: $modelName');
    print('韌體版本: $firmwareVersion');
    print('序號: $serialNumber');
  } catch (e) {
    print('獲取系統信息失敗: $e');
  }
}
```

#### 設置無線網絡

```dart
Future<void> setupWirelessNetwork(String ssid, String security, String password) async {
  try {
    // 開始配置流程
    await WifiApiService.call('postConfigStart');
    
    // 設置無線網絡
    final wirelessConfig = {
      'ssid': ssid,
      'security': security,
      'password': password,
      'enabled': true
    };
    
    await WifiApiService.call('updateWirelessBasic', wirelessConfig);
    
    // 完成配置流程
    await WifiApiService.call('postConfigFinish');
    
    print('無線網絡設置成功');
  } catch (e) {
    print('設置無線網絡失敗: $e');
  }
}
```

## 初始密碼計算與登入流程

在設備初始化過程中，通常需要使用初始密碼進行登入。本框架提供了專門的方法計算初始密碼並進行登入。

### 計算初始密碼

```dart
Future<String> getInitialPassword() async {
  try {
    // 獲取當前連接的SSID
    final currentSSID = await WifiApiService.getCurrentSSID();
    
    // 獲取系統信息以獲取序號和鹽值
    final systemInfo = await WifiApiService.call('getSystemInfo');
    final serialNumber = systemInfo['serial_number'];
    final loginSalt = systemInfo['login_salt'];
    
    // 計算初始密碼
    final password = await WifiApiService.calculateInitialPassword(
      providedSSID: currentSSID,
      serialNumber: serialNumber,
      loginSalt: loginSalt
    );
    
    return password;
  } catch (e) {
    print('計算初始密碼失敗: $e');
    rethrow;
  }
}
```

### 使用初始密碼登入

```dart
Future<bool> loginWithInitialPassword() async {
  try {
    final result = await WifiApiService.loginWithInitialPassword();
    
    if (result.containsKey('token') || result.containsKey('jwt')) {
      print('登入成功');
      return true;
    } else {
      print('登入失敗: 未獲取到令牌');
      return false;
    }
  } catch (e) {
    print('登入失敗: $e');
    return false;
  }
}
```

## SRP 安全登入流程

對於支援 SRP (Secure Remote Password) 協議的設備，框架提供了專門的 `SrpLoginService` 來實現安全登入。

```dart
import 'package:whitebox/shared/api/srp_login_service.dart';

Future<void> srpLogin(String username, String password) async {
  final srpService = SrpLoginService(
    baseUrl: 'http://192.168.1.1',
    username: username,
    password: password
  );
  
  try {
    final result = await srpService.login();
    
    if (result.success) {
      print('SRP登入成功');
      print('會話ID: ${result.sessionId}');
      print('CSRF令牌: ${result.csrfToken}');
    } else {
      print('SRP登入失敗: ${result.message}');
    }
  } catch (e) {
    print('SRP登入出錯: $e');
  } finally {
    srpService.dispose();
  }
}
```

## 錯誤處理

API服務封裝了錯誤處理邏輯，所有API呼叫的錯誤都會通過 `ApiException` 類型的異常拋出：

```dart
try {
  await WifiApiService.call('updateWirelessBasic', wirelessConfig);
} catch (e) {
  if (e is ApiException) {
    print('API錯誤: [${e.statusCode}] ${e.errorCode} - ${e.message}');
    
    if (e.statusCode == 401) {
      // 處理未授權錯誤
      await relogin();
    } else if (e.statusCode >= 500) {
      // 處理服務器錯誤
      showErrorDialog('服務器錯誤，請稍後再試');
    }
  } else {
    // 處理其他錯誤，如網絡連接問題
    print('非API錯誤: $e');
  }
}
```

## 總結

本框架的API服務設計提供了統一、靈活的方式與Wi-Fi和IoT設備通信。通過動態配置和自動方法生成，開發者可以輕鬆擴展和定制API功能，而無需修改核心代碼。

正確使用API服務可以顯著簡化設備初始化和管理流程，提高應用程式的可維護性和擴展性。

## 下一步開發

1. **更完善的API文檔系統** - 添加自動生成API文檔的功能
2. **API快取機制** - 實現對常用API結果的快取
3. **API監控和日誌** - 添加完整的API調用監控和日誌記錄
4. **批量API操作** - 支援批量API請求和響應處理
5. **API版本管理** - 實現API版本控制和兼容性處理