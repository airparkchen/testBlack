// lib/shared/services/unified_mesh_data_manager.dart
// 🎯 統一 Mesh 數據管理器 - 一次調用，多種分析

import 'dart:async';

import 'package:whitebox/shared/api/wifi_api_service.dart';
import 'package:whitebox/shared/services/mesh_data_analyzer.dart';
import 'package:whitebox/shared/models/mesh_data_models.dart';
import 'package:whitebox/shared/ui/components/basic/NetworkTopologyComponent.dart';
import 'package:whitebox/shared/ui/pages/home/DeviceDetailPage.dart';
import 'package:whitebox/shared/ui/pages/home/Topo/network_topo_config.dart';
import 'package:whitebox/shared/utils/api_logger.dart';
import 'package:whitebox/shared/utils/jwt_auto_relogin.dart';

/// 統一 Mesh 數據管理器
/// 🎯 解決問題：
/// 1. 一次 API 調用，多種數據分析
/// 2. 統一快取機制，保持數據同步
/// 3. 避免重複 API 調用
class UnifiedMeshDataManager {
  static UnifiedMeshDataManager? _instance;
  static UnifiedMeshDataManager get instance => _instance ??= UnifiedMeshDataManager._();

  UnifiedMeshDataManager._();

  // ==================== 核心數據存儲 ====================

  /// 原始 Mesh API 數據（唯一真實來源）
  dynamic _rawMeshData;

  /// 分析後的拓樸結構（快取分析結果）
  NetworkTopologyStructure? _topologyStructure;

  /// 各種預處理的設備列表（快取分析結果）
  List<NetworkDevice>? _topologyDevices;     // 拓樸圖用（只有 Extender）
  List<NetworkDevice>? _listViewDevices;     // 列表用（Gateway + Extender）
  List<DeviceConnection>? _deviceConnections; // 連接關係
  NetworkDevice? _gatewayDevice;              // Gateway 設備

  /// 客戶端設備快取（按父設備 MAC 分組）
  final Map<String, List<ClientDevice>> _clientDevicesCache = {};

  // ==================== 快取控制 ====================

  DateTime? _lastFetchTime;
  DateTime? _lastSuccessTime;  // 🎯 新增：記錄最後成功時間

  /// 🎯 使用統一的快取時間
  Duration get _cacheExpiry => NetworkTopoConfig.actualCacheDuration;

  /// 檢查快取是否有效
  bool _isCacheValid() {
    if (_lastFetchTime == null || _rawMeshData == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheExpiry;
  }

  // ==================== 🎯 核心方法：統一數據獲取 ====================

  /// 🎯 統一獲取 Mesh 數據（所有其他方法的唯一入口）
  Future<bool> _ensureMeshDataLoaded({bool forceRefresh = false}) async {
    try {
      final meshResult = await JwtAutoRelogin.instance.wrapApiCallWithFallback(
            () => ApiLogger.wrapApiCall(
          method: 'GET',
          endpoint: '/api/v1/system/mesh_topology',
          caller: 'UnifiedMeshDataManager._ensureMeshDataLoaded',
          apiCall: () => WifiApiService.getMeshTopology(),
        ),
            () => _rawMeshData, // 🎯 失敗時返回快取數據
        debugInfo: 'Mesh API (Unified)',
      );

      // 🎯 檢查 API 回應是否有錯誤
      if (_isMeshApiErrorResponse(meshResult)) {
        print('⚠️ Mesh API 返回錯誤，保持現有數據不變');
        return _rawMeshData != null; // 如果有舊數據就返回 true
      }

      // 🎯 成功獲取新數據，更新所有快取
      _rawMeshData = meshResult;
      _lastFetchTime = DateTime.now();
      _lastSuccessTime = _lastFetchTime;

      // 🎯 清除分析結果快取，強制重新分析
      _clearAnalyzedDataCache();

      print('✅ Mesh 數據更新成功，已清除分析快取');
      return true;

    } catch (e) {
      print('❌ 載入 Mesh 數據失敗: $e');

      // 🎯 保持現有數據不變
      return _rawMeshData != null;
    }
  }

  /// 🎯 清除分析結果快取（但保留原始數據）
  void _clearAnalyzedDataCache() {
    _topologyStructure = null;
    _topologyDevices = null;
    _listViewDevices = null;
    _deviceConnections = null;
    _gatewayDevice = null;
    _clientDevicesCache.clear();
    print('🗑️ 已清除分析結果快取');
  }

  /// 🎯 檢查 Mesh API 是否返回錯誤
  bool _isMeshApiErrorResponse(dynamic response) {
    if (response is Map<String, dynamic>) {
      if (response.containsKey('error')) return true;

      if (response.containsKey('response_body')) {
        final responseBody = response['response_body'].toString().toLowerCase();
        if (responseBody.contains('error') ||
            responseBody.contains('busy') ||
            responseBody.contains('failed')) {
          return true;
        }
      }
    } else if (response is List) {
      if (response.isEmpty) return true;
    }
    return false;
  }

  // ==================== 🎯 統一分析方法 ====================

  /// 🎯 確保拓樸結構已分析
  Future<NetworkTopologyStructure?> _ensureTopologyAnalyzed() async {
    if (_topologyStructure != null) {
      return _topologyStructure;
    }

    if (_rawMeshData == null) {
      print('❌ 無原始數據，無法分析拓樸結構');
      return null;
    }

    try {
      print('🔄 開始分析拓樸結構...');
      final analyzer = MeshDataAnalyzer();

      // 分析設備資訊
      final detailedDevices = analyzer.analyzeDetailedDeviceInfo(_rawMeshData);

      // 建立拓樸結構
      _topologyStructure = analyzer.analyzeTopologyStructure(detailedDevices);

      if (_topologyStructure != null) {
        print('✅ 拓樸結構分析完成');
        print('   Gateway: ${_topologyStructure!.gateway.macAddress}');
        print('   Extenders: ${_topologyStructure!.extenders.length}');
        print('   Hosts: ${_topologyStructure!.hostDevices.length}');
      }

      return _topologyStructure;
    } catch (e) {
      print('❌ 分析拓樸結構失敗: $e');
      return null;
    }
  }

  // ==================== 🎯 統一對外接口（替代 RealDataIntegrationService） ====================

  /// 獲取拓樸圖設備（只有 Extender）
  Future<List<NetworkDevice>> getNetworkDevices({bool forceRefresh = false}) async {
    print('🎯 [統一管理器] 獲取拓樸圖設備...');

    // 🎯 確保數據已載入
    if (!await _ensureMeshDataLoaded(forceRefresh: forceRefresh)) {
      return [];
    }

    // 🎯 檢查快取
    if (!forceRefresh && _topologyDevices != null) {
      print('📋 使用快取的拓樸圖設備 (${_topologyDevices!.length} 個)');
      return _topologyDevices!;
    }

    // 🎯 確保拓樸結構已分析
    final topology = await _ensureTopologyAnalyzed();
    if (topology == null) {
      return [];
    }

    // 🎯 生成拓樸圖設備列表
    final devices = <NetworkDevice>[];

    for (final extender in topology.extenders) {
      final directHosts = _getDirectHostDevices(topology, extender.macAddress);

      final device = NetworkDevice(
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
          'clientCount': directHosts.length.toString(),
          'clients': directHosts.length.toString(),
          'connectionDescription': extender.connectionInfo.description,
          'linkstate': extender.rawData['linkstate'] ?? '',
          'wirelessStandard': extender.connectionInfo.wirelessStandard,
          'rxrate': extender.rawData['rxrate'] ?? '',
          'txrate': extender.rawData['txrate'] ?? '',
        },
      );

      devices.add(device);
    }

    // 🎯 快取結果
    _topologyDevices = devices;
    print('✅ 拓樸圖設備生成完成 (${devices.length} 個 Extender)');

    return devices;
  }

  /// 獲取列表視圖設備（Gateway + Extender）
  Future<List<NetworkDevice>> getListViewDevices({bool forceRefresh = false}) async {
    print('🎯 [統一管理器] 獲取列表視圖設備...');

    // 🎯 確保數據已載入
    if (!await _ensureMeshDataLoaded(forceRefresh: forceRefresh)) {
      return [];
    }

    // 🎯 檢查快取
    if (!forceRefresh && _listViewDevices != null) {
      print('📋 使用快取的列表視圖設備 (${_listViewDevices!.length} 個)');
      return _listViewDevices!;
    }

    // 🎯 確保拓樸結構已分析
    final topology = await _ensureTopologyAnalyzed();
    if (topology == null) {
      return [];
    }

    final devices = <NetworkDevice>[];

    // 🎯 添加 Gateway
    final gatewayHosts = _getDirectHostDevices(topology, topology.gateway.macAddress);
    final gatewayDevice = NetworkDevice(
      name: 'Controller',
      id: _generateDeviceId(topology.gateway.macAddress),
      mac: topology.gateway.macAddress,
      ip: topology.gateway.ipAddress,
      connectionType: ConnectionType.wired,
      additionalInfo: {
        'type': 'gateway',
        'devName': topology.gateway.deviceName,
        'status': 'online',
        'clients': gatewayHosts.length.toString(),
        'rssi': '',
        'ssid': '',
        'radio': '',
        'parentAccessPoint': '',
        'hops': '0',
        'connectionDescription': 'Gateway 主控制器',
        'linkstate': topology.gateway.rawData['linkstate'] ?? '',
        'wirelessStandard': '',
        'rxrate': topology.gateway.rawData['rxrate'] ?? '',
        'txrate': topology.gateway.rawData['txrate'] ?? '',
      },
    );
    devices.add(gatewayDevice);

    // 🎯 添加所有 Extender
    for (final extender in topology.extenders) {
      final extenderHosts = _getDirectHostDevices(topology, extender.macAddress);
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
          'devName': extender.deviceName,
          'status': 'online',
          'clients': extenderHosts.length.toString(),
          'rssi': extender.rssiValues.join(','),
          'ssid': extender.connectionInfo.ssid,
          'radio': extender.connectionInfo.radio,
          'parentAccessPoint': extender.parentAccessPoint,
          'hops': extender.hops.toString(),
          'connectionDescription': extender.connectionInfo.description,
          'linkstate': extender.rawData['linkstate'] ?? '',
          'wirelessStandard': extender.connectionInfo.wirelessStandard,
          'rxrate': extender.rawData['rxrate'] ?? '',
          'txrate': extender.rawData['txrate'] ?? '',
        },
      );
      devices.add(extenderDevice);
    }

    // 🎯 快取結果
    _listViewDevices = devices;
    print('✅ 列表視圖設備生成完成 (${devices.length} 個設備)');

    return devices;
  }

  /// 獲取設備連接關係
  Future<List<DeviceConnection>> getDeviceConnections({bool forceRefresh = false}) async {
    print('🎯 [統一管理器] 獲取設備連接關係...');

    // 🎯 確保數據已載入
    if (!await _ensureMeshDataLoaded(forceRefresh: forceRefresh)) {
      return [];
    }

    // 🎯 檢查快取
    if (!forceRefresh && _deviceConnections != null) {
      print('📋 使用快取的設備連接關係 (${_deviceConnections!.length} 個)');
      return _deviceConnections!;
    }

    // 🎯 確保拓樸結構已分析
    final topology = await _ensureTopologyAnalyzed();
    if (topology == null) {
      return [];
    }

    final connections = <DeviceConnection>[];

    // 🎯 Gateway 連接數
    final gatewayHosts = _getDirectHostDevices(topology, topology.gateway.macAddress);
    connections.add(DeviceConnection(
      deviceId: _generateDeviceId(topology.gateway.macAddress),
      connectedDevicesCount: gatewayHosts.length,
    ));

    // 🎯 每個 Extender 的連接數
    for (final extender in topology.extenders) {
      final extenderHosts = _getDirectHostDevices(topology, extender.macAddress);
      connections.add(DeviceConnection(
        deviceId: _generateDeviceId(extender.macAddress),
        connectedDevicesCount: extenderHosts.length,
      ));
    }

    // 🎯 快取結果
    _deviceConnections = connections;
    print('✅ 設備連接關係生成完成 (${connections.length} 個連接)');

    return connections;
  }

  /// 獲取 Gateway 設備
  Future<NetworkDevice?> getGatewayDevice({bool forceRefresh = false}) async {
    print('🎯 [統一管理器] 獲取 Gateway 設備...');

    // 🎯 確保數據已載入
    if (!await _ensureMeshDataLoaded(forceRefresh: forceRefresh)) {
      return null;
    }

    // 🎯 檢查快取
    if (!forceRefresh && _gatewayDevice != null) {
      print('📋 使用快取的 Gateway 設備');
      return _gatewayDevice!;
    }

    // 🎯 確保拓樸結構已分析
    final topology = await _ensureTopologyAnalyzed();
    if (topology == null) {
      return null;
    }

    // 🎯 生成 Gateway 設備
    final gatewayHosts = _getDirectHostDevices(topology, topology.gateway.macAddress);
    _gatewayDevice = NetworkDevice(
      name: 'Controller',
      id: _generateDeviceId(topology.gateway.macAddress),
      mac: topology.gateway.macAddress,
      ip: topology.gateway.ipAddress,
      connectionType: ConnectionType.wired,
      additionalInfo: {
        'type': 'gateway',
        'devName': topology.gateway.deviceName,
        'status': 'online',
        'clients': gatewayHosts.length.toString(),
        'rssi': '',
        'ssid': '',
        'radio': '',
        'parentAccessPoint': '',
        'hops': '0',
        'connectionDescription': 'Gateway 主控制器',
        'linkstate': topology.gateway.rawData['linkstate'] ?? '',
        'wirelessStandard': '',
        'rxrate': topology.gateway.rawData['rxrate'] ?? '',
        'txrate': topology.gateway.rawData['txrate'] ?? '',
      },
    );

    print('✅ Gateway 設備生成完成');
    return _gatewayDevice!;
  }

  /// 獲取指定設備的客戶端列表
  Future<List<ClientDevice>> getClientDevicesForParent(String parentDeviceId, {bool forceRefresh = false}) async {
    print('🎯 [統一管理器] 獲取設備 $parentDeviceId 的客戶端...');

    // 🎯 檢查快取
    if (!forceRefresh && _clientDevicesCache.containsKey(parentDeviceId)) {
      final cached = _clientDevicesCache[parentDeviceId]!;
      print('📋 使用快取的客戶端設備 (${cached.length} 個)');
      return cached;
    }

    // 🎯 確保數據已載入
    if (!await _ensureMeshDataLoaded(forceRefresh: forceRefresh)) {
      return [];
    }

    // 🎯 確保拓樸結構已分析
    final topology = await _ensureTopologyAnalyzed();
    if (topology == null) {
      return [];
    }

    // 🎯 找到對應的父設備
    DetailedDeviceInfo? parentDevice;

    if (_generateDeviceId(topology.gateway.macAddress) == parentDeviceId) {
      parentDevice = topology.gateway;
    } else {
      for (final extender in topology.extenders) {
        if (_generateDeviceId(extender.macAddress) == parentDeviceId) {
          parentDevice = extender;
          break;
        }
      }
    }

    if (parentDevice == null) {
      print('❌ 找不到父設備 $parentDeviceId');
      return [];
    }

    // 🎯 獲取直接連接的 Host 設備並轉換為 ClientDevice
    final hostDevices = _getDirectHostDevices(topology, parentDevice.macAddress);
    final clientDevices = <ClientDevice>[];

    for (final host in hostDevices) {
      final clientDevice = ClientDevice(
        name: host.deviceName.isNotEmpty ? host.deviceName : host.macAddress,
        deviceType: host.connectionInfo.description,
        mac: host.macAddress,
        ip: host.ipAddress,
        connectionTime: '', // 暫時使用空值
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
    }

    // 🎯 快取結果
    _clientDevicesCache[parentDeviceId] = clientDevices;
    print('✅ 客戶端設備生成完成 (${clientDevices.length} 個)');

    return clientDevices;
  }

  // ==================== 🎯 輔助方法 ====================

  /// 獲取指定設備直接連接的 Host 設備
  List<DetailedDeviceInfo> _getDirectHostDevices(
      NetworkTopologyStructure topology,
      String parentMacAddress) {

    final directConnectedDevices = topology.getDirectConnectedDevices(parentMacAddress);
    return directConnectedDevices.where((device) => device.deviceType == 'host').toList();
  }

  /// 生成設備顯示名稱
  String _generateDisplayName(DetailedDeviceInfo device) {
    switch (device.deviceType) {
      case 'gateway':
        return 'Controller';
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
  String _generateDeviceId(String macAddress) {
    return 'device-${macAddress.replaceAll(':', '').toLowerCase()}';
  }

  /// 推斷客戶端設備類型
  ClientType _inferClientType(String deviceName, ConnectionInfo connectionInfo) {
    final String name = deviceName.toLowerCase();
    final String connectionDesc = connectionInfo.description.toLowerCase();
    final String connectionType = connectionInfo.connectionType.toLowerCase();

    if (name.contains('tv') || name.contains('television')) {
      return ClientType.tv;
    }

    if (name.contains('xbox') || name.contains('playstation') || name.contains('game')) {
      return ClientType.xbox;
    }

    if (name.contains('iphone') || name.contains('phone') || name.contains('mobile')) {
      return ClientType.iphone;
    }

    if (name.contains('laptop') || name.contains('computer') || name.contains('pc')) {
      return ClientType.laptop;
    }

    if (connectionType == 'ethernet') {
      return ClientType.xbox; // 有線通常是遊戲機
    }

    return ClientType.iphone; // 預設為手機
  }

  // ==================== 🎯 管理方法 ====================

  /// 強制重新載入
  Future<void> forceReload() async {
    print('🔄 強制重新載入 Mesh 數據...');
    clearCache();
    await _ensureMeshDataLoaded(forceRefresh: true);
  }

  /// 清除所有快取
  void clearCache() {
    _rawMeshData = null;
    _lastFetchTime = null;
    _lastSuccessTime = null;
    _clearAnalyzedDataCache();
    print('🗑️ 已清除所有 Mesh 數據快取');
  }

  /// 獲取 Gateway 名稱
  Future<String> getGatewayName() async {
    final gateway = await getGatewayDevice();
    return gateway?.additionalInfo['devName']?.toString().isNotEmpty == true
        ? gateway!.additionalInfo['devName']
        : 'Controller';
  }

  /// 🎯 獲取數據統計（調試用）
  Future<Map<String, dynamic>> getDataStatistics() async {
    await _ensureTopologyAnalyzed();

    return {
      'hasRawData': _rawMeshData != null,
      'hasTopologyStructure': _topologyStructure != null,
      'topologyDevicesCount': _topologyDevices?.length ?? 0,
      'listViewDevicesCount': _listViewDevices?.length ?? 0,
      'deviceConnectionsCount': _deviceConnections?.length ?? 0,
      'clientDevicesCacheCount': _clientDevicesCache.length,
      'lastFetchTime': _lastFetchTime?.toString(),
      'lastSuccessTime': _lastSuccessTime?.toString(),
      'cacheValidUntil': _lastFetchTime?.add(_cacheExpiry).toString(),
    };
  }

  /// 🎯 輸出完整統計報告（調試用）
  Future<void> printCompleteDataStatistics() async {
    try {
      print('\n=== 🎯 統一管理器數據統計報告 ===');

      final stats = await getDataStatistics();

      print('📊 數據狀態:');
      print('   原始數據: ${stats['hasRawData'] ? "✅" : "❌"}');
      print('   拓樸結構: ${stats['hasTopologyStructure'] ? "✅" : "❌"}');
      print('   拓樸設備快取: ${stats['topologyDevicesCount']} 個');
      print('   列表設備快取: ${stats['listViewDevicesCount']} 個');
      print('   連接關係快取: ${stats['deviceConnectionsCount']} 個');
      print('   客戶端快取: ${stats['clientDevicesCacheCount']} 個設備');

      print('\n⏰ 時間記錄:');
      print('   最後獲取: ${stats['lastFetchTime'] ?? "無"}');
      print('   最後成功: ${stats['lastSuccessTime'] ?? "無"}');
      print('   快取有效至: ${stats['cacheValidUntil'] ?? "無"}');

      if (_topologyStructure != null) {
        print('\n🌐 拓樸結構詳情:');
        print('   Gateway: ${_topologyStructure!.gateway.getDisplayName()}');
        print('   Extender: ${_topologyStructure!.extenders.length} 個');
        print('   Host: ${_topologyStructure!.hostDevices.length} 個');
      }

      print('=== 統一管理器統計結束 ===\n');

    } catch (e) {
      print('❌ 輸出統計報告失敗: $e');
    }
  }
  // 🎯 新增：統一更新計時器
  Timer? _unifiedUpdateTimer;

  /// 🎯 新增：啟動統一更新機制
  void startUnifiedUpdates() {
    _unifiedUpdateTimer?.cancel();

    final updateInterval = NetworkTopoConfig.meshApiCallInterval;
    print('🔄 啟動統一更新機制，間隔: ${updateInterval.inSeconds} 秒');

    _unifiedUpdateTimer = Timer.periodic(updateInterval, (_) {
      _triggerUnifiedUpdate();
    });
  }

  /// 🎯 新增：停止統一更新機制
  void stopUnifiedUpdates() {
    _unifiedUpdateTimer?.cancel();
    print('⏹️ 停止統一更新機制');
  }

  /// 🎯 新增：觸發統一更新
  Future<void> _triggerUnifiedUpdate() async {
    try {
      print('⏰ 統一更新觸發');

      // 強制重新載入數據（清除快取）
      await _ensureMeshDataLoaded(forceRefresh: true);

      print('✅ 統一更新完成');
    } catch (e) {
      print('❌ 統一更新失敗: $e');
    }
  }

  /// 🎯 新增：手動觸發更新（供外部調用）
  Future<void> triggerManualUpdate() async {
    await _triggerUnifiedUpdate();
  }
}