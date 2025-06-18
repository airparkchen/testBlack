// lib/shared/services/dashboard_data_service.dart - 重寫版本

import 'dart:async';
import 'package:whitebox/shared/api/wifi_api_service.dart';
import 'package:whitebox/shared/models/dashboard_data_models.dart';
import 'package:whitebox/shared/ui/pages/home/Topo/network_topo_config.dart';

/// Dashboard 資料處理服務 - 重寫版本
class DashboardDataService {
  // 快取機制
  static DashboardData? _cachedData;
  static DateTime? _lastFetchTime;
  static Duration get _cacheExpiry => NetworkTopoConfig.actualCacheDuration;  //api更新頻率

  /// 檢查快取是否有效
  static bool _isCacheValid() {
    if (_lastFetchTime == null || _cachedData == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheExpiry;
  }

  /// 清除快取
  static void clearCache() {
    _cachedData = null;
    _lastFetchTime = null;
    print('🗑️ Dashboard 快取已清除');
  }

  /// 獲取完整的 Dashboard 資料
  static Future<DashboardData> getDashboardData({bool forceRefresh = false}) async {
    try {
      // 檢查快取
      if (!forceRefresh && _isCacheValid()) {
        print('📋 使用快取的 Dashboard 資料');
        return _cachedData!;
      }

      print('🌐 開始載入 Dashboard 資料...');

      // 只需要呼叫 Dashboard API，因為所有資料都在裡面
      final dashboardInfo = await _getSystemDashboard();

      // 解析資料
      final dashboardData = _parseDashboardData(dashboardInfo);

      // 更新快取
      _cachedData = dashboardData;
      _lastFetchTime = DateTime.now();

      print('✅ Dashboard 資料載入完成');
      return dashboardData;

    } catch (e) {
      print('❌ 載入 Dashboard 資料時發生錯誤: $e');
      return _getFallbackData();
    }
  }

  /// 獲取 Dashboard 資訊
  static Future<Map<String, dynamic>> _getSystemDashboard() async {
    try {
      return await WifiApiService.getSystemDashboard();
    } catch (e) {
      print('⚠️ 獲取 Dashboard 資訊失敗: $e');
      return {'error': e.toString()};
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

  /// 獲取備用資料（當 API 失敗時使用）- 更新版本
  static DashboardData _getFallbackData() {
    print('⚠️ 使用備用資料');
    return DashboardData(
      modelName: 'API Error',
      internetStatus: InternetStatus(
        pingStatus: 'Not Connected',
        connectionType: 'unknown',
      ),
      wifiFrequencies: [],
      guestWifiFrequencies: [],
      wifiSSIDs: [],
      guestWifiSSIDs: [],
      ethernetStatus: EthernetStatus(),
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
}