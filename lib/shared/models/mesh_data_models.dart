// lib/shared/models/mesh_data_models.dart

/// 詳細設備資訊類別
class DetailedDeviceInfo {
  final String macAddress;
  final String ipAddress;
  final String deviceType; // "gateway", "extender", "host"
  final String deviceName;
  final int clientCount;
  final ConnectionInfo connectionInfo;
  final String parentAccessPoint;
  final int hops;
  final List<int> rssiValues;
  final bool isMainNode;
  final Map<String, dynamic> rawData;

  DetailedDeviceInfo({
    required this.macAddress,
    required this.ipAddress,
    required this.deviceType,
    required this.deviceName,
    required this.clientCount,
    required this.connectionInfo,
    required this.parentAccessPoint,
    required this.hops,
    required this.rssiValues,
    required this.isMainNode,
    required this.rawData,
  });

  /// 獲取顯示名稱（優先使用設備名稱，否則使用 MAC）
  String getDisplayName() {
    if (deviceName.isNotEmpty) {
      return deviceName;
    }
    return macAddress;
  }

  /// 獲取設備類型的中文描述
  String getTypeDescription() {
    switch (deviceType) {
      case 'gateway':
        return 'Gateway (Controller)';
      case 'extender':
        return 'Extender (Agent)';
      case 'host':
        return 'Host (Client)';
      default:
        return deviceType;
    }
  }

  /// 獲取信號強度狀態
  String getRSSIStatus() {
    if (rssiValues.isEmpty) return 'N/A';

    // 取第一個非零值作為主要 RSSI
    final mainRSSI = rssiValues.firstWhere((rssi) => rssi != 0, orElse: () => rssiValues.first);

    if (mainRSSI >= -65) return 'Good';
    if (mainRSSI >= -75) return 'Fair';
    return 'Poor';
  }

  @override
  String toString() {
    return 'DetailedDeviceInfo(type: $deviceType, name: ${getDisplayName()}, ip: $ipAddress, clients: $clientCount)';
  }
}

/// 連接資訊類別
class ConnectionInfo {
  final String method; // "Ethernet", "Wireless", etc.
  final String description; // 詳細描述
  final String ssid;
  final String radio; // "2.4G", "5G", "6G", etc.
  final String connectionType;
  final String wirelessStandard; // "ax", "ac", "n", etc.

  ConnectionInfo({
    required this.method,
    required this.description,
    required this.ssid,
    required this.radio,
    required this.connectionType,
    required this.wirelessStandard,
  });

  /// 是否為有線連接
  bool get isWired => method.toLowerCase() == 'ethernet';

  /// 是否為無線連接
  bool get isWireless => method.toLowerCase() == 'wireless' || connectionType.contains('GHz');

  @override
  String toString() {
    return 'ConnectionInfo(method: $method, description: $description)';
  }
}

/// 拓樸連接類別
class TopologyConnection {
  final String fromDevice; // 來源設備 MAC
  final String toDevice; // 目標設備 MAC
  final String connectionType; // 連接類型
  final int rssi; // 信號強度
  final int hops; // 跳數

  TopologyConnection({
    required this.fromDevice,
    required this.toDevice,
    required this.connectionType,
    required this.rssi,
    required this.hops,
  });

  /// 獲取信號強度顏色
  String getRSSIColor() {
    if (rssi >= -65) return 'Green';
    if (rssi >= -75) return 'Orange';
    return 'Red';
  }

  @override
  String toString() {
    return 'TopologyConnection(from: $fromDevice, to: $toDevice, type: $connectionType, rssi: $rssi)';
  }
}

/// 網路拓樸結構類別
class NetworkTopologyStructure {
  final DetailedDeviceInfo gateway;
  final List<DetailedDeviceInfo> extenders;
  final List<DetailedDeviceInfo> hostDevices;
  final List<TopologyConnection> connections;

  NetworkTopologyStructure({
    required this.gateway,
    required this.extenders,
    required this.hostDevices,
    required this.connections,
  });

  /// 獲取總設備數
  int get totalDevices => 1 + extenders.length + hostDevices.length;

  /// 獲取總客戶端數
  int get totalClients => hostDevices.length;

  /// 獲取最大跳數
  int get maxHops => extenders.isNotEmpty ? extenders.map((e) => e.hops).reduce((a, b) => a > b ? a : b) : 0;

  /// 根據跳數獲取 Extender
  List<DetailedDeviceInfo> getExtendersByHop(int hop) {
    return extenders.where((e) => e.hops == hop).toList();
  }

  /// 獲取直接連接到指定設備的設備列表
  List<DetailedDeviceInfo> getDirectConnectedDevices(String parentMAC) {
    final connectedMACs = connections
        .where((conn) => conn.fromDevice == parentMAC)
        .map((conn) => conn.toDevice)
        .toList();

    return [...extenders, ...hostDevices]
        .where((device) => connectedMACs.contains(device.macAddress))
        .toList();
  }

  @override
  String toString() {
    return 'NetworkTopologyStructure(gateway: ${gateway.macAddress}, extenders: ${extenders.length}, hosts: ${hostDevices.length})';
  }
}