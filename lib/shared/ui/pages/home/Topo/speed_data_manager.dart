// lib/shared/ui/pages/home/Topo/speed_data_manager.dart - 完整修正版本
// 移動 RealSpeedDataGenerator 到這裡，統一管理所有數據生成器

import 'dart:math' as math;
import 'package:whitebox/shared/ui/components/basic/NetworkTopologyComponent.dart';
import 'package:whitebox/shared/services/real_speed_data_service.dart';

/// 智能單位格式化工具
class SpeedUnitFormatter {
  /// 將 Mbps 數值格式化為適當單位的字串
  static String formatSpeed(double speedMbps) {
    if (speedMbps >= 100) {
      // >= 100 Mbps 顯示為 Gbps
      final gbps = speedMbps / 1000.0;
      return '${gbps.toStringAsFixed(2)} Gb/s';
    } else if (speedMbps >= 0.1) {
      // >= 0.1 Mbps 顯示為 Mbps
      return '${speedMbps.toStringAsFixed(2)} Mb/s';
    } else {
      // < 0.1 Mbps 顯示為 Kbps
      final kbps = speedMbps * 1000.0;
      return '${kbps.toStringAsFixed(1)} Kb/s';
    }
  }

  /// 針對整數速度的格式化（向後兼容現有程式碼）
  static String formatSpeedInt(int speedMbps) {
    return formatSpeed(speedMbps.toDouble());
  }
}

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
      dataPointCount: 20,  // 🎯 修改：改為20個資料點
      smoothingFactor: 0.8,
      endAtPercent: 0.7, // 固定在70%位置
    );
  }
}

/// 雙線速度數據生成器 - 固定長度滑動窗口模式
class SpeedDataGenerator {
  final int dataPointCount;
  final double minSpeed;
  final double maxSpeed;

  // 雙線數據存儲
  final List<double> _uploadData = [];
  final List<double> _downloadData = [];
  final List<double> _uploadSmoothed = [];
  final List<double> _downloadSmoothed = [];

  final math.Random _random = math.Random();
  final double smoothingFactor;
  final double fluctuationAmplitude;
  final double endAtPercent;

  // 固定長度模式標記
  final bool useFixedLengthMode;

  SpeedDataGenerator({
    this.dataPointCount = 100,
    this.minSpeed = 20,
    this.maxSpeed = 1000,
    double? initialUploadSpeed,    // 分別設定上傳和下載初始值
    double? initialDownloadSpeed,
    this.smoothingFactor = 1,
    this.endAtPercent = 0.7,
    this.fluctuationAmplitude = 15.0,
    this.useFixedLengthMode = true, // 預設使用固定長度模式
  }) {
    final initialUpload = initialUploadSpeed ?? 65.0;
    final initialDownload = initialDownloadSpeed ?? 83.0;

    // 初始化雙線數據
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

  // 新的 getter 方法
  List<double> get uploadData => List.from(_uploadSmoothed);
  List<double> get downloadData => List.from(_downloadSmoothed);
  double get currentUpload => _uploadSmoothed.isNotEmpty ? _uploadSmoothed.last : 65.0;
  double get currentDownload => _downloadSmoothed.isNotEmpty ? _downloadSmoothed.last : 83.0;

  // 保留舊的方法以兼容性
  List<double> get data => downloadData; // 向後兼容，返回下載數據
  double get currentSpeed => currentDownload; // 向後兼容，返回下載速度

  // 固定長度模式下總是返回 endAtPercent
  double getWidthPercentage() => useFixedLengthMode ? endAtPercent : _calculateDynamicWidth();

  // 原有的動態寬度計算（保留給舊模式使用）
  double _calculateDynamicWidth() {
    return (_downloadSmoothed.length / dataPointCount * endAtPercent).clamp(0.0, endAtPercent);
  }

  ///  雙線更新方法 - 固定長度滑動窗口
  void update() {
    double newUpload = _generateNextValue(_uploadData.last);
    double newDownload = _generateNextValue(_downloadData.last);

    if (useFixedLengthMode) {
      // 固定長度模式：總是移除第一個元素，添加新元素到末尾
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

    // 分別處理上傳和下載的平滑
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

// 改為20個資料點，預設填滿歷史數據

/// 🎯 真實速度數據生成器（20個資料點版本）
class RealSpeedDataGenerator {
  final int dataPointCount;
  final double minSpeed;
  final double _maxSpeedLimit;

  // 真實資料模式：數據來自API
  final List<double> _uploadData = [];
  final List<double> _downloadData = [];

  // 🎯 插值動畫相關
  final List<double> _uploadHistory = [];
  final List<double> _downloadHistory = [];
  double _lastUploadValue = 0.0;
  double _lastDownloadValue = 0.0;
  double _targetUploadValue = 0.0;
  double _targetDownloadValue = 0.0;
  int _interpolationSteps = 0;
  int _currentStep = 0;

  // 🎯 新增：追蹤是否已經初始化
  bool _isInitialized = false;

  // 更新間隔
  final Duration updateInterval;

  RealSpeedDataGenerator({
    this.dataPointCount = 20,
    this.minSpeed = 0,
    double maxSpeed = 1000,
    this.updateInterval = const Duration(seconds: 10),
  }) : _maxSpeedLimit = maxSpeed {
    _initializeData();
  }

  /// 初始化真實速度數據
  /// 🎯 修正：初始化真實速度數據 - 預設填滿20個點
  void _initializeData() async {
    try {
      print('🌐 初始化真實速度數據（${dataPointCount}個點）...');

      // 🎯 關鍵：初始化為全零，真正從底部開始
      _uploadData.clear();
      _downloadData.clear();
      _uploadData.addAll(List.filled(dataPointCount, 0.0));
      _downloadData.addAll(List.filled(dataPointCount, 0.0));

      // 🎯 初始化插值數值也為零
      _lastUploadValue = 0.0;
      _lastDownloadValue = 0.0;
      _targetUploadValue = 0.0;
      _targetDownloadValue = 0.0;
      _interpolationSteps = 0;
      _currentStep = 0;
      _isInitialized = false;  // 標記為未初始化

      print('✅ 初始化完成: 所有 ${dataPointCount} 個點設為 0.0');

      // 🎯 異步載入第一個真實數據點
      _loadFirstRealData();

    } catch (e) {
      print('❌ 初始化真實速度數據失敗: $e');
    }
  }

  Future<void> _loadFirstRealData() async {
    try {
      print('🔄 載入第一個真實數據點...');

      final currentUpload = await RealSpeedDataService.getCurrentUploadSpeed();
      final currentDownload = await RealSpeedDataService.getCurrentDownloadSpeed();

      // 🎯 關鍵：只更新最右邊的一個點，其他保持為0
      if (_uploadData.isNotEmpty && _downloadData.isNotEmpty) {
        _uploadData[_uploadData.length - 1] = currentUpload;      // 只更新最後一個點
        _downloadData[_downloadData.length - 1] = currentDownload; // 只更新最後一個點
      }

      // 🎯 設定目標值，準備正常的插值流程
      _targetUploadValue = currentUpload;
      _targetDownloadValue = currentDownload;
      _lastUploadValue = currentUpload;
      _lastDownloadValue = currentDownload;

      _isInitialized = true;  // 標記為已初始化

      print('✅ 第一個真實數據點載入完成:');
      print('   上傳: ${currentUpload.toStringAsFixed(4)} Mbps (${SpeedUnitFormatter.formatSpeed(currentUpload)})');
      print('   下載: ${currentDownload.toStringAsFixed(4)} Mbps (${SpeedUnitFormatter.formatSpeed(currentDownload)})');
      print('   策略: 只更新最右邊的點，創建漸進式曲線');

    } catch (e) {
      print('❌ 載入第一個真實數據失敗: $e');
    }
  }

  /// 🎯 新增：載入初始真實數據
  Future<void> _loadInitialRealData() async {
    try {
      print('🔄 載入初始真實數據...');

      // 取得當前真實速度
      final currentUpload = await RealSpeedDataService.getCurrentUploadSpeed();
      final currentDownload = await RealSpeedDataService.getCurrentDownloadSpeed();

      // 🎯 關鍵修正：所有點都設為當前值，創建水平線
      // 這樣第一次更新時不會有抖動，只會平滑過渡到新值
      for (int i = 0; i < dataPointCount; i++) {
        _uploadData[i] = currentUpload;      // 所有點都是當前值
        _downloadData[i] = currentDownload;  // 所有點都是當前值
      }

      // 🎯 初始化插值數值（重要：目標值也設為當前值）
      _lastUploadValue = currentUpload;
      _lastDownloadValue = currentDownload;
      _targetUploadValue = currentUpload;    // 🎯 關鍵：目標值也是當前值
      _targetDownloadValue = currentDownload; // 🎯 關鍵：目標值也是當前值

      // 🎯 重要：插值步數設為0，表示不需要插值
      _interpolationSteps = 0;
      _currentStep = 0;

      print('✅ 初始真實數據載入完成（穩定水平線）:');
      print('   當前值: 上傳 ${currentUpload.toStringAsFixed(4)} Mbps, 下載 ${currentDownload.toStringAsFixed(4)} Mbps');
      print('   已創建 ${dataPointCount} 個相同數值的點，避免抖動');
      print('   插值狀態: 步數=${_interpolationSteps}, 目標值已同步');

    } catch (e) {
      print('❌ 載入初始真實數據失敗: $e');
    }
  }

  /// 異步載入真實數據
  void _loadRealDataAsync() async {
    try {
      final uploadHistory = await RealSpeedDataService.getUploadSpeedHistory(pointCount: dataPointCount);
      final downloadHistory = await RealSpeedDataService.getDownloadSpeedHistory(pointCount: dataPointCount);

      _uploadData.clear();
      _downloadData.clear();
      _uploadData.addAll(uploadHistory);
      _downloadData.addAll(downloadHistory);

      // 🎯 初始化插值數值
      _lastUploadValue = uploadHistory.isNotEmpty ? uploadHistory.last : 0.0;
      _lastDownloadValue = downloadHistory.isNotEmpty ? downloadHistory.last : 0.0;
      _targetUploadValue = _lastUploadValue;
      _targetDownloadValue = _lastDownloadValue;

      print('📈 異步載入真實數據完成: 上傳 ${currentUpload.toStringAsFixed(2)} Mbps, 下載 ${currentDownload.toStringAsFixed(2)} Mbps');
    } catch (e) {
      print('❌ 異步載入真實數據失敗: $e');
    }
  }

  /// 🎯 API 更新（10秒一次）
  Future<void> updateFromAPI() async {
    try {
      final newUploadSpeed = await RealSpeedDataService.getCurrentUploadSpeed();
      final newDownloadSpeed = await RealSpeedDataService.getCurrentDownloadSpeed();

      // 🎯 如果還沒初始化完成，就不進行插值更新
      if (!_isInitialized) {
        print('📊 等待初始化完成，跳過API更新');
        return;
      }

      // 🎯 檢查數值是否有實際變化
      final double uploadDiff = (newUploadSpeed - _targetUploadValue).abs();
      final double downloadDiff = (newDownloadSpeed - _targetDownloadValue).abs();

      if (uploadDiff < 0.000001 && downloadDiff < 0.000001) {
        print('📊 API數值無變化，跳過插值動畫');
        return;
      }

      // 🎯 正常的插值更新
      _lastUploadValue = _targetUploadValue;
      _lastDownloadValue = _targetDownloadValue;
      _targetUploadValue = newUploadSpeed;
      _targetDownloadValue = newDownloadSpeed;

      _interpolationSteps = 20;
      _currentStep = 0;

      // 保存到歷史記錄
      _uploadHistory.add(newUploadSpeed);
      _downloadHistory.add(newDownloadSpeed);

      if (_uploadHistory.length > dataPointCount) {
        _uploadHistory.removeAt(0);
        _downloadHistory.removeAt(0);
      }

      print('📊 API 更新開始插值:');
      print('   從: 上傳 ${_lastUploadValue.toStringAsFixed(4)} Mbps, 下載 ${_lastDownloadValue.toStringAsFixed(4)} Mbps');
      print('   到: 上傳 ${newUploadSpeed.toStringAsFixed(4)} Mbps, 下載 ${newDownloadSpeed.toStringAsFixed(4)} Mbps');
      print('   變化: 上傳 ${uploadDiff.toStringAsFixed(4)} Mbps, 下載 ${downloadDiff.toStringAsFixed(4)} Mbps');

    } catch (e) {
      print('❌ 更新 API 數據失敗: $e');
    }
  }

  /// 🎯 插值動畫更新（500ms一次）
  void updateInterpolation() {
    // 🎯 如果還沒初始化完成，就不進行插值
    if (!_isInitialized) {
      return;
    }

    if (_currentStep >= _interpolationSteps) {
      return; // 插值完成
    }

    _currentStep++;

    // 線性插值計算當前值
    final double progress = _currentStep / _interpolationSteps;
    final double currentUploadValue = _lastUploadValue + (_targetUploadValue - _lastUploadValue) * progress;
    final double currentDownloadValue = _lastDownloadValue + (_targetDownloadValue - _lastDownloadValue) * progress;

    // 滑動窗口：移除最舊的，添加新的插值點
    _uploadData.removeAt(0);
    _downloadData.removeAt(0);
    _uploadData.add(currentUploadValue);
    _downloadData.add(currentDownloadValue);

    print('🎬 插值動畫: 步數 ${_currentStep}/${_interpolationSteps}');
    print('   當前值: 上傳 ${currentUploadValue.toStringAsFixed(4)} Mbps, 下載 ${currentDownloadValue.toStringAsFixed(4)} Mbps');
  }

  /// 🎯 統一的 update 方法（由500ms計時器調用）
  Future<void> update() async {
    updateInterpolation();
  }

  // Getters
  List<double> get uploadData => List.from(_uploadData);
  List<double> get downloadData => List.from(_downloadData);
  double get currentUpload => _uploadData.isNotEmpty ? _uploadData.last : 0.0;
  double get currentDownload => _downloadData.isNotEmpty ? _downloadData.last : 0.0;

  /// 動態範圍計算
  double get maxSpeed {
    final uploadMax = _uploadData.isNotEmpty ? _uploadData.reduce(math.max) : 0.001;
    final downloadMax = _downloadData.isNotEmpty ? _downloadData.reduce(math.max) : 0.001;
    final currentMax = math.max(uploadMax, downloadMax);

    double calculatedMax;
    if (currentMax < 0.01) {
      calculatedMax = math.max(currentMax * 2.0, 0.001);
    } else {
      calculatedMax = currentMax * 1.5;
    }

    calculatedMax = math.min(calculatedMax, _maxSpeedLimit);
    return calculatedMax;
  }

  // 向後兼容
  List<double> get data => downloadData;
  double get currentSpeed => currentDownload;
  double getWidthPercentage() => 0.7;
}