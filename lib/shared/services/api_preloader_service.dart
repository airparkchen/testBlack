// lib/shared/services/api_preloader_service.dart - 增強版本
// 確保每一筆資料都成功載入，有錯誤則重試

import 'package:whitebox/shared/services/dashboard_data_service.dart';
import 'package:whitebox/shared/services/real_data_integration_service.dart';
import 'package:whitebox/shared/services/real_speed_data_service.dart';
import 'package:whitebox/shared/utils/api_coordinator.dart';

class ApiPreloaderService {
  static bool _isPreloading = false;
  static bool _isPreloaded = false;

  /// 🔥 增強：預載入時確保每筆資料都成功載入
  static Future<void> preloadAllAPIs() async {
    if (_isPreloading || _isPreloaded) {
      print('🔄 API 預載入已在進行中或已完成');
      return;
    }

    _isPreloading = true;
    print('🚀 開始預載入所有 API 資料...');

    try {
      // 🎯 關鍵：只在預載入時啟用協調器
      await ApiCoordinator.withCoordination(() async {
        print('📡 [1/3] 預載入 Dashboard API（確保成功）...');
        final dashboardResult = await _preloadDashboardAPIWithRetry();

        print('🌐 [2/3] 預載入 Mesh API（確保成功）...');
        final meshResult = await _preloadMeshAPIWithRetry();

        print('💨 [3/3] 預載入 Throughput API（確保成功）...');
        final throughputResult = await _preloadThroughputAPIWithRetry();

        // 統計結果
        final results = [meshResult, dashboardResult, throughputResult];
        final successCount = results.where((result) => result == true).length;

        print('✅ 預載入完成：$successCount/3 個 API 成功載入');
        print('📊 詳細結果:');
        print('   Dashboard API: ${dashboardResult ? "✅" : "❌"}');
        print('   Mesh API: ${meshResult ? "✅" : "❌"}');
        print('   Throughput API: ${throughputResult ? "✅" : "❌"}');

        // 🔥 新增：如果有任何失敗，整個預載入重新開始
        if (successCount < 3) {
          print('⚠️ 有 API 載入失敗，2秒後重新嘗試整個預載入流程...');
          await Future.delayed(Duration(seconds: 2));
          _isPreloading = false;
          _isPreloaded = false;
          return await preloadAllAPIs(); // 遞迴重試整個流程
        }
      });

      _isPreloaded = true;

    } catch (e) {
      print('❌ API 預載入過程中發生錯誤: $e');
      _isPreloading = false;
      _isPreloaded = false;

      // 預載入失敗，2秒後重試
      print('🔄 2秒後重新嘗試預載入...');
      await Future.delayed(Duration(seconds: 2));
      return await preloadAllAPIs();
    } finally {
      _isPreloading = false;
      // 🎯 預載入完成後確保協調器停用
      ApiCoordinator.setEnabled(false);
      print('🎛️ 預載入完成，協調器已停用，後續API調用恢復高速模式');
    }
  }

  /// 🔥 新增：Dashboard API 重試載入（確保成功）
  static Future<bool> _preloadDashboardAPIWithRetry() async {
    const int maxRetries = 5;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('📊 Dashboard API 載入嘗試 $attempt/$maxRetries...');
        final startTime = DateTime.now();

        await DashboardDataService.getDashboardData(forceRefresh: true);

        final duration = DateTime.now().difference(startTime);
        print('✅ Dashboard API 載入成功，耗時: ${duration.inMilliseconds}ms');
        return true;

      } catch (e) {
        print('❌ Dashboard API 載入失敗（嘗試 $attempt/$maxRetries): $e');

        if (attempt < maxRetries) {
          final delaySeconds = attempt; // 遞增延遲：1s, 2s, 3s, 4s
          print('⏳ ${delaySeconds}秒後重試...');
          await Future.delayed(Duration(seconds: delaySeconds));
        } else {
          print('💀 Dashboard API 達到最大重試次數，載入失敗');
          return false;
        }
      }
    }

    return false;
  }

  /// 🔥 新增：Mesh API 重試載入（確保成功）
  static Future<bool> _preloadMeshAPIWithRetry() async {
    const int maxRetries = 5;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('🌐 Mesh API 載入嘗試 $attempt/$maxRetries...');
        final startTime = DateTime.now();

        await RealDataIntegrationService.forceReload();

        final duration = DateTime.now().difference(startTime);
        print('✅ Mesh API 載入成功，耗時: ${duration.inMilliseconds}ms');
        return true;

      } catch (e) {
        print('❌ Mesh API 載入失敗（嘗試 $attempt/$maxRetries): $e');

        if (attempt < maxRetries) {
          final delaySeconds = attempt; // 遞增延遲：1s, 2s, 3s, 4s
          print('⏳ ${delaySeconds}秒後重試...');
          await Future.delayed(Duration(seconds: delaySeconds));
        } else {
          print('💀 Mesh API 達到最大重試次數，載入失敗');
          return false;
        }
      }
    }

    return false;
  }

  /// 🔥 新增：Throughput API 重試載入（確保成功）
  static Future<bool> _preloadThroughputAPIWithRetry() async {
    const int maxRetries = 5;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('💨 Throughput API 載入嘗試 $attempt/$maxRetries...');
        final startTime = DateTime.now();

        // 同時載入上傳和下載速度
        final uploadFuture = RealSpeedDataService.getCurrentUploadSpeed();
        final downloadFuture = RealSpeedDataService.getCurrentDownloadSpeed();

        final results = await Future.wait([uploadFuture, downloadFuture]);
        final uploadSpeed = results[0];
        final downloadSpeed = results[1];

        final duration = DateTime.now().difference(startTime);
        print('✅ Throughput API 載入成功，耗時: ${duration.inMilliseconds}ms');
        print('   上傳速度: ${uploadSpeed.toStringAsFixed(4)} Mbps');
        print('   下載速度: ${downloadSpeed.toStringAsFixed(4)} Mbps');
        return true;

      } catch (e) {
        print('❌ Throughput API 載入失敗（嘗試 $attempt/$maxRetries): $e');

        if (attempt < maxRetries) {
          final delaySeconds = attempt; // 遞增延遲：1s, 2s, 3s, 4s
          print('⏳ ${delaySeconds}秒後重試...');
          await Future.delayed(Duration(seconds: delaySeconds));
        } else {
          print('💀 Throughput API 達到最大重試次數，載入失敗');
          return false;
        }
      }
    }

    return false;
  }

  /// 🔥 移除：原有的單次嘗試方法（已被重試版本取代）

  /// 重置預載入狀態（登出時調用）
  static void reset() {
    _isPreloading = false;
    _isPreloaded = false;
    print('🔄 API 預載入狀態已重置');
  }

  /// 檢查是否已預載入
  static bool get isPreloaded => _isPreloaded;

  /// 檢查是否正在預載入
  static bool get isPreloading => _isPreloading;
}