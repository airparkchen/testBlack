// lib/shared/ui/pages/home/Topo/fake_data_generator.dart

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

      final device = NetworkDevice(
        name: name,
        id: 'device-${i + 1}',
        mac: '48:21:0B:4A:47:9B',
        ip: '192.168.1.164',
        connectionType: isWired ? ConnectionType.wired : ConnectionType.wireless,
        additionalInfo: {
          'type': deviceType,
          'status': 'online',
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

  /// 創建速度數據生成器（保持原有邏輯）
  static SpeedDataGenerator createSpeedGenerator() {
    return SpeedDataGenerator(
      initialSpeed: 87,
      minSpeed: 20,
      maxSpeed: 150,
      dataPointCount: 100,
      smoothingFactor: 0.8,
    );
  }
}

/// 速度數據生成器（從原程式碼完整保留）
class SpeedDataGenerator {
  final int dataPointCount;
  final double minSpeed;
  final double maxSpeed;
  final List<double> _speedData = [];
  final List<double> _smoothedData = [];
  final math.Random _random = math.Random();
  final double smoothingFactor;
  final double fluctuationAmplitude;
  double _currentWidthPercentage = 0.05;
  final double endAtPercent;
  final double growthRate;

  SpeedDataGenerator({
    this.dataPointCount = 100,
    this.minSpeed = 20,
    this.maxSpeed = 1000,
    double? initialSpeed,
    this.smoothingFactor = 1,
    this.endAtPercent = 0.7,
    this.growthRate = 0.01,
    this.fluctuationAmplitude = 15.0,
  }) {
    final initialValue = initialSpeed ?? 87.0;
    for (int i = 0; i < 5; i++) {
      _speedData.add(initialValue);
      _smoothedData.add(initialValue);
    }
  }

  List<double> get data => List.from(_smoothedData);
  double get currentSpeed => _smoothedData.last;
  bool isFullWidth() => _currentWidthPercentage >= endAtPercent;
  double getWidthPercentage() => _currentWidthPercentage;

  void update() {
    double newValue = _generateNextValue(_speedData.last);

    if (_currentWidthPercentage < endAtPercent) {
      _currentWidthPercentage += growthRate;
      if (_currentWidthPercentage > endAtPercent) {
        _currentWidthPercentage = endAtPercent;
      }
    }

    if (_currentWidthPercentage >= endAtPercent && _speedData.length >= dataPointCount) {
      _speedData.removeAt(0);
      _smoothedData.removeAt(0);
    }

    _speedData.add(newValue);

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