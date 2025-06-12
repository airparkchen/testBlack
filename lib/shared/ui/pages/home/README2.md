# Dashboard 頁面系統開發指南

本文檔詳細說明 WhiteBox 應用程式中 Dashboard 相關頁面的架構、組成和維護方法。

## 📋 目錄
- [系統概覽](#系統概覽)
- [頁面架構](#頁面架構)
- [核心檔案說明](#核心檔案說明)
- [PageView 三頁詳細組成](#pageview-三頁詳細組成)
- [數據流向](#數據流向)
- [主題系統](#主題系統)
- [開發指南](#開發指南)
- [常見修改場景](#常見修改場景)
- [故障排除](#故障排除)

---

## 系統概覽

### 🎯 設計理念
Dashboard 系統採用 **PageView 滑動切換** 設計，提供類似現代 App（如 Instagram、微信）的流暢用戶體驗。用戶可以通過底部導航或手指滑動在三個主要功能區域間切換。

### 🏗️ 整體架構
```
應用程式入口 (main.dart)
├── DashboardPage ⭐ (主導航容器)
│   ├── PageView 滑動容器
│   │   ├── Page 0: Dashboard 內容 (乙太網路狀態)
│   │   ├── Page 1: NetworkTopo 內容 (網路拓樸)
│   │   └── Page 2: Settings 內容 (設定頁面)
│   └── BottomNavigationBar (統一底部導航)
└── 獨立頁面
    ├── NetworkTopoView (可獨立使用或嵌入)
    └── DeviceDetailPage (設備詳情)
```

### ✨ 核心特性
- **無縫切換**：PageView 提供流暢的頁面滑動體驗
- **狀態保持**：三個頁面同時在記憶體中，切換時狀態不丟失
- **模組化設計**：NetworkTopoView 既可獨立使用，也可嵌入使用
- **響應式佈局**：根據螢幕尺寸自動調整元件位置
- **統一主題**：所有頁面共用 app_theme.dart 確保視覺一致性

---

## 頁面架構

### 🗂️ 主要檔案結構
```
lib/shared/ui/pages/
├── home/
│   ├── DashboardPage.dart          ⭐ 主導航容器
│   ├── DeviceDetailPage.dart       📱 設備詳情頁面
│   └── README.md                   📄 本文檔
├── test/
│   └── NetworkTopoView.dart        🌐 網路拓樸頁面
└── components/basic/
    ├── DashboardComponent.dart     📊 Dashboard 組件
    ├── NetworkTopologyComponent.dart 🗺️ 拓樸圖組件
    ├── topology_display_widget.dart 🎯 拓樸顯示組合
    └── device_list_widget.dart     📋 設備列表組件
```

### 🔄 導航流程
```
用戶操作 → DashboardPage 導航控制 → PageView 滑動切換 → 目標頁面顯示
    ↓                ↓                    ↓               ↓
底部導航點擊      圓圈動畫效果          平滑滑動動畫      內容渲染
手指滑動         狀態更新              頁面切換          元件更新
```

---

## 核心檔案說明

### 🎛️ DashboardPage.dart (主導航容器)
**檔案路徑**: `lib/shared/ui/pages/home/DashboardPage.dart`

**主要職責**:
- 管理三個主頁面的 PageView 容器
- 處理底部導航欄的點擊和動畫
- 管理設備詳情頁面的顯示/隱藏
- 統一背景和主題管理

**關鍵參數**:
```dart
const DashboardPage({
  this.showBottomNavigation = true,     // 是否顯示底部導航
  this.initialNavigationIndex = 0,     // 初始頁面索引 (0:Dashboard, 1:NetworkTopo, 2:Settings)
  this.enableBackground = true,        // 是否啟用背景圖片
  this.enableAutoSwitch = false,       // 是否啟用自動切換 (通常為 false)
})
```

**核心方法**:
- `_handleBottomTabChanged(int index)`: 處理底部導航切換
- `_buildNavigationContainer()`: 構建包含導航的主容器
- `_buildDashboardContent()`: 構建 Dashboard 內容
- `_buildNetworkTopoPage()`: 構建 NetworkTopo 內容
- `_handleDeviceSelected(NetworkDevice device)`: 處理設備選擇事件

### 🌐 NetworkTopoView.dart (網路拓樸頁面)
**檔案路徑**: `lib/shared/ui/pages/test/NetworkTopoView.dart`

**雙模式支援**:
- **獨立模式** (`showBottomNavigation = true`): 完整的獨立頁面
- **嵌入模式** (`showBottomNavigation = false`): 嵌入到 DashboardPage 中使用

**主要功能**:
- Topology/List 視圖切換 (TabBar)
- 網路拓樸圖顯示 (設備圖標、連接線、數字標籤)
- 速度圖表顯示 (實時更新的網路速度曲線)
- 設備列表顯示 (Gateway + Extender 清單)
- 真實/假數據模式切換

**關鍵參數**:
```dart
const NetworkTopoView({
  this.showBottomNavigation = true,          // 是否顯示底部導航
  this.enableInteractions = true,           // 是否啟用互動功能
  this.defaultDeviceCount = 0,              // 預設設備數量
  this.onDeviceSelected,                    // 設備選擇回調
})
```

### 📱 DeviceDetailPage.dart (設備詳情頁面)
**檔案路徑**: `lib/shared/ui/pages/home/DeviceDetailPage.dart`

**主要功能**:
- 顯示選中設備的詳細資訊 (Gateway 或 Extender)
- 三段式 RSSI 顯示 (綠色/黃色/橙色)
- 連接客戶端設備列表
- 支援真實數據和假數據模式

**顯示內容**:
- 設備基本資訊 (名稱、MAC、IP、客戶端數量)
- RSSI 信號強度指示器
- 連接的客戶端設備清單 (TV、Xbox、iPhone、Laptop 等)

---

## PageView 三頁詳細組成

### 📊 Page 0: Dashboard 內容
```
DashboardPage._buildDashboardContent()
├── DashboardTitleComponent (絕對定位)
│   ├── 位置: screenHeight * 0.1 ~ 0.15
│   └── 內容: "Dashboard" 標題文字
├── DashboardIndicatorComponent (絕對定位)
│   ├── 位置: screenHeight * 0.12 ~ 0.21  
│   ├── 內容: 三個分頁指示圓點 (●○○)
│   └── 互動: 點擊切換分頁
└── DashboardContentComponent (絕對定位)
    ├── 位置: screenHeight * 0.19 ~ 0.8
    ├── 容器: app_theme.dart 的 WhiteBoxTheme.buildStandardCard()
    ├── 內容: PageView 包含三個乙太網路狀態分頁
    │   ├── Page 1: 10Gbps Disconnect, 1Gbps Connected, 10Gbps Connected, 1Gbps Connected
    │   ├── Page 2: 10Gbps Connected, 1Gbps Disconnect, 10Gbps Connected, 1Gbps Disconnect  
    │   └── Page 3: 10Gbps Connected, 1Gbps Connected, 10Gbps Disconnect, 1Gbps Connected
    ├── 自動切換: enableAutoSwitch (預設關閉)
    └── 手動重新整理: onRefresh 回調
```

**版面配置變數 (可調整)**:
```dart
// 在 DashboardPage.dart 中定義
static const double titleTopRatio = 0.1;           // 標題頂部位置比例
static const double titleBottomRatio = 0.15;       // 標題底部位置比例
static const double indicatorTopRatio = 0.12;      // 指示點頂部位置比例
static const double indicatorBottomRatio = 0.21;   // 指示點底部位置比例
static const double contentTopRatio = 0.19;        // 內容頂部位置比例
static const double contentBottomRatio = 0.8;      // 內容底部位置比例
```

### 🌐 Page 1: NetworkTopo 內容
```
DashboardPage._buildNetworkTopoPage()
├── [條件渲染 A] 設備詳情模式:
│   └── DeviceDetailPage
│       ├── 頂部 RSSI 指示器 (三段式顏色)
│       ├── 設備主要資訊區域
│       │   ├── 設備圖標 (Gateway: router.png, Extender: mesh.png)
│       │   ├── 設備名稱和 MAC 地址
│       │   └── 客戶端數量顯示
│       └── 客戶端列表區域
│           └── 使用 real_data_integration_service.dart 載入客戶端
│
└── [條件渲染 B] 正常拓樸模式:
    └── NetworkTopoView (嵌入模式: showBottomNavigation = false)
        ├── TabBar (Topology/List 切換)
        │   ├── 樣式: 白色膠囊背景 + 漸層邊框
        │   └── 動畫: 膠囊平滑移動效果
        │
        ├── [Topology 視圖]
        │   └── topology_display_widget.dart
        │       ├── 上半部: NetworkTopologyComponent
        │       │   ├── Internet 圖標 (白色圓點 + "Internet" 標籤)
        │       │   ├── Gateway 圖標 (router.png + 連接數字標籤)
        │       │   ├── Extender 圖標們 (mesh.png + 各自的連接數字標籤)
        │       │   ├── 連接線 (實線=有線, 虛線=無線)
        │       │   └── 佈局邏輯: 1~4設備有特殊佈局，5+設備用圓形排列
        │       └── 下半部: SpeedChartWidget
        │           ├── 速度曲線 (藍綠漸層 + 發光效果)
        │           ├── 白色圓點 (當前速度位置)
        │           ├── 垂直漸層線 (從圓點到底部)
        │           └── 速度標籤 (模糊背景 + 三角形指向)
        │
        └── [List 視圖]
            └── device_list_widget.dart
                ├── 設備卡片樣式: app_theme.dart 的 buildStandardCard()
                ├── Gateway 卡片:
                │   ├── 圖標: router.png (60x60)
                │   ├── 資訊: "Controller MAC地址", "Clients: X"
                │   └── 高度: 100px
                └── Extender 卡片們:
                    ├── 圖標: mesh.png (50x50, 白色濾鏡)
                    ├── 資訊: 設備名稱, IP地址, RSSI, Clients數量
                    └── 高度: 95px
```

### ⚙️ Page 2: Settings 內容
```
DashboardPage._buildSettingsPage()
└── 簡單佔位頁面
    ├── Settings 圖標 (64x64)
    ├── "Settings Page" 標題
    └── "Coming Soon..." 副標題
```

---

## 數據流向

### 🎭 假數據模式 (NetworkTopoConfig.useRealData = false)
```
fake_data_generator.dart
├── FakeDataGenerator.generateDevices(count)
│   └── 生成指定數量的假設備 (TV, Xbox, iPhone, Laptop)
├── FakeDataGenerator.generateConnections(devices)  
│   └── 為每個設備生成連接數 (固定為 2)
└── SpeedDataGenerator (假速度數據)
    ├── 固定長度滑動窗口模式 (100個數據點)
    ├── 平滑係數: 0.8
    ├── 速度範圍: 20~150 Mbps
    └── 更新頻率: 500ms
```

### 🌐 真實數據模式 (NetworkTopoConfig.useRealData = true)
```
WiFi API 調用鏈:
wifi_api_service.dart.getMeshTopology()
    ↓ HTTPS GET /api/v1/system/mesh_topology
mesh_data_analyzer.dart.analyzeDetailedDeviceInfo()
    ↓ 解析和過濾原始數據
    ├── 過濾規則: RSSI全0的extender, ssid包含"bh-"的host, 無IP的host
    └── 生成 DetailedDeviceInfo 物件列表
mesh_data_analyzer.dart.analyzeTopologyStructure()
    ↓ 建立網路拓樸結構
real_data_integration_service.dart (統一資料整合層)
    ├── getNetworkDevices() → 拓樸圖用 (只包含 Extender)
    ├── getListViewDevices() → 列表用 (Gateway + Extender)
    ├── getDeviceConnections() → 連接數字標籤用 (小圓圈數字)
    ├── getClientDevicesForParent() → 設備詳情頁用 (Host設備列表)
    └── getGatewayName() → Gateway名稱
UI 組件
    ├── NetworkTopologyComponent → 使用 getNetworkDevices() + getDeviceConnections()
    ├── DeviceListWidget → 使用 getListViewDevices()  
    └── DeviceDetailPage → 使用 getClientDevicesForParent()
```

### 🔄 快取機制
```
real_data_integration_service.dart
├── 快取時間: NetworkTopoConfig.actualCacheDuration (預設10秒)
├── 快取檢查: _isCacheValid() 
├── 強制重新載入: forceReload() (清除快取)
└── 自動重新載入: 每30秒觸發 (如果啟用 enableAutoReload)
```

---

## 主題系統

### 🎨 app_theme.dart 結構
```dart
AppTheme (單例)
├── AppColors
│   ├── primary: #9747FF (主紫色)
│   ├── primaryDark: #162140 (深藍色)
│   ├── background: #D9D9D9 (淺灰背景)
│   └── textLight: #FFFFFF (白色文字)
├── AppTextStyles  
│   ├── heading1/2/3 (標題樣式)
│   ├── bodyLarge/Medium/Small (內文樣式)
│   └── buttonText (按鈕樣式)
├── AppDimensions
│   ├── spacing: XS(4) S(8) M(16) L(24) XL(32)
│   ├── radius: XS(2) S(4) M(8) L(12) XL(16)
│   └── 元件高度: button(48) input(56) card(120/180/240)
└── WhiteBoxTheme (組件主題)
    ├── buildStandardCard() → 標準漸層卡片
    ├── buildStandardButton() → 標準按鈕
    ├── buildCustomCard() → 自定義卡片
    └── buildBlurredTextField() → 模糊背景輸入框
```

### 🎭 背景系統
```dart
BackgroundDecorator
├── getResponsiveBackground() → 根據螢幕大小選擇背景
│   ├── >1920px: background_5x.png
│   ├── >1440px: background_4x.png  
│   ├── >1080px: background_3x.png
│   ├── >720px: background_2x.png
│   └── 預設: background.png
└── imageBackground() → 建立背景裝飾
    ├── 圖片: AssetImage
    ├── 適配: BoxFit.cover
    └── 覆蓋層: 可選的顏色遮罩
```

---

## 開發指南

### 🛠️ 修改 Dashboard 分頁內容
若要修改 Dashboard 的乙太網路狀態顯示：

**步驟 1**: 修改資料來源
```dart
// 在 DashboardPage.dart 的 _fetchDashboardDataFromAPI() 方法中
Future<List<EthernetPageData>> _fetchDashboardDataFromAPI() async {
  // 修改這裡的模擬資料或改為真實 API 調用
  return [
    EthernetPageData(
      pageTitle: "自定義標題",
      connections: [
        EthernetConnection(speed: "25Gbps", status: "Connected"), // 新增更高速度
        // 添加更多連接...
      ],
    ),
  ];
}
```

**步驟 2**: 調整版面配置
```dart
// 修改版面配置比例常數
static const double contentTopRatio = 0.15;        // 調整內容區域位置
static const double contentBottomRatio = 0.85;     // 調整內容區域大小
```

### 🌐 添加新的 NetworkTopo 功能
若要在網路拓樸頁面添加新功能：

**步驟 1**: 修改 NetworkTopoView.dart
```dart
// 在 _buildMainContent() 方法中添加新的視圖模式
Widget _buildMainContent() {
  if (_viewMode == 'topology') {
    return TopologyDisplayWidget(...);
  } else if (_viewMode == 'list') {
    return DeviceListWidget(...);
  } else if (_viewMode == 'newFeature') {  // 新增模式
    return NewFeatureWidget(...);
  }
}
```

**步驟 2**: 修改 TabBar 支援更多選項
```dart
// 在 _buildTabBar() 中添加新的標籤
Row(
  children: [
    Expanded(child: GestureDetector(...)), // Topology
    Expanded(child: GestureDetector(...)), // List  
    Expanded(child: GestureDetector(...)), // 新功能
  ],
)
```

### 📱 添加新的設備詳情資訊
若要在設備詳情頁面顯示更多資訊：

**步驟 1**: 修改 DeviceDetailPage.dart 的 _buildDeviceInfo()
```dart
Widget _buildDeviceInfo() {
  return Column(
    children: [
      // 現有的名稱、MAC、客戶端資訊
      Text('NAME'),
      Text('$deviceName $formattedMac'),
      Text('Clients: $clientCount'),
      
      // 新增的資訊
      SizedBox(height: 8),
      Text('Uptime: ${device.additionalInfo['uptime'] ?? 'N/A'}'),
      Text('Signal Quality: ${_getRSSIQualityLabel(rssi)}'),
    ],
  );
}
```

### 🎨 自定義主題樣式
若要修改應用程式的顏色主題：

**步驟 1**: 修改 app_theme.dart 中的 AppColors
```dart
class AppColors {
  static const Color primary = Color(0xFF4CAF50);      // 改為綠色主題
  static const Color primaryDark = Color(0xFF2E7D32);  // 深綠色
  // 其他顏色...
}
```

**步驟 2**: 如果需要新的卡片樣式
```dart
// 在 WhiteBoxTheme 中添加新方法
Widget buildGreenCard({required double width, required double height, Widget? child}) {
  return buildCustomCard(
    width: width,
    height: height,
    gradientColors: [Color(0xFF4CAF50), Color(0xFF81C784)], // 綠色漸層
    child: child,
  );
}
```

---

## 常見修改場景

### 📊 場景 1: 更改 Dashboard 顯示的網路資訊
**需求**: 將乙太網路狀態改為 WiFi 狀態

**修改檔案**: `DashboardPage.dart`
**修改位置**: `_fetchDashboardDataFromAPI()` 和 `DashboardContentComponent`

```dart
// 修改資料模型
class WiFiPageData {
  final String pageTitle;
  final List<WiFiConnection> connections;
  // 新的資料結構...
}

// 修改顯示邏輯
Widget _buildConnectionItem(WiFiConnection connection) {
  return Row(
    children: [
      Text(connection.ssid),           // 顯示 SSID 而不是速度
      Text(connection.signalStrength), // 顯示信號強度
    ],
  );
}
```

### 🌐 場景 2: 在拓樸圖中添加新的設備類型
**需求**: 支援顯示 IoT 設備 (除了 Gateway 和 Extender)

**修改檔案**:
- `NetworkTopologyComponent.dart` (顯示邏輯)
- `mesh_data_models.dart` (資料模型)
- `real_data_integration_service.dart` (資料處理)

```dart
// 在 NetworkTopologyComponent.dart 中
String _getDeviceIconPath(String deviceType) {
  switch (deviceType) {
    case 'gateway': return 'assets/images/icon/router.png';
    case 'extender': return 'assets/images/icon/mesh.png';
    case 'iot': return 'assets/images/icon/iot.png';        // 新增
    case 'camera': return 'assets/images/icon/camera.png';  // 新增
    default: return 'assets/images/icon/device.png';
  }
}
```

### 📱 場景 3: 自定義設備詳情頁面佈局
**需求**: 重新設計設備詳情頁面的排版

**修改檔案**: `DeviceDetailPage.dart`
**修改位置**: `build()` 方法和相關的 `_build...()` 方法

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Column(
      children: [
        _buildCustomTopArea(),     // 自定義頂部區域
        _buildTabView(),          // 新增：分頁檢視 (資訊/統計/設定)
        _buildCustomBottomArea(), // 自定義底部區域
      ],
    ),
  );
}
```

### ⚙️ 場景 4: 添加新的主頁面到 PageView
**需求**: 在 Dashboard、NetworkTopo、Settings 之外新增第四個頁面

**修改檔案**: `DashboardPage.dart`

```dart
// 修改 PageView 的 children
PageView(
  controller: _mainPageController,
  children: [
    _buildDashboardContent(),    // Page 0
    _buildNetworkTopoPage(),     // Page 1  
    _buildSettingsPage(),        // Page 2
    _buildNewFeaturePage(),      // Page 3: 新增頁面
  ],
)

// 修改底部導航的佈局計算
double _getCirclePosition() {
  final sectionWidth = barWidth / 4;  // 改為 4 等分
  // 重新計算各個位置...
}

// 添加新的圖標和處理邏輯
Widget _buildBottomNavIcon(int index, String imagePath, IconData fallbackIcon) {
  // 處理第 4 個圖標...
}
```

---

## 故障排除

### ❗ 常見問題

#### 1. **底部導航圓圈動畫位置不正確**
**症狀**: 圓圈沒有移動到正確的圖標位置
**原因**: 螢幕尺寸變化導致計算偏差
**解決方法**: 檢查 `_getCirclePosition()` 方法中的位置計算
```dart
// 確保使用正確的螢幕寬度
final screenWidth = MediaQuery.of(context).size.width;
final barWidth = screenWidth * 0.70;  // 檢查這個比例是否正確
```

#### 2. **NetworkTopo 頁面顯示空白**
**症狀**: 切換到 NetworkTopo 時什麼都不顯示
**原因**: 數據載入失敗或組件初始化問題
**解決方法**:
```dart
// 檢查數據載入狀態
if (_isLoadingData) {
  return Center(child: CircularProgressIndicator());
}

// 檢查設備數據是否為空
final devices = _getDevices();
if (devices.isEmpty) {
  return Center(child: Text('No devices found'));
}
```

#### 3. **主題樣式不一致**
**症狀**: 某些組件的顏色或樣式與其他不同
**原因**: 沒有使用統一的主題系統
**解決方法**: 確保所有組件都使用 `app_theme.dart`
```dart
// 正確的使用方式
final appTheme = AppTheme();
Container(
  decoration: appTheme.whiteBoxTheme.buildStandardCard(...),
  child: Text(
    'Example',
    style: AppTextStyles.bodyLarge,  // 使用統一的文字樣式
  ),
)
```

#### 4. **數據更新不及時**
**症狀**: 真實數據模式下，設備資訊沒有及時更新
**原因**: 快取機制阻止了頻繁的 API 調用
**解決方法**: 調整快取時間或強制重新載入
```dart
// 在 network_topo_config.dart 中調整
static const int meshApiCacheSeconds = 5;  // 改為 5 秒快取

// 或者手動清除快取
RealDataIntegrationService.clearCache();
await RealDataIntegrationService.forceReload();
```

### 🔧 調試技巧

#### 1. **啟用詳細日誌**
```dart
// 在相關組件中添加調試輸出
print('=== DEBUG: 當前頁面索引 $_currentPageIndex ===');
print('=== DEBUG: 設備數量 ${devices.length} ===');
print('=== DEBUG: 載入狀態 $_isLoadingData ===');
```

#### 2. **使用假數據測試**
```dart
// 在 network_topo_config.dart 中
static bool useRealData = false;  // 暫時改為假數據模式測試
```

#### 3. **檢查組件邊界**
```dart
// 在組件外加上有顏色的 Container 來檢查佈局
Container(
  color: Colors.red.withOpacity(0.3),  // 半透明紅色邊界
  child: YourWidget(),
)
```

### 📞 技術支援

如果遇到無法解決的問題，請檢查：

1. **Flutter 版本**: 確保使用 3.27.0 或更高版本
2. **依賴版本**: 檢查 `pubspec.yaml` 中的套件版本
3. **設備權限**: 確保應用有網路