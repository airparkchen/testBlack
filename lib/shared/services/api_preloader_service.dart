import 'package:whitebox/shared/services/dashboard_data_service.dart';
import 'package:whitebox/shared/services/real_data_integration_service.dart';
import 'package:whitebox/shared/services/real_speed_data_service.dart';
import 'package:whitebox/shared/utils/api_coordinator.dart';

class ApiPreloaderService {
  static bool _isPreloading = false;
  static bool _isPreloaded = false;

  /// 🔥 修改：預載入時啟用協調器
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
        print('📡 [1/3] 預載入 Dashboard API（協調模式）...');
        final dashboardResult = await _preloadDashboardAPI();

        print('🌐 [2/3] 預載入 Mesh API（協調模式）...');
        final meshResult = await _preloadMeshAPI();

        print('💨 [3/3] 預載入 Throughput API（協調模式）...');
        final throughputResult = await _preloadThroughputAPI();

        // 統計結果
        final results = [meshResult, dashboardResult, throughputResult];
        final successCount = results.where((result) => result == true).length;

        print('✅ 協調預載入完成：$successCount/3 個 API 成功載入');
        print('📊 詳細結果:');
        print('   Dashboard API: ${dashboardResult ? "✅" : "❌"}');
        print('   Mesh API: ${meshResult ? "✅" : "❌"}');
        print('   Throughput API: ${throughputResult ? "✅" : "❌"}');
      });

      _isPreloaded = true;

    } catch (e) {
      print('❌ API 預載入過程中發生錯誤: $e');
    } finally {
      _isPreloading = false;
      // 🎯 預載入完成後確保協調器停用
      ApiCoordinator.setEnabled(false);
      print('🎛️ 預載入完成，協調器已停用，後續API調用恢復高速模式');
    }
  }

  static Future<void> _smartDelay(String apiName) async {
    // 根據API類型設定不同延遲
    int delaySeconds = 1;

    if (apiName.contains('Dashboard')) {
      delaySeconds = 1;  // Dashboard API 需要更多時間
    } else if (apiName.contains('Mesh')) {
      delaySeconds = 1;  // Mesh API 資料量大
    } else {
      delaySeconds = 1;  // Throughput API 較輕量
    }

    print('⏰ 等待 $delaySeconds 秒避免與 $apiName 衝突...');
    await Future.delayed(Duration(seconds: delaySeconds));
  }

  /// 預載入 Mesh Topology API
  static Future<bool> _preloadMeshAPI() async {
    try {
      print('🌐 預載入 Mesh API...');
      final startTime = DateTime.now();

      await RealDataIntegrationService.forceReload();

      final duration = DateTime.now().difference(startTime);
      print('✅ Mesh API 預載入成功，耗時: ${duration.inMilliseconds}ms');
      return true;

    } catch (e) {
      print('❌ Mesh API 預載入失敗: $e');
      return false;
    }
  }

  /// 預載入 Dashboard API
  static Future<bool> _preloadDashboardAPI() async {
    try {
      print('📊 預載入 Dashboard API...');
      final startTime = DateTime.now();

      await DashboardDataService.getDashboardData(forceRefresh: true);

      final duration = DateTime.now().difference(startTime);
      print('✅ Dashboard API 預載入成功，耗時: ${duration.inMilliseconds}ms');
      return true;

    } catch (e) {
      print('❌ Dashboard API 預載入失敗: $e');
      return false;
    }
  }

  /// 預載入 Throughput API
  static Future<bool> _preloadThroughputAPI() async {
    try {
      print('💨 預載入 Throughput API...');
      final startTime = DateTime.now();

      final uploadFuture = RealSpeedDataService.getCurrentUploadSpeed();
      final downloadFuture = RealSpeedDataService.getCurrentDownloadSpeed();

      await Future.wait([uploadFuture, downloadFuture]);

      final duration = DateTime.now().difference(startTime);
      print('✅ Throughput API 預載入成功，耗時: ${duration.inMilliseconds}ms');
      return true;

    } catch (e) {
      print('❌ Throughput API 預載入失敗: $e');
      return false;
    }
  }

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