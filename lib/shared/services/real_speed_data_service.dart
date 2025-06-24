// lib/shared/services/real_speed_data_service.dart - 添加協調器版本

import 'dart:async';
import 'package:whitebox/shared/api/wifi_api_service.dart';
import 'package:whitebox/shared/ui/pages/home/Topo/network_topo_config.dart';
import 'package:whitebox/shared/utils/api_logger.dart';
import 'package:whitebox/shared/utils/api_coordinator.dart'; // 🔥 新增導入

/// 真實速度資料整合服務
class RealSpeedDataService {
  // 🎯 修改：分別快取上傳和下載速度
  static double? _cachedUploadSpeed;
  static double? _cachedDownloadSpeed;
  static DateTime? _lastUploadFetchTime;
  static DateTime? _lastDownloadFetchTime;

  // 🎯 使用較短的快取時間（5秒），因為速度變化較快
  static Duration get _cacheExpiry => Duration(seconds: NetworkTopoConfig.throughputApiCacheSeconds);

  /// 檢查上傳速度快取是否有效
  static bool _isUploadCacheValid() {
    if (_lastUploadFetchTime == null) return false;
    return DateTime.now().difference(_lastUploadFetchTime!) < _cacheExpiry;
  }

  /// 檢查下載速度快取是否有效
  static bool _isDownloadCacheValid() {
    if (_lastDownloadFetchTime == null) return false;
    return DateTime.now().difference(_lastDownloadFetchTime!) < _cacheExpiry;
  }

  /// 清除快取
  static void clearCache() {
    _cachedUploadSpeed = null;
    _cachedDownloadSpeed = null;
    _lastUploadFetchTime = null;
    _lastDownloadFetchTime = null;
    print('🗑️ 已清除真實速度資料快取');
  }

  /// 🎯 從真實 Throughput API 獲取上傳速度（添加協調器）
  static Future<double> getCurrentUploadSpeed() async {
    // 🔥 快取檢查在協調器之前
    if (_isUploadCacheValid() && _cachedUploadSpeed != null) {
      print('📋 使用快取的上傳速度: ${_cachedUploadSpeed!.toStringAsFixed(6)} Mbps');
      return _cachedUploadSpeed!;
    }

    try {
      // 🔥 使用協調器包裝API調用
      final throughputResult = await ApiCoordinator.coordinatedCall('throughput', () async {
        return await ApiLogger.wrapApiCall(
          method: 'GET',
          endpoint: '/api/v1/system/throughput',
          caller: 'RealSpeedDataService.getCurrentUploadSpeed',
          apiCall: () => WifiApiService.getSystemThroughput(),
        );
      });

      double uploadSpeed = 0.0;

      if (throughputResult is Map<String, dynamic>) {
        if (throughputResult.containsKey('wan') && throughputResult['wan'] is List) {
          final List<dynamic> wanList = throughputResult['wan'];
          if (wanList.isNotEmpty && wanList[0] is Map<String, dynamic>) {
            final wanData = wanList[0] as Map<String, dynamic>;
            final String txSpeedStr = wanData['tx_speed']?.toString() ?? '0';

            final double txSpeedBps = double.tryParse(txSpeedStr) ?? 0.0;

            if (txSpeedBps > 0) {
              uploadSpeed = txSpeedBps / 1000000.0;

              if (uploadSpeed < 0.01 && txSpeedBps > 0) {
                final double kbps = txSpeedBps / 1000.0;
                print('✅ 上傳速度轉換: ${txSpeedStr} bps → ${kbps.toStringAsFixed(2)} Kbps → ${uploadSpeed.toStringAsFixed(6)} Mbps');
              } else {
                print('✅ 上傳速度轉換: ${txSpeedStr} bps → ${uploadSpeed.toStringAsFixed(6)} Mbps');
              }
            } else {
              print('✅ 上傳速度: ${txSpeedStr} bps = 0.00 Mbps (無上傳流量)');
            }
          }
        }
      }

      // 🔥 更新快取
      _cachedUploadSpeed = uploadSpeed;
      _lastUploadFetchTime = DateTime.now();

      return uploadSpeed;
    } catch (e) {
      // 🔥 處理協調器特殊錯誤
      if (e.toString().contains('API call too frequent')) {
        print('🕐 上傳速度API調用過於頻繁，使用快取值');
        return _cachedUploadSpeed ?? 0.0;
      }

      print('❌ 獲取上傳速度時發生錯誤: $e');
      return _cachedUploadSpeed ?? 0.0; // 出錯時返回快取值
    }
  }

  /// 🎯 從真實 Throughput API 獲取下載速度（添加協調器）
  static Future<double> getCurrentDownloadSpeed() async {
    // 🔥 快取檢查在協調器之前
    if (_isDownloadCacheValid() && _cachedDownloadSpeed != null) {
      print('📋 使用快取的下載速度: ${_cachedDownloadSpeed!.toStringAsFixed(6)} Mbps');
      return _cachedDownloadSpeed!;
    }

    try {
      // 🔥 使用協調器包裝API調用
      final throughputResult = await ApiCoordinator.coordinatedCall('throughput', () async {
        return await ApiLogger.wrapApiCall(
          method: 'GET',
          endpoint: '/api/v1/system/throughput',
          caller: 'RealSpeedDataService.getCurrentDownloadSpeed',
          apiCall: () => WifiApiService.getSystemThroughput(),
        );
      });

      double downloadSpeed = 0.0;

      if (throughputResult is Map<String, dynamic>) {
        if (throughputResult.containsKey('wan') && throughputResult['wan'] is List) {
          final List<dynamic> wanList = throughputResult['wan'];
          if (wanList.isNotEmpty && wanList[0] is Map<String, dynamic>) {
            final wanData = wanList[0] as Map<String, dynamic>;
            final String rxSpeedStr = wanData['rx_speed']?.toString() ?? '0';

            final double rxSpeedBps = double.tryParse(rxSpeedStr) ?? 0.0;

            if (rxSpeedBps > 0) {
              downloadSpeed = rxSpeedBps / 1000000.0;

              if (downloadSpeed < 0.01 && rxSpeedBps > 0) {
                final double kbps = rxSpeedBps / 1000.0;
                print('✅ 下載速度轉換: ${rxSpeedStr} bps → ${kbps.toStringAsFixed(2)} Kbps → ${downloadSpeed.toStringAsFixed(6)} Mbps');
              } else {
                print('✅ 下載速度轉換: ${rxSpeedStr} bps → ${downloadSpeed.toStringAsFixed(6)} Mbps');
              }
            } else {
              print('✅ 下載速度: ${rxSpeedStr} bps = 0.00 Mbps (無下載流量)');
            }
          }
        }
      }

      // 🔥 更新快取
      _cachedDownloadSpeed = downloadSpeed;
      _lastDownloadFetchTime = DateTime.now();

      return downloadSpeed;
    } catch (e) {
      // 🔥 處理協調器特殊錯誤
      if (e.toString().contains('API call too frequent')) {
        print('🕐 下載速度API調用過於頻繁，使用快取值');
        return _cachedDownloadSpeed ?? 0.0;
      }

      print('❌ 獲取下載速度時發生錯誤: $e');
      return _cachedDownloadSpeed ?? 0.0; // 出錯時返回快取值
    }
  }

  /// 🎯 獲取上傳速度歷史數據（保持不變）
  static Future<List<double>> getUploadSpeedHistory({int pointCount = 100}) async {
    try {
      final currentSpeed = await getCurrentUploadSpeed();
      final List<double> history = List.filled(pointCount, currentSpeed);
      print('📈 生成上傳速度歷史: ${pointCount} 個點，當前速度 ${currentSpeed.toStringAsFixed(2)} Mbps');
      return history;
    } catch (e) {
      print('❌ 獲取上傳速度歷史時發生錯誤: $e');
      return List.filled(pointCount, 0.0);
    }
  }

  /// 🎯 獲取下載速度歷史數據（保持不變）
  static Future<List<double>> getDownloadSpeedHistory({int pointCount = 100}) async {
    try {
      final currentSpeed = await getCurrentDownloadSpeed();
      final List<double> history = List.filled(pointCount, currentSpeed);
      print('📈 生成下載速度歷史: ${pointCount} 個點，當前速度 ${currentSpeed.toStringAsFixed(2)} Mbps');
      return history;
    } catch (e) {
      print('❌ 獲取下載速度歷史時發生錯誤: $e');
      return List.filled(pointCount, 0.0);
    }
  }
}