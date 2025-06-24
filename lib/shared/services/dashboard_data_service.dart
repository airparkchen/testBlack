// lib/shared/services/dashboard_data_service.dart - Internet 狀態支援版本

import 'dart:async';
import 'package:whitebox/shared/api/wifi_api_service.dart';
import 'package:whitebox/shared/models/dashboard_data_models.dart';
import 'package:whitebox/shared/ui/pages/home/Topo/network_topo_config.dart';
import 'package:whitebox/shared/utils/api_logger.dart';
import 'package:whitebox/shared/utils/api_coordinator.dart';

/// Internet 連線狀態數據類
class InternetConnectionStatus {
  final bool isConnected;
  final String status;
  final DateTime timestamp;

  InternetConnectionStatus({
    required this.isConnected,
    required this.status,
    required this.timestamp,
  });

  /// 創建未知狀態
  factory InternetConnectionStatus.unknown() {
    return InternetConnectionStatus(
      isConnected: false,
      status: 'unknown',
      timestamp: DateTime.now(),
    );
  }

  /// 是否應該顯示錯誤標記
  bool get shouldShowError => !isConnected && status.toLowerCase() != 'unknown';

  /// 格式化狀態顯示
  String get formattedStatus {
    switch (status.toLowerCase()) {
      case 'connected':
        return 'Connected';
      case 'disconnected':
        return 'Disconnected';
      case 'timeout':
        return 'Timeout';
      case 'error':
        return 'Error';
      default:
        return 'Unknown';
    }
  }
}

/// Dashboard 資料處理服務 - Internet 狀態支援版本
class DashboardDataService {
  // 快取機制
  static DashboardData? _cachedData;
  static DateTime? _lastFetchTime;
  static Duration get _cacheExpiry => NetworkTopoConfig.actualCacheDuration;

  // 🎯 新增：Internet 狀態快取
  static InternetConnectionStatus? _cachedInternetStatus;
  static DateTime? _lastInternetFetchTime;
  static Map<String, dynamic>? _cachedDashboardData;

  /// 檢查快取是否有效
  static bool _isCacheValid() {
    if (_lastFetchTime == null || _cachedData == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheExpiry;
  }

  /// 🎯 新增：檢查 Internet 狀態快取是否有效
  static bool _isInternetCacheValid() {
    if (_lastInternetFetchTime == null || _cachedInternetStatus == null) return false;
    return DateTime.now().difference(_lastInternetFetchTime!) < _cacheExpiry;
  }

  /// 清除快取
  static void clearCache() {
    _cachedData = null;
    _lastFetchTime = null;
    _cachedInternetStatus = null;
    _lastInternetFetchTime = null;
    _cachedDashboardData = null;
    print('🗑️ Dashboard 快取已清除');
  }

  /// 🎯 新增：獲取 Internet 連線狀態
  static Future<InternetConnectionStatus> getInternetConnectionStatus() async {
    try {
      // 檢查快取
      if (_isInternetCacheValid()) {
        print('📋 使用快取的 Internet 狀態');
        return _cachedInternetStatus!;
      }

      print('🌐 從 Dashboard API 獲取 Internet 連線狀態...');

      // 呼叫 Dashboard API
      final dashboardResult = await WifiApiService.getSystemDashboard();

      if (dashboardResult.containsKey('error')) {
        print('❌ Dashboard API 錯誤: ${dashboardResult['error']}');
        return InternetConnectionStatus.unknown();
      }

      // 提取 Internet 狀態
      final internetStatus = _extractInternetStatus(dashboardResult);

      // 更新快取
      _cachedInternetStatus = internetStatus;
      _lastInternetFetchTime = DateTime.now();
      _cachedDashboardData = dashboardResult;

      return internetStatus;

    } catch (e) {
      print('❌ 獲取 Internet 狀態失敗: $e');
      return InternetConnectionStatus.unknown();
    }
  }

  /// 🎯 新增：從 Dashboard 數據中提取 Internet 狀態
  static InternetConnectionStatus _extractInternetStatus(Map<String, dynamic> data) {
    try {
      // 根據 Dashboard API 結構提取 wan.pingstatus
      final wan = data['wan'];
      if (wan is List && wan.isNotEmpty) {
        final wanData = wan[0] as Map<String, dynamic>;
        final pingStatus = wanData['ping_status']?.toString() ?? '';

        print('🔍 WAN Ping Status: $pingStatus');

        // 判斷連線狀態
        final bool isConnected = pingStatus.toLowerCase() == 'connected';

        return InternetConnectionStatus(
          isConnected: isConnected,
          status: pingStatus.isNotEmpty ? pingStatus : 'unknown',
          timestamp: DateTime.now(),
        );
      }

      print('⚠️ Dashboard 數據中未找到 WAN 資訊');
      return InternetConnectionStatus.unknown();

    } catch (e) {
      print('❌ 解析 Internet 狀態失敗: $e');
      return InternetConnectionStatus.unknown();
    }
  }

  /// 獲取完整的 Dashboard 資料
  static Future<DashboardData> getDashboardData({bool forceRefresh = false}) async {
    try {
      // 檢查快取（優先使用快取）
      if (!forceRefresh && _isCacheValid()) {
        print('📋 使用快取的 Dashboard 資料');
        return _cachedData!;
      }

      print('🌐 開始載入 Dashboard 資料...');

      // 嘗試獲取新資料
      try {
        final dashboardInfo = await _getSystemDashboard();
        final dashboardData = _parseDashboardData(dashboardInfo);

        // 更新快取
        _cachedData = dashboardData;
        _lastFetchTime = DateTime.now();

        print('✅ Dashboard 資料載入完成');
        return dashboardData;

      } catch (e) {
        // 🔥 新增：如果是協調器跳過，且有快取，則使用快取
        if (e.toString().contains('frequency limit') && _cachedData != null) {
          print('🕐 Dashboard API 被跳過，使用現有快取資料');
          return _cachedData!;
        }

        // 🔥 新增：如果是API忙碌，且有快取，則使用快取
        if (e.toString().contains('Another API request is busy') && _cachedData != null) {
          print('⚠️ Dashboard API 忙碌，使用現有快取資料');
          return _cachedData!;
        }

        // 其他錯誤才使用備用資料
        print('❌ 載入 Dashboard 資料時發生錯誤: $e');
        return _getFallbackData();
      }

    } catch (e) {
      print('❌ 載入 Dashboard 資料時發生錯誤: $e');
      return _getFallbackData();
    }
  }
  /// 獲取 Dashboard 資訊
  static Future<Map<String, dynamic>> _getSystemDashboard({int retryCount = 0}) async {
    const int maxRetries = 2;

    try {
      print('🌐 調用 Dashboard API (嘗試 ${retryCount + 1}/${maxRetries + 1})');

      // 🔥 修改：條件式使用協調器
      final result = await ApiCoordinator.coordinatedCall('dashboard', () async {
        return await ApiLogger.wrapApiCall(
          method: 'GET',
          endpoint: '/api/v1/system/dashboard',
          caller: 'DashboardDataService._getSystemDashboard',
          apiCall: () => WifiApiService.getSystemDashboard(),
        );
      });

      if (retryCount > 0) {
        print('✅ Dashboard API 重試成功 (第${retryCount + 1}次嘗試)');
      }

      return result;
    } catch (e) {
      // 🔥 修改：如果協調器停用且是頻率限制錯誤，直接重試
      if (!ApiCoordinator.isEnabled && e.toString().contains('API call too frequent')) {
        print('🚀 協調器已停用，忽略頻率限制，直接重試');
        await Future.delayed(Duration(milliseconds: 500)); // 短暫延遲
        return await _getSystemDashboard(retryCount: retryCount);
      }

      // 原有錯誤處理邏輯...
      if (e.toString().contains('API call too frequent') && retryCount == 0) {
        print('🕐 Dashboard API 被協調器跳過，等待後重試');
        await Future.delayed(Duration(seconds: 3));
        return await _getSystemDashboard(retryCount: retryCount + 1);
      }

      if (retryCount < maxRetries) {
        print('⚠️ Dashboard API 調用失敗，準備重試... 錯誤: $e');
        await Future.delayed(Duration(seconds: 2));
        return await _getSystemDashboard(retryCount: retryCount + 1);
      }

      print('❌ Dashboard API 達到最大重試次數，調用失敗: $e');
      throw Exception('Dashboard API 調用失敗: $e');
    }
  }

  /// 解析 Dashboard 資料 - 重寫版本
  static DashboardData _parseDashboardData(Map<String, dynamic> dashboardInfo) {
    // 解析 Model Name
    final modelName = _parseModelName(dashboardInfo);

    // 解析 Internet 狀態
    final internetStatus = _parseInternetStatus(dashboardInfo);

    // 解析 WiFi 頻率狀態（第一頁用）
    final wifiFrequencies = _parseWiFiFrequencies(dashboardInfo);

    // 解析 WiFi SSID 資訊（第二頁用）
    final wifiSSIDs = _parseWiFiSSIDs(dashboardInfo);

    // 解析 LAN 埠資訊（第三頁用）
    final lanPorts = _parseLANPorts(dashboardInfo);

    // Guest WiFi（目前空列表，由 config 控制）
    final guestWifiFrequencies = <WiFiFrequencyStatus>[];
    final guestWifiSSIDs = <WiFiSSIDInfo>[];

    // 建立乙太網路狀態
    final ethernetStatus = EthernetStatus();

    return DashboardData(
      modelName: modelName,
      internetStatus: internetStatus,
      wifiFrequencies: wifiFrequencies,
      guestWifiFrequencies: guestWifiFrequencies,
      wifiSSIDs: wifiSSIDs,
      guestWifiSSIDs: guestWifiSSIDs,
      ethernetStatus: ethernetStatus,
      lanPorts: lanPorts,
    );
  }

  /// 解析 Model Name
  static String _parseModelName(Map<String, dynamic> dashboardInfo) {
    try {
      if (dashboardInfo.containsKey('model_name') && dashboardInfo['model_name'] != null) {
        final modelName = dashboardInfo['model_name'].toString();
        print('✅ 解析 Model Name: $modelName');
        return modelName;
      }
    } catch (e) {
      print('⚠️ 解析 Model Name 時發生錯誤: $e');
    }

    return 'Unknown Model';
  }

  /// 解析 Internet 連接狀態 - 修正版本
  static InternetStatus _parseInternetStatus(Map<String, dynamic> dashboardInfo) {
    String pingStatus = 'Not Connected';
    String connectionType = 'unknown';

    try {
      // 從 dashboard 的 wan 陣列獲取狀態
      if (dashboardInfo.containsKey('wan') && dashboardInfo['wan'] is List) {
        final List<dynamic> wanList = dashboardInfo['wan'];
        if (wanList.isNotEmpty && wanList[0] is Map<String, dynamic>) {
          final wanData = wanList[0] as Map<String, dynamic>;

          // 使用 ping_status（如果有的話），否則用 connected_status
          if (wanData.containsKey('ping_status')) {
            pingStatus = wanData['ping_status'].toString();
          } else if (wanData.containsKey('connected_status')) {
            pingStatus = wanData['connected_status'].toString();
          }

          // 從 wanv4_type 獲取連接類型
          if (wanData.containsKey('wanv4_type')) {
            connectionType = wanData['wanv4_type'].toString();
          }

          print('✅ 解析 Internet 狀態: $pingStatus, 類型: $connectionType');
        }
      }
    } catch (e) {
      print('⚠️ 解析 Internet 狀態時發生錯誤: $e');
    }

    return InternetStatus(
      pingStatus: pingStatus,
      connectionType: connectionType,
    );
  }

  /// 解析 WiFi 頻率狀態（第一頁用）- 重寫版本
  static List<WiFiFrequencyStatus> _parseWiFiFrequencies(Map<String, dynamic> dashboardInfo) {
    final List<WiFiFrequencyStatus> frequencies = [];

    try {
      if (dashboardInfo.containsKey('vaps') && dashboardInfo['vaps'] is List) {
        final List<dynamic> vapsList = dashboardInfo['vaps'];

        for (var vap in vapsList) {
          if (vap is Map<String, dynamic>) {
            // 只處理 primary type（Guest WiFi 目前由 config 控制隱藏）
            if (vap['vap_type'] == 'primary') {
              final radioName = vap['radio_name']?.toString() ?? '';
              final isEnabled = vap['vap_enabled']?.toString() == 'ON';
              final ssid = vap['ssid']?.toString() ?? '';

              frequencies.add(WiFiFrequencyStatus(
                radioName: radioName,
                isEnabled: isEnabled,
                ssid: ssid,
              ));

              print('✅ 解析 WiFi 頻率: $radioName → ${isEnabled ? "ON" : "OFF"}');
            }
          }
        }
      }
    } catch (e) {
      print('⚠️ 解析 WiFi 頻率狀態時發生錯誤: $e');
    }

    return frequencies;
  }

  /// 解析 WiFi SSID 資訊（第二頁用）- 新增方法
  static List<WiFiSSIDInfo> _parseWiFiSSIDs(Map<String, dynamic> dashboardInfo) {
    final List<WiFiSSIDInfo> ssidInfos = [];

    try {
      if (dashboardInfo.containsKey('vaps') && dashboardInfo['vaps'] is List) {
        final List<dynamic> vapsList = dashboardInfo['vaps'];

        for (var vap in vapsList) {
          if (vap is Map<String, dynamic>) {
            // 只處理 primary type
            if (vap['vap_type'] == 'primary') {
              final radioName = vap['radio_name']?.toString() ?? '';
              final ssid = vap['ssid']?.toString() ?? '';
              final isEnabled = vap['vap_enabled']?.toString() == 'ON';

              ssidInfos.add(WiFiSSIDInfo(
                radioName: radioName,
                ssid: ssid,
                isEnabled: isEnabled,
              ));

              print('✅ 解析 WiFi SSID: $radioName → $ssid (${isEnabled ? "ON" : "OFF"})');
            }
          }
        }
      }
    } catch (e) {
      print('⚠️ 解析 WiFi SSID 時發生錯誤: $e');
    }

    return ssidInfos;
  }

  /// 解析 LAN 埠資訊（第三頁用）
  static List<LANPortInfo> _parseLANPorts(Map<String, dynamic> dashboardInfo) {
    final List<LANPortInfo> lanPorts = [];

    try {
      // 從 dashboard 的 lan 陣列解析 LAN 埠資訊
      if (dashboardInfo.containsKey('lan') && dashboardInfo['lan'] is List) {
        final List<dynamic> lanList = dashboardInfo['lan'];

        print('🔍 發現 ${lanList.length} 個 LAN 項目');

        for (int i = 0; i < lanList.length; i++) {
          final lanData = lanList[i];

          if (lanData is Map<String, dynamic>) {
            final String name = lanData['name']?.toString() ?? 'LAN Port ${i + 1}';
            final String connectedStatus = lanData['connected_status']?.toString() ?? 'Unknown';

            lanPorts.add(LANPortInfo(
              name: name,
              connectedStatus: connectedStatus,
            ));

            print('✅ 解析 LAN 埠: $name → $connectedStatus');
          } else {
            print('⚠️ LAN 項目 $i 資料格式錯誤，跳過');
          }
        }
      } else {
        print('⚠️ 找不到 lan 陣列或格式錯誤');
      }

      // 如果沒有 LAN 資料，提供預設項目
      if (lanPorts.isEmpty) {
        print('📋 沒有找到 LAN 資料，使用預設項目');
        lanPorts.add(LANPortInfo(
          name: 'Ethernet Port',
          connectedStatus: 'Unknown',
        ));
      }

    } catch (e) {
      print('❌ 解析 LAN 埠時發生錯誤: $e');

      // 錯誤時提供預設項目
      lanPorts.add(LANPortInfo(
        name: 'Ethernet Port',
        connectedStatus: 'Error',
      ));
    }

    print('📊 總共解析到 ${lanPorts.length} 個 LAN 埠');
    return lanPorts;
  }

  /// 獲取備用資料（當 API 失敗時使用）- 更新版本
  static DashboardData _getFallbackData() {
    print('⚠️ 使用備用資料');
    return DashboardData(
      modelName: 'Unknown',
      internetStatus: InternetStatus(
        pingStatus: 'Not Connected',
        connectionType: 'unknown',
      ),
      wifiFrequencies: [],
      guestWifiFrequencies: [],
      wifiSSIDs: [],
      guestWifiSSIDs: [],
      ethernetStatus: EthernetStatus(),
      lanPorts: [
        LANPortInfo(
          name: 'Ethernet Port',
          connectedStatus: 'Unknown',
        ),
      ],
    );
  }

  /// 生成 Dashboard 分頁資料 - 使用新的分頁生成器
  static List<DashboardPageData> generateDashboardPages(DashboardData data) {
    return DashboardPageContentGenerator.generateAllPages(data);
  }

  // ==================== 調試方法 ====================

  /// 輸出完整的解析結果（調試用）
  static void printParsedData(DashboardData data) {
    print('\n=== 📊 Dashboard 解析結果 ===');
    print('Model Name: ${data.modelName}');
    print('Internet: ${data.internetStatus.pingStatus} (${data.internetStatus.formattedStatus})');

    print('\nWiFi 頻率狀態:');
    for (var freq in data.wifiFrequencies) {
      print('  ${freq.displayFrequency}: ${freq.statusText}');
    }

    print('\nWiFi SSID 資訊:');
    for (var ssid in data.wifiSSIDs) {
      print('  ${ssid.ssidLabel}: ${ssid.ssid} (${ssid.isEnabled ? "ON" : "OFF"})');
    }

    // 🔥 新增：LAN 埠資訊輸出
    print('\nLAN 埠資訊:');
    for (var lanPort in data.lanPorts) {
      print('  ${lanPort.name}: ${lanPort.formattedStatus}');
    }

    if (DashboardConfig.showGuestWiFi) {
      print('\nGuest WiFi 頻率狀態:');
      for (var freq in data.guestWifiFrequencies) {
        print('  ${freq.displayFrequency}: ${freq.statusText}');
      }

      print('\nGuest WiFi SSID 資訊:');
      for (var ssid in data.guestWifiSSIDs) {
        print('  ${ssid.ssidLabel}: ${ssid.ssid} (${ssid.isEnabled ? "ON" : "OFF"})');
      }
    } else {
      print('\nGuest WiFi: 已隱藏 (DashboardConfig.showGuestWiFi = false)');
    }

    print('\nEthernet: ${data.ethernetStatus.title} (詳細資訊: ${data.ethernetStatus.showDetails ? "顯示" : "隱藏"})');
    print('=== Dashboard 解析結果結束 ===\n');
  }

  /// 測試用：獲取並輸出解析結果
  static Future<void> testParsing() async {
    try {
      print('🧪 測試 Dashboard 資料解析...');
      final data = await getDashboardData(forceRefresh: true);
      printParsedData(data);
    } catch (e) {
      print('❌ 測試解析失敗: $e');
    }
  }

  /// 🎯 新增：測試 Internet 狀態
  static Future<void> testInternetStatus() async {
    try {
      print('🧪 測試 Internet 狀態...');
      final status = await getInternetConnectionStatus();
      print('✅ Internet 狀態測試結果:');
      print('   連接狀態: ${status.isConnected ? "已連接" : "未連接"}');
      print('   狀態值: ${status.status}');
      print('   格式化狀態: ${status.formattedStatus}');
      print('   應顯示錯誤: ${status.shouldShowError}');
      print('   時間戳: ${status.timestamp}');
    } catch (e) {
      print('❌ 測試 Internet 狀態失敗: $e');
    }
  }
}