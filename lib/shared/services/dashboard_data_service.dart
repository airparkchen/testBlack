// lib/shared/services/dashboard_data_service.dart

import 'dart:async';
import 'package:whitebox/shared/api/wifi_api_service.dart';
import 'package:whitebox/shared/models/dashboard_data_models.dart';

/// Dashboard 資料處理服務
class DashboardDataService {
  // 快取機制
  static DashboardData? _cachedData;
  static DateTime? _lastFetchTime;
  static const Duration _cacheExpiry = Duration(seconds: 30);

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

      // 並行呼叫多個 API
      final futures = await Future.wait([
        _getSystemInfo(),
        _getSystemDashboard(),
        _getWanEthInfo(),
      ]);

      final systemInfo = futures[0] as Map<String, dynamic>;
      final dashboardInfo = futures[1] as Map<String, dynamic>;
      final wanEthInfo = futures[2] as Map<String, dynamic>;

      // 解析資料
      final dashboardData = _parseDashboardData(systemInfo, dashboardInfo, wanEthInfo);

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

  /// 獲取系統資訊
  static Future<Map<String, dynamic>> _getSystemInfo() async {
    try {
      return await WifiApiService.getSystemInfo();
    } catch (e) {
      print('⚠️ 獲取系統資訊失敗: $e');
      return {'error': e.toString()};
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

  /// 獲取 WAN 乙太網路資訊
  static Future<Map<String, dynamic>> _getWanEthInfo() async {
    try {
      return await WifiApiService.getWanEth();
    } catch (e) {
      print('⚠️ 獲取 WAN 乙太網路資訊失敗: $e');
      return {'error': e.toString()};
    }
  }

  /// 解析 Dashboard 資料
  static DashboardData _parseDashboardData(
      Map<String, dynamic> systemInfo,
      Map<String, dynamic> dashboardInfo,
      Map<String, dynamic> wanEthInfo,
      ) {
    // 解析 Model Name
    final modelName = _parseModelName(systemInfo, dashboardInfo);

    // 解析 Internet 狀態
    final internetStatus = _parseInternetStatus(dashboardInfo, wanEthInfo);

    // 解析 WiFi 頻率狀態
    final wifiFrequencies = _parseWiFiFrequencies(dashboardInfo, false);
    final guestWifiFrequencies = _parseWiFiFrequencies(dashboardInfo, true);

    // 解析已啟用的 SSID
    final enabledSSIDs = _parseEnabledSSIDs(dashboardInfo, false);
    final enabledGuestSSIDs = _parseEnabledSSIDs(dashboardInfo, true);

    // 建立乙太網路狀態（使用假資料）
    final ethernetStatus = EthernetStatus();

    return DashboardData(
      modelName: modelName,
      internetStatus: internetStatus,
      wifiFrequencies: wifiFrequencies,
      guestWifiFrequencies: guestWifiFrequencies,
      enabledSSIDs: enabledSSIDs,
      enabledGuestSSIDs: enabledGuestSSIDs,
      ethernetStatus: ethernetStatus,
    );
  }

  /// 解析 Model Name
  static String _parseModelName(Map<String, dynamic> systemInfo, Map<String, dynamic> dashboardInfo) {
    // 優先使用 system/info 的 model_name
    if (systemInfo.containsKey('model_name') && systemInfo['model_name'] != null) {
      return systemInfo['model_name'].toString();
    }

    // 備用：使用 dashboard 的 model_name
    if (dashboardInfo.containsKey('model_name') && dashboardInfo['model_name'] != null) {
      return dashboardInfo['model_name'].toString();
    }

    return 'Unknown Model';
  }

  /// 解析 Internet 連接狀態
  static InternetStatus _parseInternetStatus(Map<String, dynamic> dashboardInfo, Map<String, dynamic> wanEthInfo) {
    String connectionStatus = 'Not Connected';
    String connectionType = 'unknown';

    try {
      // 從 dashboard 獲取連接狀態
      if (dashboardInfo.containsKey('wan') && dashboardInfo['wan'] is List) {
        final List<dynamic> wanList = dashboardInfo['wan'];
        if (wanList.isNotEmpty && wanList[0] is Map<String, dynamic>) {
          final wanData = wanList[0] as Map<String, dynamic>;
          connectionStatus = wanData['connected_status']?.toString() ?? 'Not Connected';
        }
      }

      // 從 wan_eth 獲取連接類型
      if (wanEthInfo.containsKey('connection_type')) {
        connectionType = wanEthInfo['connection_type'].toString();
      }
    } catch (e) {
      print('⚠️ 解析 Internet 狀態時發生錯誤: $e');
    }

    return InternetStatus(
      connectionStatus: connectionStatus,
      connectionType: connectionType,
    );
  }

  /// 解析 WiFi 頻率狀態
  static List<WiFiFrequencyStatus> _parseWiFiFrequencies(Map<String, dynamic> dashboardInfo, bool isGuest) {
    final List<WiFiFrequencyStatus> frequencies = [];

    try {
      if (dashboardInfo.containsKey('vaps') && dashboardInfo['vaps'] is List) {
        final List<dynamic> vapsList = dashboardInfo['vaps'];

        for (var vap in vapsList) {
          if (vap is Map<String, dynamic>) {
            // 目前只處理 primary type (根據需求，Guest 也使用 primary 的資料)
            if (vap['vap_type'] == 'primary') {
              final radioName = vap['radio_name']?.toString() ?? '';
              final isEnabled = vap['vap_enabled']?.toString() == 'ON';
              final ssid = vap['ssid']?.toString();

              frequencies.add(WiFiFrequencyStatus(
                frequency: radioName,
                isEnabled: isEnabled,
                ssid: ssid,
              ));
            }
          }
        }
      }
    } catch (e) {
      print('⚠️ 解析 WiFi 頻率狀態時發生錯誤: $e');
    }

    return frequencies;
  }

  /// 解析已啟用的 SSID 列表
  static List<String> _parseEnabledSSIDs(Map<String, dynamic> dashboardInfo, bool isGuest) {
    final List<String> enabledSSIDs = [];

    try {
      if (dashboardInfo.containsKey('vaps') && dashboardInfo['vaps'] is List) {
        final List<dynamic> vapsList = dashboardInfo['vaps'];

        for (var vap in vapsList) {
          if (vap is Map<String, dynamic>) {
            // 目前只處理 primary type
            if (vap['vap_type'] == 'primary' && vap['vap_enabled']?.toString() == 'ON') {
              final ssid = vap['ssid']?.toString();
              if (ssid != null && ssid.isNotEmpty) {
                enabledSSIDs.add(ssid);
              }
            }
          }
        }
      }
    } catch (e) {
      print('⚠️ 解析已啟用 SSID 時發生錯誤: $e');
    }

    return enabledSSIDs;
  }

  /// 獲取備用資料（當 API 失敗時使用）
  static DashboardData _getFallbackData() {
    return DashboardData(
      modelName: 'API Error',
      internetStatus: InternetStatus(
        connectionStatus: 'Not Connected',
        connectionType: 'unknown',
      ),
      wifiFrequencies: [],
      guestWifiFrequencies: [],
      enabledSSIDs: [],
      enabledGuestSSIDs: [],
      ethernetStatus: EthernetStatus(),
    );
  }

  /// 生成 Dashboard 分頁資料
  static List<DashboardPageData> generateDashboardPages(
      DashboardData data,
      DashboardDisplayConfig config,
      ) {
    final pages = <DashboardPageData>[];

    // 第一頁：系統狀態
    pages.add(DashboardPageData(
      pageTitle: 'System Status',
      pageType: DashboardPageType.systemStatus,
      content: {
        'modelName': data.modelName,
        'internetStatus': data.internetStatus,
        'wifiFrequencies': data.wifiFrequencies,
        'guestWifiFrequencies': data.guestWifiFrequencies,
        'config': config,
      },
    ));

    // 第二頁：WiFi SSID
    pages.add(DashboardPageData(
      pageTitle: 'WiFi SSID',
      pageType: DashboardPageType.wifiSSID,
      content: {
        'enabledSSIDs': data.enabledSSIDs,
        'enabledGuestSSIDs': data.enabledGuestSSIDs,
        'config': config,
      },
    ));

    // 第三頁：乙太網路
    pages.add(DashboardPageData(
      pageTitle: 'Ethernet',
      pageType: DashboardPageType.ethernet,
      content: {
        'ethernetStatus': data.ethernetStatus,
        'config': config,
      },
    ));

    return pages;
  }
}