// lib/shared/ui/pages/home/Topo/real_data_service.dart

import 'package:whitebox/shared/api/wifi_api_service.dart';
import 'package:whitebox/shared/services/mesh_data_analyzer.dart';
import 'package:whitebox/shared/models/mesh_data_models.dart';
import 'package:whitebox/shared/ui/components/basic/NetworkTopologyComponent.dart';
// 🎯 修正：統一使用 home 目錄下的 DeviceDetailPage
import 'package:whitebox/shared/ui/pages/home/DeviceDetailPage.dart';

/// 真實資料服務類 - 負責從 Mesh API 獲取並轉換資料
class RealDataService {
  // 快取機制，避免重複呼叫 API
  static List<NetworkDevice>? _cachedDevices;
  static List<DeviceConnection>? _cachedConnections;
  static DateTime? _lastFetchTime;
  static const Duration _cacheExpiry = Duration(seconds: 10);

  /// 檢查快取是否有效
  static bool _isCacheValid() {
    if (_lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheExpiry;
  }

  /// 清除快取
  static void clearCache() {
    _cachedDevices = null;
    _cachedConnections = null;
    _lastFetchTime = null;
    print('🗑️ 已清除快取');
  }

  /// 從 Mesh API 載入設備資料
  static Future<List<NetworkDevice>> loadDevicesFromMeshAPI() async {
    try {
      // 檢查快取
      if (_isCacheValid() && _cachedDevices != null) {
        print('📋 使用快取的設備資料 (${_cachedDevices!.length} 個設備)');
        return _cachedDevices!;
      }

      print('🌐 開始從 Mesh API 載入真實設備資料...');

      // 呼叫 Mesh Topology API
      final meshResult = await WifiApiService.getMeshTopology();

      if (meshResult is! List) {
        print('❌ Mesh API 回傳的資料格式不正確: ${meshResult.runtimeType}');
        if (meshResult is Map && meshResult.containsKey('error')) {
          print('API 錯誤: ${meshResult['error']}');
        }
        return [];
      }

      final List<dynamic> meshData = meshResult;
      final List<NetworkDevice> devices = [];

      print('📊 原始節點數量: ${meshData.length}');

      // 處理每個節點
      for (int i = 0; i < meshData.length; i++) {
        final nodeData = meshData[i];
        if (nodeData is! Map<String, dynamic>) {
          print('⚠️ 節點 $i 資料格式錯誤，跳過');
          continue;
        }

        final String type = nodeData['type'] ?? '';
        final String macAddr = nodeData['macAddr'] ?? '';
        final String devName = nodeData['devName'] ?? '';

        print('🔍 處理節點 $i: type="$type", mac="$macAddr", name="$devName"');

        // 處理主節點 (Gateway 或 Extender)
        if (type == 'gateway' || type == 'extender') {
          // 排除 RSSI 全部為 0 的 extender
          if (type == 'extender') {
            final rssiData = nodeData['rssi'];
            if (_isAllRSSIZero(rssiData)) {
              print('⚠️ 排除 RSSI 全為 0 的 extender: $macAddr');
              continue;
            }
          }

          final mainDevice = _convertToNetworkDevice(nodeData);
          if (mainDevice != null) {
            devices.add(mainDevice);
            print('✅ 添加主節點: ${mainDevice.name} (type: $type)');
          }
        }

        // 處理連接的設備
        final connectedDevices = nodeData['connectedDevices'];
        if (connectedDevices is List) {
          print('👥 處理 ${connectedDevices.length} 個連接設備');

          for (int j = 0; j < connectedDevices.length; j++) {
            final clientData = connectedDevices[j];
            if (clientData is! Map<String, dynamic>) {
              print('⚠️ 連接設備 $j 資料格式錯誤，跳過');
              continue;
            }

            final String clientType = clientData['type'] ?? '';
            final String clientSSID = clientData['ssid'] ?? '';
            final String clientIP = clientData['ipAddress'] ?? '';
            final String clientMac = clientData['macAddr'] ?? '';
            final String clientDevName = clientData['devName'] ?? '';

            print('🔍 處理客戶端 $j: type="$clientType", name="$clientDevName", ssid="$clientSSID", ip="$clientIP"');

            // 根據 API 文件的過濾規則
            if (clientType == 'host') {
              // 排除包含 "bh-" 的 host
              if (clientSSID.contains('bh-')) {
                print('⚠️ 排除 backhaul host: $clientMac (ssid: $clientSSID)');
                continue;
              }

              // 排除沒有 IP 的 host
              if (clientIP.isEmpty || clientIP == '0.0.0.0') {
                print('⚠️ 排除無 IP 的 host: $clientMac');
                continue;
              }
            }

            final clientDevice = _convertToNetworkDevice(clientData, isClient: true);
            if (clientDevice != null) {
              devices.add(clientDevice);
              print('✅ 添加客戶端設備: ${clientDevice.name} (type: $clientType)');
            }
          }
        }
      }

      // 更新快取
      _cachedDevices = devices;
      _lastFetchTime = DateTime.now();

      print('✅ 成功載入 ${devices.length} 個過濾後的設備');
      _printDeviceSummary(devices);
      return devices;

    } catch (e) {
      print('❌ 載入 Mesh API 資料時發生錯誤: $e');
      return [];
    }
  }

  /// 載入設備連接資料
  static Future<List<DeviceConnection>> loadConnectionsFromMeshAPI() async {
    try {
      // 檢查快取
      if (_isCacheValid() && _cachedConnections != null) {
        print('📋 使用快取的連接資料 (${_cachedConnections!.length} 個連接)');
        return _cachedConnections!;
      }

      print('🌐 開始從 Mesh API 載入連接資料...');

      final meshResult = await WifiApiService.getMeshTopology();

      if (meshResult is! List) {
        print('❌ Mesh API 回傳的連接資料格式不正確');
        return [];
      }

      final List<dynamic> meshData = meshResult;
      final List<DeviceConnection> connections = [];

      // 分析每個節點的連接數
      for (int i = 0; i < meshData.length; i++) {
        final nodeData = meshData[i];
        if (nodeData is! Map<String, dynamic>) continue;

        final String macAddr = nodeData['macAddr'] ?? '';
        final String type = nodeData['type'] ?? '';
        final connectedDevices = nodeData['connectedDevices'];

        // 只處理 gateway 和 extender
        if ((type == 'gateway' || type == 'extender') && macAddr.isNotEmpty) {
          int validConnectedCount = 0;

          if (connectedDevices is List) {
            for (final clientData in connectedDevices) {
              if (clientData is! Map<String, dynamic>) continue;

              final String clientType = clientData['type'] ?? '';
              final String clientSSID = clientData['ssid'] ?? '';
              final String clientIP = clientData['ipAddress'] ?? '';

              // 應用過濾規則
              if (clientType == 'host') {
                if (clientSSID.contains('bh-')) continue;
                if (clientIP.isEmpty || clientIP == '0.0.0.0') continue;
              }

              validConnectedCount++;
            }
          }

          connections.add(DeviceConnection(
            deviceId: _generateDeviceId(macAddr),
            connectedDevicesCount: validConnectedCount,
          ));

          print('🔗 連接資料: $type ($macAddr) -> $validConnectedCount 個有效設備');
        }
      }

      // 更新快取
      _cachedConnections = connections;
      _lastFetchTime = DateTime.now();

      print('✅ 成功載入 ${connections.length} 個連接資料');
      return connections;

    } catch (e) {
      print('❌ 載入連接資料時發生錯誤: $e');
      return [];
    }
  }

  /// 獲取客戶端設備清單（用於設備詳情頁面）
  static Future<List<ClientDevice>> loadClientDevicesFromMeshAPI(String parentDeviceId) async {
    try {
      print('🌐 載入設備 $parentDeviceId 的客戶端資料...');

      final meshResult = await WifiApiService.getMeshTopology();

      if (meshResult is! List) {
        print('❌ Mesh API 回傳格式錯誤');
        return [];
      }

      final List<dynamic> meshData = meshResult;
      final List<ClientDevice> clientDevices = [];

      // 尋找對應的節點
      for (final nodeData in meshData) {
        if (nodeData is! Map<String, dynamic>) continue;

        final String macAddr = nodeData['macAddr'] ?? '';
        final String deviceId = _generateDeviceId(macAddr);

        if (deviceId == parentDeviceId) {
          final connectedDevices = nodeData['connectedDevices'];

          if (connectedDevices is List) {
            for (final clientData in connectedDevices) {
              if (clientData is! Map<String, dynamic>) continue;

              final String clientType = clientData['type'] ?? '';
              final String clientSSID = clientData['ssid'] ?? '';
              final String clientIP = clientData['ipAddress'] ?? '';

              // 應用過濾規則
              if (clientType == 'host') {
                if (clientSSID.contains('bh-')) continue;
                if (clientIP.isEmpty || clientIP == '0.0.0.0') continue;
              }

              final clientDevice = _convertToClientDevice(clientData);
              if (clientDevice != null) {
                clientDevices.add(clientDevice);
              }
            }
          }
          break;
        }
      }

      print('✅ 成功載入 ${clientDevices.length} 個客戶端設備');
      return clientDevices;

    } catch (e) {
      print('❌ 載入客戶端設備時發生錯誤: $e');
      return [];
    }
  }

  /// 檢查 RSSI 是否全為 0
  static bool _isAllRSSIZero(dynamic rssiData) {
    if (rssiData == null) return true;

    String rssiString = rssiData.toString();
    if (rssiString.isEmpty) return true;

    // 分割 RSSI 字串（可能是 "0,-21,-25" 格式）
    List<String> rssiValues = rssiString.split(',');

    // 檢查是否所有值都是 0
    for (String value in rssiValues) {
      final trimmedValue = value.trim();
      if (trimmedValue.isNotEmpty && trimmedValue != '0') {
        return false;
      }
    }

    return true;
  }

  /// 將 API 資料轉換為 NetworkDevice
  static NetworkDevice? _convertToNetworkDevice(Map<String, dynamic> data, {bool isClient = false}) {
    try {
      final String macAddr = data['macAddr'] ?? '';
      final String hostMacAddr = data['hostMacAddr'] ?? macAddr;
      final String deviceName = data['devName'] ?? '';
      final String type = data['type'] ?? 'unknown';
      final String ipAddress = data['ipAddress'] ?? '';
      final String connectionType = data['connectionType'] ?? '';
      final String name = data['name'] ?? macAddr;

      if (macAddr.isEmpty) {
        print('❌ macAddr 為空，跳過此設備');
        return null;
      }

      // 判斷連接類型
      ConnectionType connType = ConnectionType.wireless;
      final String connTypeStr = connectionType.toLowerCase();

      if (connTypeStr == 'ethernet') {
        connType = ConnectionType.wired;
      } else if (connTypeStr.contains('ghz') || connTypeStr == 'wireless') {
        connType = ConnectionType.wireless;
      }

      // 生成顯示名稱
      String displayName = _generateDisplayName(type, deviceName, macAddr);

      return NetworkDevice(
        name: displayName,
        id: _generateDeviceId(macAddr),
        mac: macAddr,
        ip: ipAddress,
        connectionType: connType,
        additionalInfo: {
          // API 文件對應欄位
          'type': type,
          'devName': deviceName,
          'hostMacAddr': hostMacAddr,
          'name': name,
          'status': data['status'] ?? '',
          'rssi': data['rssi']?.toString() ?? '',
          'linkstate': data['linkstate'] ?? '',
          'hops': data['hops']?.toString() ?? '0',
          'parentAccessPoint': data['parentAccessPoint'] ?? '',
          'ssid': data['ssid'] ?? '',
          'wirelessStandard': data['wirelessStandard'] ?? '',
          'radio': data['radio'] ?? '',
          'rxrate': data['rxrate'] ?? '',
          'txrate': data['txrate'] ?? '',
          'ip6Address': data['ip6Address'] ?? '',
          'connectionType': connectionType,

          // 進階欄位
          'isClient': isClient,
          'isGateway': type == 'gateway',
          'isExtender': type == 'extender',
          'supportMlo': data['supportMlo'] ?? 'No',
          'isMldRoot': data['isMldRoot']?.toString() ?? '-1',
          'MapBSSType': data['MapBSSType'] ?? '',
          'MldVapList': data['MldVapList'] ?? {},
          'isAgentBsta': data['isAgentBsta'] ?? false,
          'isAgentEth': data['isAgentEth'] ?? false,
          'hostNumber': data['hostNumber']?.toString() ?? '0',
          'extenderNumber': data['extenderNumber']?.toString() ?? '0',
          'num_of_extenders': data['num_of_extenders']?.toString() ?? '0',
          'serial_number': data['serial_number'] ?? '',
        },
      );
    } catch (e) {
      print('❌ 轉換 NetworkDevice 時發生錯誤: $e');
      return null;
    }
  }

  /// 生成顯示名稱
  static String _generateDisplayName(String type, String deviceName, String macAddr) {
    switch (type.toLowerCase()) {
      case 'gateway':
        return 'Controller';
      case 'extender':
        return deviceName.isNotEmpty ? deviceName : 'Agent';
      case 'host':
        return deviceName.isNotEmpty ? deviceName : 'Client ${macAddr.substring(macAddr.length - 5)}';
      default:
        return deviceName.isNotEmpty ? deviceName : 'Device ${macAddr.substring(macAddr.length - 5)}';
    }
  }

  /// 將 API 資料轉換為 ClientDevice
  static ClientDevice? _convertToClientDevice(Map<String, dynamic> data) {
    try {
      final String macAddr = data['macAddr'] ?? '';
      final String deviceName = data['devName'] ?? '';
      final String ipAddress = data['ipAddress'] ?? '';
      final String connectionType = data['connectionType'] ?? '';
      final dynamic rssiData = data['rssi'];

      if (macAddr.isEmpty) return null;

      // 連接時間暫時用假資料
      String connectionTime = '2h/15m/30s';

      // 判斷設備類型
      ClientType clientType = _inferClientType(deviceName, connectionType);

      // 處理 RSSI 資料
      String rssiString = '';
      if (rssiData != null) {
        if (rssiData is int) {
          rssiString = rssiData.toString();
        } else if (rssiData is String) {
          rssiString = rssiData;
        }
      }

      return ClientDevice(
        name: deviceName.isNotEmpty ? deviceName : macAddr,
        deviceType: connectionType.isNotEmpty ? connectionType : 'Unknown',
        mac: macAddr,
        ip: ipAddress,
        connectionTime: connectionTime,
        clientType: clientType,
        rssi: rssiString,
        status: data['status']?.toString(),
        lastSeen: null,
        additionalInfo: {
          'wirelessStandard': data['wirelessStandard'],
          'radio': data['radio'],
          'rxrate': data['rxrate'],
          'txrate': data['txrate'],
          'ssid': data['ssid'],
          'hops': data['hops'],
          'parentAccessPoint': data['parentAccessPoint'],
          'linkstate': data['linkstate'],
          'supportMlo': data['supportMlo'],
        },
      );
    } catch (e) {
      print('轉換 ClientDevice 時發生錯誤: $e');
      return null;
    }
  }

  /// 生成設備 ID
  static String _generateDeviceId(String macAddr) {
    return 'device-${macAddr.replaceAll(':', '').toLowerCase()}';
  }

  /// 推斷客戶端設備類型
  static ClientType _inferClientType(String deviceName, String connectionType) {
    final String name = deviceName.toLowerCase();

    if (name.contains('tv') || name.contains('television')) {
      return ClientType.tv;
    } else if (name.contains('xbox') || name.contains('playstation') || name.contains('game')) {
      return ClientType.xbox;
    } else if (name.contains('iphone') || name.contains('phone') || name.contains('mobile') ||
        name.contains('oppo') || name.contains('samsung') || name.contains('Pixel') || name.contains('huawei') ||
        name.contains('xiaomi')) {
      return ClientType.iphone;
    } else if (name.contains('laptop') || name.contains('computer') || name.contains('DESK') || name.contains('pc') ||
        name.contains('-nb') || name.contains('notebook')) {
      return ClientType.laptop;
    } else {
      if (connectionType.toLowerCase().contains('ethernet')) {
        return ClientType.xbox;
      } else {
        return ClientType.unknown;
      }
    }
  }

  /// 輸出設備摘要資訊
  static void _printDeviceSummary(List<NetworkDevice> devices) {
    print('\n=== 設備載入摘要 ===');

    int gatewayCount = 0;
    int extenderCount = 0;
    int clientCount = 0;

    for (final device in devices) {
      final type = device.additionalInfo['type'] ?? '';
      switch (type) {
        case 'gateway':
          gatewayCount++;
          break;
        case 'extender':
          extenderCount++;
          break;
        case 'host':
          clientCount++;
          break;
      }
    }

    print('📊 Gateway: $gatewayCount 個');
    print('📊 Extender: $extenderCount 個');
    print('📊 Client: $clientCount 個');
    print('📊 總計: ${devices.length} 個設備');
    print('===================\n');
  }

  /// 根據 RSSI 值獲取連線品質顏色
  static String getRSSIQualityColor(String rssiString) {
    if (rssiString.isEmpty) return 'gray';

    try {
      final List<String> rssiValues = rssiString.split(',');
      final int rssi = int.parse(rssiValues[0].trim());

      if (rssi >= -65) {
        return 'green';
      } else if (rssi >= -75) {
        return 'orange';
      } else {
        return 'red';
      }
    } catch (e) {
      print('解析 RSSI 值時出錯: $e');
      return 'gray';
    }
  }
}