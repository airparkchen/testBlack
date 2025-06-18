import 'package:whitebox/shared/services/dashboard_data_service.dart';
import 'package:whitebox/shared/services/real_data_integration_service.dart';
import 'package:whitebox/shared/services/real_speed_data_service.dart';


class ApiPreloaderService {
  static bool _isPreloading = false;
  static bool _isPreloaded = false;

  /// 登入成功後立即預載入所有必要的 API 資料
  static Future<void> preloadAllAPIs() async {
    if (_isPreloading || _isPreloaded) {
      print('🔄 API 預載入已在進行中或已完成');
      return;
    }

    _isPreloading = true;
    print('🚀 開始預載入所有 API 資料...');

    try {
      // 並行載入所有 API（最快的方式）
      final results = await Future.wait([
        _preloadMeshAPI(),
        _preloadDashboardAPI(),
        _preloadThroughputAPI(),
      ], eagerError: false); // eagerError: false 表示即使某個失敗也繼續執行其他

      // 統計成功載入的 API 數量
      final successCount = results.where((result) => result == true).length;
      print('✅ 預載入完成：$successCount/3 個 API 成功載入');

      _isPreloaded = true;

    } catch (e) {
      print('❌ API 預載入過程中發生錯誤: $e');
    } finally {
      _isPreloading = false;
    }
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

      // 強制重新載入（忽略快取）
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

      // 同時載入上傳和下載速度
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