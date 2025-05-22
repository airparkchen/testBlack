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

## 目前實現功能

- **設備初始化**：Wi-Fi 設備設定嚮導
- **帳戶設定**：用戶名與密碼設定
- **連線類型**：DHCP、Static IP、PPPoE
- **SSID 配置**：Wi-Fi 網絡名稱與安全選項
- **QR 碼掃描**：快速添加設備
- **Wi-Fi 掃描**：自動發現可用設備
- **多設備支援**：JSON 配置不同型號
- **安全機制**：
    - 初始密碼計算
    - API 身份驗證
    - SRP 安全登入
- **進度顯示**：設定流程進度條

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
│   │   └── ...
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
│       │       └── WifiScannerComponent.dart       # Wi-Fi 掃描組件
│       └── pages/                       # 頁面
│           ├── initialization/          # 初始化相關頁面
│           │   ├── InitializationPage.dart         # 初始化主頁面
│           │   ├── LoginPage.dart                  # 登入頁面
│           │   ├── QrCodeScannerPage.dart          # QR 碼掃描頁面
│           │   ├── WifiConnectionPage.dart         # Wi-Fi 連線頁面
│           │   └── WifiSettingFlowPage.dart        # Wi-Fi 設定流程頁面
│           └── test/                    # 測試頁面
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


## 設計風格

- **主色調**：紫色 (#9747FF) 和深藍色 (#162140)
- **背景色**：淺灰色 (#D9D9D9) 和卡片背景色 (#EEEEEE)
- **按鈕樣式**：方形或微圓角，帶紫色漸層背景
- **元件佈局**：清晰的邊界和簡潔的元素間距
- **統一文字樣式**：標題 32px，副標題 22px，正文 16px
- **漸層效果**：從深藍色 (#162140) 到紫色 (#9747FF) 的漸層

此設計風格更現代化，具有前衛的紫色漸層元素，同時保持了清晰的佈局和簡潔結構。紫色和深藍色的漸層為應用程式增添了時尚感，同時保持了專業的外觀。

## 安全機制

- **初始密碼**：基於設備序號、鹽值、SSID 計算
- **JWT 認證**：API 訪問授權
- **SRP 登入**：零知識證明協議
- **通訊加密**：標準加密保護數據
- **密碼校驗**：確保密碼複雜度

## 開發指南

### 使用標準元件

- **StepperComponent**：動態配置步驟導航
- **WifiScannerComponent**：掃描並顯示 Wi-Fi 設備
- **表單元件**：帳戶、連線類型、SSID 等

### 擴展流程

- 修改 `wifi.json` 配置設備初始化流程。例如，針對 "Micky" 設備型號的配置如下：

    ```json
    {
      "models": {
        "Micky": {
          "steps": [
            {
              "id": 1,
              "name": "Account",
              "next": 2,
              "components": [
                "AccountPasswordComponent"
              ],
              "detail": [
                "User",
                "Password",
                "Confirm Password"
              ],
              "apiCalls": [
                {
                  "type": "start",
                  "methods": [
                    "systemInfo",
                    "userLogin"
                  ]
                }
              ]
            },
            {
              "id": 2,
              "name": "Internet",
              "next": 3,
              "components": [
                "ConnectionTypeComponent"
              ],
              "detail": [
                "DHCP",
                "Static IP",
                "PPPoE"
              ],
              "detailOptions": {
                "Static IP": ["IP Address", "IP Subnet Mask", "Gateway IP Address", "Primary DNS"],
                "PPPoE": ["User", "Password"]
              },
              "apiCalls": [
                {
                  "type": "start",
                  "methods": [
                    "wanEthGet"
                  ]
                }
              ]
            },
            {
              "id": 3,
              "name": "Wireless",
              "next": 4,
              "components": [
                "SetSSIDComponent"
              ],
              "detail": [
                "WPA3 Personal"
              ],
              "detailOptions": {
                "WPA3 Personal": ["Password"]
              },
              "apiCalls": [
                {
                  "type": "start",
                  "methods": [
                    "wirelessBasicGet"
                  ]
                }
              ]
            },
            {
              "id": 4,
              "name": "Summary",
              "next": null,
              "components": [
                "SummaryComponent"
              ],
              "detail": [
                "Model Name",
                "Operation Mode",
                "Wireless SSID",
                "Wireless Key"
              ],
              "apiCalls": [
                {
                  "type": "finish",
                  "method": "postWizardFinish"
                },
                {
                  "type": "end",
                  "methods": [
                    "wizardStart",
                    "userChangePassword",
                    "wanEthUpdate",
                    "wirelessBasicUpdate",
                    "wizardFinish"
                  ]
                }
              ]
            }
          ],
          "type": "JSON",
          "API": "WifiAPI"
        }
      }
    }
    ```


### 添加新設備型號

1. 在 `wifi.json` 添加型號定義（如上面的 "Micky"）
2. 實現特定組件與流程
3. 在設備選擇頁面註冊型號

### API 服務

```dart
// 獲取系統信息
final systemInfo = await WifiApiService.getSystemInfo();
// 更新 Wi-Fi 參數
await WifiApiService.updateWirelessBasic({
  'ssid': 'MyNetwork',
  'security': 'WPA3',
  'password': 'SecurePassword'
});
// 初始密碼登入
await WifiApiService.loginWithInitialPassword();
```

## 待實現功能

- 設備儀表板：運行狀態與管理
- 高級設定：設備特定選項
- 設備管理：多設備添加/刪除
- 協同控制：IoT 設備聯動
- 固件升級：設備更新支援

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

## 許可證

- Apache 許可證 2.0（詳見 LICENSE 文件）