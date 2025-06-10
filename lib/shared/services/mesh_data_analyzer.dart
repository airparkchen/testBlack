// lib/shared/services/mesh_data_analyzer.dart

import 'dart:convert';
import 'package:whitebox/shared/models/mesh_data_models.dart';

/// Mesh 數據分析器
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

  /// 分析網路拓樸結構
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

    // 分析 Extender 和其連接關係
    final extenders = devices.where((d) => d.deviceType == 'extender').toList();
    final hosts = devices.where((d) => d.deviceType == 'host').toList();

    // 建立連接關係
    for (var extender in extenders) {
      final connection = TopologyConnection(
        fromDevice: extender.parentAccessPoint,
        toDevice: extender.macAddress,
        connectionType: extender.connectionInfo.method,
        rssi: extender.rssiValues.isNotEmpty ? extender.rssiValues.first : 0,
        hops: extender.hops,
      );
      topology.connections.add(connection);
      topology.extenders.add(extender);
    }

    // 添加 Host 設備的連接
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

  /// 分析單個設備節點
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

  /// 設備過濾邏輯
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

  /// 分析連接資訊
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

  /// 輸出詳細設備分析到控制台
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

  /// 輸出拓樸結構到控制台
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

    // Extender 層級結構
    print("║");
    print("║ 📡 Extender 層級結構:");

    // 按 hops 分組
    final extendersByHops = <int, List<DetailedDeviceInfo>>{};
    for (var extender in topology.extenders) {
      extendersByHops.putIfAbsent(extender.hops, () => []).add(extender);
    }

    final sortedHops = extendersByHops.keys.toList()..sort();

    for (var hop in sortedHops) {
      final extendersAtHop = extendersByHops[hop]!;
      print("║   🔸 第 $hop 跳:");

      for (var extender in extendersAtHop) {
        final connection = topology.connections.firstWhere(
              (conn) => conn.toDevice == extender.macAddress,
          orElse: () => TopologyConnection(fromDevice: '', toDevice: '', connectionType: '', rssi: 0, hops: 0),
        );

        print("║     📍 ${extender.getDisplayName()}");
        print("║       ├─ MAC: ${extender.macAddress}");
        print("║       ├─ IP: ${extender.ipAddress}");
        print("║       ├─ 連接到: ${extender.parentAccessPoint}");
        print("║       ├─ 連接方式: ${connection.connectionType}");
        print("║       ├─ RSSI: ${extender.rssiValues}");
        print("║       └─ 客戶端數: ${extender.clientCount}");
      }
    }

    // 連接關係摘要
    print("║");
    print("║ 🔗 連接關係摘要:");
    print("║   ├─ Gateway → Extender: ${topology.connections.where((c) => topology.extenders.any((e) => e.macAddress == c.toDevice)).length}");
    print("║   ├─ Extender → Host: ${topology.connections.where((c) => topology.hostDevices.any((h) => h.macAddress == c.toDevice)).length}");
    print("║   └─ Gateway → Host: ${topology.hostDevices.where((h) => h.parentAccessPoint == topology.gateway.macAddress).length}");

    print("╚════════════════════════════════════════════════════════════════════════════════════════════════════════════");
    print("");
  }
}