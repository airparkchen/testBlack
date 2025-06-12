// lib/shared/models/dashboard_data_models.dart

/// Dashboard 完整資料模型
class DashboardData {
  final String modelName;
  final InternetStatus internetStatus;
  final List<WiFiFrequencyStatus> wifiFrequencies;
  final List<WiFiFrequencyStatus> guestWifiFrequencies;
  final List<String> enabledSSIDs;
  final List<String> enabledGuestSSIDs;
  final EthernetStatus ethernetStatus;

  DashboardData({
    required this.modelName,
    required this.internetStatus,
    required this.wifiFrequencies,
    required this.guestWifiFrequencies,
    required this.enabledSSIDs,
    required this.enabledGuestSSIDs,
    required this.ethernetStatus,
  });
}

/// 網路連接狀態模型
class InternetStatus {
  final String connectionStatus;  // "Connected" / "Not Connected"
  final String connectionType;    // "dhcp" / "static" / "pppoe"

  InternetStatus({
    required this.connectionStatus,
    required this.connectionType,
  });

  /// 格式化連接類型顯示文字
  String get formattedConnectionType {
    switch (connectionType.toLowerCase()) {
      case 'dhcp':
        return 'Connect(DHCP)';
      case 'static':
        return 'Connect(Static)';
      case 'pppoe':
        return 'Connect(PPPoE)';
      default:
        return 'Connect($connectionType)';
    }
  }
}

/// WiFi 頻率狀態模型
class WiFiFrequencyStatus {
  final String frequency;   // "2.4GHz" / "5GHz" / "6GHz" / "MLO"
  final bool isEnabled;     // true = ON, false = OFF
  final String? ssid;       // 對應的 SSID 名稱

  WiFiFrequencyStatus({
    required this.frequency,
    required this.isEnabled,
    this.ssid,
  });

  /// 格式化頻率顯示文字
  String get displayFrequency {
    switch (frequency.toLowerCase()) {
      case 'wifi_2g':
      case '2g':
        return '2.4GHz';
      case 'wifi_5g':
      case '5g':
        return '5GHz';
      case 'wifi_6g':
      case '6g':
        return '6GHz';
      case 'wifi_mlo':
      case 'mlo':
        return 'MLO';
      default:
        return frequency;
    }
  }

  /// 狀態文字
  String get statusText => isEnabled ? 'ON' : 'OFF';
}

/// 乙太網路狀態模型（目前使用假資料）
class EthernetStatus {
  final String title;
  final bool showDetails;  // 控制是否顯示詳細資訊

  EthernetStatus({
    this.title = 'Ethernet',
    this.showDetails = false,
  });
}

/// Dashboard 分頁資料模型
class DashboardPageData {
  final String pageTitle;
  final DashboardPageType pageType;
  final Map<String, dynamic> content;

  DashboardPageData({
    required this.pageTitle,
    required this.pageType,
    required this.content,
  });
}

/// Dashboard 分頁類型
enum DashboardPageType {
  systemStatus,    // 第一頁：系統狀態
  wifiSSID,        // 第二頁：WiFi SSID
  ethernet,        // 第三頁：乙太網路
}

/// 顯示控制配置
class DashboardDisplayConfig {
  // 第一頁顯示控制
  final bool showModelName;
  final bool showInternet;
  final bool showWiFiFrequencies;
  final bool showGuestWiFiFrequencies;

  // 第二頁顯示控制
  final bool showWiFiSSIDs;
  final bool showGuestWiFiSSIDs;

  // 第三頁顯示控制
  final bool showEthernetTitle;
  final bool showEthernetDetails;

  const DashboardDisplayConfig({
    // 第一頁預設都顯示
    this.showModelName = true,
    this.showInternet = true,
    this.showWiFiFrequencies = true,
    this.showGuestWiFiFrequencies = false,  // Guest WiFi 預設隱藏

    // 第二頁
    this.showWiFiSSIDs = true,
    this.showGuestWiFiSSIDs = false,  // Guest WiFi SSID 預設隱藏

    // 第三頁
    this.showEthernetTitle = true,
    this.showEthernetDetails = false,  // 乙太網路詳細資訊預設隱藏
  });
}