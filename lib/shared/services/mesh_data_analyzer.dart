// lib/shared/services/mesh_data_analyzer.dart - 修正版本
// 🎯 修正：正確辨識 gateway-extender1-extender2 串聯結構

import 'dart:convert';
import 'package:whitebox/shared/models/mesh_data_models.dart';

/// Mesh 數據分析器 - 修正版本
class MeshDataAnalyzer {
  // 過濾統計
  int filteredExtenders = 0;
  int filteredHosts = 0;

  /// 分析詳細設備資訊
  List<DetailedDeviceInfo> analyzeDetailedDeviceInfo(dynamic meshData) {
    print("🔍 [DEVICE_ANALYSIS] 開始詳細設備分析");

    List<DetailedDeviceInfo> devices = [];
    filteredExtenders = 0;
    filteredHosts = 0;

    if (meshData is List) {
      // 分析主要節點
      for (int i = 0; i < meshData.length; i++) {
        final node = meshData[i];
        if (node is Map<String, dynamic>) {
          final deviceInfo = _analyzeDeviceNode(node, true);
          if (deviceInfo != null) {
            devices.add(deviceInfo);

            // 分析連接的設備
            if (node.containsKey('connectedDevices') && node['connectedDevices'] is List) {
              final connectedDevices = node['connectedDevices'] as List;
              for (var connectedDevice in connectedDevices) {
                if (connectedDevice is Map<String, dynamic>) {
                  final connectedInfo = _analyzeDeviceNode(connectedDevice, false);
                  if (connectedInfo != null) {
                    devices.add(connectedInfo);
                  }
                } else if (connectedDevice is Map) {
                  // 處理 Map<dynamic, dynamic> 的情況
                  final convertedDevice = Map<String, dynamic>.from(connectedDevice);
                  final connectedInfo = _analyzeDeviceNode(convertedDevice, false);
                  if (connectedInfo != null) {
                    devices.add(connectedInfo);
                  }
                }
              }
            }
          }
        } else if (node is Map) {
          // 處理 Map<dynamic, dynamic> 的情況
          final convertedNode = Map<String, dynamic>.from(node);
          final deviceInfo = _analyzeDeviceNode(convertedNode, true);
          if (deviceInfo != null) {
            devices.add(deviceInfo);

            // 分析連接的設備
            if (convertedNode.containsKey('connectedDevices') && convertedNode['connectedDevices'] is List) {
              final connectedDevices = convertedNode['connectedDevices'] as List;
              for (var connectedDevice in connectedDevices) {
                if (connectedDevice is Map<String, dynamic>) {
                  final connectedInfo = _analyzeDeviceNode(connectedDevice, false);
                  if (connectedInfo != null) {
                    devices.add(connectedInfo);
                  }
                } else if (connectedDevice is Map) {
                  final convertedConnectedDevice = Map<String, dynamic>.from(connectedDevice);
                  final connectedInfo = _analyzeDeviceNode(convertedConnectedDevice, false);
                  if (connectedInfo != null) {
                    devices.add(connectedInfo);
                  }
                }
              }
            }
          }
        }
      }
    }

    print("✅ [DEVICE_ANALYSIS] 分析完成：${devices.length} 個設備");
    print("🚫 [DEVICE_ANALYSIS] 過濾統計: Extender($filteredExtenders), Host($filteredHosts)");

    return devices;
  }

  /// 🎯 修正：分析網路拓樸結構 - 正確處理串聯關係
  NetworkTopologyStructure? analyzeTopologyStructure(List<DetailedDeviceInfo> devices) {
    print("🌐 [TOPOLOGY_ANALYSIS] 開始拓樸結構分析");

    if (devices.isEmpty) {
      print("⚠️ [TOPOLOGY_ANALYSIS] 沒有可用的設備資料");
      return null;
    }

    // 找到 Gateway
    DetailedDeviceInfo? gateway;
    try {
      gateway = devices.firstWhere((device) => device.deviceType == 'gateway');
    } catch (e) {
      print("❌ [TOPOLOGY_ANALYSIS] 找不到 Gateway 設備");
      return null;
    }

    // 建立拓樸結構
    final topology = NetworkTopologyStructure(
      gateway: gateway,
      extenders: [],
      hostDevices: [],
      connections: [],
    );

    // 🎯 修正：正確分析 Extender 和其串聯關係
    final extenders = devices.where((d) => d.deviceType == 'extender').toList();
    final hosts = devices.where((d) => d.deviceType == 'host').toList();

    // 🎯 關鍵修正：按照 parentAccessPoint 正確建立連接關係
    for (var extender in extenders) {
      // 🎯 修正：根據 parentAccessPoint 建立正確的連接
      final connection = TopologyConnection(
        fromDevice: extender.parentAccessPoint, // 🎯 關鍵：使用 parentAccessPoint 作為來源
        toDevice: extender.macAddress,          // 🎯 目標是 extender 本身
        connectionType: extender.connectionInfo.method,
        rssi: extender.rssiValues.isNotEmpty ? extender.rssiValues.first : 0,
        hops: extender.hops,
      );
      topology.connections.add(connection);
      topology.extenders.add(extender);

      print("🔗 [TOPOLOGY_ANALYSIS] Extender 連接: ${extender.parentAccessPoint} → ${extender.macAddress} (hops: ${extender.hops})");
    }

    // 添加 Host 設備的連接（邏輯保持不變）
    for (var host in hosts) {
      final connection = TopologyConnection(
        fromDevice: host.parentAccessPoint,
        toDevice: host.macAddress,
        connectionType: host.connectionInfo.method,
        rssi: host.rssiValues.isNotEmpty ? host.rssiValues.first : 0,
        hops: 0,
      );
      topology.connections.add(connection);
      topology.hostDevices.add(host);
    }

    print("✅ [TOPOLOGY_ANALYSIS] 分析完成");
    return topology;
  }

  /// 🎯 修正：輸出拓樸結構到控制台 - 正確顯示串聯結構
  void printTopologyStructure(NetworkTopologyStructure topology) {
    final timestamp = DateTime.now().toString();

    print("");
    print("╔════════════════════════════════════════════════════════════════════════════════════════════════════════════");
    print("║ [TOPOLOGY_STRUCTURE] 網路拓樸結構分析");
    print("║ 時間: $timestamp");
    print("╠════════════════════════════════════════════════════════════════════════════════════════════════════════════");

    // Gateway 資訊
    print("║");
    print("║ 🏠 Gateway (Root):");
    print("║   📍 ${topology.gateway.getDisplayName()}");
    print("║     ├─ MAC: ${topology.gateway.macAddress}");
    print("║     ├─ IP: ${topology.gateway.ipAddress}");
    print("║     └─ 直連客戶端: ${topology.gateway.clientCount}");

    // 🎯 修正：顯示 Gateway 直接連接的 Host 設備
    final gatewayHosts = topology.getDirectConnectedDevices(topology.gateway.macAddress)
        .where((device) => device.deviceType == 'host')
        .toList();

    if (gatewayHosts.isNotEmpty) {
      print("║");
      print("║ 🏠 Gateway 直接連接的 Host 設備:");
      for (var host in gatewayHosts) {
        print("║   📱 ${host.getDisplayName()}");
        print("║     ├─ MAC: ${host.macAddress}");
        print("║     ├─ IP: ${host.ipAddress}");
        print("║     ├─ 連接方式: ${host.connectionInfo.description}");
        if (host.rssiValues.isNotEmpty && host.rssiValues.any((r) => r != 0)) {
          print("║     └─ RSSI: ${host.rssiValues}");
        } else {
          print("║     └─ 連接: 有線");
        }
      }
    }

    // 🎯 修正：按串聯結構顯示 Extender 層級
    print("║");
    print("║ 📡 Extender 串聯結構:");
    _printExtenderChain(topology, topology.gateway.macAddress, 0);

    // 連接關係摘要
    print("║");
    print("║ 🔗 連接關係摘要:");
    print("║   ├─ Gateway → Host: ${gatewayHosts.length} 個");

    // 🎯 修正：正確統計串聯關係
    final gatewayToExtenderCount = topology.connections
        .where((c) => c.fromDevice == topology.gateway.macAddress &&
        topology.extenders.any((e) => e.macAddress == c.toDevice))
        .length;
    print("║   ├─ Gateway → Extender: $gatewayToExtenderCount 個");

    final extenderToExtenderCount = topology.connections
        .where((c) => topology.extenders.any((e) => e.macAddress == c.fromDevice) &&
        topology.extenders.any((e) => e.macAddress == c.toDevice))
        .length;
    print("║   ├─ Extender → Extender: $extenderToExtenderCount 個");

    final extenderToHostCount = topology.connections
        .where((c) => topology.extenders.any((e) => e.macAddress == c.fromDevice) &&
        topology.hostDevices.any((h) => h.macAddress == c.toDevice))
        .length;
    print("║   └─ Extender → Host: $extenderToHostCount 個");

    print("╚════════════════════════════════════════════════════════════════════════════════════════════════════════════");
    print("");
  }

  /// 🎯 新增：遞迴顯示 Extender 串聯結構
  void _printExtenderChain(NetworkTopologyStructure topology, String parentMAC, int level) {
    // 找到直接連接到當前父節點的 Extender
    final childExtenders = topology.extenders
        .where((extender) => extender.parentAccessPoint == parentMAC)
        .toList();

    for (int i = 0; i < childExtenders.length; i++) {
      final extender = childExtenders[i];
      final isLast = i == childExtenders.length - 1;
      final prefix = _getTreePrefix(level, isLast);

      print("║ $prefix 📡 ${extender.getDisplayName()} (Hop ${extender.hops})");
      print("║ ${_getTreeIndent(level, isLast)}  ├─ MAC: ${extender.macAddress}");
      print("║ ${_getTreeIndent(level, isLast)}  ├─ IP: ${extender.ipAddress}");
      print("║ ${_getTreeIndent(level, isLast)}  ├─ RSSI: ${extender.rssiValues} (${_parseRSSIDescription(extender.rssiValues)})");
      print("║ ${_getTreeIndent(level, isLast)}  ├─ 父節點: ${_getParentDescription(topology, extender.parentAccessPoint)}");

      // 顯示直接連接的 Host 設備
      final extenderHosts = topology.hostDevices
          .where((host) => host.parentAccessPoint == extender.macAddress)
          .toList();

      if (extenderHosts.isNotEmpty) {
        print("║ ${_getTreeIndent(level, isLast)}  └─ 連接 Host: ${extenderHosts.length} 個");
        for (int j = 0; j < extenderHosts.length; j++) {
          final host = extenderHosts[j];
          final hostIsLast = j == extenderHosts.length - 1;
          final hostPrefix = hostIsLast ? "└─" : "├─";
          print("║ ${_getTreeIndent(level, isLast)}      $hostPrefix ${host.getDisplayName()}");
          print("║ ${_getTreeIndent(level, isLast)}         └─ IP: ${host.ipAddress} (${host.connectionInfo.description})");
        }
      } else {
        print("║ ${_getTreeIndent(level, isLast)}  └─ 無連接 Host");
      }

      // 🎯 關鍵：遞迴顯示子 Extender
      _printExtenderChain(topology, extender.macAddress, level + 1);
    }
  }

  /// 🎯 輔助方法：獲取樹狀結構前綴
  String _getTreePrefix(int level, bool isLast) {
    if (level == 0) {
      return isLast ? "   └─" : "   ├─";
    } else {
      return "      " + ("   " * level) + (isLast ? "└─" : "├─");
    }
  }

  /// 🎯 輔助方法：獲取樹狀結構縮排
  String _getTreeIndent(int level, bool isLast) {
    if (level == 0) {
      return isLast ? "     " : "   │ ";
    } else {
      return "      " + ("   " * level) + (isLast ? "   " : "│  ");
    }
  }

  /// 🎯 輔助方法：解析 RSSI 描述
  String _parseRSSIDescription(List<int> rssiValues) {
    if (rssiValues.isEmpty || rssiValues.every((r) => r == 0)) {
      return "有線連接";
    }

    final validRSSI = rssiValues.where((r) => r != 0).toList();
    if (validRSSI.isEmpty) return "有線連接";

    final bestRSSI = validRSSI.reduce((a, b) => a > b ? a : b);

    if (bestRSSI > -65) return "優秀";
    if (bestRSSI > -75) return "良好";
    return "需改善";
  }

  /// 🎯 輔助方法：獲取父節點描述
  String _getParentDescription(NetworkTopologyStructure topology, String parentMAC) {
    if (parentMAC == topology.gateway.macAddress) {
      return "Gateway";
    }

    final parentExtender = topology.extenders
        .where((e) => e.macAddress == parentMAC)
        .firstOrNull;

    if (parentExtender != null) {
      return "${parentExtender.getDisplayName()} (Hop ${parentExtender.hops})";
    }

    return "Unknown ($parentMAC)";
  }

  /// 分析單個設備節點（邏輯保持不變）
  DetailedDeviceInfo? _analyzeDeviceNode(Map<String, dynamic> node, bool isMainNode) {
    final String deviceType = node['type']?.toString() ?? 'unknown';
    final String macAddr = node['macAddr']?.toString() ?? '';
    final String ipAddress = node['ipAddress']?.toString() ?? '';

    // 應用過濾規則
    if (_shouldFilterDevice(node)) {
      if (deviceType == 'extender') {
        filteredExtenders++;
      } else if (deviceType == 'host') {
        filteredHosts++;
      }
      print("🚫 [DEVICE_ANALYSIS] 過濾設備: $macAddr (類型: $deviceType)");
      return null;
    }

    // 分析連接資訊
    final connectionInfo = _analyzeConnectionInfo(node);

    // 計算客戶端數量
    int clientCount = 0;
    if (isMainNode && node.containsKey('connectedDevices') && node['connectedDevices'] is List) {
      final connectedDevices = node['connectedDevices'] as List;
      // 只計算有效的 host 設備
      clientCount = connectedDevices.where((device) {
        if (device is Map<String, dynamic>) {
          return device['type'] == 'host' && !_shouldFilterDevice(device);
        } else if (device is Map) {
          final convertedDevice = Map<String, dynamic>.from(device);
          return convertedDevice['type'] == 'host' && !_shouldFilterDevice(convertedDevice);
        }
        return false;
      }).length;
    }

    final deviceInfo = DetailedDeviceInfo(
      macAddress: macAddr,
      ipAddress: ipAddress,
      deviceType: deviceType,
      deviceName: node['devName']?.toString() ?? '',
      clientCount: clientCount,
      connectionInfo: connectionInfo,
      parentAccessPoint: node['parentAccessPoint']?.toString() ?? '',
      hops: node['hops'] ?? 0,
      rssiValues: _parseRSSI(node['rssi']),
      isMainNode: isMainNode,
      rawData: node,
    );

    print("✅ [DEVICE_ANALYSIS] 解析設備: ${deviceInfo.getDisplayName()}");
    print("    ├─ 類型: $deviceType");
    print("    ├─ IP: $ipAddress");
    print("    ├─ 連接方式: ${connectionInfo.description}");
    print("    ├─ 客戶端數: $clientCount");
    print("    └─ 父節點: ${deviceInfo.parentAccessPoint}");

    return deviceInfo;
  }

  /// 設備過濾邏輯（保持不變）
  bool _shouldFilterDevice(Map<String, dynamic> device) {
    final String deviceType = device['type']?.toString() ?? '';

    if (deviceType == 'extender') {
      // 過濾 RSSI 全部為 0 的 extender
      final rssiValues = _parseRSSI(device['rssi']);
      if (rssiValues.isNotEmpty && rssiValues.every((rssi) => rssi == 0)) {
        return true;
      }
    } else if (deviceType == 'host') {
      // 過濾 ssid 包含 "bh-" 的 host
      final String ssid = device['ssid']?.toString() ?? '';
      if (ssid.contains('bh-')) {
        return true;
      }

      // 過濾沒有 IP 的 host
      final String ip = device['ipAddress']?.toString() ?? '';
      if (ip.isEmpty) {
        return true;
      }
    }

    return false;
  }

  /// 解析 RSSI 值（支援多頻段）
  List<int> _parseRSSI(dynamic rssiData) {
    if (rssiData == null) return [];

    String rssiStr = rssiData.toString();
    if (rssiStr.isEmpty) return [];

    // 處理多頻段 RSSI，如 "0,-21,-25"
    return rssiStr.split(',').map((s) => int.tryParse(s.trim()) ?? 0).toList();
  }

  /// 分析連接資訊（邏輯保持不變）
  ConnectionInfo _analyzeConnectionInfo(Map<String, dynamic> device) {
    final String connectionType = device['connectionType']?.toString() ?? '';
    final String ssid = device['ssid']?.toString() ?? '';
    final String radio = device['radio']?.toString() ?? '';
    final String wirelessStandard = device['wirelessStandard']?.toString() ?? '';

    String method = '';
    String description = '';

    if (connectionType.toLowerCase() == 'ethernet') {
      method = 'Ethernet';
      description = 'Ethernet 有線連接';
    } else if (connectionType.toLowerCase() == 'wireless') {
      method = 'Wireless';
      description = 'WiFi 無線連接';
      if (radio.isNotEmpty) {
        description += ' ($radio)';
      }
    } else if (connectionType.contains('GHz')) {
      method = 'Wireless';
      description = 'WiFi $connectionType 連接';
      if (ssid.isNotEmpty) {
        description += ' (SSID: $ssid)';
      }
    } else {
      method = connectionType.isNotEmpty ? connectionType : 'Unknown';
      description = connectionType.isNotEmpty ? connectionType : '未知連接方式';
    }

    // 添加 WiFi 標準資訊
    if (wirelessStandard.isNotEmpty) {
      description += ' [802.11$wirelessStandard]';
    }

    return ConnectionInfo(
      method: method,
      description: description,
      ssid: ssid,
      radio: radio,
      connectionType: connectionType,
      wirelessStandard: wirelessStandard,
    );
  }

  /// 輸出詳細設備分析到控制台（保持不變）
  void printDetailedDeviceAnalysis(List<DetailedDeviceInfo> devices) {
    final timestamp = DateTime.now().toString();

    print("");
    print("╔════════════════════════════════════════════════════════════════════════════════════════════════════════════");
    print("║ [DETAILED_DEVICE_ANALYSIS] 詳細設備分析結果");
    print("║ 時間: $timestamp");
    print("║ 總設備數: ${devices.length}");
    print("║ 過濾的 Extender: $filteredExtenders");
    print("║ 過濾的 Host: $filteredHosts");
    print("╠════════════════════════════════════════════════════════════════════════════════════════════════════════════");

    // 按設備類型分組
    final gatewayDevices = devices.where((d) => d.deviceType == 'gateway').toList();
    final extenderDevices = devices.where((d) => d.deviceType == 'extender').toList();
    final hostDevices = devices.where((d) => d.deviceType == 'host').toList();

    // Gateway 分析
    print("║");
    print("║ 🏠 Gateway (Controller) 設備:");
    for (var device in gatewayDevices) {
      print("║   📍 ${device.getDisplayName()}");
      print("║     ├─ MAC: ${device.macAddress}");
      print("║     ├─ IP: ${device.ipAddress}");
      print("║     ├─ 客戶端數: ${device.clientCount}");
      print("║     └─ 連接方式: ${device.connectionInfo.description}");
    }

    // Extender 分析
    print("║");
    print("║ 📡 Extender (Agent) 設備:");
    for (var device in extenderDevices) {
      print("║   📍 ${device.getDisplayName()}");
      print("║     ├─ MAC: ${device.macAddress}");
      print("║     ├─ IP: ${device.ipAddress}");
      print("║     ├─ 客戶端數: ${device.clientCount}");
      print("║     ├─ 連接方式: ${device.connectionInfo.description}");
      print("║     ├─ 父節點: ${device.parentAccessPoint}");
      print("║     ├─ 跳數: ${device.hops}");
      print("║     └─ RSSI: ${device.rssiValues}");
    }

    // Host 分析
    print("║");
    print("║ 📱 Host (Client) 設備:");
    for (var device in hostDevices) {
      print("║   📍 ${device.getDisplayName()}");
      print("║     ├─ MAC: ${device.macAddress}");
      print("║     ├─ IP: ${device.ipAddress}");
      print("║     ├─ 連接方式: ${device.connectionInfo.description}");
      print("║     ├─ 父節點: ${device.parentAccessPoint}");
      print("║     └─ RSSI: ${device.rssiValues}");
    }

    print("╚════════════════════════════════════════════════════════════════════════════════════════════════════════════");
    print("");
  }
}