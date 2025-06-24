// lib/shared/utils/api_coordinator.dart
class ApiCoordinator {
  static DateTime? _lastApiCall;
  static const Duration _minInterval = Duration(seconds: 3);
  static final Map<String, DateTime> _lastCallByType = {};

  // 🎯 新增：協調器開關
  static bool _enableCoordination = false;

  /// 🎯 啟用/停用協調器
  static void setEnabled(bool enabled) {
    _enableCoordination = enabled;
    print('🎛️ API協調器：${enabled ? "啟用" : "停用"}');
  }

  /// 🎯 檢查協調器是否啟用
  static bool get isEnabled => _enableCoordination;

  /// 🎯 條件式協調調用
  static Future<T> coordinatedCall<T>(
      String apiType,
      Future<T> Function() apiCall,
      ) async {
    // 🔥 關鍵：如果協調器停用，直接調用API
    if (!_enableCoordination) {
      print('🚀 [$apiType] 協調器已停用，直接調用API');
      return await apiCall();
    }

    // 🔥 協調器啟用時的原有邏輯
    final now = DateTime.now();

    // 檢查總體間隔
    if (_lastApiCall != null) {
      final timeSinceLastCall = now.difference(_lastApiCall!);
      if (timeSinceLastCall < _minInterval) {
        final waitTime = _minInterval - timeSinceLastCall;
        print('🕐 [$apiType] 等待 ${waitTime.inMilliseconds}ms 避免API衝突');
        await Future.delayed(waitTime);
      }
    }

    // 檢查同類型API間隔
    final lastCallOfType = _lastCallByType[apiType];
    if (lastCallOfType != null) {
      final typeInterval = now.difference(lastCallOfType);
      Duration minTypeInterval;

      switch (apiType) {
        case 'dashboard':
          minTypeInterval = Duration(seconds: 2);
          break;
        case 'mesh':
          minTypeInterval = Duration(seconds: 5);
          break;
        case 'throughput':
          minTypeInterval = Duration(seconds: 2);
          break;
        default:
          minTypeInterval = Duration(seconds: 5);
      }

      if (typeInterval < minTypeInterval) {
        print('🔄 [$apiType] 同類型API調用間隔太短，跳過此次調用');
        throw Exception('API call too frequent');
      }
    }

    try {
      print('🌐 [$apiType] 開始協調API調用');
      final result = await apiCall();
      _lastApiCall = DateTime.now();
      _lastCallByType[apiType] = _lastApiCall!;
      print('✅ [$apiType] API調用成功');
      return result;
    } catch (e) {
      print('❌ [$apiType] API調用失敗: $e');
      rethrow;
    }
  }

  /// 🎯 重置協調器狀態
  static void reset() {
    _lastApiCall = null;
    _lastCallByType.clear();
    print('🔄 API協調器：狀態已重置');
  }

  /// 🎯 臨時啟用協調器執行操作
  static Future<T> withCoordination<T>(Future<T> Function() operation) async {
    final wasEnabled = _enableCoordination;

    try {
      setEnabled(true);
      reset(); // 重置狀態確保乾淨開始
      return await operation();
    } finally {
      setEnabled(wasEnabled); // 恢復原有狀態
    }
  }
}