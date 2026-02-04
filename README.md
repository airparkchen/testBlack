# Wi-Fi 5G IoT App 框架 

一個模組化的 Flutter 應用框架，專為物聯網、Wi-Fi 和 5G 設備管理設計，支援多產品線的設備控制與監控。

## 📋 目錄
- [專案概述](#專案概述)
- [系統架構與演進](#系統架構與演進)
- [Phase 1: 初始化系統](#phase-1-初始化系統)
- [Phase 2: 主應用系統](#phase-2-主應用系統)
- [專案結構](#專案結構)
- [技術實現](#技術實現)
- [開發指南](#開發指南)
- [故障排除](#故障排除)
- [部署與維護](#部署與維護)

---

## 專案概述

### 🎯 設計目標
- **統一平台**：提供統一、可重用的框架，用於開發控制 Wi-Fi、5G 和 IoT 設備的移動應用
- **模組化架構**：支援跨產品線的 UI 和 API 整合，元件可重複使用
- **現代化體驗**：採用 PageView 滑動切換導航系統，提供流暢的用戶體驗
- **真實數據整合**：支援真實 Mesh 網路拓樸顯示和即時速度監控

### 🌟 核心特點
- **雙階段系統**：Phase1 初始化設定 + Phase2 主應用介面
- **三頁導航系統**：Dashboard、NetworkTopo、Settings 統一底部導航
- **智能拓樸圖**：支援 Gateway → Extender → Client 的階層連接顯示
- **即時監控**：網路速度圖表、設備狀態、客戶端管理
- **安全機制**：SRP 登入、JWT 認證、密碼加密保護
- **響應式設計**：適配不同螢幕尺寸，統一紫色漸層主題

---

## 系統架構與演進

### 🏗️ 整體系統流程
```
應用程式啟動
    ↓
main.dart → InitializationPage
    ↓
檢查 system/info API
    ↓
判斷 blank_state 狀態
    ├── 需要設定 → Phase1: Setup Wizard
    │   ├── Wi-Fi 設定流程
    │   ├── 帳戶密碼設定
    │   ├── 連線類型配置
    │   └── 完成設定 → LoginPage
    └── 已設定完成 → LoginPage
        ↓
        SRP/傳統登入驗證
        ↓
        API 預載入 (協調模式)
        ↓
        Phase2: DashboardPage (主應用)
        ├── Dashboard (乙太網路狀態)
        ├── NetworkTopo (網路拓樸 + 速度圖表)
        └── Settings (系統設定)
```

### 📱 導航架構演進
```
Phase1: 獨立頁面導航
InitializationPage → WifiSettingFlowPage → LoginPage

Phase2: 統一導航容器
DashboardPage (主容器)
├── PageView 滑動容器
│   ├── Page 0: Dashboard Content
│   ├── Page 1: NetworkTopo Content
│   └── Page 2: Settings Content
└── BottomNavigationBar (統一底部導航)
    ├── 圓圈移動動畫
    └── 三頁切換控制
```

---

## Phase 1: 初始化系統

### 🎯 主要功能
- **設備初始化**：Wi-Fi 設備設定嚮導，支援 QR 碼掃描
- **帳戶設定**：用戶名與密碼設定，基於設備序號計算初始密碼
- **連線配置**：DHCP、Static IP、PPPoE 連線類型選擇
- **SSID 配置**：Wi-Fi 網絡名稱與安全選項設定
- **安全驗證**：SRP 協議零知識證明登入

### 🔧 核心組件
```
lib/shared/ui/components/basic/
├── AccountPasswordComponent.dart     # 帳戶密碼設定
├── ConnectionTypeComponent.dart      # 連線類型選擇
├── SetSSIDComponent.dart            # SSID 設定
├── StepperComponent.dart            # 步驟導航
├── WifiScannerComponent.dart        # Wi-Fi 掃描
└── FinishingWizardComponent.dart    # 完成嚮導
```

### 📋 設定流程
1. **系統檢查** → 檢查設備狀態，判斷是否需要初始化
2. **Wi-Fi 掃描** → 自動發現可用設備，支援 QR 碼快速添加
3. **帳戶設定** → 設定用戶名密碼，自動計算初始密碼
4. **連線配置** → 選擇網路連線方式 (DHCP/Static/PPPoE)
5. **SSID 設定** → 配置無線網路名稱和安全選項
6. **完成驗證** → SRP 登入驗證，進入主應用

---

## Phase 2: 主應用系統

### 🎯 三頁導航系統

#### 📊 Dashboard 頁面
```
絕對定位布局系統:
├── 標題區域 (10%-15%): "Dashboard" 標題
├── 指示器區域 (12%-21%): 三個分頁指示圓點
└── 內容區域 (19%-80%): DashboardComponent
    ├── Page 1: 系統狀態 (Model Name, Internet, WiFi 頻率)
    ├── Page 2: SSID 列表 (WiFi SSID 詳細資訊)
    └── Page 3: Ethernet (LAN 埠狀態)
```

**數據來源**: `DashboardDataService` → `/api/v1/system/dashboard`

#### 🌐 NetworkTopo 頁面
```
雙視圖模式:
├── Topology 視圖
│   ├── 上半部: NetworkTopologyComponent
│   │   ├── Internet 圖標 → Gateway 圖標 → Extender 圖標們
│   │   ├── 連接線 (實線=有線, 虛線=無線)
│   │   ├── 數字標籤 (顯示連接的客戶端數量)
│   │   └── 智能佈局 (1-4設備特殊佈局，5+設備圓形排列)
│   └── 下半部: SpeedChartWidget
│       ├── 雙線速度曲線 (藍色下載線 + 橙色上傳線)
│       ├── 20個資料點滑動窗口
│       ├── 插值動畫 (500ms 更新)
│       └── 智能單位格式化 (Kbps/Mbps/Gbps)
└── List 視圖
    ├── Gateway 卡片 (Controller + MAC 地址)
    └── Extender 卡片們 (Agent MAC, IP, RSSI, 客戶端數)
```

**數據來源**:
- `/api/v1/system/mesh_topology` (拓樸結構)
- `/api/v1/system/throughput` (速度數據)

#### ⚙️ Settings 頁面
簡單佔位頁面，顯示 "Coming Soon..." (未來擴展)

### 📱 設備詳情系統
```
DeviceDetailPage:
├── 頂部 RSSI 指示器 (三段式顏色: 綠/黃/橙)
├── 設備主要資訊
│   ├── 設備圖標 + 紫色數字標籤
│   ├── 名稱顯示邏輯:
│   │   ├── Gateway: "Controller" + MAC
│   │   └── Extender: 偵測名稱 + "Agent MAC"
│   └── IP、客戶端數量
└── 客戶端列表 (TV, Xbox, iPhone, Laptop 等)
    ├── 設備類型自動識別
    ├── 連接方式格式化 (SSID_頻段 或 Ethernet)
    └── RSSI、IP、連接時間資訊
```

---

## 專案結構

### 📁 主要目錄架構
```
lib/
├── main.dart                        # 應用程式入口點
├── shared/
│   ├── api/
│   │   ├── wifi_api_service.dart    # 核心 API 服務 (HTTPS 支援)
│   │   └── wifi_api/                # API 實現細節
│   ├── models/
│   │   ├── dashboard_data_models.dart  # Dashboard 數據模型
│   │   ├── mesh_data_models.dart       # Mesh 網路數據模型
│   │   └── StaticIpConfig.dart         # 靜態 IP 配置
│   ├── services/
│   │   ├── api_preloader_service.dart     # API 預載入協調
│   │   ├── dashboard_data_service.dart    # Dashboard 數據服務
│   │   ├── real_data_integration_service.dart # 真實數據整合
│   │   ├── real_speed_data_service.dart   # 速度數據服務
│   │   └── mesh_data_analyzer.dart        # Mesh 數據分析
│   ├── theme/
│   │   └── app_theme.dart              # 統一主題系統
│   ├── utils/
│   │   ├── api_coordinator.dart        # API 協調器
│   │   ├── api_logger.dart            # API 日誌系統
│   │   ├── srp_helper.dart            # SRP 協議幫助
│   │   └── validators.dart            # 驗證工具
│   └── ui/
│       ├── components/basic/           # 基礎 UI 組件
│       │   ├── DashboardComponent.dart
│       │   ├── NetworkTopologyComponent.dart
│       │   ├── topology_display_widget.dart
│       │   ├── device_list_widget.dart
│       │   └── Phase1 組件們...
│       └── pages/
│           ├── home/                  # Phase2 主頁面系統
│           │   ├── DashboardPage.dart      # 主導航容器
│           │   ├── DeviceDetailPage.dart   # 設備詳情
│           │   └── Topo/                   # 拓樸配置
│           ├── initialization/        # Phase1 初始化頁面
│           │   ├── InitializationPage.dart
│           │   ├── LoginPage.dart
│           │   ├── QrCodeScannerPage.dart
│           │   └── WifiSettingFlowPage.dart
│           └── test/                  # 測試頁面
│               ├── NetworkTopoView.dart
│               └── 其他測試頁面...
└── docs/                             # 技術文檔
    ├── Phase1 與 Phase2 技術指南
    └── API 整合與安全機制文檔
```

---

## 技術實現

### 🔗 API 整合策略

#### 預載入階段 (協調模式)
```dart
// 確保應用啟動時所有關鍵 API 都能成功載入
await ApiCoordinator.withCoordination(() async {
  await _preloadDashboardAPI();    // 載入 Dashboard 數據
  await _preloadMeshAPI();         // 載入 Mesh 拓樸數據  
  await _preloadThroughputAPI();   // 載入速度數據
});
```

#### 運行時階段 (平行處理 + 快取)
```dart
// 錯開時間避免 API 衝突
- Mesh API: 每 9 秒調用，18 秒快取
- Dashboard API: 每 14 秒調用，15 秒快取  
- Throughput API: 每 6 秒調用，12 秒快取
- 自動重新載入: 每 47 秒觸發 (錯開所有 API)
```

### 🎨 主題系統

#### WhiteBoxTheme 核心組件
```dart
AppTheme (單例)
├── AppColors
│   ├── primary: #9747FF (主紫色)
│   ├── primaryDark: #162140 (深藍色)
│   └── 紫藍漸層: [#162140, #9747FF]
├── AppTextStyles (heading1/2/3, bodyLarge/Medium/Small)
├── AppDimensions (spacing, radius, heights)
└── WhiteBoxTheme
    ├── buildStandardCard() → 標準漸層卡片
    ├── buildStandardButton() → 標準按鈕
    └── 響應式背景系統
```

### 📊 數據流向

#### 真實數據模式流程
```
WiFi API 調用:
wifi_api_service.dart.getMeshTopology()
    ↓ HTTPS GET /api/v1/system/mesh_topology
mesh_data_analyzer.dart
    ↓ 解析過濾 (排除 RSSI全0、backhaul、無IP設備)
real_data_integration_service.dart
    ├── getNetworkDevices() → 拓樸圖用 (Extender only)
    ├── getListViewDevices() → 列表用 (Gateway + Extender)
    ├── getDeviceConnections() → 連接數字標籤
    └── getClientDevicesForParent() → 設備詳情頁
UI 組件渲染
```

#### 假數據模式流程
```
fake_data_generator.dart
├── FakeDataGenerator.generateDevices() → 生成設備
├── FakeDataGenerator.generateConnections() → 生成連接
└── SpeedDataGenerator → 固定長度滑動窗口 (20點)
    ├── 雙線數據 (上傳65Mbps, 下載83Mbps)
    ├── 平滑係數: 0.8
    └── 更新頻率: 500ms
```

---

## 開發指南

### 🛠️ 環境設定
```bash
# 前置需求
Flutter SDK ≥3.27.0
Dart SDK (與 Flutter 兼容)

# 必要套件
wifi_scan, mobile_scanner, http, connectivity_plus
network_info_plus, crypto, srp

# 安裝步驟
git clone https://github.com/yourusername/wifi-5g-iot-app.git
cd wifi-5g-iot-app
flutter pub get
flutter run
```

### 🔧 配置參數

#### 網路拓樸配置
```dart
// network_topo_config.dart
static bool useRealData = true;                    // true: 真實API, false: 假數據
static const bool showExtenderConnections = true; // 顯示 Extender 間連線
static const int meshApiCacheSeconds = 18;        // API 快取時間
```

#### API 端點配置
```json
// wifi.json
{
  "baseUrl": "https://192.168.1.1",
  "apiVersion": "/api/v1",
  "endpoints": {
    "systemInfo": "/api/v1/system/info",
    "systemDashboard": "/api/v1/system/dashboard",
    "meshTopology": "/api/v1/system/mesh_topology",
    "systemThroughput": "/api/v1/system/throughput",
    "userLogin": "/api/v1/user/login"
  }
}
```

### 📝 常見修改場景

#### 1. 更改 Dashboard 顯示內容
```dart
// 修改 DashboardPage.dart 中的 _fetchDashboardDataFromAPI()
Future<List<EthernetPageData>> _fetchDashboardDataFromAPI() async {
  final dashboardData = await DashboardDataService.getDashboardData();
  return _convertDashboardDataToEthernetPages(dashboardData);
}
```

#### 2. 添加新的拓樸功能
```dart
// 在 NetworkTopoView.dart 中擴展 TabBar
Row(
  children: [
    Expanded(child: GestureDetector(...)), // Topology
    Expanded(child: GestureDetector(...)), // List  
    Expanded(child: GestureDetector(...)), // 新功能
  ],
)
```

#### 3. 自定義設備詳情頁面
```dart
// 修改 DeviceDetailPage.dart 的排版
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Column(
      children: [
        _buildCustomTopArea(),     // 自定義頂部
        _buildTabView(),          // 分頁檢視
        _buildCustomBottomArea(), // 自定義底部
      ],
    ),
  );
}
```

### 🎯 使用方法

#### 基本使用
```dart
// 預設顯示 Dashboard
home: const DashboardPage(),

// 預設顯示 NetworkTopo (推薦從 LoginPage 跳轉)
home: const DashboardPage(
  showBottomNavigation: true,
  initialNavigationIndex: 1,
),

// 獨立使用 NetworkTopo
home: const NetworkTopoView(),
```

#### 從 LoginPage 跳轉
```dart
Navigator.of(context).pushReplacement(
  MaterialPageRoute(
    builder: (context) => const DashboardPage(
      showBottomNavigation: true,
      initialNavigationIndex: 1, // NetworkTopo
    ),
  ),
);
```

---

## 故障排除

### ❗ 常見問題

#### 1. 底部導航圓圈位置不正確
**原因**: 螢幕尺寸計算偏差  
**解決**: 檢查 `_getCirclePosition()` 中的位置計算
```dart
final screenWidth = MediaQuery.of(context).size.width;
final barWidth = screenWidth * 0.70;  // 確認比例正確
```

#### 2. NetworkTopo 頁面顯示空白
**原因**: 數據載入失敗或組件初始化問題  
**解決**: 檢查數據載入狀態和設備數據
```dart
if (_isLoadingData) {
  return Center(child: CircularProgressIndicator());
}
if (devices.isEmpty) {
  return Center(child: Text('No devices found'));
}
```

#### 3. API 連接失敗
**原因**: 網路連接或端點配置問題  
**解決**: 檢查網路狀態和 API 端點
```dart
if (!await _isApiReachable()) {
  throw Exception('無法連接到路由器');
}
print('當前 API 端點: ${WifiApiService.baseUrl}');
```

#### 4. 數據更新不及時
**原因**: 快取機制阻止頻繁 API 調用  
**解決**: 調整快取時間或強制重新載入
```dart
// 調整快取時間
static const int meshApiCacheSeconds = 5;

// 或強制重新載入
RealDataIntegrationService.clearCache();
await RealDataIntegrationService.forceReload();
```

### 🔧 調試技巧

#### 1. 啟用詳細日誌
```dart
// network_topo_config.dart
static const bool enableDetailedLogging = true;
```

#### 2. 使用假數據測試
```dart
static bool useRealData = false;  // 暫時改為假數據模式
```

#### 3. 檢查組件邊界
```dart
Container(
  color: Colors.red.withOpacity(0.3),  // 半透明邊界
  child: YourWidget(),
)
```

---

## 部署與維護

### 🚀 生產環境配置
```dart
// 關閉除錯模式
NetworkTopoConfig.enableDetailedLogging = false;
NetworkTopoConfig.enableFastUpdateMode = false;

// 使用 API
WifiApiService.baseUrl = '';
```

### 📦 打包發布
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```


### 🔄 維護建議
1. **定期更新依賴**: 檢查 Flutter 和套件版本
2. **監控 API 效能**: 使用 ApiLogger 追蹤調用統計
3. **測試多設備**: 確保不同螢幕尺寸的兼容性
4. **備份配置**: 保留 API 端點和主題配置備份

---

## 📄 授權與貢獻

**專案**: Wi-Fi 5G IoT App Framework  
**維護者**: WhiteBox 開發團隊  
**版本**: v0.2.0.0527  
**授權**: Apache License 2.0  
**最後更新**: 2025年6月

### 🤝 貢獻流程
1. Fork 專案
2. 創建功能分支：`git checkout -b feature/amazing-feature`
3. 提交更改：`git commit -m '添加功能說明'`
4. 推送分支：`git push origin feature/amazing-feature`
5. 開啟 Pull Request

### 📚 相關資源
- **Flutter 官方文檔**: https://flutter.dev/docs
- **Dart 語言指南**: https://dart.dev/guides
- **API 參考**: Swagger UI 
