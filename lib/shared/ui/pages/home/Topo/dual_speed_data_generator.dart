// lib/shared/ui/pages/home/Topo/dual_speed_data_generator.dart - 新文件

import 'dart:math' as math;
import 'package:whitebox/shared/ui/pages/home/Topo/network_topo_config.dart';

/// 🎯 雙線速度數據生成器 - 同時生成上傳和下載數據
class DualSpeedDataGenerator {
  final int dataPointCount;
  final double minSpeed;
  final double maxSpeed;

  // 下載數據（上方藍綠色線）
  final List<double> _downloadData = [];
  // 上傳數據（下方橙色線）
  final List<double> _uploadData = [];

  final math.Random _random = math.Random();
  final double smoothingFactor;
  final double fluctuationAmplitude;
  final bool useFixedLengthMode;

  DualSpeedDataGenerator({
    this.dataPointCount = 100,
    this.minSpeed = 20,
    this.maxSpeed = 150,
    this.smoothingFactor = 0.8,
    this.fluctuationAmplitude = 15.0,
    this.useFixedLengthMode = true,
  }) {
    _initializeData();
  }

  /// 初始化數據
  void _initializeData() {
    // 🎯 預設值：下載速度較高，上傳速度較低
    const double defaultDownloadSpeed = 93.0; // 下載速度
    const double defaultUploadSpeed = 53.0;   // 上傳速度

    if (useFixedLengthMode) {
      // 填滿整個陣列，添加一些變化讓線條更自然
      for (int i = 0; i < dataPointCount; i++) {
        // 下載數據（變化範圍較大）
        final downloadVariation = (_random.nextDouble() * 20) - 10; // ±10的變化
        final downloadValue = (defaultDownloadSpeed + downloadVariation).clamp(minSpeed, maxSpeed);
        _downloadData.add(downloadValue);

        // 上傳數據（變化範圍較小，速度較低）
        final uploadVariation = (_random.nextDouble() * 10) - 5; // ±5的變化
        final uploadValue = (defaultUploadSpeed + uploadVariation).clamp(minSpeed, maxSpeed);
        _uploadData.add(uploadValue);
      }
    }

    print('✅ 初始化雙線速度數據: 下載 ${_downloadData.length} 點, 上傳 ${_uploadData.length} 點');
  }

  /// 更新數據
  void update() {
    // 生成新的下載速度
    final newDownloadSpeed = _generateNextValue(_downloadData.last, isDownload: true);
    // 生成新的上傳速度
    final newUploadSpeed = _generateNextValue(_uploadData.last, isDownload: false);

    if (useFixedLengthMode) {
      // 固定長度滑動窗口
      _downloadData.removeAt(0);
      _uploadData.removeAt(0);
    }

    _downloadData.add(newDownloadSpeed);
    _uploadData.add(newUploadSpeed);
  }

  /// 生成下一個數據點
  double _generateNextValue(double currentValue, {required bool isDownload}) {
    // 下載速度通常比上傳速度高，變化幅度也較大
    final amplitude = isDownload ? fluctuationAmplitude : fluctuationAmplitude * 0.6;
    final fluctuation = (_random.nextDouble() * amplitude * 2) - amplitude;

    double newValue = currentValue + fluctuation;

    // 偶爾產生較大的變化
    if (_random.nextDouble() < 0.1) {
      final bigChange = (_random.nextDouble() * 20) - 10;
      newValue += bigChange;
    }

    // 確保值在範圍內
    if (newValue < minSpeed) newValue = minSpeed;
    if (newValue > maxSpeed) newValue = maxSpeed;

    return newValue;
  }

  // Getters
  List<double> get downloadData => List.from(_downloadData);
  List<double> get uploadData => List.from(_uploadData);
  double get currentDownloadSpeed => _downloadData.isNotEmpty ? _downloadData.last : 93.0;
  double get currentUploadSpeed => _uploadData.isNotEmpty ? _uploadData.last : 53.0;
  double get widthPercentage => 0.7; // 固定70%
}

/// 🎯 真實雙線速度數據服務
class RealDualSpeedDataService {
  // API 端點（預留）
  static const String speedApiEndpoint = '/api/v1/system/speed/dual';

  // 快取機制
  static double? _cachedDownloadSpeed;
  static double? _cachedUploadSpeed;
  static DateTime? _lastFetchTime;
  static const Duration _cacheExpiry = Duration(seconds: 5);

  /// 檢查快取是否有效
  static bool _isCacheValid() {
    if (_lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheExpiry;
  }

  /// 🎯 獲取當前雙線速度數據
  static Future<Map<String, double>> getCurrentSpeeds() async {
    try {
      // 檢查快取
      if (_isCacheValid() && _cachedDownloadSpeed != null && _cachedUploadSpeed != null) {
        return {
          'download': _cachedDownloadSpeed!,
          'upload': _cachedUploadSpeed!,
        };
      }

      // 🎯 使用配置檔案中的 API 可用性設定
      if (!NetworkTopoConfig.isSpeedApiAvailable) {
        final downloadSpeed = 93.0; // 預設下載速度
        final uploadSpeed = 53.0;   // 預設上傳速度

        // 更新快取
        _cachedDownloadSpeed = downloadSpeed;
        _cachedUploadSpeed = uploadSpeed;
        _lastFetchTime = DateTime.now();

        return {
          'download': downloadSpeed,
          'upload': uploadSpeed,
        };
      }

      // 🎯 TODO: 將來實現真實的 API 呼叫
      /*
      final response = await WifiApiService.getDualSystemSpeed();
      final downloadSpeed = response['download_speed']?.toDouble() ?? 93.0;
      final uploadSpeed = response['upload_speed']?.toDouble() ?? 53.0;

      _cachedDownloadSpeed = downloadSpeed;
      _cachedUploadSpeed = uploadSpeed;
      _lastFetchTime = DateTime.now();

      return {
        'download': downloadSpeed,
        'upload': uploadSpeed,
      };
      */

      return {
        'download': 93.0,
        'upload': 53.0,
      };

    } catch (e) {
      print('❌ 獲取雙線速度數據時發生錯誤: $e');
      return {
        'download': 93.0,
        'upload': 53.0,
      };
    }
  }

  /// 清除快取
  static void clearCache() {
    _cachedDownloadSpeed = null;
    _cachedUploadSpeed = null;
    _lastFetchTime = null;
  }

  /// 🎯 獲取雙線速度歷史數據
  static Future<Map<String, List<double>>> getSpeedHistory({int pointCount = 100}) async {
    try {
      if (!NetworkTopoConfig.isSpeedApiAvailable) {
        final currentSpeeds = await getCurrentSpeeds();
        return {
          'download': List.filled(pointCount, currentSpeeds['download']!),
          'upload': List.filled(pointCount, currentSpeeds['upload']!),
        };
      }

      // 🎯 TODO: 將來實現真實的 API 呼叫
      return {
        'download': List.filled(pointCount, 93.0),
        'upload': List.filled(pointCount, 53.0),
      };

    } catch (e) {
      print('❌ 獲取雙線速度歷史數據時發生錯誤: $e');
      return {
        'download': List.filled(pointCount, 93.0),
        'upload': List.filled(pointCount, 53.0),
      };
    }
  }
}

/// 🎯 真實雙線速度數據生成器
class RealDualSpeedDataGenerator {
  final int dataPointCount;
  final double minSpeed;
  final double maxSpeed;
  final List<double> _downloadData = [];
  final List<double> _uploadData = [];
  final Duration updateInterval;

  RealDualSpeedDataGenerator({
    this.dataPointCount = 100,
    this.minSpeed = 20,
    this.maxSpeed = 150,
    this.updateInterval = const Duration(seconds: 5),
  }) {
    _initializeDataSync();
  }

  /// 同步初始化數據
  void _initializeDataSync() {
    try {
      // 立即使用預設值填充
      final defaultDownload = 93.0;
      final defaultUpload = 53.0;

      _downloadData.clear();
      _uploadData.clear();
      _downloadData.addAll(List.filled(dataPointCount, defaultDownload));
      _uploadData.addAll(List.filled(dataPointCount, defaultUpload));

      print('✅ 同步初始化真實雙線速度數據: ${_downloadData.length} 個點');

      // 異步獲取真實數據（如果 API 可用）
      if (NetworkTopoConfig.isSpeedApiAvailable) {
        _loadRealDataAsync();
      }
    } catch (e) {
      print('❌ 同步初始化真實雙線速度數據失敗: $e');
      // 確保至少有基本數據
      _downloadData.clear();
      _uploadData.clear();
      _downloadData.addAll(List.filled(dataPointCount, 93.0));
      _uploadData.addAll(List.filled(dataPointCount, 53.0));
    }
  }

  /// 異步載入真實數據
  void _loadRealDataAsync() async {
    try {
      final history = await RealDualSpeedDataService.getSpeedHistory(pointCount: dataPointCount);
      if (history['download']!.isNotEmpty && history['upload']!.isNotEmpty) {
        _downloadData.clear();
        _uploadData.clear();
        _downloadData.addAll(history['download']!);
        _uploadData.addAll(history['upload']!);
        print('✅ 異步載入真實雙線速度歷史數據');
      }
    } catch (e) {
      print('❌ 異步載入真實雙線速度數據失敗: $e');
    }
  }

  /// 更新數據
  Future<void> update() async {
    try {
      final newSpeeds = await RealDualSpeedDataService.getCurrentSpeeds();

      // 固定長度滑動窗口
      if (_downloadData.length >= dataPointCount) {
        _downloadData.removeAt(0);
        _uploadData.removeAt(0);
      }

      _downloadData.add(newSpeeds['download']!);
      _uploadData.add(newSpeeds['upload']!);

      print('📈 更新真實雙線速度數據: 下載 ${newSpeeds['download']!.toInt()}, 上傳 ${newSpeeds['upload']!.toInt()} Mbps');
    } catch (e) {
      print('❌ 更新真實雙線速度數據失敗: $e');
    }
  }

  // Getters
  List<double> get downloadData => List.from(_downloadData);
  List<double> get uploadData => List.from(_uploadData);
  double get currentDownloadSpeed => _downloadData.isNotEmpty ? _downloadData.last : 93.0;
  double get currentUploadSpeed => _uploadData.isNotEmpty ? _uploadData.last : 53.0;
  double get widthPercentage => 0.7;
}