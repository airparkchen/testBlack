# 📡 Phase 2 API 調用架構與數據管理 README

## 🎯 架構概覽

本專案實現了統一的 API 調用架構，確保數據一致性、減少重複調用，並提供即時同步更新機制。
(透過cluade查看程式架構，並協助我總結的，請主要以參考程式架構為主就好，文字說明可以忽略)

### 核心設計原則
- **單一數據源** - 每種 API 只調用一次，多處分享
- **統一管理** - 集中式數據管理與分發
- **事件驅動** - 基於事件的狀態更新機制
- **容錯優先** - API 失敗時保持現有狀態

---

## 🏗️ 系統架構圖

```
┌─────────────────── API 層 ───────────────────┐
│                                              │
│  🌐 Mesh API      📊 Dashboard API    💨 Throughput API │
│      (9s)              (14s)              (6s)        │
│       │                 │                  │          │
└───────┼─────────────────┼──────────────────┼──────────┘
        │                 │                  │
        ▼                 ▼                  ▼
┌─────────────────── 管理層 ───────────────────┐
│                                              │
│ 📋 UnifiedMeshDataManager  📢 DashboardEventNotifier │
│     (統一 Mesh 數據)          (事件通知系統)           │
│                                              │
└──────────────────┬───────────────────────────┘
                   │
                   ▼
┌─────────────────── 組件層 ───────────────────┐
│                                              │
│ 🗺️ NetworkTopoView     📱 DeviceDetailPage      │
│ 🎨 TopologyDisplayWidget  📋 DeviceListWidget   │
│                                              │
└──────────────────────────────────────────────┘
```

---

## 📁 核心檔案架構

### 🎛️ 管理服務層
```
lib/shared/services/
├─ 📋 unified_mesh_data_manager.dart      # Mesh 數據統一管理器
├─ 📊 dashboard_data_service.dart         # Dashboard API 服務
├─ 📢 dashboard_event_notifier.dart       # Dashboard 事件通知系統
├─ 💨 real_speed_data_service.dart        # 速度數據服務
└─ 🚀 api_preloader_service.dart          # API 預載入服務
```

### 🎨 UI 組件層
```
lib/shared/ui/
├─ pages/home/
│  ├─ 🗺️ NetworkTopoView.dart             # 主拓樸頁面
│  └─ 📱 DeviceDetailPage.dart             # 設備詳情頁面
└─ components/basic/
   ├─ 🎨 topology_display_widget.dart      # 拓樸顯示組件
   ├─ 📋 device_list_widget.dart           # 設備列表組件
   └─ 🌐 NetworkTopologyComponent.dart     # 網路拓樸組件
```

---

## 🔄 API 調用流程

### 1. 🚀 應用啟動時（預載入階段）

```
ApiPreloaderService.preloadAllAPIs()
├─ 📊 Dashboard API 預載入 ──────┐
├─ 🌐 Mesh API 預載入 ──────────┤ → 確保全部成功
├─ 💨 Throughput API 預載入 ────┘    才進入主功能
└─ ✅ 全部載入成功 → 啟用主要功能
```

**相關檔案**: `api_preloader_service.dart`
**關鍵方法**: `preloadAllAPIs()`

### 2. 🌐 Mesh 數據管理（統一架構）

```
UnifiedMeshDataManager.instance
├─ 🌐 WifiApiService.getMeshTopology() ──┐ 單次 API 調用
│                                        │
├─ 📊 原始數據存儲與快取 ────────────────┤
├─ 🔍 MeshDataAnalyzer 數據分析 ────────┘
│
├─ 🎯 多重數據分發：
│  ├─ getNetworkDevices() ──────────── 拓樸圖設備 (只含 Extender)
│  ├─ getListViewDevices() ─────────── 列表設備 (Gateway + Extender)
│  ├─ getDeviceConnections() ────────── 連接關係 (客戶端數量)
│  ├─ getGatewayDevice() ─────────────── Gateway 設備資料
│  └─ getClientDevicesForParent() ──── 指定設備的客戶端列表
│
└─ 🔄 定期更新 (9秒間隔)
```

**相關檔案**: `unified_mesh_data_manager.dart`
**關鍵方法**:
- `getNetworkDevices()` - 拓樸圖專用
- `getListViewDevices()` - 設備列表專用
- `getDeviceConnections()` - 連接數量
- `getGatewayDevice()` - Gateway 資料
- `getClientDevicesForParent(deviceId)` - 客戶端列表

### 3. 📊 Dashboard 事件驅動更新

```
任何地方調用 Dashboard API
├─ DashboardDataService.getDashboardData()
│  │
│  ├─ ✅ API 成功 ────────────────┐
│  │                              │
│  └─ ❌ API 失敗 ────────────────┤
│                                 │
├─ 📢 DashboardEventNotifier ────┘
│  │
│  ├─ notifySuccess(data) ──────── 🎯 通知所有監聽器
│  └─ notifyError(error) ──────── ⚠️ 通知錯誤監聽器
│
└─ 📱 監聽器自動更新：
   ├─ Internet 狀態顯示 (拓樸圖)
   ├─ Dashboard 頁面資料
   └─ 其他相關組件
```

**相關檔案**:
- `dashboard_data_service.dart` - API 調用與通知
- `dashboard_event_notifier.dart` - 事件通知系統

**關鍵方法**:
- `DashboardEventNotifier.addSuccessListener()` - 註冊成功監聽器
- `DashboardEventNotifier.addErrorListener()` - 註冊錯誤監聽器
- `DashboardDataService.getDashboardData()` - 獲取 Dashboard 數據

### 4. 💨 速度數據獨立更新

```
RealSpeedDataService
├─ getCurrentUploadSpeed() ────── 📤 上傳速度 (6秒更新)
├─ getCurrentDownloadSpeed() ──── 📥 下載速度 (6秒更新)
└─ TopologyDisplayWidget ────────── 🎨 速度圖表顯示
```

**相關檔案**: `real_speed_data_service.dart`, `topology_display_widget.dart`

---

## 🎯 組件互動關係

### 🗺️ NetworkTopoView (主拓樸頁面)
```
功能: 主要的拓樸頁面容器
├─ 📊 數據來源: UnifiedMeshDataManager
├─ 🎨 子組件: TopologyDisplayWidget, DeviceListWidget
└─ 🔄 更新頻率: 9秒間隔

關鍵方法:
├─ _getDevices() ──────────── 根據模式返回不同設備列表
├─ _getDeviceConnections() ── 獲取連接關係
└─ _loadTopologyData() ────── 載入拓樸數據
```

### 🎨 TopologyDisplayWidget (拓樸顯示組件)
```
功能: 拓樸圖 + 速度圖組合組件
├─ 📊 Mesh 數據: UnifiedMeshDataManager
├─ 💨 速度數據: RealSpeedDataService (6秒更新)
├─ 🌐 Internet 狀態: Dashboard 事件監聽 (零額外 API)
└─ 🎯 顯示: 網路拓樸圖 + 即時速度圖表

事件監聽:
├─ DashboardEventNotifier.addSuccessListener() ── Internet 狀態更新
└─ DashboardEventNotifier.addErrorListener() ──── 錯誤處理

更新機制:
├─ 速度數據: 6秒獨立更新 (Throughput API)
├─ Internet 狀態: 事件驅動更新 (Dashboard API)  
└─ 拓樸數據: 9秒統一更新 (Mesh API)
```

### 📋 DeviceListWidget (設備列表組件)
```
功能: 設備管理列表顯示
├─ 📊 數據來源: UnifiedMeshDataManager.getListViewDevices()
├─ 🎯 顯示內容: Gateway + 所有 Extender
└─ 🔄 更新: 被動接收 NetworkTopoView 傳遞的數據

顯示邏輯:
├─ Gateway: Controller + MAC + 客戶端數
└─ Extender: Agent + MAC + IP + RSSI + 客戶端數
```

### 📱 DeviceDetailPage (設備詳情頁面)
```
功能: 設備詳細資訊與客戶端列表
├─ 📊 數據來源: UnifiedMeshDataManager.getClientDevicesForParent()
├─ 🔄 更新頻率: 9秒間隔 (新增定期更新)
└─ 🎯 顯示: 設備資訊 + RSSI 狀態 + 連接客戶端列表

關鍵方法:
├─ _loadClientDevices() ────── 載入客戶端設備
├─ _startPeriodicUpdate() ──── 啟動定期更新 ✨ 新增
└─ _generateDeviceId() ──────── 生成設備 ID
```

---

## ⚡ 性能優化特色

### 📉 API 調用次數優化
```
優化前:                    優化後:
├─ Mesh API: 多處重複調用   ├─ Mesh API: 統一單次調用
├─ Dashboard API: 獨立調用  ├─ Dashboard API: 事件驅動更新
└─ 總調用數: 高            └─ 總調用數: 減少 ~60%
```

### 🔄 數據同步保證
```
三組件同步更新:
├─ 🎨 拓樸圖客戶端數量 ────┐
├─ 📋 列表客戶端數量 ──────┤ → 9秒間隔統一更新
└─ 📱 詳情頁客戶端數量 ────┘   完全一致顯示
```

### 🛡️ 容錯機制
```
API 失敗處理:
├─ ✅ 成功: 更新快取 → 更新 UI
├─ ❌ 失敗: 保持快取 → 維持顯示  
└─ ⚠️ 錯誤: 使用備用 → 避免空白
```

---

## 🔧 開發者使用指南

### 🎯 如何添加新的 Mesh 數據使用者

1. **引入統一管理器**:
```dart
import 'package:whitebox/shared/services/unified_mesh_data_manager.dart';

final manager = UnifiedMeshDataManager.instance;
```

2. **選擇適當的數據方法**:
```dart
// 拓樸圖用（只包含 Extender）
final topologyDevices = await manager.getNetworkDevices();

// 設備列表用（Gateway + Extender）
final listDevices = await manager.getListViewDevices();

// 連接關係（客戶端數量）
final connections = await manager.getDeviceConnections();

// Gateway 設備資料
final gateway = await manager.getGatewayDevice();

// 特定設備的客戶端列表
final clients = await manager.getClientDevicesForParent(deviceId);
```

### 🌐 如何監聽 Internet 狀態變化

1. **註冊監聽器**:
```dart
import 'package:whitebox/shared/services/dashboard_event_notifier.dart';

@override
void initState() {
  DashboardEventNotifier.addSuccessListener(_onDashboardSuccess);
  DashboardEventNotifier.addErrorListener(_onDashboardError);
}
```

2. **實現回調方法**:
```dart
void _onDashboardSuccess(DashboardData dashboardData) {
  final internetStatus = InternetConnectionStatus(
    isConnected: dashboardData.internetStatus.pingStatus.toLowerCase() == 'connected',
    status: dashboardData.internetStatus.pingStatus,
    timestamp: DateTime.now(),
  );
  
  // 更新 UI
  setState(() {
    _internetStatus = internetStatus;
  });
}

void _onDashboardError(dynamic error) {
  // 保持現有狀態，不更新 UI
  print('Dashboard API 失敗: $error');
}
```

3. **清理監聽器**:
```dart
@override
void dispose() {
  DashboardEventNotifier.removeSuccessListener(_onDashboardSuccess);
  DashboardEventNotifier.removeErrorListener(_onDashboardError);
  super.dispose();
}
```

### 💨 如何使用速度數據

```dart
import 'package:whitebox/shared/services/real_speed_data_service.dart';

// 獲取當前速度
final uploadSpeed = await RealSpeedDataService.getCurrentUploadSpeed();
final downloadSpeed = await RealSpeedDataService.getCurrentDownloadSpeed();

// 獲取歷史數據（用於圖表）
final uploadHistory = await RealSpeedDataService.getUploadSpeedHistory(pointCount: 20);
final downloadHistory = await RealSpeedDataService.getDownloadSpeedHistory(pointCount: 20);
```

---

## 🚨 注意事項

### ⚠️ 避免重複 API 調用
```
❌ 錯誤做法:
await WifiApiService.getMeshTopology();  // 直接調用原始 API

✅ 正確做法:
final manager = UnifiedMeshDataManager.instance;
await manager.getNetworkDevices();       // 使用統一管理器
```

### 🔄 數據更新最佳實踐
```
❌ 避免:
Timer.periodic(Duration(seconds: 5), (_) {
  // 創建獨立的更新計時器
});

✅ 推薦:
// 監聽統一管理器的更新事件
// 或使用現有的更新機制
```

### 🎯 錯誤處理原則
```
try {
  final data = await manager.getNetworkDevices();
  // 使用數據
} catch (e) {
  // 不要清空 UI，保持現有顯示
  print('獲取數據失敗，保持現有狀態: $e');
}
```

---

## 📊 調試與監控

### 🔍 查看數據統計
```dart
// 獲取統一管理器狀態
final stats = await UnifiedMeshDataManager.instance.getDataStatistics();
print('數據統計: $stats');

// 輸出完整統計報告
await UnifiedMeshDataManager.instance.printCompleteDataStatistics();
```

### 📢 監控事件通知
```dart
// 查看監聽器統計
final listenerStats = DashboardEventNotifier.getListenerStats();
print('監聽器統計: $listenerStats');
```

### 🔬 測試 API 功能
```dart
// 測試 Dashboard 解析
await DashboardDataService.testParsing();

// 測試 Internet 狀態
await DashboardDataService.testInternetStatus();
```

---

這個架構確保了**數據一致性**、**性能優化**和**開發維護性**，是一個可擴展且穩定的 API 管理系統！ 🎉