// lib/shared/services/dashboard_event_notifier.dart
import 'package:whitebox/shared/services/dashboard_data_service.dart';
import 'package:whitebox/shared/models/dashboard_data_models.dart';
//用來讓其他頁面取得dashboard資訊，避免重複呼叫dashboard api

/// Dashboard API 事件通知器
class DashboardEventNotifier {
  // 成功監聽器列表
  static final List<Function(DashboardData)> _successListeners = [];

  // 錯誤監聽器列表
  static final List<Function(dynamic)> _errorListeners = [];

  /// 註冊 Dashboard API 成功監聽器
  static void addSuccessListener(Function(DashboardData) listener) {
    _successListeners.add(listener);
    print('📝 Dashboard 成功監聽器已註冊，總數: ${_successListeners.length}');
  }

  /// 註冊 Dashboard API 錯誤監聽器
  static void addErrorListener(Function(dynamic) listener) {
    _errorListeners.add(listener);
    print('📝 Dashboard 錯誤監聽器已註冊，總數: ${_errorListeners.length}');
  }

  /// 移除成功監聽器
  static void removeSuccessListener(Function(DashboardData) listener) {
    _successListeners.remove(listener);
    print('🗑️ Dashboard 成功監聽器已移除，剩餘: ${_successListeners.length}');
  }

  /// 移除錯誤監聽器
  static void removeErrorListener(Function(dynamic) listener) {
    _errorListeners.remove(listener);
    print('🗑️ Dashboard 錯誤監聽器已移除，剩餘: ${_errorListeners.length}');
  }

  /// 通知所有監聽器：Dashboard API 調用成功
  static void notifySuccess(DashboardData data) {
    if (_successListeners.isNotEmpty) {
      print('📢 Dashboard API 成功，通知 ${_successListeners.length} 個監聽器');

      for (final listener in _successListeners) {
        try {
          listener(data);
        } catch (e) {
          print('❌ Dashboard 成功監聽器執行錯誤: $e');
        }
      }
    }
  }

  /// 通知所有監聽器：Dashboard API 調用失敗
  static void notifyError(dynamic error) {
    if (_errorListeners.isNotEmpty) {
      print('📢 Dashboard API 失敗，通知 ${_errorListeners.length} 個錯誤監聽器: $error');

      for (final listener in _errorListeners) {
        try {
          listener(error);
        } catch (e) {
          print('❌ Dashboard 錯誤監聽器執行錯誤: $e');
        }
      }
    }
  }

  /// 清除所有監聽器（用於應用關閉或重置）
  static void clearAllListeners() {
    _successListeners.clear();
    _errorListeners.clear();
    print('🗑️ 所有 Dashboard 監聽器已清除');
  }

  /// 獲取監聽器統計資訊（調試用）
  static Map<String, int> getListenerStats() {
    return {
      'successListeners': _successListeners.length,
      'errorListeners': _errorListeners.length,
    };
  }
}