// lib/shared/ui/pages/home/Topo/fake_data_generator.dart - 修正版本
// 🎯 修正：移動 RealSpeedDataGenerator 到這裡，統一管理所有數據生成器

import 'dart:math' as math;
import 'package:whitebox/shared/ui/components/basic/NetworkTopologyComponent.dart';
import 'package:whitebox/shared/services/real_speed_data_service.dart'; // 🎯 新增

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

  /// 創建速度數據生成器（修改為雙線固定長度滑動窗口）
  static SpeedDataGenerator createSpeedGenerator() {
    return SpeedDataGenerator(
      initialUploadSpeed: 65,
      initialDownloadSpeed: 83,
      minSpeed: 20,
      maxSpeed: 150,
      dataPointCount: 100,
      smoothingFactor: 0.8,
      endAtPercent: 0.7, // 🎯 固定在70%位置
    );
  }
}

/// 🎯 修改：雙線速度數據生成器 - 固定長度滑動窗口模式
class SpeedDataGenerator {
  final int dataPointCount;
  final double minSpeed;
  final double maxSpeed;

  // 🎯 修改：雙線數據存儲
  final List<double> _uploadData = [];
  final List<double> _downloadData = [];
  final List<double> _uploadSmoothed = [];
  final List<double> _downloadSmoothed = [];

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
    double? initialUploadSpeed,    // 🎯 修改：分別設定上傳和下載初始值
    double? initialDownloadSpeed,
    this.smoothingFactor = 1,
    this.endAtPercent = 0.7,
    this.fluctuationAmplitude = 15.0,
    this.useFixedLengthMode = true, // 🎯 預設使用固定長度模式
  }) {
    final initialUpload = initialUploadSpeed ?? 65.0;
    final initialDownload = initialDownloadSpeed ?? 83.0;

    // 🎯 修改：初始化雙線數據
    if (useFixedLengthMode) {
      // 填滿整個陣列，讓線圖一開始就顯示完整的70%長度
      for (int i = 0; i < dataPointCount; i++) {
        // 上傳數據（稍低一些，比如65左右）
        final uploadVariation = (_random.nextDouble() * 8) - 4; // ±4的變化
        final uploadValue = (initialUpload + uploadVariation).clamp(minSpeed, maxSpeed);

        // 下載數據（稍高一些，比如83左右）
        final downloadVariation = (_random.nextDouble() * 10) - 5; // ±5的變化
        final downloadValue = (initialDownload + downloadVariation).clamp(minSpeed, maxSpeed);

        _uploadData.add(uploadValue);
        _downloadData.add(downloadValue);
        _uploadSmoothed.add(uploadValue);
        _downloadSmoothed.add(downloadValue);
      }
    } else {
      // 原有的逐漸增長模式
      for (int i = 0; i < 5; i++) {
        _uploadData.add(initialUpload);
        _downloadData.add(initialDownload);
        _uploadSmoothed.add(initialUpload);
        _downloadSmoothed.add(initialDownload);
      }
    }
  }

  // 🎯 修改：新的 getter 方法
  List<double> get uploadData => List.from(_uploadSmoothed);
  List<double> get downloadData => List.from(_downloadSmoothed);
  double get currentUpload => _uploadSmoothed.isNotEmpty ? _uploadSmoothed.last : 65.0;
  double get currentDownload => _downloadSmoothed.isNotEmpty ? _downloadSmoothed.last : 83.0;

  // 🎯 保留舊的方法以兼容性
  List<double> get data => downloadData; // 向後兼容，返回下載數據
  double get currentSpeed => currentDownload; // 向後兼容，返回下載速度

  // 🎯 修改：固定長度模式下總是返回 endAtPercent
  double getWidthPercentage() => useFixedLengthMode ? endAtPercent : _calculateDynamicWidth();

  // 原有的動態寬度計算（保留給舊模式使用）
  double _calculateDynamicWidth() {
    return (_downloadSmoothed.length / dataPointCount * endAtPercent).clamp(0.0, endAtPercent);
  }

  /// 🎯 修改：雙線更新方法 - 固定長度滑動窗口
  void update() {
    double newUpload = _generateNextValue(_uploadData.last);
    double newDownload = _generateNextValue(_downloadData.last);

    if (useFixedLengthMode) {
      // 🎯 固定長度模式：總是移除第一個元素，添加新元素到末尾
      // 這樣會產生向右滑動的效果
      _uploadData.removeAt(0);
      _downloadData.removeAt(0);
      _uploadSmoothed.removeAt(0);
      _downloadSmoothed.removeAt(0);
    } else {
      // 原有的動態增長模式
      if (_uploadData.length >= dataPointCount) {
        _uploadData.removeAt(0);
        _downloadData.removeAt(0);
        _uploadSmoothed.removeAt(0);
        _downloadSmoothed.removeAt(0);
      }
    }

    _uploadData.add(newUpload);
    _downloadData.add(newDownload);

    // 🎯 修改：分別處理上傳和下載的平滑
    // 上傳平滑處理
    double smoothedUpload;
    if (_uploadSmoothed.isNotEmpty) {
      smoothedUpload = _uploadSmoothed.last * smoothingFactor + newUpload * (1 - smoothingFactor);
    } else {
      smoothedUpload = newUpload;
    }

    // 下載平滑處理
    double smoothedDownload;
    if (_downloadSmoothed.isNotEmpty) {
      smoothedDownload = _downloadSmoothed.last * smoothingFactor + newDownload * (1 - smoothingFactor);
    } else {
      smoothedDownload = newDownload;
    }

    _uploadSmoothed.add(smoothedUpload);
    _downloadSmoothed.add(smoothedDownload);
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

/// 🎯 新增：真實速度數據生成器（移到這裡統一管理）
class RealSpeedDataGenerator {
  final int dataPointCount;
  final double minSpeed;
  final double maxSpeed;

  // 🎯 真實資料模式：數據來自API
  final List<double> _uploadData = [];
  final List<double> _downloadData = [];

  // 更新間隔
  final Duration updateInterval;

  RealSpeedDataGenerator({
    this.dataPointCount = 100,
    this.minSpeed = 0,      // 🎯 真實模式從0開始
    this.maxSpeed = 1000,
    this.updateInterval = const Duration(seconds: 10), // 🎯 統一10秒更新
  }) {
    _initializeData();
  }

  /// 🎯 修正：初始化真實速度數據 - 立即顯示預設值0
  void _initializeData() async {
    try {
      print('🌐 初始化真實速度數據...');

      // 🎯 修正：先填入預設值0，讓白球立即顯示
      _uploadData.clear();
      _downloadData.clear();
      _uploadData.addAll(List.filled(dataPointCount, 0.0)); // 🎯 預設值0
      _downloadData.addAll(List.filled(dataPointCount, 0.0)); // 🎯 預設值0

      print('✅ 初始化完成: 上傳 ${_uploadData.length} 個點, 下載 ${_downloadData.length} 個點 (預設值: 0 Mbps)');

      // 🎯 然後異步載入真實數據
      _loadRealDataAsync();

    } catch (e) {
      print('❌ 初始化真實速度數據失敗: $e');
      // 錯誤時使用全0數據
      _uploadData.clear();
      _downloadData.clear();
      _uploadData.addAll(List.filled(dataPointCount, 0.0));
      _downloadData.addAll(List.filled(dataPointCount, 0.0));
    }
  }

  /// 🎯 新增：異步載入真實數據
  void _loadRealDataAsync() async {
    try {
      final uploadHistory = await RealSpeedDataService.getUploadSpeedHistory(pointCount: dataPointCount);
      final downloadHistory = await RealSpeedDataService.getDownloadSpeedHistory(pointCount: dataPointCount);

      _uploadData.clear();
      _downloadData.clear();
      _uploadData.addAll(uploadHistory);
      _downloadData.addAll(downloadHistory);

      print('📈 異步載入真實數據完成: 上傳 ${currentUpload.toStringAsFixed(2)} Mbps, 下載 ${currentDownload.toStringAsFixed(2)} Mbps');

    } catch (e) {
      print('❌ 異步載入真實數據失敗: $e');
    }
  }

  /// 🎯 更新真實速度數據
  Future<void> update() async {
    try {
      final newUploadSpeed = await RealSpeedDataService.getCurrentUploadSpeed();
      final newDownloadSpeed = await RealSpeedDataService.getCurrentDownloadSpeed();

      // 🎯 固定長度滑動窗口：移除第一個，添加新的到最後
      if (_uploadData.length >= dataPointCount) {
        _uploadData.removeAt(0);
      }
      if (_downloadData.length >= dataPointCount) {
        _downloadData.removeAt(0);
      }

      _uploadData.add(newUploadSpeed);
      _downloadData.add(newDownloadSpeed);

      print('📈 更新真實速度: 上傳 ${newUploadSpeed.toStringAsFixed(2)} Mbps, 下載 ${newDownloadSpeed.toStringAsFixed(2)} Mbps');

    } catch (e) {
      print('❌ 更新真實速度數據失敗: $e');
    }
  }

  // Getters
  List<double> get uploadData => List.from(_uploadData);
  List<double> get downloadData => List.from(_downloadData);
  double get currentUpload => _uploadData.isNotEmpty ? _uploadData.last : 0.0;
  double get currentDownload => _downloadData.isNotEmpty ? _downloadData.last : 0.0;

  // 向後兼容（用於現有的速度圖表）
  List<double> get data => downloadData;
  double get currentSpeed => currentDownload;
  double get widthPercentage => 0.7; // 固定70%
}