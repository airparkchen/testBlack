// lib/shared/services/real_data_integration_service.dart - 修正版本

import 'package:whitebox/shared/api/wifi_api_service.dart';
import 'package:whitebox/shared/services/mesh_data_analyzer.dart';
import 'package:whitebox/shared/models/mesh_data_models.dart';
import 'package:whitebox/shared/ui/components/basic/NetworkTopologyComponent.dart';
import 'package:whitebox/shared/ui/pages/home/DeviceDetailPage.dart';

/// 真實數據整合服務 - 修正版本
/// 🎯 關鍵修正：正確區分 Host 和 Extender 的計算邏輯
class RealDataIntegrationService {
  static final MeshDataAnalyzer _analyzer = MeshDataAnalyzer();

  // 快取機制
  static List<NetworkDevice>? _cachedNetworkDevices;
  static List<DeviceConnection>? _cachedDeviceConnections;
  static NetworkTopologyStructure? _cachedTopologyStructure;
  static DateTime? _lastFetchTime;
  static const Duration _cacheExpiry = Duration(seconds: 30);

  /// 檢查快取是否有效
  static bool _isCacheValid() {
    if (_lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheExpiry;
  }

  /// 清除快取
  static void clearCache() {
    _cachedNetworkDevices = null;
    _cachedDeviceConnections = null;
    _cachedTopologyStructure = null;
    _lastFetchTime = null;
    print('🗑️ 已清除真實數據快取');
  }

  /// 拓撲圖設備列表：只返回 Extender（Gateway 由元件內部處理）
  static Future<List<NetworkDevice>> getNetworkDevices() async {
    try {
      // 檢查快取
      if (_isCacheValid() && _cachedNetworkDevices != null) {
        print('📋 使用快取的 NetworkDevice 資料');
        return _cachedNetworkDevices!;
      }

      print('🌐 開始從 Mesh API 獲取拓撲圖設備資料...');

      // 1. 獲取拓撲結構
      final topologyStructure = await getTopologyStructure();
      if (topologyStructure == null) {
        print('❌ 無法獲取拓撲結構');
        return [];
      }

      // 2. 🎯 只轉換 Extender 為 NetworkDevice
      final networkDevices = <NetworkDevice>[];

      for (final extender in topologyStructure.extenders) {
        // 🎯 關鍵修正：只計算直接連接的 Host 數量
        final directHosts = _getDirectHostDevices(topologyStructure, extender.macAddress);

        final networkDevice = NetworkDevice(
          name: _generateDisplayName(extender),
          id: _generateDeviceId(extender.macAddress),
          mac: extender.macAddress,
          ip: extender.ipAddress,
          connectionType: extender.connectionInfo.isWired
              ? ConnectionType.wired
              : ConnectionType.wireless,
          additionalInfo: {
            'type': extender.deviceType,
            'devName': extender.deviceName,
            'status': 'online',
            'rssi': extender.rssiValues.join(','),
            'ssid': extender.connectionInfo.ssid,
            'radio': extender.connectionInfo.radio,
            'parentAccessPoint': extender.parentAccessPoint,
            'hops': extender.hops.toString(),
            'clientCount': directHosts.length.toString(), // 🎯 只計算 Host
            'connectionDescription': extender.connectionInfo.description,
            'linkstate': extender.rawData['linkstate'] ?? '',
            'wirelessStandard': extender.connectionInfo.wirelessStandard,
            'rxrate': extender.rawData['rxrate'] ?? '',
            'txrate': extender.rawData['txrate'] ?? '',
          },
        );

        networkDevices.add(networkDevice);
        print('✅ 添加 Extender: ${extender.deviceName}, Host 數量: ${directHosts.length}');
      }

      // 更新快取
      _cachedNetworkDevices = networkDevices;
      _lastFetchTime = DateTime.now();

      print('✅ 拓撲圖設備數量: ${networkDevices.length} 個 Extender');
      return networkDevices;

    } catch (e) {
      print('❌ 獲取 NetworkDevice 時發生錯誤: $e');
      return [];
    }
  }

  /// 🎯 修正版本：設備連接數據（小圓圈數字）- 只計算 Host 數量
  static Future<List<DeviceConnection>> getDeviceConnections() async {
    try {
      // 檢查快取
      if (_isCacheValid() && _cachedDeviceConnections != null) {
        print('📋 使用快取的 DeviceConnection 資料');
        return _cachedDeviceConnections!;
      }

      print('🌐 開始從 Mesh API 獲取連接資料...');

      // 1. 獲取拓撲結構
      final topologyStructure = await getTopologyStructure();
      if (topologyStructure == null) {
        print('❌ 無法獲取拓撲結構');
        return [];
      }

      final deviceConnections = <DeviceConnection>[];

      // 2. 🎯 Gateway 的連接數 = 直接連接的 Host 數量（不包括 Extender）
      final gatewayHosts = _getDirectHostDevices(topologyStructure, topologyStructure.gateway.macAddress);
      final gatewayConnection = DeviceConnection(
        deviceId: _generateDeviceId(topologyStructure.gateway.macAddress),
        connectedDevicesCount: gatewayHosts.length,
      );
      deviceConnections.add(gatewayConnection);
      print('✅ Gateway Host 連接數: ${gatewayHosts.length}');

      // 3. 🎯 每個 Extender 的連接數 = 直接連接的 Host 數量（不包括其他 Extender）
      for (final extender in topologyStructure.extenders) {
        final extenderHosts = _getDirectHostDevices(topologyStructure, extender.macAddress);
        final extenderConnection = DeviceConnection(
          deviceId: _generateDeviceId(extender.macAddress),
          connectedDevicesCount: extenderHosts.length,
        );
        deviceConnections.add(extenderConnection);
        print('✅ Extender ${extender.deviceName} Host 連接數: ${extenderHosts.length}');
      }

      // 更新快取
      _cachedDeviceConnections = deviceConnections;
      _lastFetchTime = DateTime.now();

      print('✅ 成功獲取 ${deviceConnections.length} 個 DeviceConnection');
      return deviceConnections;

    } catch (e) {
      print('❌ 獲取 DeviceConnection 時發生錯誤: $e');
      return [];
    }
  }

  /// List 視圖設備列表：Gateway + 所有 Extender
  /// 🎯 修正 getListViewDevices 方法中的重複設備問題
  static Future<List<NetworkDevice>> getListViewDevices() async {
    try {
      print('🌐 開始獲取 List 視圖設備資料...');

      // 1. 獲取拓撲結構
      final topologyStructure = await getTopologyStructure();
      if (topologyStructure == null) {
        print('❌ 無法獲取拓撲結構');
        return [];
      }

      final listDevices = <NetworkDevice>[];

      // 🎯 調試：輸出拓撲結構中的所有設備
      print('=== 拓撲結構調試資訊 ===');
      print('Gateway MAC: ${topologyStructure.gateway.macAddress}');
      print('Gateway 名稱: ${topologyStructure.gateway.deviceName}');
      print('Extender 數量: ${topologyStructure.extenders.length}');

      for (int i = 0; i < topologyStructure.extenders.length; i++) {
        final extender = topologyStructure.extenders[i];
        print('Extender $i: ${extender.deviceName} (${extender.macAddress})');
      }
      print('========================');

      // 2. 🎯 添加 Gateway - 只計算直接連接的 Host
      final gatewayHosts = _getDirectHostDevices(topologyStructure, topologyStructure.gateway.macAddress);
      final gatewayDevice = NetworkDevice(
        name: 'Controller',
        id: _generateDeviceId(topologyStructure.gateway.macAddress),
        mac: topologyStructure.gateway.macAddress,
        ip: topologyStructure.gateway.ipAddress,
        connectionType: ConnectionType.wired,
        additionalInfo: {
          'type': 'gateway',
          'status': 'online',
          'clients': gatewayHosts.length.toString(), // 🎯 只計算 Host
          'rssi': '',
        },
      );
      listDevices.add(gatewayDevice);
      print('✅ 添加 Gateway: ${topologyStructure.gateway.macAddress}, Host 數量 ${gatewayHosts.length}');

      // 3. 🎯 添加所有 Extender - 只計算直接連接的 Host
      for (final extender in topologyStructure.extenders) {
        final extenderHosts = _getDirectHostDevices(topologyStructure, extender.macAddress);
        final extenderDevice = NetworkDevice(
          name: _generateDisplayName(extender),
          id: _generateDeviceId(extender.macAddress),
          mac: extender.macAddress,
          ip: extender.ipAddress,
          connectionType: extender.connectionInfo.isWired
              ? ConnectionType.wired
              : ConnectionType.wireless,
          additionalInfo: {
            'type': 'extender',
            'status': 'online',
            'clients': extenderHosts.length.toString(), // 🎯 只計算 Host
            'rssi': extender.rssiValues.join(','),
          },
        );
        listDevices.add(extenderDevice);
        print('✅ 添加 Extender: ${extender.deviceName} (${extender.macAddress}), Host 數量 ${extenderHosts.length}');
      }

      // 🎯 最終檢查：確保沒有重複設備
      print('=== List 設備最終檢查 ===');
      final macAddresses = <String>{};
      for (final device in listDevices) {
        if (macAddresses.contains(device.mac)) {
          print('❌ 發現重複設備: ${device.mac}');
        } else {
          macAddresses.add(device.mac);
          print('✅ 設備: ${device.name} (${device.mac}) - 客戶端: ${device.additionalInfo['clients']}');
        }
      }
      print('總設備數: ${listDevices.length}');
      print('========================');

      return listDevices;

    } catch (e) {
      print('❌ 獲取 List 視圖設備時發生錯誤: $e');
      return [];
    }
  }

  /// 🎯 新增：檢查和調試 MAC 地址不一致的問題
  static Future<void> debugMacAddressIssue() async {
    try {
      print('\n=== MAC 地址詳細分析 ===');

      final meshResult = await WifiApiService.getMeshTopology();

      if (meshResult is List) {
        final Set<String> allMacAddresses = {};

        print('📋 原始 API 中的所有設備:');
        for (int i = 0; i < meshResult.length; i++) {
          final node = meshResult[i];
          if (node is Map<String, dynamic>) {
            final String type = node['type'] ?? 'unknown';
            final String mac = node['macAddr'] ?? '';
            final String devName = node['devName'] ?? '';
            final String ip = node['ipAddress'] ?? '';

            allMacAddresses.add(mac);
            print('📍 主節點 $i:');
            print('   類型: $type');
            print('   MAC: $mac');
            print('   名稱: $devName');
            print('   IP: $ip');

            // 檢查連接設備
            if (node.containsKey('connectedDevices') && node['connectedDevices'] is List) {
              final connectedDevices = node['connectedDevices'] as List;
              print('   連接設備數: ${connectedDevices.length}');

              for (int j = 0; j < connectedDevices.length; j++) {
                final device = connectedDevices[j];
                if (device is Map<String, dynamic>) {
                  final String deviceType = device['type'] ?? 'unknown';
                  final String deviceMac = device['macAddr'] ?? '';
                  final String deviceName = device['devName'] ?? '';
                  final String deviceIp = device['ipAddress'] ?? '';
                  final String parentAP = device['parentAccessPoint'] ?? '';

                  allMacAddresses.add(deviceMac);
                  print('   └─ 子設備 $j:');
                  print('      類型: $deviceType');
                  print('      MAC: $deviceMac');
                  print('      名稱: $deviceName');
                  print('      IP: $deviceIp');
                  print('      父節點: $parentAP');
                }
              }
            }
            print('');
          }
        }

        print('🔢 總計發現 ${allMacAddresses.length} 個唯一 MAC 地址:');
        for (final mac in allMacAddresses) {
          print('   - $mac');
        }
      }

      print('===========================\n');
    } catch (e) {
      print('❌ MAC 地址分析失敗: $e');
    }
  }

  /// 獲取網路拓樸結構
  /// 🎯 修正：在 getTopologyStructure 方法中加入調試
  static Future<NetworkTopologyStructure?> getTopologyStructure() async {
    try {
      // 檢查快取
      if (_isCacheValid() && _cachedTopologyStructure != null) {
        print('📋 使用快取的 TopologyStructure 資料');
        return _cachedTopologyStructure;
      }

      print('🌐 開始從 Mesh API 獲取拓樸結構...');

      // 🎯 新增：調試 MAC 地址
      await debugMacAddressIssue();

      // 1. 獲取原始 Mesh 數據
      final meshResult = await WifiApiService.getMeshTopology();

      // 2. 使用分析器解析詳細設備資訊
      final detailedDevices = _analyzer.analyzeDetailedDeviceInfo(meshResult);

      // 🎯 調試：檢查分析器的結果
      print('=== MeshDataAnalyzer 分析結果 ===');
      print('分析出的設備總數: ${detailedDevices.length}');
      for (final device in detailedDevices) {
        print('設備: ${device.deviceType} - ${device.macAddress} (${device.deviceName})');
      }
      print('==============================');

      // 3. 建立拓樸結構
      final topologyStructure = _analyzer.analyzeTopologyStructure(detailedDevices);

      // 更新快取
      _cachedTopologyStructure = topologyStructure;
      _lastFetchTime = DateTime.now();

      if (topologyStructure != null) {
        print('✅ 成功獲取網路拓樸結構');
        print('   Gateway: ${topologyStructure.gateway.macAddress}');
        print('   Extenders: ${topologyStructure.extenders.length}');
        print('   Hosts: ${topologyStructure.hostDevices.length}');

        // 🎯 詳細檢查 Host 分布
        print('=== Host 分布詳情 ===');
        final gatewayHosts = _getDirectHostDevices(topologyStructure, topologyStructure.gateway.macAddress);
        print('Gateway 直接連接的 Host: ${gatewayHosts.length} 個');
        for (final host in gatewayHosts) {
          print('  - ${host.getDisplayName()} (${host.macAddress}) → 父節點: ${host.parentAccessPoint}');
        }

        for (final extender in topologyStructure.extenders) {
          final extenderHosts = _getDirectHostDevices(topologyStructure, extender.macAddress);
          print('Extender ${extender.deviceName} 直接連接的 Host: ${extenderHosts.length} 個');
          for (final host in extenderHosts) {
            print('  - ${host.getDisplayName()} (${host.macAddress}) → 父節點: ${host.parentAccessPoint}');
          }
        }
        print('==================');
      }

      return topologyStructure;

    } catch (e) {
      print('❌ 獲取 TopologyStructure 時發生錯誤: $e');
      return null;
    }
  }


  /// 🎯 新增調試方法：檢查客戶端數量計算
  static Future<void> debugClientCounts() async {
    try {
      print('\n=== 客戶端數量計算分析 ===');

      final topologyStructure = await getTopologyStructure();
      if (topologyStructure == null) {
        print('❌ 無法獲取拓撲結構');
        return;
      }

      print('🏠 Gateway 分析:');
      print('   MAC: ${topologyStructure.gateway.macAddress}');
      print('   名稱: ${topologyStructure.gateway.deviceName}');
      print('   IP: ${topologyStructure.gateway.ipAddress}');

      final gatewayAllConnected = topologyStructure.getDirectConnectedDevices(topologyStructure.gateway.macAddress);
      final gatewayHosts = _getDirectHostDevices(topologyStructure, topologyStructure.gateway.macAddress);

      print('   直接連接的所有設備: ${gatewayAllConnected.length} 個');
      for (final device in gatewayAllConnected) {
        print('     └─ ${device.deviceType}: ${device.getDisplayName()} (${device.macAddress})');
      }

      print('   直接連接的 Host 設備: ${gatewayHosts.length} 個');
      for (final host in gatewayHosts) {
        print('     └─ Host: ${host.getDisplayName()} (${host.macAddress})');
      }

      print('\n📡 Extender 分析:');
      for (int i = 0; i < topologyStructure.extenders.length; i++) {
        final extender = topologyStructure.extenders[i];
        print('   Extender $i:');
        print('     MAC: ${extender.macAddress}');
        print('     名稱: ${extender.deviceName}');
        print('     IP: ${extender.ipAddress}');

        final extenderAllConnected = topologyStructure.getDirectConnectedDevices(extender.macAddress);
        final extenderHosts = _getDirectHostDevices(topologyStructure, extender.macAddress);

        print('     直接連接的所有設備: ${extenderAllConnected.length} 個');
        for (final device in extenderAllConnected) {
          print('       └─ ${device.deviceType}: ${device.getDisplayName()} (${device.macAddress})');
        }

        print('     直接連接的 Host 設備: ${extenderHosts.length} 個');
        for (final host in extenderHosts) {
          print('       └─ Host: ${host.getDisplayName()} (${host.macAddress})');
        }
        print('');
      }

      print('===========================\n');
    } catch (e) {
      print('❌ 客戶端數量分析失敗: $e');
    }
  }
  static Future<void> debugCompleteDataFlow() async {
    try {
      print('\n=== 🔍 完整數據流分析 ===');

      print('1️⃣ 原始 API 數據分析...');
      await debugMacAddressIssue();

      print('2️⃣ 客戶端數量計算分析...');
      await debugClientCounts();

      print('3️⃣ 最終生成的數據分析...');
      await printDataStatistics();

      print('=== 🔍 完整分析結束 ===\n');
    } catch (e) {
      print('❌ 完整數據流分析失敗: $e');
    }
  }

  /// 🎯 修正版本：獲取客戶端設備列表 - 只返回 Host 設備
  static Future<List<ClientDevice>> getClientDevicesForParent(String parentDeviceId) async {
    try {
      print('🌐 獲取設備 $parentDeviceId 的客戶端列表...');

      // 1. 獲取拓樸結構
      final topologyStructure = await getTopologyStructure();
      if (topologyStructure == null) {
        print('❌ 無法獲取拓樸結構');
        return [];
      }

      // 2. 找到對應的父設備
      DetailedDeviceInfo? parentDevice;

      // 在 Gateway 中尋找
      if (_generateDeviceId(topologyStructure.gateway.macAddress) == parentDeviceId) {
        parentDevice = topologyStructure.gateway;
        print('✅ 找到父設備: Gateway');
      }

      // 在 Extenders 中尋找
      if (parentDevice == null) {
        for (final extender in topologyStructure.extenders) {
          if (_generateDeviceId(extender.macAddress) == parentDeviceId) {
            parentDevice = extender;
            print('✅ 找到父設備: Extender ${extender.deviceName}');
            break;
          }
        }
      }

      if (parentDevice == null) {
        print('❌ 找不到設備 $parentDeviceId');
        return [];
      }

      // 3. 🎯 關鍵修正：只獲取直接連接的 Host 設備
      final hostDevices = _getDirectHostDevices(topologyStructure, parentDevice.macAddress);
      print('✅ 找到 ${hostDevices.length} 個直接連接的 Host 設備');

      // 4. 轉換為 ClientDevice 格式
      final clientDevices = <ClientDevice>[];

      for (final host in hostDevices) {
        final clientDevice = ClientDevice(
          name: host.deviceName.isNotEmpty ? host.deviceName : host.macAddress,
          deviceType: host.connectionInfo.description,
          mac: host.macAddress,
          ip: host.ipAddress,
          connectionTime: '2h/15m/30s', // 暫時使用假資料
          clientType: _inferClientType(host.deviceName, host.connectionInfo),
          rssi: host.rssiValues.join(','),
          status: host.rawData['linkstate']?.toString(),
          additionalInfo: {
            'deviceType': host.deviceType, // 保留原始設備類型
            'ssid': host.connectionInfo.ssid,
            'radio': host.connectionInfo.radio,
            'wirelessStandard': host.connectionInfo.wirelessStandard,
            'rxrate': host.rawData['rxrate'],
            'txrate': host.rawData['txrate'],
            'hops': host.hops.toString(),
          },
        );

        clientDevices.add(clientDevice);
        print('✅ 添加 Host 客戶端: ${host.getDisplayName()}');
      }

      print('✅ 成功獲取 ${clientDevices.length} 個 Host 客戶端設備');
      return clientDevices;

    } catch (e) {
      print('❌ 獲取客戶端設備時發生錯誤: $e');
      return [];
    }
  }

  /// 獲取 Gateway 名稱
  static Future<String> getGatewayName() async {
    try {
      final topologyStructure = await getTopologyStructure();
      if (topologyStructure != null) {
        return topologyStructure.gateway.deviceName.isNotEmpty
            ? topologyStructure.gateway.deviceName
            : 'Controller';
      }
      return 'Controller';
    } catch (e) {
      print('❌ 獲取 Gateway 名稱時發生錯誤: $e');
      return 'Controller';
    }
  }

  // ==================== 🎯 核心輔助方法 ====================

  /// 🎯 關鍵方法：獲取指定設備直接連接的 Host 設備（不包括 Extender）
  static List<DetailedDeviceInfo> _getDirectHostDevices(
      NetworkTopologyStructure topology,
      String parentMacAddress) {

    final directConnectedDevices = topology.getDirectConnectedDevices(parentMacAddress);

    // 🎯 只保留 Host 設備，過濾掉 Extender
    final hostDevices = directConnectedDevices
        .where((device) => device.deviceType == 'host')
        .toList();

    print('🔍 設備 $parentMacAddress 直接連接的 Host: ${hostDevices.length} 個');
    for (final host in hostDevices) {
      print('   - ${host.getDisplayName()} (${host.deviceType})');
    }

    return hostDevices;
  }

  // ==================== 其他輔助方法 ====================

  /// 生成設備顯示名稱
  static String _generateDisplayName(DetailedDeviceInfo device) {
    switch (device.deviceType) {
      case 'extender':
        return device.deviceName.isNotEmpty ? device.deviceName : 'Agent';
      case 'host':
        return device.deviceName.isNotEmpty
            ? device.deviceName
            : 'Device ${device.macAddress.substring(device.macAddress.length - 5)}';
      default:
        return device.deviceName.isNotEmpty ? device.deviceName : device.macAddress;
    }
  }

  /// 生成設備 ID
  static String _generateDeviceId(String macAddress) {
    return 'device-${macAddress.replaceAll(':', '').toLowerCase()}';
  }

  /// 推斷客戶端設備類型
  static ClientType _inferClientType(String deviceName, ConnectionInfo connectionInfo) {
    final String name = deviceName.toLowerCase();

    if (name.contains('tv') || name.contains('television')) {
      return ClientType.tv;
    } else if (name.contains('xbox') || name.contains('playstation') || name.contains('game')) {
      return ClientType.xbox;
    } else if (name.contains('iphone') || name.contains('phone') || name.contains('mobile') ||
        name.contains('oppo') || name.contains('samsung') || name.contains('huawei') ||
        name.contains('xiaomi')) {
      return ClientType.iphone;
    } else if (name.contains('laptop') || name.contains('computer') || name.contains('pc') ||
        name.contains('-nb') || name.contains('notebook') || name.contains('ppc')) {
      return ClientType.laptop;
    } else {
      // 根據連接類型推斷
      if (connectionInfo.isWired) {
        return ClientType.xbox; // 有線通常是遊戲機或電腦
      } else {
        return ClientType.laptop; // 無線通常是筆電或手機
      }
    }
  }

  /// 檢查是否有可用的真實數據
  static Future<bool> isRealDataAvailable() async {
    try {
      final meshResult = await WifiApiService.getMeshTopology();

      if (meshResult is Map && meshResult.containsKey('error')) {
        print('❌ Mesh API 返回錯誤: ${meshResult['error']}');
        return false;
      }

      if (meshResult is List && meshResult.isNotEmpty) {
        print('✅ 真實數據可用，節點數: ${meshResult.length}');
        return true;
      }

      print('⚠️ Mesh API 返回空數據');
      return false;

    } catch (e) {
      print('❌ 檢查真實數據可用性時發生錯誤: $e');
      return false;
    }
  }

  /// 輸出數據統計（調試用）
  static Future<void> printDataStatistics() async {
    try {
      final networkDevices = await getNetworkDevices();
      final deviceConnections = await getDeviceConnections();
      final listDevices = await getListViewDevices();
      final topologyStructure = await getTopologyStructure();

      print('\n=== 🎯 修正後的數據統計 ===');
      print('拓撲圖 Extender 數量: ${networkDevices.length}');
      print('List 視圖設備數量: ${listDevices.length}');
      print('DeviceConnection 數量: ${deviceConnections.length}');

      if (topologyStructure != null) {
        print('Gateway: ${topologyStructure.gateway.getDisplayName()}');
        print('Extender 數量: ${topologyStructure.extenders.length}');
        print('Host 數量: ${topologyStructure.hostDevices.length}');

        // 🎯 Host 分布統計
        final gatewayHosts = _getDirectHostDevices(topologyStructure, topologyStructure.gateway.macAddress);
        print('Gateway 直接 Host: ${gatewayHosts.length}');

        for (final extender in topologyStructure.extenders) {
          final extenderHosts = _getDirectHostDevices(topologyStructure, extender.macAddress);
          print('${extender.deviceName} 直接 Host: ${extenderHosts.length}');
        }
      }

      print('============================\n');

    } catch (e) {
      print('❌ 輸出數據統計時發生錯誤: $e');
    }
  }
}