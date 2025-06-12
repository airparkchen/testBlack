# Wi-Fi 5G IoT App 框架

一個模組化的 Flutter 應用框架，專為物聯網、Wi-Fi 和 5G 設備管理設計，支援多產品線的設備控制與監控。

## 概述

- **目標**：提供統一、可重用的框架，用於開發控制 Wi-Fi、5G 和 IoT 設備的移動應用。
- **設計理念**：模組化架構，支援跨產品線的 UI 和 API 整合。
- **核心特點**：
    - 多產品支援（Wi-Fi、5G、IoT）
    - 可重用模組化 UI 元件
    - 統一 API 整合（設備、雲端、第三方）
    - 標準化初始化與運行流程
    - 統一紫色漸層色調、現代化設計
    - 完整安全機制（初始密碼、API 認證）
    - **PageView 滑動切換導航系統**（新增）
    - **真實 Mesh 網路拓樸顯示**（新增）

## 目前實現功能

### 核心功能
- **設備初始化**：Wi-Fi 設備設定嚮導
- **帳戶設定**：用戶名與密碼設定
- **連線類型**：DHCP、Static IP、PPPoE
- **SSID 配置**：Wi-Fi 網絡名稱與安全選項
- **QR 碼掃描**：快速添加設備
- **Wi-Fi 掃描**：自動發現可用設備
- **多設備支援**：JSON 配置不同型號

### Dashboard 系統（新增）
- **三頁式導航**：Dashboard、NetworkTopo、Settings
- **PageView 滑動切換**：流暢的現代化導航體驗
- **乙太網路狀態監控**：即時連接狀態顯示
- **分頁指示器**：三點式頁面導航指示

### 網路拓樸系統（新增）
- **Mesh 網路拓樸圖**：視覺化設備連接關係
- **設備類型支援**：Gateway、Extender、Host 設備
- **連線類型顯示**：有線（實線）、無線（虛線）連接
- **Extender 間連線**：支援多層級 Extender 連接顯示
- **設備數量標籤**：動態顯示連接的客戶端數量
- **速度圖表**：即時網路速度監控
- **雙視圖模式**：拓樸圖/設備列表切換
- **設備詳情頁面**：詳細設備資訊和客戶端列表

### 安全機制
- **初始密碼**：基於設備序號、鹽值、SSID 計算
- **JWT 認證**：API 訪問授權
- **SRP 登入**：零知識證明協議
- **通訊加密**：標準加密保護數據
- **密碼校驗**：確保密碼複雜度

## 專案結構

```
lib/
├── main.dart                            # 應用程式入口點
├── shared/
│   ├── api/                             # API 服務層
│   │   ├── wifi_api_service.dart        # Wi-Fi API 服務封裝
│   │   └── wifi_api/                    # Wi-Fi API 詳細實現
│   │       ├── login_process.dart       # 登入處理流程
│   │       ├── password_service.dart    # 密碼服務
│   │       └── ...
│   ├── connection/                      # 連接相關類
│   │   ├── abs_api_request.dart         # API 請求抽象類
│   │   ├── api_service.dart             # API 服務實現
│   │   ├── connection_utils.dart        # 連接工具類
│   │   ├── login_process.dart           # 登入流程
│   │   └── ...
│   ├── config/                          # 配置文件
│   │   ├── api/
│   │   │   └── wifi.json                # API 端點配置
│   │   └── flows/
│   │       └── initialization/
│   │           └── wifi.json            # Wi-Fi 初始化流程配置
│   ├── models/                          # 數據模型
│   │   ├── StaticIpConfig.dart          # 靜態 IP 配置模型
│   │   ├── mesh_data_models.dart        # Mesh 網路數據模型（新增）
│   │   └── ...
│   ├── services/                        # 服務層（新增）
│   │   ├── mesh_data_analyzer.dart      # Mesh 數據分析服務
│   │   └── real_data_integration_service.dart # 真實數據整合服務
│   ├── theme/                           # 主題設定
│   │   └── app_theme.dart               # 應用程式主題設定
│   ├── utils/                           # 工具類
│   │   ├── resource.dart                # 資源管理
│   │   ├── srp_helper.dart              # SRP 協議幫助類
│   │   ├── utility.dart                 # 通用工具
│   │   └── validators.dart              # 驗證工具
│   └── ui/
│       ├── components/                  # UI 組件
│       │   └── basic/                   # 基礎 UI 組件
│       │       ├── AccountPasswordComponent.dart   # 帳戶密碼設定組件
│       │       ├── ConnectionTypeComponent.dart    # 連線類型選擇組件
│       │       ├── FinishingWizardComponent.dart   # 完成嚮導組件
│       │       ├── SetSSIDComponent.dart           # SSID 設定組件
│       │       ├── StepperComponent.dart           # 步驟導航組件
│       │       ├── SummaryComponent.dart           # 設定摘要組件
│       │       ├── WifiScannerComponent.dart       # Wi-Fi 掃描組件
│       │       ├── DashboardComponent.dart         # Dashboard 分頁組件（新增）
│       │       ├── NetworkTopologyComponent.dart  # 網路拓樸圖組件（新增）
│       │       ├── topology_display_widget.dart   # 拓樸顯示組合組件（新增）
│       │       └── device_list_widget.dart        # 設備列表組件（新增）
│       └── pages/                       # 頁面
│           ├── home/                    # 主頁面系統（新增）
│           │   ├── DashboardPage.dart           # 主導航容器頁面
│           │   ├── DeviceDetailPage.dart        # 設備詳情頁面
│           │   └── Topo/                        # 拓樸相關頁面
│           │       ├── network_topo_config.dart     # 網路拓樸配置
│           │       ├── fake_data_generator.dart     # 測試數據生成器
│           │       └── real_data_service.dart       # 真實數據服務
│           ├── initialization/          # 初始化相關頁面
│           │   ├── InitializationPage.dart         # 初始化主頁面
│           │   ├── LoginPage.dart                  # 登入頁面
│           │   ├── QrCodeScannerPage.dart          # QR 碼掃描頁面
│           │   ├── WifiConnectionPage.dart         # Wi-Fi 連線頁面
│           │   └── WifiSettingFlowPage.dart        # Wi-Fi 設定流程頁面
│           └── test/                    # 測試頁面
│               ├── NetworkTopoView.dart            # 網路拓樸視圖頁面（新增）
│               ├── SpeedAreaTestPage.dart          # 速度區域測試頁面（新增）
│               ├── SrpLoginModifiedTestPage.dart   # SRP 登入測試頁面
│               ├── SrpLoginTestPage.dart           # SRP 登入標準測試頁面
│               ├── TestPage.dart                   # 通用測試頁面
│               ├── TestPasswordPage.dart           # 密碼測試頁面
│               └── theme_test_page.dart            # 主題測試頁面
└── docs/                                # 技術文檔
    ├── 01-app-structure.md              # 專案結構與組件說明
    ├── 02-ui-components-guide.md        # UI 組件使用指南
    ├── 03-wifi-setting-flow-guide.md    # Wi-Fi 設定流程實作指南
    ├── 04-ui-components-design-guide.md # UI 佈局風格指南
    ├── 05-api-integration-guide.md      # API 整合指南
    ├── 06-security-implementation-guide.md # 安全機制實現指南
    └── README.md                        # 文檔索引
```

## 開始使用

### 前置需求

- Flutter SDK (≥3.7.2)
- Dart SDK (與 Flutter 兼容)
- Android Studio / VS Code + Flutter 插件
- 套件：wifi_scan, mobile_scanner, http, connectivity_plus, network_info_plus, crypto, JSON 序列化

### 安裝步驟

1. 複製專案：

    ```bash
    git clone https://github.com/yourusername/wifi-5g-iot-app.git
    ```

2. 進入目錄：

    ```bash
    cd wifi-5g-iot-app
    ```

3. 安裝依賴：

    ```bash
    flutter pub get
    ```

4. 運行應用：

    ```bash
    flutter run
    ```

## 應用程式導航架構

### PageView 滑動切換系統
應用程式採用現代化的 PageView 滑動切換設計，類似 Instagram、微信等主流應用：

```
DashboardPage (主導航容器)
├── PageView 滑動容器
│   ├── Page 0: Dashboard (乙太網路狀態監控)
│   ├── Page 1: NetworkTopo (網路拓樸顯示)
│   └── Page 2: Settings (系統設定)
└── BottomNavigationBar (統一底部導航)
```

### 導航特點
- **無縫切換**：手指滑動或底部導航點擊
- **狀態保持**：三個頁面同時在記憶體中，切換時狀態不丟失
- **動畫效果**：底部導航圓圈移動動畫
- **響應式設計**：根據螢幕尺寸自動調整

## 網路拓樸系統

### Mesh 網路支援
- **多層級拓樸**：支援 Gateway → Extender → Extender 的階層連接
- **真實數據整合**：從 Mesh API (`/api/v1/system/mesh_topology`) 獲取即時數據
- **設備過濾**：自動過濾無效設備（RSSI 全 0 的 Extender、backhaul Host 等）
- **連接類型識別**：Ethernet（實線）、Wireless（虛線）視覺區分

### 拓樸圖功能
- **智能佈局**：根據設備數量自動調整排列方式
    - 1-4 設備：特殊優化佈局
    - 5+ 設備：圓形排列
- **Extender 間連線**：支援顯示 Extender 之間的直接連接
- **數字標籤**：顯示每個設備連接的客戶端數量
- **設備詳情**：點擊設備查看詳細資訊和連接的客戶端列表

### 速度監控
- **即時速度圖表**：固定長度滑動窗口顯示網路速度變化
- **平滑動畫**：500ms 更新間隔，流暢的動畫效果
- **數據模式切換**：支援真實 API 數據和測試數據

## 設計風格

- **主色調**：紫色 (#9747FF) 和深藍色 (#162140)
- **背景色**：淺灰色 (#D9D9D9) 和卡片背景色 (#EEEEEE)
- **按鈕樣式**：方形或微圓角，帶紫色漸層背景
- **元件佈局**：清晰的邊界和簡潔的元素間距
- **統一文字樣式**：標題 32px，副標題 22px，正文 16px
- **漸層效果**：從深藍色 (#162140) 到紫色 (#9747FF) 的漸層
- **毛玻璃效果**：使用 BackdropFilter 實現現代化半透明卡片

## 開發指南

### 使用標準元件

#### Dashboard 系統
- **DashboardPage**：主導航容器，管理三頁切換
- **DashboardComponent**：可重用的 Dashboard 內容組件
- **PageView 導航**：支援手指滑動和底部導航點擊

#### 網路拓樸系統
- **NetworkTopoView**：支援獨立使用或嵌入使用的雙模式設計
- **NetworkTopologyComponent**：核心拓樸圖繪製組件
- **topology_display_widget**：拓樸圖和速度圖的組合組件
- **device_list_widget**：設備列表顯示組件

#### 傳統初始化流程
- **StepperComponent**：動態配置步驟導航
- **WifiScannerComponent**：掃描並顯示 Wi-Fi 設備
- **表單元件**：帳戶、連線類型、SSID 等

### 擴展流程

#### 修改 Dashboard 內容
修改 `DashboardPage.dart` 中的 `_fetchDashboardDataFromAPI()` 方法來自定義 Dashboard 顯示內容。

#### 添加新的拓樸功能
在 `NetworkTopoView.dart` 中擴展 TabBar 支援更多視圖模式，或在 `NetworkTopologyComponent.dart` 中添加新的設備類型支援。

#### API 端點配置
修改 `wifi.json` 配置 API 端點和服務設定：

```json
{
  "baseUrl": "http://192.168.1.1",
  "apiVersion": "/api/v1",
  "timeoutSeconds": 10,
  "endpoints": {
    "systemInfo": {
      "path": "$apiVersion/system/info",
      "method": "get",
      "description": "獲取系統資訊"
    },
    "systemMeshTopology": {
      "path": "$apiVersion/system/mesh_topology",
      "method": "get",
      "description": "獲取網格拓撲資訊"
    },
    "userLogin": {
      "path": "$apiVersion/user/login",
      "method": "post",
      "description": "使用者SRP驗證登入"
    }
  }
}
```

#### 設備初始化流程配置
設備型號的初始化流程配置位於 `flows/initialization/wifi.json`：

```json
{
  "models": {
    "Micky": {
      "steps": [
        {
          "id": 1,
          "name": "Account",
          "components": ["AccountPasswordComponent"],
          "apiCalls": [{"type": "start", "methods": ["systemInfo", "userLogin"]}]
        }
      ],
      "type": "JSON",
      "API": "WifiAPI"
    }
  }
}
```

### API 服務

```dart
// 獲取系統信息
final systemInfo = await WifiApiService.getSystemInfo();

// 獲取 Mesh 網路拓樸
final meshTopology = await WifiApiService.getMeshTopology();

// 更新 Wi-Fi 參數
await WifiApiService.updateWirelessBasic({
'ssid': 'MyNetwork',
'security': 'WPA3',
'password': 'SecurePassword'
});

// 初始密碼登入
await WifiApiService.loginWithInitialPassword();
```

### 數據模式配置

```dart
// 在 network_topo_config.dart 中配置
class NetworkTopoConfig {
  static bool useRealData = true;                    // true: 真實 API 數據, false: 測試數據
  static const bool showExtenderConnections = true; // 是否顯示 Extender 間連線
  static const int meshApiCacheSeconds = 10;        // API 快取時間（秒）
}
```

## 待實現功能

- **Settings 頁面**：完整的系統設定界面
- **設備儀表板增強**：更多運行狀態與管理功能
- **高級拓樸功能**：支援更複雜的 Mesh 網路結構視覺化
- **協同控制**：IoT 設備聯動管理
- **固件升級**：設備更新支援
- **多語言支援**：國際化界面
- **暗色主題**：支援暗色模式

## 技術特點

### 模組化架構
- **組件可重用**：UI 組件支援多場景使用
- **數據層分離**：API、服務、模型清晰分層
- **配置驅動**：JSON 配置檔案控制流程和行為

### 效能優化
- **快取機制**：API 數據智能快取，減少網路請求
- **懶載入**：大型組件按需載入
- **記憶體管理**：PageView 保持狀態同時控制記憶體使用

### 用戶體驗
- **流暢動畫**：所有切換和載入都有平滑動畫
- **錯誤處理**：友善的錯誤提示和恢復機制
- **響應式設計**：適配不同螢幕尺寸

## 貢獻

1. Fork 專案
2. 創建功能分支：`git checkout -b feature/amazing-feature`
3. 提交更改：`git commit -m '添加功能'`
4. 推送分支：`git push origin feature/amazing-feature`
5. 開啟 Pull Request

## 文檔

- 位於 `docs/` 目錄，包含：
    - 專案結構與組件說明
    - UI 組件使用指南
    - Wi-Fi 設定流程
    - UI 佈局與風格
    - API 整合與安全機制
    - Dashboard 系統開發指南（新增）
    - 網路拓樸系統技術文檔（新增）

## 許可證

- Apache 許可證 2.0（詳見 LICENSE 文件）