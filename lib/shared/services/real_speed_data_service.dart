// lib/shared/services/real_speed_data_service.dart - 修正版本
// 🎯 修正：移除重複的 RealSpeedDataGenerator，設定預設值為0

import 'dart:async';
import 'package:whitebox/shared/api/wifi_api_service.dart';
import 'package:whitebox/shared/ui/pages/home/Topo/network_topo_config.dart';
import 'package:whitebox/shared/utils/api_logger.dart';

/// 真實速度資料整合服務
class RealSpeedDataService {
  // 快取機制
  static double? _cachedUploadSpeed;
  static double? _cachedDownloadSpeed;
  static DateTime? _lastFetchTime;

  // 🎯 使用統一的10秒快取時間
  static Duration get _cacheExpiry => NetworkTopoConfig.actualCacheDuration;

  /// 檢查快取是否有效
  static bool _isCacheValid() {
    if (_lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheExpiry;
  }

  /// 清除快取
  static void clearCache() {
    _cachedUploadSpeed = null;
    _cachedDownloadSpeed = null;
    _lastFetchTime = null;
    print('🗑️ 已清除真實速度資料快取');
  }

  /// 🎯 從真實 Throughput API 獲取上傳速度
  static Future<double> getCurrentUploadSpeed() async {
    try {
      final throughputResult = await ApiLogger.wrapApiCall(
        method: 'GET',
        endpoint: '/api/v1/system/throughput',
        caller: 'RealSpeedDataService.getCurrentUploadSpeed',
        apiCall: () => WifiApiService.getSystemThroughput(),
      );

      double uploadSpeed = 0.0;

      if (throughputResult is Map<String, dynamic>) {
        if (throughputResult.containsKey('wan') && throughputResult['wan'] is List) {
          final List<dynamic> wanList = throughputResult['wan'];
          if (wanList.isNotEmpty && wanList[0] is Map<String, dynamic>) {
            final wanData = wanList[0] as Map<String, dynamic>;
            final String txSpeedStr = wanData['tx_speed']?.toString() ?? '0';

            // 🎯 改善：保留更多精度的數字轉換
            final double txSpeedBps = double.tryParse(txSpeedStr) ?? 0.0;

            if (txSpeedBps > 0) {
              // 轉換 bps 到 Mbps，保留更多精度（不要過早四捨五入）
              uploadSpeed = txSpeedBps / 1000000.0;

              // 🎯 詳細調試輸出，幫助理解數據轉換
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

      return uploadSpeed;
    } catch (e) {
      print('❌ 獲取上傳速度時發生錯誤: $e');
      return 0.0;
    }
  }

  /// 🎯 從真實 Throughput API 獲取下載速度
  /// 🎯 修正：獲取下載速度 - 改善轉換邏輯
  static Future<double> getCurrentDownloadSpeed() async {
    try {
      final throughputResult = await ApiLogger.wrapApiCall(
        method: 'GET',
        endpoint: '/api/v1/system/throughput',
        caller: 'RealSpeedDataService.getCurrentDownloadSpeed',
        apiCall: () => WifiApiService.getSystemThroughput(),
      );

      double downloadSpeed = 0.0;

      if (throughputResult is Map<String, dynamic>) {
        if (throughputResult.containsKey('wan') && throughputResult['wan'] is List) {
          final List<dynamic> wanList = throughputResult['wan'];
          if (wanList.isNotEmpty && wanList[0] is Map<String, dynamic>) {
            final wanData = wanList[0] as Map<String, dynamic>;
            final String rxSpeedStr = wanData['rx_speed']?.toString() ?? '0';

            // 🎯 改善：保留更多精度的數字轉換
            final double rxSpeedBps = double.tryParse(rxSpeedStr) ?? 0.0;

            if (rxSpeedBps > 0) {
              // 轉換 bps 到 Mbps，保留更多精度（不要過早四捨五入）
              downloadSpeed = rxSpeedBps / 1000000.0;

              // 🎯 詳細調試輸出，幫助理解數據轉換
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

      return downloadSpeed;
    } catch (e) {
      print('❌ 獲取下載速度時發生錯誤: $e');
      return 0.0;
    }
  }


  /// 🎯 獲取上傳速度歷史數據（真實API模式）
  static Future<List<double>> getUploadSpeedHistory({int pointCount = 100}) async {
    try {
      final currentSpeed = await getCurrentUploadSpeed();

      // 🎯 真實API模式：返回全為當前速度的直線（因為我們沒有歷史資料）
      final List<double> history = List.filled(pointCount, currentSpeed);

      print('📈 生成上傳速度歷史: ${pointCount} 個點，當前速度 ${currentSpeed.toStringAsFixed(2)} Mbps');
      return history;

    } catch (e) {
      print('❌ 獲取上傳速度歷史時發生錯誤: $e');
      return List.filled(pointCount, 0.0);
    }
  }

  /// 🎯 獲取下載速度歷史數據（真實API模式）
  static Future<List<double>> getDownloadSpeedHistory({int pointCount = 100}) async {
    try {
      final currentSpeed = await getCurrentDownloadSpeed();

      // 🎯 真實API模式：返回全為當前速度的直線（因為我們沒有歷史資料）
      final List<double> history = List.filled(pointCount, currentSpeed);

      print('📈 生成下載速度歷史: ${pointCount} 個點，當前速度 ${currentSpeed.toStringAsFixed(2)} Mbps');
      return history;

    } catch (e) {
      print('❌ 獲取下載速度歷史時發生錯誤: $e');
      return List.filled(pointCount, 0.0);
    }
  }
}