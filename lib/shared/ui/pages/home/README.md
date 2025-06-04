# WhiteBox 應用程式導航系統 README

## 📋 目錄
- [概述](#概述)
- [系統架構](#系統架構)
- [核心元件](#核心元件)
- [程式邏輯說明](#程式邏輯說明)
- [使用方法](#使用方法)
- [配置參數](#配置參數)
- [常見問題](#常見問題)
- [開發指南](#開發指南)

---

## 概述

WhiteBox 應用程式採用**統一導航系統**，透過 `DashboardPage` 作為主容器，整合三個核心頁面：
- **Dashboard**：乙太網路狀態監控
- **NetworkTopo**：網路拓撲視圖與設備管理
- **Settings**：系統設定（未來擴展）

### 🎯 設計目標
- **統一體驗**：所有頁面共用底部導航欄
- **流暢動畫**：圓圈移動動畫增強用戶體驗
- **模組化**：各頁面功能完全獨立，可單獨使用
- **易維護**：清晰的架構便於擴展和維護

---

## 系統架構

### 🏗️ 整體架構圖

```
Application
├── main.dart (應用程式入口)
│   └── DashboardPage (主導航容器)
│       ├── PageView (頁面切換容器)
│       │   ├── Page 0: Dashboard Content
│       │   ├── Page 1: NetworkTopo Content  
│       │   └── Page 2: Settings Content
│       └── BottomNavigationBar (統一底部導航)
└── Standalone Pages (可獨立使用)
    ├── NetworkTopoView (原始獨立頁面)
    └── Other Pages...
```

### 🔄 導航流程圖

```
LoginPage
    ↓ Navigator.pushReplacement
DashboardPage (initialNavigationIndex: 1)
    ├── Dashboard ←→ NetworkTopo ←→ Settings
    │      ↑              ↑            ↑
    │   索引 0          索引 1       索引 2
    └── 底部導航欄圓圈動畫切換
```

---

## 核心元件

### 1. DashboardPage (主容器)

**檔案位置**: `lib/shared/ui/pages/home/DashboardPage.dart`

**主要功能**:
- 作為三頁導航的主容器
- 管理底部導航欄和頁面切換
- 處理圓圈移動動畫
- 整合各子頁面內容

**關鍵參數**:
```dart
const DashboardPage({
  this.showBottomNavigation = true,     // 是否顯示底部導航
  this.initialNavigationIndex = 0,     // 初始頁面索引
  this.enableBackground = true,        // 是否啟用背景
  // ... 其他參數
})
```

### 2. Dashboard 內容元件

**組成結構**:
```
DashboardContent
├── DashboardTitleComponent (標題)
├── DashboardIndicatorComponent (分頁指示點)
└── DashboardContentComponent (乙太網路狀態內容)
```

**版面配置變數** (可調整):
```dart
// 螢幕絕對位置比例
static const double titleTopRatio = 0.1;           // 標題開始位置
static const double titleBottomRatio = 0.15;       // 標題結束位置
static const double indicatorTopRatio = 0.12;      // 指示點開始位置  
static const double indicatorBottomRatio = 0.21;   // 指示點結束位置
static const double contentTopRatio = 0.19;        // 內容開始位置
static const double contentBottomRatio = 0.8;      // 內容結束位置
```

### 3. NetworkTopoView (網路拓撲)

**檔案位置**: `lib/shared/ui/pages/test/NetworkTopoView.dart`

**雙模式支援**:
- **獨立模式** (`showBottomNavigation = true`): 顯示自己的底部導航
- **嵌入模式** (`showBottomNavigation = false`): 作為子頁面嵌入到 DashboardPage

**內容結構**:
```
NetworkTopoView
├── TabBar (Topology/List 切換)
├── TopologyView (網路拓撲圖)
│   ├── NetworkTopologyComponent
│   └── Device Management
├── SpeedArea (速度監控圖表)
└── BottomNavBar (可選)
```

---

## 程式邏輯說明

### 🎮 導航邏輯

#### 1. 頁面切換流程

```dart
用戶點擊底部導航圖標
    ↓
_handleBottomTabChanged(int index)
    ↓
更新 _selectedBottomTab 狀態
    ↓
啟動圓圈移動動畫 (_navigationAnimationController)
    ↓
動畫完成後執行頁面切換
    ↓
_mainPageController.animateToPage(index)
    ↓
PageView 切換到目標頁面
```

#### 2. 動畫系統

**圓圈位置計算**:
```dart
double _getCirclePosition() {
  final screenWidth = MediaQuery.of(context).size.width;
  final barWidth = screenWidth * 0.70;
  final circleSize = 47.0;
  final sectionWidth = barWidth / 3;
  
  switch (_selectedBottomTab) {
    case 0: return edgeDistance - 1.9;           // Dashboard
    case 1: return sectionWidth + centerOffset;  // NetworkTopo  
    case 2: return barWidth - circleSize - edgeDistance - 0.2; // Settings
  }
}
```

**動畫時序**:
1. 用戶點擊 → 圓圈開始移動 (300ms)
2. 動畫完成 → 頁面開始切換 (300ms)
3. 動畫控制器重置，準備下次動畫

### 🎨 背景與版面管理

#### 1. 背景處理策略

```dart
// DashboardPage: 統一背景管理
Container(
  decoration: _getBackgroundDecoration(context), // 主背景
  child: PageView(...) // 子頁面
)

// NetworkTopoView: 條件式背景
Container(
  decoration: widget.showBottomNavigation 
      ? BackgroundDecorator.imageBackground(...)  // 獨立使用時有背景
      : null,                                     // 嵌入時無背景
)
```

#### 2. 響應式間距系統

**間距計算邏輯**:
```dart
// 根據螢幕高度動態計算
final screenHeight = MediaQuery.of(context).size.height;

// 獨立使用時的間距
final independentTopSpacing = screenHeight * 0.08;
final independentBottomSpacing = screenHeight * 0.08;

// 嵌入使用時的間距  
final embeddedTopSpacing = screenHeight * 0.02;
final embeddedBottomSpacing = screenHeight * 0.02;
```

### 📊 資料流管理

#### 1. Dashboard 資料流

```
API Call → _fetchDashboardDataFromAPI()
    ↓
Data Processing → List<EthernetPageData>
    ↓  
State Update → setState()
    ↓
UI Render → DashboardContentComponent
    ↓
PageView → 分頁內容顯示
```

#### 2. NetworkTopo 資料流

```
Device Generation → _getDevices()
    ↓
Connection Data → _getDeviceConnections()
    ↓
Speed Data → SpeedDataGenerator.update()
    ↓
UI Components → NetworkTopologyComponent + SpeedChartWidget
```

---

## 使用方法

### 🚀 基本使用

#### 1. 在 main.dart 中設定

```dart
// 方法 A: 預設顯示 Dashboard
home: const DashboardPage(),

// 方法 B: 預設顯示 NetworkTopo (推薦給從 LoginPage 跳轉)
home: const DashboardPage(
  showBottomNavigation: true,
  initialNavigationIndex: 1,
),

// 方法 C: 獨立使用 NetworkTopo
home: const NetworkTopoView(),
```

#### 2. 從其他頁面導航

```dart
// 從 LoginPage 跳轉到 NetworkTopo 頁面
Navigator.of(context).pushReplacement(
  MaterialPageRoute(
    builder: (context) => const DashboardPage(
      showBottomNavigation: true,
      initialNavigationIndex: 1, // NetworkTopo
    ),
  ),
);

// 跳轉到 Dashboard 頁面
Navigator.of(context).pushReplacement(
  MaterialPageRoute(
    builder: (context) => const DashboardPage(
      showBottomNavigation: true,
      initialNavigationIndex: 0, // Dashboard
    ),
  ),
);
```

### 🛠️ 進階使用

#### 1. 自定義 Dashboard 配置

```dart
DashboardPage(
  // 版面配置
  showBottomNavigation: true,
  initialNavigationIndex: 0,
  
  // Dashboard 特定配置
  enableBackground: true,
  enableAutoSwitch: false,        // 停用自動切換
  refreshInterval: Duration(minutes: 2),
  
  // API 配置
  apiEndpoint: 'https://your-api.com/dashboard',
)
```

#### 2. 自定義 NetworkTopo 配置

```dart
NetworkTopoView(
  // 顯示配置
  showBottomNavigation: false,    // 嵌入模式
  enableInteractions: true,
  
  // 內容配置
  defaultDeviceCount: 4,
  showDeviceCountController: false,
  
  // 資料來源
  externalDevices: customDeviceList,
  externalDeviceConnections: customConnections,
)
```

---

## 配置參數

### 📐 DashboardPage 參數

| 參數名稱 | 類型 | 預設值 | 說明 |
|---------|------|--------|------|
| `showBottomNavigation` | `bool` | `true` | 是否顯示底部導航欄 |
| `initialNavigationIndex` | `int` | `0` | 初始頁面索引 (0:Dashboard, 1:NetworkTopo, 2:Settings) |
| `enableBackground` | `bool` | `true` | 是否啟用背景圖片 |
| `customBackgroundPath` | `String?` | `null` | 自定義背景圖片路徑 |
| `apiEndpoint` | `String?` | `null` | API 端點 URL |
| `refreshInterval` | `Duration` | `1分鐘` | 資料重新整理間隔 |
| `enableAutoSwitch` | `bool` | `false` | 是否啟用自動切換分頁 |

### 🌐 NetworkTopoView 參數

| 參數名稱 | 類型 | 預設值 | 說明 |
|---------|------|--------|------|
| `showBottomNavigation` | `bool` | `true` | 是否顯示底部導航欄 |
| `enableInteractions` | `bool` | `false` | 是否啟用互動功能 |
| `defaultDeviceCount` | `int` | `0` | 預設設備數量 |
| `showDeviceCountController` | `bool` | `false` | 是否顯示設備數量控制器 |
| `externalDevices` | `List<NetworkDevice>?` | `null` | 外部設備列表 |
| `externalDeviceConnections` | `List<DeviceConnection>?` | `null` | 外部連接資料 |

### 🎨 版面配置參數 (可在程式碼中調整)

```dart
// Dashboard 版面比例
static const double titleTopRatio = 0.1;           // 標題頂部位置
static const double titleBottomRatio = 0.15;       // 標題底部位置
static const double indicatorTopRatio = 0.12;      // 指示點頂部位置
static const double indicatorBottomRatio = 0.21;   // 指示點底部位置
static const double contentTopRatio = 0.19;        // 內容頂部位置
static const double contentBottomRatio = 0.8;      // 內容底部位置

// 樣式配置
static const double indicatorSize = 6.0;           // 指示點大小
static const double indicatorSpacing = 8.0;        // 指示點間距
static const double titleFontSizeRatio = 0.032;    // 標題字體大小比例
static const double contentWidthRatio = 0.9;       // 內容寬度比例
```

---

## 常見問題

### ❓ 為什麼直接使用 NetworkTopoView 時底部導航無法跳轉？

**原因**: 獨立的 NetworkTopoView 中的 `_handleBottomTabChanged` 方法只更新內部狀態，沒有實際的頁面跳轉邏輯。

**解決方法**:
1. 使用 DashboardPage 作為主容器 (推薦)
2. 或在 NetworkTopoView 中添加導航邏輯 (參考進階使用章節)

### ❓ 為什麼 NetworkTopo 頁面在 DashboardPage 中排版異常？

**原因**: 雙重背景設定和間距計算衝突。

**解決方法**: 我們已經修正此問題：
- 嵌入模式時 NetworkTopoView 不設定背景
- 動態調整間距以適應不同的使用模式

### ❓ 如何自定義底部導航欄的圖標？

**位置**: `_buildBottomNavIconWithImage` 方法

```dart
// 修改圖標路徑
'assets/images/icon/dashboard.png'    // Dashboard 圖標
'assets/images/icon/topohome.png'     // NetworkTopo 圖標  
'assets/images/icon/setting.png'     // Settings 圖標
```

### ❓ 如何添加新的頁面到導航系統？

1. 在 DashboardPage 的 PageView 中添加新頁面
2. 修改 `_totalPages` 常數
3. 更新 `_getCirclePosition()` 方法中的位置計算
4. 添加對應的圖標和處理邏輯

### ❓ 如何禁用某個頁面的底部導航？

```dart
DashboardPage(
  showBottomNavigation: false,  // 完全隱藏底部導航
)
```

---

## 開發指南

### 🔧 開發環境設定

1. **確保 Flutter 版本**: 3.27.0 或更高
2. **必要依賴**: 檢查 `pubspec.yaml` 中的依賴項目
3. **圖標資源**: 確保 `assets/images/icon/` 目錄下有對應圖標

### 📝 程式碼結構建議

```
lib/shared/ui/pages/
├── home/
│   └── DashboardPage.dart          # 主導航容器
├── test/  
│   └── NetworkTopoView.dart        # 網路拓撲頁面
└── other_pages/
    └── ...                         # 其他頁面

lib/shared/ui/components/
├── basic/
│   ├── DashboardComponent.dart     # Dashboard 基礎組件
│   └── NetworkTopologyComponent.dart # 網路拓撲組件
└── ...
```

### 🎯 最佳實踐

1. **狀態管理**: 使用 setState 進行簡單狀態管理，複雜狀態考慮 Provider 或 Bloc
2. **動畫**: 使用 AnimationController 控制頁面切換動畫
3. **響應式設計**: 使用螢幕比例而非固定數值
4. **錯誤處理**: 在 API 呼叫和頁面導航中加入適當的錯誤處理
5. **效能**: 避免在 build 方法中進行重複計算

### 🧪 測試建議

```dart
// 單元測試
testWidgets('DashboardPage navigation test', (WidgetTester tester) async {
  await tester.pumpWidget(MyApp());
  
  // 測試初始狀態
  expect(find.text('Dashboard'), findsOneWidget);
  
  // 測試導航
  await tester.tap(find.byIcon(Icons.home));
  await tester.pumpAndSettle();
  
  // 驗證頁面切換
  expect(find.byType(NetworkTopologyComponent), findsOneWidget);
});
```

### 🚀 部署注意事項

1. **圖標資源**: 確保所有圖標都正確打包
2. **API 端點**: 生產環境中使用正確的 API URL
3. **效能優化**: 檢查動畫流暢度和記憶體使用
4. **兼容性**: 測試不同螢幕尺寸和設備

---

## 📄 授權與貢獻

此導航系統是 WhiteBox 專案的一部分。

**維護者**: WhiteBox 開發團隊  
**最後更新**: 2024年12月  
**版本**: 1.0.0

如有問題或建議，請聯繫開發團隊。