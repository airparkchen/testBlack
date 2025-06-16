// lib/shared/services/real_speed_data_service.dart - 修正版本
// 🎯 修正：移除重複的 RealSpeedDataGenerator，設定預設值為0

import 'dart:async';
import 'package:whitebox/shared/api/wifi_api_service.dart';
import 'package:whitebox/shared/ui/pages/home/Topo/network_topo_config.dart';

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
      // 檢查快取
      if (_isCacheValid() && _cachedUploadSpeed != null) {
        return _cachedUploadSpeed!;
      }

      print('🌐 從 Throughput API 獲取上傳速度...');

      // 呼叫真實API
      final throughputResult = await WifiApiService.getSystemThroughput();

      double uploadSpeed = 0.0;

      if (throughputResult is Map<String, dynamic>) {
        // 解析 wan[0].tx_speed
        if (throughputResult.containsKey('wan') && throughputResult['wan'] is List) {
          final List<dynamic> wanList = throughputResult['wan'];
          if (wanList.isNotEmpty && wanList[0] is Map<String, dynamic>) {
            final wanData = wanList[0] as Map<String, dynamic>;
            final String txSpeedStr = wanData['tx_speed']?.toString() ?? '0';

            // 轉換為數字（假設單位為 bps，轉為 Mbps）
            final double txSpeedBps = double.tryParse(txSpeedStr) ?? 0.0;
            uploadSpeed = txSpeedBps / 1000000.0; // bps 轉 Mbps

            print('✅ 解析上傳速度: ${txSpeedStr} bps = ${uploadSpeed.toStringAsFixed(2)} Mbps');
          }
        }
      }

      // 更新快取
      _cachedUploadSpeed = uploadSpeed;
      _lastFetchTime = DateTime.now();

      return uploadSpeed;

    } catch (e) {
      print('❌ 獲取上傳速度時發生錯誤: $e');
      return 0.0; // 錯誤時返回0
    }
  }

  /// 🎯 從真實 Throughput API 獲取下載速度
  static Future<double> getCurrentDownloadSpeed() async {
    try {
      // 檢查快取
      if (_isCacheValid() && _cachedDownloadSpeed != null) {
        return _cachedDownloadSpeed!;
      }

      print('🌐 從 Throughput API 獲取下載速度...');

      // 呼叫真實API
      final throughputResult = await WifiApiService.getSystemThroughput();

      double downloadSpeed = 0.0;

      if (throughputResult is Map<String, dynamic>) {
        // 解析 wan[0].rx_speed
        if (throughputResult.containsKey('wan') && throughputResult['wan'] is List) {
          final List<dynamic> wanList = throughputResult['wan'];
          if (wanList.isNotEmpty && wanList[0] is Map<String, dynamic>) {
            final wanData = wanList[0] as Map<String, dynamic>;
            final String rxSpeedStr = wanData['rx_speed']?.toString() ?? '0';

            // 轉換為數字（假設單位為 bps，轉為 Mbps）
            final double rxSpeedBps = double.tryParse(rxSpeedStr) ?? 0.0;
            downloadSpeed = rxSpeedBps / 1000000.0; // bps 轉 Mbps

            print('✅ 解析下載速度: ${rxSpeedStr} bps = ${downloadSpeed.toStringAsFixed(2)} Mbps');
          }
        }
      }

      // 更新快取
      _cachedDownloadSpeed = downloadSpeed;
      _lastFetchTime = DateTime.now();

      return downloadSpeed;

    } catch (e) {
      print('❌ 獲取下載速度時發生錯誤: $e');
      return 0.0; // 錯誤時返回0
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