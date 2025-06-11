// lib/shared/services/real_data_integration_service.dart - 修正版本

import 'package:whitebox/shared/api/wifi_api_service.dart';
import 'package:whitebox/shared/services/mesh_data_analyzer.dart';
import 'package:whitebox/shared/models/mesh_data_models.dart';
import 'package:whitebox/shared/ui/components/basic/NetworkTopologyComponent.dart';
import 'package:whitebox/shared/ui/pages/home/DeviceDetailPage.dart';
import 'package:whitebox/shared/ui/pages/home/Topo/network_topo_config.dart';

/// 真實數據整合服務 - 修正版本
/// 🎯 關鍵修正：統一資料來源，確保拓樸圖和列表使用相同的數據
class RealDataIntegrationService {
  static final MeshDataAnalyzer _analyzer = MeshDataAnalyzer();

  // 🎯 修正：使用可配置的快取時間
  static NetworkTopologyStructure? _cachedTopologyStructure;
  static DateTime? _lastFetchTime;

  /// 🎯 修正：使用配置檔案中的快取時間
  static Duration get _cacheExpiry => NetworkTopoConfig.actualCacheDuration;

  /// 檢查快取是否有效
  static bool _isCacheValid() {
    if (_lastFetchTime == null) return false;

    final timeSinceLastFetch = DateTime.now().difference(_lastFetchTime!);
    final isValid = timeSinceLastFetch < _cacheExpiry;

    // 🎯 新增：詳細的快取狀態日誌
    print('🕒 快取檢查: 上次更新 ${timeSinceLastFetch.inSeconds} 秒前, '
        '快取期限 ${_cacheExpiry.inSeconds} 秒, 是否有效: $isValid');

    return isValid;
  }

  /// 🎯 新增：強制重新載入（忽略快取）
  static Future<NetworkTopologyStructure?> forceReload() async {
    print('🔄 強制重新載入 Mesh 數據...');
    clearCache();
    return await getTopologyStructure();
  }

  /// 清除快取
  static void clearCache() {
    _cachedTopologyStructure = null;
    _lastFetchTime = null;
    print('🗑️ 已清除真實數據快取');
  }

  /// 🎯 修正：獲取網路拓樸結構（統一資料源）
  static Future<NetworkTopologyStructure?> getTopologyStructure() async {
    try {
      // 檢查快取
      if (_isCacheValid() && _cachedTopologyStructure != null) {
        final secondsSinceUpdate = DateTime.now().difference(_lastFetchTime!).inSeconds;
        print('📋 使用快取的 TopologyStructure 資料 (${secondsSinceUpdate}s 前更新)');
        return _cachedTopologyStructure;
      }

      print('🌐 快取已過期或不存在，開始從 Mesh API 獲取拓樸結構...');
      print('⚙️  當前快取設定: ${_cacheExpiry.inSeconds} 秒');

      // 記錄 API 呼叫時間
      final apiStartTime = DateTime.now();

      // 1. 獲取原始 Mesh 數據
      final meshResult = await WifiApiService.getMeshTopology();

      // 2. 使用分析器解析詳細設備資訊
      final detailedDevices = _analyzer.analyzeDetailedDeviceInfo(meshResult);

      // 3. 建立拓樸結構
      final topologyStructure = _analyzer.analyzeTopologyStructure(detailedDevices);

      // 🎯 更新快取和時間戳記
      _cachedTopologyStructure = topologyStructure;
      _lastFetchTime = DateTime.now();

      final apiDuration = DateTime.now().difference(apiStartTime);
      print('✅ Mesh API 呼叫完成，耗時: ${apiDuration.inMilliseconds}ms');
      print('📅 下次更新時間: ${DateTime.now().add(_cacheExpiry).toString().substring(11, 19)}');

      if (topologyStructure != null) {
        print('✅ 成功更新網路拓樸結構');
        print('   Gateway: ${topologyStructure.gateway.macAddress}');
        print('   Extenders: ${topologyStructure.extenders.length}');
        print('   Hosts: ${topologyStructure.hostDevices.length}');
      }

      return topologyStructure;

    } catch (e) {
      print('❌ 獲取 TopologyStructure 時發生錯誤: $e');
      return null;
    }
  }

  /// 🎯 修正：拓樸圖設備列表（只返回 Extender，但包含正確的連接數）
  static Future<List<NetworkDevice>> getNetworkDevices() async {
    try {
      print('🌐 獲取拓樸圖設備資料（只包含 Extender）...');

      // 1. 獲取統一的拓樸結構
      final topologyStructure = await getTopologyStructure();
      if (topologyStructure == null) {
        print('❌ 無法獲取拓樸結構');
        return [];
      }

      // 2. 🎯 只轉換 Extender 為 NetworkDevice，但包含正確的 Host 數量
      final networkDevices = <NetworkDevice>[];

      for (final extender in topologyStructure.extenders) {
        // 🎯 計算直接連接的 Host 數量
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
            'clientCount': directHosts.length.toString(), // 🎯 正確的 Host 數量
            'clients': directHosts.length.toString(), // 🎯 統一欄位名稱
            'connectionDescription': extender.connectionInfo.description,
            'linkstate': extender.rawData['linkstate'] ?? '',
            'wirelessStandard': extender.connectionInfo.wirelessStandard,
            'rxrate': extender.rawData['rxrate'] ?? '',
            'txrate': extender.rawData['txrate'] ?? '',
          },
        );

        networkDevices.add(networkDevice);
        print('✅ 添加拓樸圖 Extender: ${extender.deviceName}, Host 數量: ${directHosts.length}');
      }

      print('✅ 拓樸圖設備數量: ${networkDevices.length} 個 Extender');
      return networkDevices;

    } catch (e) {
      print('❌ 獲取拓樸圖 NetworkDevice 時發生錯誤: $e');
      return [];
    }
  }

  /// 🎯 修正：設備連接數據（包含 Gateway 和所有 Extender 的正確 Host 數量）
  static Future<List<DeviceConnection>> getDeviceConnections() async {
    try {
      print('🌐 獲取設備連接資料（包含 Gateway 和 Extender 的 Host 數量）...');

      // 1. 獲取統一的拓樸結構
      final topologyStructure = await getTopologyStructure();
      if (topologyStructure == null) {
        print('❌ 無法獲取拓樸結構');
        return [];
      }

      final deviceConnections = <DeviceConnection>[];

      // 2. 🎯 Gateway 的連接數 = 直接連接的 Host 數量
      final gatewayHosts = _getDirectHostDevices(topologyStructure, topologyStructure.gateway.macAddress);
      final gatewayConnection = DeviceConnection(
        deviceId: _generateDeviceId(topologyStructure.gateway.macAddress),
        connectedDevicesCount: gatewayHosts.length,
      );
      deviceConnections.add(gatewayConnection);
      print('✅ Gateway (${topologyStructure.gateway.macAddress}) Host 連接數: ${gatewayHosts.length}');

      // 3. 🎯 每個 Extender 的連接數 = 直接連接的 Host 數量
      for (final extender in topologyStructure.extenders) {
        final extenderHosts = _getDirectHostDevices(topologyStructure, extender.macAddress);
        final extenderConnection = DeviceConnection(
          deviceId: _generateDeviceId(extender.macAddress),
          connectedDevicesCount: extenderHosts.length,
        );
        deviceConnections.add(extenderConnection);
        print('✅ Extender ${extender.deviceName} (${extender.macAddress}) Host 連接數: ${extenderHosts.length}');
      }

      print('✅ 成功獲取 ${deviceConnections.length} 個 DeviceConnection');
      return deviceConnections;

    } catch (e) {
      print('❌ 獲取 DeviceConnection 時發生錯誤: $e');
      return [];
    }
  }

  /// 🎯 修正：List 視圖設備列表（Gateway + 所有 Extender，使用統一資料源）
  static Future<List<NetworkDevice>> getListViewDevices() async {
    try {
      print('🌐 獲取 List 視圖設備資料（Gateway + Extender）...');

      // 1. 獲取統一的拓樸結構
      final topologyStructure = await getTopologyStructure();
      if (topologyStructure == null) {
        print('❌ 無法獲取拓樸結構');
        return [];
      }

      final listDevices = <NetworkDevice>[];

      // 2. 🎯 添加 Gateway - 使用真實 MAC 地址和正確的 Host 數量
      final gatewayHosts = _getDirectHostDevices(topologyStructure, topologyStructure.gateway.macAddress);
      final gatewayDevice = NetworkDevice(
        name: 'Controller',
        id: _generateDeviceId(topologyStructure.gateway.macAddress),
        mac: topologyStructure.gateway.macAddress, // 🎯 使用真實 MAC
        ip: topologyStructure.gateway.ipAddress,
        connectionType: ConnectionType.wired,
        additionalInfo: {
          'type': 'gateway',
          'status': 'online',
          'clients': gatewayHosts.length.toString(), // 🎯 正確的 Host 數量
          'rssi': '',
        },
      );
      listDevices.add(gatewayDevice);
      print('✅ 添加 List Gateway: ${topologyStructure.gateway.macAddress}, Host 數量 ${gatewayHosts.length}');

      // 3. 🎯 添加所有 Extender - 使用真實資料和正確的 Host 數量
      for (final extender in topologyStructure.extenders) {
        final extenderHosts = _getDirectHostDevices(topologyStructure, extender.macAddress);
        final extenderDevice = NetworkDevice(
          name: _generateDisplayName(extender),
          id: _generateDeviceId(extender.macAddress),
          mac: extender.macAddress, // 🎯 使用真實 MAC
          ip: extender.ipAddress,
          connectionType: extender.connectionInfo.isWired
              ? ConnectionType.wired
              : ConnectionType.wireless,
          additionalInfo: {
            'type': 'extender',
            'status': 'online',
            'clients': extenderHosts.length.toString(), // 🎯 正確的 Host 數量
            'rssi': extender.rssiValues.join(','),
          },
        );
        listDevices.add(extenderDevice);
        print('✅ 添加 List Extender: ${extender.deviceName} (${extender.macAddress}), Host 數量 ${extenderHosts.length}');
      }

      print('✅ List 視圖總設備數: ${listDevices.length} 個（1 Gateway + ${topologyStructure.extenders.length} Extender）');
      return listDevices;

    } catch (e) {
      print('❌ 獲取 List 視圖設備時發生錯誤: $e');
      return [];
    }
  }

  /// 🎯 修正：獲取客戶端設備列表（使用統一資料源）
  static Future<List<ClientDevice>> getClientDevicesForParent(String parentDeviceId) async {
    try {
      print('🌐 獲取設備 $parentDeviceId 的客戶端列表...');

      // 1. 獲取統一的拓樸結構
      final topologyStructure = await getTopologyStructure();
      if (topologyStructure == null) {
        print('❌ 無法獲取拓樸結構');
        return [];
      }

      // 2. 找到對應的父設備（Gateway 或 Extender）
      DetailedDeviceInfo? parentDevice;

      // 在 Gateway 中尋找
      if (_generateDeviceId(topologyStructure.gateway.macAddress) == parentDeviceId) {
        parentDevice = topologyStructure.gateway;
        print('✅ 找到父設備: Gateway (${topologyStructure.gateway.macAddress})');
      }

      // 在 Extenders 中尋找
      if (parentDevice == null) {
        for (final extender in topologyStructure.extenders) {
          if (_generateDeviceId(extender.macAddress) == parentDeviceId) {
            parentDevice = extender;
            print('✅ 找到父設備: Extender ${extender.deviceName} (${extender.macAddress})');
            break;
          }
        }
      }

      if (parentDevice == null) {
        print('❌ 找不到設備 $parentDeviceId');
        return [];
      }

      // 3. 🎯 只獲取直接連接的 Host 設備
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
            'deviceType': host.deviceType,
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

  /// 🎯 修正：獲取 Gateway 名稱（使用真實資料）
  static Future<String> getGatewayName() async {
    try {
      final topologyStructure = await getTopologyStructure();
      if (topologyStructure != null) {
        // 如果有設備名稱就使用，否則使用 "Controller"
        final gatewayName = topologyStructure.gateway.deviceName.isNotEmpty
            ? topologyStructure.gateway.deviceName
            : 'Controller';
        print('✅ Gateway 名稱: $gatewayName');
        return gatewayName;
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

  /// 🎯 新增：輸出完整的資料統計（調試用）
  static Future<void> printCompleteDataStatistics() async {
    try {
      print('\n=== 🎯 完整資料統計報告 ===');

      final topologyStructure = await getTopologyStructure();
      if (topologyStructure == null) {
        print('❌ 無法獲取拓樸結構');
        return;
      }

      print('📊 拓樸結構概覽:');
      print('   Gateway: ${topologyStructure.gateway.getDisplayName()} (${topologyStructure.gateway.macAddress})');
      print('   Extender 數量: ${topologyStructure.extenders.length}');
      print('   Host 數量: ${topologyStructure.hostDevices.length}');

      // 分別獲取不同用途的資料
      final topologyDevices = await getNetworkDevices();
      final listDevices = await getListViewDevices();
      final deviceConnections = await getDeviceConnections();

      print('\n📊 拓樸圖資料 (Extender):');
      print('   設備數量: ${topologyDevices.length}');
      for (var device in topologyDevices) {
        print('   - ${device.name} (${device.mac}) → Host: ${device.additionalInfo['clients']}');
      }

      print('\n📊 List 視圖資料 (Gateway + Extender):');
      print('   設備數量: ${listDevices.length}');
      for (var device in listDevices) {
        print('   - ${device.name} (${device.mac}) → Host: ${device.additionalInfo['clients']}');
      }

      print('\n📊 設備連接資料 (小圓圈數字):');
      print('   連接數量: ${deviceConnections.length}');
      for (var conn in deviceConnections) {
        print('   - ${conn.deviceId} → ${conn.connectedDevicesCount} 個 Host');
      }

      print('\n🔍 Host 分布驗證:');
      final gatewayHosts = _getDirectHostDevices(topologyStructure, topologyStructure.gateway.macAddress);
      print('   Gateway 直接 Host: ${gatewayHosts.length} 個');
      for (final host in gatewayHosts) {
        print('     - ${host.getDisplayName()} (${host.macAddress})');
      }

      for (final extender in topologyStructure.extenders) {
        final extenderHosts = _getDirectHostDevices(topologyStructure, extender.macAddress);
        print('   Extender ${extender.deviceName} 直接 Host: ${extenderHosts.length} 個');
        for (final host in extenderHosts) {
          print('     - ${host.getDisplayName()} (${host.macAddress})');
        }
      }

      print('=== 完整資料統計結束 ===\n');

    } catch (e) {
      print('❌ 輸出完整資料統計時發生錯誤: $e');
    }
  }
}