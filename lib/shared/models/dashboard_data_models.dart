// lib/shared/models/dashboard_data_models.dart - 重新設計版本

/// Dashboard 配置類
class DashboardConfig {
  // Guest WiFi 顯示控制（目前關閉）
  static const bool showGuestWiFi = false;

  // Ethernet 詳細資訊顯示控制（目前關閉）
  static const bool showEthernetDetails = true;
}

/// Dashboard 完整資料模型 - 重新設計
class DashboardData {
  final String modelName;
  final InternetStatus internetStatus;
  final List<WiFiFrequencyStatus> wifiFrequencies;
  final List<WiFiFrequencyStatus> guestWifiFrequencies;  // 預留，目前不使用
  final List<WiFiSSIDInfo> wifiSSIDs;                    // 第二頁用的 SSID 資訊
  final List<WiFiSSIDInfo> guestWifiSSIDs;               // 預留，目前不使用
  final EthernetStatus ethernetStatus;
  final List<LANPortInfo> lanPorts;                      // LAN 埠資訊

  DashboardData({
    required this.modelName,
    required this.internetStatus,
    required this.wifiFrequencies,
    required this.guestWifiFrequencies,
    required this.wifiSSIDs,
    required this.guestWifiSSIDs,
    required this.ethernetStatus,
    required this.lanPorts,
  });
}

/// LAN 埠資訊模型
class LANPortInfo {
  final String name;              // LAN 埠名稱，如 "2.5Gbps"
  final String connectedStatus;   // 連接狀態，如 "Connected"

  LANPortInfo({
    required this.name,
    required this.connectedStatus,
  });

  /// 格式化狀態顯示文字
  String get formattedStatus {
    // 根據 connected_status 進行格式化，保持原樣或可以自訂
    return connectedStatus;
  }
}

/// 網路連接狀態模型
class InternetStatus {
  final String pingStatus;        // 從 wan[0].ping_status 取得
  final String connectionType;    // 從 /network/wan_eth 的 connection_type 取得

  InternetStatus({
    required this.pingStatus,
    required this.connectionType,
  });

  /// 格式化連接顯示文字
  String get formattedStatus {
    // 根據 connection_type 格式化顯示
    String typeText;
    switch (connectionType.toLowerCase()) {
      case 'dhcp':
        typeText = 'DHCP';
        break;
      case 'static':
        typeText = 'Static';
        break;
      case 'pppoe':
        typeText = 'PPPoE';
        break;
      default:
        typeText = connectionType;
    }
    final bool isConnected = pingStatus.toLowerCase() == 'connected';

    if (isConnected) {
      return 'Connect($typeText)';
    } else {
      return 'Disconnect($typeText)';  // 🔥 修正：未連接時顯示 Disconnect  //dashboard internet
    }
  }
}

/// WiFi 頻率狀態模型 - 用於第一頁
class WiFiFrequencyStatus {
  final String radioName;     // 原始的 radio_name (wifi_2G, wifi_5G, etc.)
  final bool isEnabled;       // vap_enabled == "ON"
  final String ssid;          // 對應的 SSID 名稱

  WiFiFrequencyStatus({
    required this.radioName,
    required this.isEnabled,
    required this.ssid,
  });

  /// 格式化頻率顯示文字 - 修正 MLO 對應
  String get displayFrequency {
    switch (radioName.toLowerCase()) {
      case 'wifi_2g':
        return '2.4GHz';
      case 'wifi_5g':
        return '5GHz';
      case 'wifi_6g':
        return '6GHz';
        case 'wifi_mlo':           // 修正：加入 MLO 對應
        return 'MLO';
      default:
        return radioName;
    }
  }

  /// 狀態文字
  String get statusText => isEnabled ? 'ON' : 'OFF';
}

/// WiFi SSID 資訊模型 - 用於第二頁
class WiFiSSIDInfo {
  final String radioName;     // wifi_2G, wifi_5G, etc.
  final String ssid;          // SSID 名稱
  final bool isEnabled;       // 是否啟用

  WiFiSSIDInfo({
    required this.radioName,
    required this.ssid,
    required this.isEnabled,
  });

  /// 格式化頻率顯示文字（用於 SSID 標籤）
  String get displayFrequency {
    switch (radioName.toLowerCase()) {
      case 'wifi_2g':
        return '2.4GHz';
      case 'wifi_5g':
        return '5GHz';
      case 'wifi_6g':
        return '6GHz';
      case 'wifi_mlo':
        return 'MLO';              // 第二頁
      default:
        return radioName;
    }
  }

  /// SSID 標籤格式：SSID(2.4GHz)
  String get ssidLabel => 'SSID(${displayFrequency})';
}

/// 乙太網路狀態模型
class EthernetStatus {
  final String title;
  final bool showDetails;

  EthernetStatus({
    this.title = 'Ethernet',
    this.showDetails = DashboardConfig.showEthernetDetails,  // 使用配置控制
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
  systemStatus,    // 第一頁：系統狀態（Model Name, Internet, WiFi 頻率）
  ssidList,        // 第二頁：SSID 列表（WiFi SSID, Guest WiFi SSID）
  ethernet,        // 第三頁：乙太網路（只顯示標題）
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
    this.showGuestWiFiFrequencies = DashboardConfig.showGuestWiFi,  // 使用配置控制

    // 第二頁
    this.showWiFiSSIDs = true,
    this.showGuestWiFiSSIDs = DashboardConfig.showGuestWiFi,       // 使用配置控制

    // 第三頁
    this.showEthernetTitle = true,
    this.showEthernetDetails = DashboardConfig.showEthernetDetails, // 使用配置控制
  });
}

/// Dashboard 頁面內容生成器
class DashboardPageContentGenerator {
  /// 生成第一頁內容：系統狀態
  static Map<String, dynamic> generateSystemStatusContent(DashboardData data) {
    return {
      'modelName': data.modelName,
      'internetStatus': data.internetStatus,
      'wifiFrequencies': data.wifiFrequencies,
      'guestWifiFrequencies': DashboardConfig.showGuestWiFi ? data.guestWifiFrequencies : <WiFiFrequencyStatus>[],
    };
  }

  /// 生成第二頁內容：SSID 列表
  static Map<String, dynamic> generateSSIDListContent(DashboardData data) {
    // 只顯示啟用的 SSID
    final enabledWiFiSSIDs = data.wifiSSIDs.where((ssid) => ssid.isEnabled).toList();
    final enabledGuestSSIDs = DashboardConfig.showGuestWiFi
        ? data.guestWifiSSIDs.where((ssid) => ssid.isEnabled).toList()
        : <WiFiSSIDInfo>[];

    return {
      'wifiSSIDs': enabledWiFiSSIDs,
      'guestWifiSSIDs': enabledGuestSSIDs,
    };
  }

  /// 生成第三頁內容：乙太網路
  static Map<String, dynamic> generateEthernetContent(DashboardData data) {
    return {
      'ethernetStatus': data.ethernetStatus,
      'lanPorts': data.lanPorts,
    };
  }

  /// 生成所有分頁
  static List<DashboardPageData> generateAllPages(DashboardData data) {
    return [
      // 第一頁：系統狀態
      DashboardPageData(
        pageTitle: 'System Status',
        pageType: DashboardPageType.systemStatus,
        content: generateSystemStatusContent(data),
      ),

      // 第二頁：SSID 列表
      DashboardPageData(
        pageTitle: 'SSID List',
        pageType: DashboardPageType.ssidList,
        content: generateSSIDListContent(data),
      ),

      // 第三頁：乙太網路
      DashboardPageData(
        pageTitle: 'Ethernet',
        pageType: DashboardPageType.ethernet,
        content: generateEthernetContent(data),
      ),
    ];
  }
}