import 'package:whitebox/shared/services/dashboard_data_service.dart';
import 'package:whitebox/shared/services/real_data_integration_service.dart';
import 'package:whitebox/shared/services/real_speed_data_service.dart';


class ApiPreloaderService {
  static bool _isPreloading = false;
  static bool _isPreloaded = false;

  /// 修改後的預載入方法
  static Future<void> preloadAllAPIs() async {
    if (_isPreloading || _isPreloaded) {
      print('🔄 API 預載入已在進行中或已完成');
      return;
    }

    _isPreloading = true;
    print('🚀 開始序列化預載入所有 API 資料...');

    try {
      // 🔥 序列化調用，智能延遲
      print('📡 [1/3] 預載入 Mesh API...');
      final meshResult = await _preloadMeshAPI();

      await _smartDelay('Mesh API 完成');

      print('📊 [2/3] 預載入 Dashboard API...');
      final dashboardResult = await _preloadDashboardAPI();

      await _smartDelay('Dashboard API 完成');

      print('💨 [3/3] 預載入 Throughput API...');
      final throughputResult = await _preloadThroughputAPI();

      // 統計結果
      final results = [meshResult, dashboardResult, throughputResult];
      final successCount = results.where((result) => result == true).length;

      print('✅ 序列化預載入完成：$successCount/3 個 API 成功載入');
      print('📊 詳細結果:');
      print('   Mesh API: ${meshResult ? "✅" : "❌"}');
      print('   Dashboard API: ${dashboardResult ? "✅" : "❌"}');
      print('   Throughput API: ${throughputResult ? "✅" : "❌"}');
      print('⏱️ 總耗時約: ${3 + 2}秒 (含延遲)');

      _isPreloaded = true;

    } catch (e) {
      print('❌ API 預載入過程中發生錯誤: $e');
    } finally {
      _isPreloading = false;
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

      // 強制重新載入（忽略快取）
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

      // 🔥 修復：改為使用快取，而非強制刷新
      await DashboardDataService.getDashboardData(forceRefresh: false);  // 改為 false

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

      // 同時載入上傳和下載速度
      final uploadFuture = RealSpeedDataService.getCurrentUploadSpeed();
      await Future.delayed(Duration(milliseconds: 100));
      final downloadFuture = RealSpeedDataService.getCurrentDownloadSpeed();

      // await Future.wait([uploadFuture, downloadFuture]);

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