// lib/shared/utils/api_logger.dart
// 安全的 API 日誌系統 - 完全不影響現有功能

import 'dart:convert';

/// 非侵入式 API 日誌追蹤器
/// 只記錄，不改變任何現有邏輯
class ApiLogger {
  static const String logTag = '[API_LOG]';
  static int _callCounter = 0;
  static final Map<String, ApiCallInfo> _activeCalls = {};

  /// 🔍 包裝現有的 API 調用，添加日誌但不改變功能
  static Future<T> wrapApiCall<T>({
    required String method,
    required String endpoint,
    required Future<T> Function() apiCall,
    String? caller,
    Map<String, dynamic>? requestData,
  }) async {
    _callCounter++;
    final String callId = 'call_$_callCounter';
    final DateTime startTime = DateTime.now();

    // 記錄調用資訊
    _activeCalls[callId] = ApiCallInfo(
      callId: callId,
      method: method,
      endpoint: endpoint,
      caller: caller ?? 'Unknown',
      startTime: startTime,
    );

    // 輸出開始日誌
    _logStart(callId, method, endpoint, caller ?? 'Unknown', startTime, requestData);

    try {
      // 🔥 關鍵：完全不改變原有的 API 調用邏輯
      final result = await apiCall();

      // 記錄成功
      _logSuccess(callId, result, startTime);

      return result;

    } catch (e) {
      // 記錄錯誤
      _logError(callId, e, startTime);

      // 🔥 重要：重新拋出原始錯誤，保持現有錯誤處理邏輯
      rethrow;
    } finally {
      _activeCalls.remove(callId);
    }
  }

  /// 簡單的調用記錄（適用於無法包裝的場合）
  static void logApiCall({
    required String method,
    required String endpoint,
    String? caller,
    String? status,
    dynamic result,
    dynamic error,
  }) {
    _callCounter++;
    final time = DateTime.now();
    final timeStr = _formatTime(time);

    print('$logTag 📞 CALL [$_callCounter] $method $endpoint');
    print('$logTag   📍 Caller: ${caller ?? "Unknown"}');
    print('$logTag   ⏰ Time: $timeStr');

    if (status != null) {
      print('$logTag   📊 Status: $status');
    }

    if (error != null) {
      print('$logTag   ❌ Error: $error');
    } else if (result != null) {
      print('$logTag   ✅ Result: ${_formatResponseData(result)}');
    }
  }

  /// 記錄API衝突（當多個API同時調用時）
  static void logApiConflict({
    required String endpoint,
    required String caller,
    required String conflictReason,
  }) {
    print('$logTag ⚡ CONFLICT $endpoint');
    print('$logTag   📍 Caller: $caller');
    print('$logTag   ⚠️ Reason: $conflictReason');
    print('$logTag   ⏰ Time: ${_formatTime(DateTime.now())}');
  }

  /// 記錄API被跳過
  static void logApiSkipped({
    required String endpoint,
    required String caller,
    required String reason,
  }) {
    print('$logTag ⏭️ SKIPPED $endpoint');
    print('$logTag   📍 Caller: $caller');
    print('$logTag   💡 Reason: $reason');
    print('$logTag   ⏰ Time: ${_formatTime(DateTime.now())}');
  }

  /// 獲取當前活躍的調用狀態
  static void logActiveCallsStatus() {
    if (_activeCalls.isEmpty) {
      print('$logTag 📊 STATUS: No active API calls');
      return;
    }

    print('$logTag 📊 STATUS: ${_activeCalls.length} active API calls:');
    for (final callInfo in _activeCalls.values) {
      final Duration duration = DateTime.now().difference(callInfo.startTime);
      print('$logTag   🔄 [${callInfo.callId}] ${callInfo.method} ${callInfo.endpoint} (${duration.inSeconds}s)');
      print('$logTag      📍 Caller: ${callInfo.caller}');
    }
  }

  // 私有方法，內部使用
  static void _logStart(String callId, String method, String endpoint, String caller, DateTime startTime, Map<String, dynamic>? requestData) {
    print('$logTag 🚀 START [$callId] $method $endpoint');
    print('$logTag   📍 Caller: $caller');
    print('$logTag   ⏰ Start Time: ${_formatTime(startTime)}');
    print('$logTag   🔢 Call Counter: $_callCounter');

    if (requestData != null && requestData.isNotEmpty) {
      print('$logTag   📤 Request Data: ${_formatJson(requestData)}');
    }
  }

  static void _logSuccess(String callId, dynamic result, DateTime startTime) {
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);
    final callInfo = _activeCalls[callId];

    if (callInfo != null) {
      print('$logTag ✅ SUCCESS [$callId] ${callInfo.method} ${callInfo.endpoint}');
      print('$logTag   📍 Caller: ${callInfo.caller}');
      print('$logTag   ⏱️ Duration: ${duration.inMilliseconds}ms');
      print('$logTag   📥 Response: ${_formatResponseData(result)}');
      print('$logTag   🏁 End Time: ${_formatTime(endTime)}');
    }
  }

  static void _logError(String callId, dynamic error, DateTime startTime) {
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);
    final callInfo = _activeCalls[callId];

    if (callInfo != null) {
      print('$logTag ❌ ERROR [$callId] ${callInfo.method} ${callInfo.endpoint}');
      print('$logTag   📍 Caller: ${callInfo.caller}');
      print('$logTag   ⏱️ Duration: ${duration.inMilliseconds}ms');
      print('$logTag   💥 Error: $error');
      print('$logTag   🏁 End Time: ${_formatTime(endTime)}');
    }
  }

  static String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}.'
        '${time.millisecond.toString().padLeft(3, '0')}';
  }

  static String _formatResponseData(dynamic data) {
    if (data == null) return 'null';

    try {
      if (data is Map || data is List) {
        final jsonStr = json.encode(data);
        if (jsonStr.length > 300) {
          if (data is Map) {
            return 'Map with ${data.length} keys: [${data.keys.take(3).join(', ')}${data.length > 3 ? ', ...' : ''}]';
          } else if (data is List) {
            return 'List with ${data.length} items';
          }
        }
        return jsonStr;
      } else {
        final str = data.toString();
        return str.length > 300 ? str.substring(0, 300) + '...' : str;
      }
    } catch (e) {
      return 'Error formatting data: $e';
    }
  }

  static String _formatJson(Map<String, dynamic> data) {
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (e) {
      return data.toString();
    }
  }

  static Map<String, dynamic> getStatistics() {
    return {
      'totalCalls': _callCounter,
      'activeCalls': _activeCalls.length,
      'activeCallIds': _activeCalls.keys.toList(),
    };
  }
}

class ApiCallInfo {
  final String callId;
  final String method;
  final String endpoint;
  final String caller;
  final DateTime startTime;

  ApiCallInfo({
    required this.callId,
    required this.method,
    required this.endpoint,
    required this.caller,
    required this.startTime,
  });
}