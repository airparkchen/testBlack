# Wi-Fi 5G IOT APP 專案結構與組件說明

## 專案概述

這是一個為物聯網、Wi-Fi和5G設備管理設計的模組化Flutter應用框架。目前您的專案已經實現了一些基本畫面和組件，主要集中在Wi-Fi設備的初始化流程上。

## 主要檔案結構

```
lib/
├── main.dart                            # 應用程式入口點
├── shared/
    ├── config/
    │   └── flows/
    │       └── initialization/
    │           └── wifi.json            # Wi-Fi 初始化流程配置
    └── ui/
        ├── components/
        │   └── basic/                   # 基礎UI組件
        │       ├── AccountPasswordComponent.dart  # 帳戶密碼設定組件
        │       ├── ConnectionTypeComponent.dart   # 連線類型選擇組件
        │       ├── SetSSIDComponent.dart         # SSID設定組件
        │       ├── StepperComponent.dart         # 步驟導航組件
        │       └── WifiScannerComponent.dart     # Wi-Fi掃描組件
        └── pages/
            └── initialization/          # 初始化相關頁面
                ├── AddDevices.dart                # 添加設備頁面
                ├── InitializationPage.dart        # 初始化主頁面
                ├── QrCodeScannerPage.dart         # QR碼掃描頁面
                ├── WifiConnectionPage.dart        # Wi-Fi連線頁面
                └── WifiSettingFlowPage.dart       # Wi-Fi設定流程頁面
```

## 核心組件說明

### 基礎組件

1. **StepperComponent**
    - 提供步驟導航功能
    - 支援步驟間的跳轉和進度顯示
    - 通過JSON配置文件加載步驟數據

2. **WifiScannerComponent**
    - 掃描並顯示可用的Wi-Fi網絡
    - 提供設備選擇功能
    - 包含掃描結果處理邏輯

3. **AccountPasswordComponent**
    - 用戶名和密碼設定界面
    - 包含表單驗證功能
    - 支持密碼可見性切換

4. **ConnectionTypeComponent**
    - 網絡連接類型選擇界面
    - 支持DHCP、Static IP和PPPoE選項

5. **SetSSIDComponent**
    - Wi-Fi SSID和密碼設定界面
    - 根據安全選項動態顯示密碼區域
    - 支持多種Wi-Fi安全協議選擇

### 頁面組件

1. **WifiSettingFlowPage**
    - 多步驟Wi-Fi設定流程的主頁面
    - 使用PageView和StepperComponent實現步驟轉換
    - 從JSON配置文件動態加載步驟定義

2. **InitializationPage**
    - 設備初始化主頁面
    - 集成Wi-Fi掃描功能
    - 提供QR碼掃描和手動添加設備入口

3. **QrCodeScannerPage**
    - QR碼掃描界面
    - 使用mobile_scanner套件實現掃描功能
    - 支持閃光燈控制

4. **WifiConnectionPage**
    - Wi-Fi網絡選擇界面
    - 顯示網絡列表和信號強度
    - 支持網絡選擇和跳轉

5. **AddDevicesPage**
    - 設備添加界面
    - 使用GridView顯示設備列表
    - 支持添加新設備

## 配置文件說明

### wifi.json

這個配置文件定義了不同型號設備的初始化流程步驟：

```json
{
  "models": {
    "A": {
      "steps": [
        {
          "id": 1,
          "name": "Account",
          "next": 2,
          "components": ["AccountPasswordComponent"]
        },
        ...
      ],
      "type": "JSON",
      "API": "WifiAPI"
    },
    "B": {
      "steps": [
        ...
      ],
      "type": "JSON",
      "API": "WifiAPI"
    }
  }
}
```

- 每個型號定義了一個步驟序列
- 每個步驟包含：
    - `id`: 步驟標識符
    - `name`: 顯示名稱
    - `next`: 下一步的 id
    - `components`: 該步驟使用的組件列表

## 當前實現流程

目前已實現的初始化流程包括：

1. 帳戶設定（用戶名和密碼）
2. 網絡連接類型選擇
3. SSID設定（Wi-Fi名稱和密碼）
4. 總結頁面

## 待實現功能

1. 設備API連接
2. 儀表板/設備狀態監控
3. 高級設置選項
4. 設備管理功能
5. 多設備協同控制