# UI 組件使用指南

## 基礎 UI 組件

本專案的 UI 組件設計遵循模組化和可重用的原則。以下是主要 UI 組件的使用指南。

### StepperComponent

#### 概述
`StepperComponent` 是一個多步驟導航組件，可從 JSON 配置文件加載步驟定義。

#### 使用方法

```dart
StepperComponent(
  configPath: 'lib/shared/config/flows/initialization/wifi.json',
  modelType: 'A',
  onStepChanged: (index) {
    // 處理步驟變化
  },
  controller: stepperController,
)
```

#### 屬性說明
- `configPath`: JSON 配置文件路徑
- `modelType`: 設備型號標識符
- `onStepChanged`: 步驟變化時的回調函數
- `controller`: 步驟控制器，用於外部控制步驟狀態

#### 控制器使用

```dart
// 創建控制器
final StepperController controller = StepperController();

// 跳轉到指定步驟
controller.jumpToStep(2);

// 前進到下一步
controller.nextStep();

// 返回上一步
controller.previousStep();
```

### AccountPasswordComponent

#### 概述
用於設置帳戶密碼的表單組件。

#### 使用方法

```dart
AccountPasswordComponent(
  onFormChanged: (user, password, confirmPassword, isComplete) {
    // 處理表單變化
  },
  onNextPressed: () {
    // 處理下一步按鈕點擊
  },
  onBackPressed: () {
    // 處理返回按鈕點擊
  },
)
```

#### 屬性說明
- `onFormChanged`: 表單內容變化時的回調
- `onNextPressed`: 下一步按鈕點擊回調
- `onBackPressed`: 返回按鈕點擊回調

### ConnectionTypeComponent

#### 概述
用於選擇網絡連接類型的下拉選擇組件。

#### 使用方法

```dart
ConnectionTypeComponent(
  onSelectionChanged: (connectionType, isComplete) {
    // 處理選擇變化
  },
  onNextPressed: () {
    // 處理下一步按鈕點擊
  },
  onBackPressed: () {
    // 處理返回按鈕點擊
  },
)
```

#### 屬性說明
- `onSelectionChanged`: 選擇變化時的回調
- `onNextPressed`: 下一步按鈕點擊回調
- `onBackPressed`: 返回按鈕點擊回調

### SetSSIDComponent

#### 概述
用於設置 Wi-Fi SSID 和密碼的表單組件。

#### 使用方法

```dart
SetSSIDComponent(
  onFormChanged: (ssid, securityOption, password, isValid) {
    // 處理表單變化
  },
  onNextPressed: () {
    // 處理下一步按鈕點擊
  },
  onBackPressed: () {
    // 處理返回按鈕點擊
  },
)
```

#### 屬性說明
- `onFormChanged`: 表單內容變化時的回調
- `onNextPressed`: 下一步按鈕點擊回調
- `onBackPressed`: 返回按鈕點擊回調

### WifiScannerComponent

#### 概述
用於掃描和顯示 Wi-Fi 設備的組件。

#### 使用方法

```dart
WifiScannerComponent(
  controller: scannerController,
  maxDevicesToShow: 3,
  deviceBoxSize: 80,
  spacing: 20,
  onScanComplete: (devices, error) {
    // 處理掃描完成
  },
  onDeviceSelected: (device) {
    // 處理設備選擇
  },
)
```

#### 屬性說明
- `controller`: Wi-Fi 掃描控制器
- `maxDevicesToShow`: 最多顯示的設備數量
- `deviceBoxSize`: 設備方框大小
- `spacing`: 設備間距
- `onScanComplete`: 掃描完成回調
- `onDeviceSelected`: 設備選擇回調

#### 控制器使用

```dart
// 創建控制器
final WifiScannerController controller = WifiScannerController();

// 開始掃描
controller.startScan();

// 獲取掃描到的設備
List<WiFiAccessPoint> devices = controller.getDiscoveredDevices();

// 檢查是否正在掃描
bool scanning = controller.isScanning();
```

## 頁面組件使用指南

### WifiSettingFlowPage

用於實現完整的 Wi-Fi 設置流程。此頁面通過 JSON 配置加載不同型號設備的設置步驟。

#### 關鍵功能：
- 步驟間平滑切換
- 動態加載並顯示每個步驟對應的組件
- 表單驗證和流程控制
- 進度顯示和導航

#### 使用方法：
直接導航到此頁面即可開始 Wi-Fi 設置流程：

```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const WifiSettingFlowPage()),
);
```

### InitializationPage

設備初始化的主頁面，提供設備掃描和添加功能。

#### 關鍵功能：
- Wi-Fi 設備掃描
- QR 碼掃描入口
- 手動添加設備入口

#### 使用方法：
作為設備添加流程的起始頁面：

```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const InitializationPage()),
);
```

### QrCodeScannerPage

用於掃描設備 QR 碼的頁面。

#### 關鍵功能：
- 相機預覽和 QR 碼掃描
- 掃描結果顯示和處理
- 閃光燈控制

#### 使用方法：
從 InitializationPage 跳轉，可獲取掃描結果：

```dart
final result = await Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const QrCodeScannerPage()),
);

if (result != null) {
  // 處理掃描結果
}
```

### WifiConnectionPage

用於選擇 Wi-Fi 網絡的頁面。

#### 關鍵功能：
- Wi-Fi 網絡掃描和列表顯示
- 網絡選擇和返回選擇結果

#### 使用方法：
跳轉到此頁面並獲取選擇的網絡：

```dart
final selectedWifi = await Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const WifiConnectionPage()),
);

if (selectedWifi != null) {
  // 處理選擇的網絡
}
```

### AddDevicesPage

用於手動添加設備的頁面。

#### 關鍵功能：
- 設備列表顯示
- 添加新設備功能

#### 使用方法：

```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const AddDevicesScreen()),
);
```

## 自定義樣式建議

本項目使用了統一的灰色主題，以下是一些樣式常量供參考：

### 顏色

```dart
// 主要背景色
final Color mainBackgroundColor = const Color(0xFFFFFFFF);

// 次要背景色
final Color secondaryBackgroundColor = const Color(0xFFEFEFEF);

// 按鈕背景色
final Color buttonBackgroundColor = const Color(0xFFDDDDDD);

// 邊框顏色
final Color borderColor = Colors.grey[400]!;
```

### 文字樣式

```dart
// 大標題
final TextStyle titleStyle = const TextStyle(
  fontSize: 32,
  fontWeight: FontWeight.bold,
);

// 小標題
final TextStyle subtitleStyle = const TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.bold,
);

// 普通文字
final TextStyle bodyStyle = const TextStyle(
  fontSize: 16,
);

// 按鈕文字
final TextStyle buttonStyle = const TextStyle(
  fontSize: 18,
  color: Colors.black,
);
```

### 間距常量

```dart
// 標準水平內邊距
const double horizontalPadding = 20.0;

// 標準垂直內邊距
const double verticalPadding = 20.0;

// 元素間距
const double elementSpacing = 16.0;

// 組件間距
const double componentSpacing = 24.0;
```