// lib/shared/ui/pages/home/Topo/fake_data_generator.dart - 修改版本

import 'dart:math' as math;
import 'package:whitebox/shared/ui/components/basic/NetworkTopologyComponent.dart';

/// 假資料生成器 - 可作為 package 使用
class FakeDataGenerator {

  /// 生成假設備資料（保持原有邏輯）
  static List<NetworkDevice> generateDevices(int deviceCount) {
    List<NetworkDevice> dummyDevices = [];

    for (int i = 0; i < deviceCount; i++) {
      String name = '';
      String deviceType = '';

      // 新增：parentAccessPoint 邏輯
      String parentAccessPoint = 'gateway-mac'; // 預設連接到 Gateway

      // 如果是第二個設備且有多個設備，讓它連接到第一個設備（測試 Extender 間連線）
      if (i == 1 && deviceCount >= 2) {
        parentAccessPoint = '48:21:0B:4A:47:9B'; // 連接到第一個設備的 MAC
      }
      // 如果是第三個設備且有多個設備，讓它連接到第二個設備（測試鏈式連線）
      if (i == 2 && deviceCount >= 3) {
        parentAccessPoint = '48:21:0B:4A:47:9C'; // 連接到第二個設備的 MAC（需要修改 MAC）
      }


      switch (i) {
        case 0:
          name = 'TV';
          deviceType = 'OWA813V_6G';
          break;
        case 1:
          name = 'Xbox';
          deviceType = 'Connected via Ethernet';
          break;
        case 2:
          name = 'Iphone';
          deviceType = 'OWA813V_6G';
          break;
        case 3:
          name = 'Laptop';
          deviceType = 'OWA813V_5G';
          break;
        default:
          name = '設備 ${i + 1}';
          deviceType = 'OWA813V_6G';
      }

      final isWired = (name == 'Xbox');

      // 🔸 為每個設備分配不同的 MAC 地址 👇
      String macAddress = '48:21:0B:4A:47:9${String.fromCharCode(66 + i)}'; // 生成不同的 MAC

      final device = NetworkDevice(
        name: name,
        id: 'device-${i + 1}',
        mac: macAddress, // 🔸 使用新的 MAC 地址
        ip: '192.168.1.164',
        connectionType: isWired ? ConnectionType.wired : ConnectionType.wireless,
        additionalInfo: {
          'type': 'extender', // 🔸 修改：改為 extender 以便測試
          'status': 'online',
          'parentAccessPoint': parentAccessPoint, // 🔸 新增：父節點資訊
        },
      );

      dummyDevices.add(device);
    }

    return dummyDevices;
  }

  /// 生成假連接資料（保持原有邏輯）
  static List<DeviceConnection> generateConnections(List<NetworkDevice> devices) {
    List<DeviceConnection> connections = [];

    for (var device in devices) {
      connections.add(
        DeviceConnection(
          deviceId: device.id,
          connectedDevicesCount: 2,
        ),
      );
    }

    return connections;
  }

  /// 創建速度數據生成器（修改為固定長度滑動窗口）
  static SpeedDataGenerator createSpeedGenerator() {
    return SpeedDataGenerator(
      initialSpeed: 87,
      minSpeed: 20,
      maxSpeed: 150,
      dataPointCount: 100,
      smoothingFactor: 0.8,
      endAtPercent: 0.7, // 🎯 固定在70%位置
    );
  }
}

/// 🎯 修改：速度數據生成器 - 固定長度滑動窗口模式
class SpeedDataGenerator {
  final int dataPointCount;
  final double minSpeed;
  final double maxSpeed;
  final List<double> _speedData = [];
  final List<double> _smoothedData = [];
  final math.Random _random = math.Random();
  final double smoothingFactor;
  final double fluctuationAmplitude;
  final double endAtPercent;

  // 🎯 新增：固定長度模式標記
  final bool useFixedLengthMode;

  SpeedDataGenerator({
    this.dataPointCount = 100,
    this.minSpeed = 20,
    this.maxSpeed = 1000,
    double? initialSpeed,
    this.smoothingFactor = 1,
    this.endAtPercent = 0.7,
    this.fluctuationAmplitude = 15.0,
    this.useFixedLengthMode = true, // 🎯 預設使用固定長度模式
  }) {
    final initialValue = initialSpeed ?? 87.0;

    // 🎯 修改：初始化時就填滿整個數據陣列
    if (useFixedLengthMode) {
      // 填滿整個陣列，讓線圖一開始就顯示完整的70%長度
      for (int i = 0; i < dataPointCount; i++) {
        // 可以添加一些小的隨機變化讓初始線條更自然
        final variation = (_random.nextDouble() * 10) - 5; // ±5的變化
        final value = (initialValue + variation).clamp(minSpeed, maxSpeed);
        _speedData.add(value);
        _smoothedData.add(value);
      }
    } else {
      // 原有的逐漸增長模式
      for (int i = 0; i < 5; i++) {
        _speedData.add(initialValue);
        _smoothedData.add(initialValue);
      }
    }
  }

  List<double> get data => List.from(_smoothedData);
  double get currentSpeed => _smoothedData.last;

  // 🎯 修改：固定長度模式下總是返回 endAtPercent
  double getWidthPercentage() => useFixedLengthMode ? endAtPercent : _calculateDynamicWidth();

  // 原有的動態寬度計算（保留給舊模式使用）
  double _calculateDynamicWidth() {
    return (_smoothedData.length / dataPointCount * endAtPercent).clamp(0.0, endAtPercent);
  }

  /// 🎯 修改：更新方法 - 固定長度滑動窗口
  void update() {
    double newValue = _generateNextValue(_speedData.last);

    if (useFixedLengthMode) {
      // 🎯 固定長度模式：總是移除第一個元素，添加新元素到末尾
      // 這樣會產生向右滑動的效果
      _speedData.removeAt(0);
      _smoothedData.removeAt(0);
    } else {
      // 原有的動態增長模式
      if (_speedData.length >= dataPointCount) {
        _speedData.removeAt(0);
        _smoothedData.removeAt(0);
      }
    }

    _speedData.add(newValue);

    // 平滑處理
    double smoothedValue;
    if (_smoothedData.isNotEmpty) {
      smoothedValue = _smoothedData.last * smoothingFactor + newValue * (1 - smoothingFactor);
    } else {
      smoothedValue = newValue;
    }

    _smoothedData.add(smoothedValue);
  }

  double _generateNextValue(double currentValue) {
    final double fluctuation = (_random.nextDouble() * fluctuationAmplitude * 2) - fluctuationAmplitude;
    double newValue = currentValue + fluctuation;

    if (_random.nextDouble() < 0.1) {
      newValue += (_random.nextDouble() * 20) - 10;
    }

    if (newValue < minSpeed) newValue = minSpeed;
    if (newValue > maxSpeed) newValue = maxSpeed;

    return newValue;
  }
}

/// 🎯 新增：真實速度數據服務
class RealSpeedDataService {
  // API 端點（預留）
  static const String speedApiEndpoint = '/api/v1/system/speed';

  // 快取機制
  static double? _cachedSpeed;
  static DateTime? _lastFetchTime;
  static const Duration _cacheExpiry = Duration(seconds: 5); // 5秒快取

  // 🎯 新增：API 可用性標記（目前設為 false）
  static const bool isApiAvailable = false;

  /// 檢查快取是否有效
  static bool _isCacheValid() {
    if (_lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheExpiry;
  }

  /// 🎯 從真實 API 獲取速度數據（目前返回預設值）
  static Future<double> getCurrentSpeed() async {
    try {
      // 檢查快取
      if (_isCacheValid() && _cachedSpeed != null) {
        return _cachedSpeed!;
      }

      // 🎯 目前直接返回預設值，不呼叫API
      if (!isApiAvailable) {
        final speed = 87.0;

        // 更新快取
        _cachedSpeed = speed;
        _lastFetchTime = DateTime.now();

        return speed;
      }

      // 🎯 TODO: 將來實現真實的 API 呼叫
      /*
      print('🌐 從 API 獲取速度數據: $speedApiEndpoint');
      final response = await WifiApiService.getSystemSpeed();
      final speed = response['current_speed']?.toDouble() ?? 87.0;

      // 更新快取
      _cachedSpeed = speed;
      _lastFetchTime = DateTime.now();

      print('✅ 獲取速度數據: ${speed.toInt()} Mbps');
      return speed;
      */

      return 87.0; // 備用預設值

    } catch (e) {
      print('❌ 獲取速度數據時發生錯誤: $e');
      return 87.0; // 返回預設值
    }
  }

  /// 🎯 清除快取（用於強制重新載入）
  static void clearCache() {
    _cachedSpeed = null;
    _lastFetchTime = null;
  }

  /// 🎯 獲取速度歷史數據（預留方法）
  static Future<List<double>> getSpeedHistory({int pointCount = 100}) async {
    try {
      // 🎯 目前直接返回預設直線，不呼叫API
      if (!isApiAvailable) {
        final currentSpeed = await getCurrentSpeed();
        return List.filled(pointCount, currentSpeed);
      }

      // 🎯 TODO: 將來實現真實的 API 呼叫
      /*
      final response = await WifiApiService.getSystemSpeedHistory(pointCount);
      return response['speed_history']?.cast<double>() ?? [];
      */

      return List.filled(pointCount, 87.0);

    } catch (e) {
      print('❌ 獲取速度歷史數據時發生錯誤: $e');
      return List.filled(pointCount, 87.0);
    }
  }
}

/// 🎯 新增：真實速度數據生成器
class RealSpeedDataGenerator {
  final int dataPointCount;
  final double minSpeed;
  final double maxSpeed;
  final List<double> _speedData = [];

  // 更新間隔
  final Duration updateInterval;

  RealSpeedDataGenerator({
    this.dataPointCount = 100,
    this.minSpeed = 20,
    this.maxSpeed = 1000,
    this.updateInterval = const Duration(seconds: 5),
  }) {
    _initializeData();
  }

  /// 初始化數據
  void _initializeData() async {
    try {
      final history = await RealSpeedDataService.getSpeedHistory(pointCount: dataPointCount);
      _speedData.clear();
      _speedData.addAll(history);
      print('✅ 初始化真實速度數據: ${_speedData.length} 個點');
    } catch (e) {
      print('❌ 初始化真實速度數據失敗: $e');
      // 使用預設直線
      _speedData.clear();
      _speedData.addAll(List.filled(dataPointCount, 87.0));
    }
  }

  /// 更新數據
  Future<void> update() async {
    try {
      final newSpeed = await RealSpeedDataService.getCurrentSpeed();

      // 🎯 固定長度滑動窗口：移除第一個，添加新的到最後
      if (_speedData.length >= dataPointCount) {
        _speedData.removeAt(0);
      }
      _speedData.add(newSpeed);

      // print('📈 更新真實速度數據: ${newSpeed.toInt()} Mbps');
    } catch (e) {
      print('❌ 更新真實速度數據失敗: $e');
    }
  }

  List<double> get data => List.from(_speedData);
  double get currentSpeed => _speedData.isNotEmpty ? _speedData.last : 87.0;
  double get widthPercentage => 0.7; // 固定70%
}