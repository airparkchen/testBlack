// lib/shared/utils/jwt_auto_relogin.dart
// JWT 自動重新登入管理器 + API 錯誤容錯處理

import 'dart:async';
import 'dart:convert';
import 'package:whitebox/shared/api/wifi_api/login_process.dart';
import 'package:whitebox/shared/api/wifi_api_service.dart';

/// 增強型 JWT 自動重新登入管理器 + API 容錯處理
class JwtAutoRelogin {
  static JwtAutoRelogin? _instance;
  static JwtAutoRelogin get instance => _instance ??= JwtAutoRelogin._();

  JwtAutoRelogin._();

  // 登入憑證（用於自動重新登入）
  String? _lastUsername;
  String? _lastPassword;

  // 重新登入狀態控制
  bool _isRelogging = false;
  final List<Completer> _waitingCalls = [];

  /// 初始化：儲存登入憑證
  void saveCredentials(String username, String password) {
    _lastUsername = username;
    _lastPassword = password;
    print('🔐 JWT 自動重新登入：已儲存登入憑證 ($username)');
  }

  /// 檢查錯誤是否為 JWT 相關
  bool isJwtError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('jwt') ||
        errorStr.contains('token') ||
        errorStr.contains('unauthorized') ||
        errorStr.contains('401') ||
        errorStr.contains('403') ||
        errorStr.contains('bearer') ||
        errorStr.contains('authentication') ||
        errorStr.contains('認證錯誤');
  }

  /// 檢查是否為臨時性錯誤（應該使用快取而非重新登入）
  bool isTemporaryError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('another api request is busy') ||
        errorStr.contains('api request is busy') ||
        errorStr.contains('busy') ||
        errorStr.contains('timeout') ||
        errorStr.contains('connection') ||
        errorStr.contains('network') ||
        errorStr.contains('請求超時') ||
        errorStr.contains('連線超時');
  }

  /// 檢查 API 回應是否包含臨時性錯誤
  bool isTemporaryErrorResponse(dynamic response) {
    if (response is Map<String, dynamic>) {
      // 檢查 error 欄位
      if (response.containsKey('error')) {
        final errorStr = response['error'].toString().toLowerCase();
        if (errorStr.contains('api request is busy') ||
            errorStr.contains('another api request is busy') ||
            errorStr.contains('busy') ||
            errorStr.contains('timeout') ||
            errorStr.contains('connection')) {
          return true;
        }
      }

      // 檢查 response_body 欄位中的錯誤
      if (response.containsKey('response_body')) {
        final responseBodyStr = response['response_body'].toString().toLowerCase();
        if (responseBodyStr.contains('another api request is busy') ||
            responseBodyStr.contains('api request is busy') ||
            responseBodyStr.contains('busy')) {
          return true;
        }
      }

      // 檢查 message 欄位
      if (response.containsKey('message')) {
        final messageStr = response['message'].toString().toLowerCase();
        if (messageStr.contains('another api request is busy') ||
            messageStr.contains('api request is busy') ||
            messageStr.contains('busy')) {
          return true;
        }
      }
    }

    return false;
  }

  /// 檢查 API 回應是否包含 JWT 錯誤
  bool isJwtErrorResponse(dynamic response) {
    if (response is Map<String, dynamic>) {
      // 檢查 error 欄位
      if (response.containsKey('error')) {
        final errorStr = response['error'].toString().toLowerCase();
        if (errorStr.contains('jwt') || errorStr.contains('token') ||
            errorStr.contains('unauthorized') || errorStr.contains('401') ||
            errorStr.contains('403')) {
          return true;
        }
      }

      // 檢查 response_body 欄位中的 JWT 錯誤
      if (response.containsKey('response_body')) {
        final responseBodyStr = response['response_body'].toString().toLowerCase();
        if (responseBodyStr.contains('jwt token has expired') ||
            (responseBodyStr.contains('jwt') && responseBodyStr.contains('expired')) ||
            (responseBodyStr.contains('token') && responseBodyStr.contains('expired'))) {
          return true;
        }
      }

      // 檢查狀態碼
      if (response.containsKey('status_code')) {
        final statusCode = response['status_code'].toString();
        if (statusCode == '401' || statusCode == '403') {
          return true;
        }
      }
    }

    return false;
  }

  /// 記錄 API 原始資料
  void logApiRawData(String apiName, dynamic rawData, {String? status}) {
    try {
      print('[API_DATA] 📊 $apiName ${status ?? "RAW_DATA"}');

      if (rawData == null) {
        print('[API_DATA]   💀 NULL_RESPONSE');
        return;
      }

      // 格式化輸出
      if (rawData is Map || rawData is List) {
        final jsonStr = const JsonEncoder.withIndent('  ').convert(rawData);
        _printApiDataInChunks(apiName, jsonStr);
      } else {
        final str = rawData.toString();
        if (str.length > 1000) {
          _printApiDataInChunks(apiName, str);
        } else {
          print('[API_DATA]   📄 $str');
        }
      }

      print('[API_DATA] 🏁 $apiName END');
    } catch (e) {
      print('[API_DATA] ❌ $apiName FORMAT_ERROR: $e');
    }
  }

  /// 分段輸出大型 API 資料
  void _printApiDataInChunks(String apiName, String content) {
    const int chunkSize = 800; // 每段 800 字符
    final int totalLength = content.length;
    final int totalChunks = (totalLength / chunkSize).ceil();

    print('[API_DATA]   📏 LENGTH: $totalLength, CHUNKS: $totalChunks');

    for (int i = 0; i < totalChunks; i++) {
      final int start = i * chunkSize;
      final int end = (start + chunkSize < totalLength) ? start + chunkSize : totalLength;
      final String chunk = content.substring(start, end);

      print('[API_DATA]   📋 CHUNK_${i + 1}/$totalChunks: $chunk');
    }
  }

  /// 包裝 API 調用，自動處理 JWT 過期和臨時錯誤，支援快取回退
  Future<T> wrapApiCallWithFallback<T>(
      Future<T> Function() apiCall,
      T? Function()? getCachedData,
      {String? debugInfo}
      ) async {
    // 如果正在重新登入，等待完成
    if (_isRelogging) {
      print('⏸️ API 調用等待重新登入完成... ${debugInfo ?? ""}');
      final completer = Completer<void>();
      _waitingCalls.add(completer);
      await completer.future;
    }

    try {
      final result = await apiCall();

      // 記錄成功的 API 原始資料
      if (debugInfo != null && _shouldLogApiData(debugInfo)) {
        logApiRawData(debugInfo, result, status: 'SUCCESS');
      }

      // 關鍵：檢查回應是否包含臨時性錯誤
      if (isTemporaryErrorResponse(result)) {
        print('⚠️ 檢測到臨時性錯誤，使用快取資料: $result ${debugInfo ?? ""}');

        // 嘗試使用快取資料
        if (getCachedData != null) {
          final cachedData = getCachedData();
          if (cachedData != null) {
            print('📋 使用快取資料避免錯誤顯示 ${debugInfo ?? ""}');
            return cachedData;
          }
        }

        // 如果沒有快取，仍返回錯誤結果但記錄日誌
        print('❌ 無快取資料可用，返回錯誤結果 ${debugInfo ?? ""}');
        return result;
      }

      // 檢查回應是否包含 JWT 錯誤
      if (isJwtErrorResponse(result)) {
        print('❌ 檢測到回應中的 JWT 錯誤: $result ${debugInfo ?? ""}');

        // 執行自動重新登入
        await _performAutoRelogin();

        // 重試 API 調用
        try {
          final retryResult = await apiCall();

          // 記錄重試成功的資料
          if (debugInfo != null && _shouldLogApiData(debugInfo)) {
            logApiRawData(debugInfo, retryResult, status: 'RETRY_SUCCESS');
          }

          return retryResult;
        } catch (retryError) {
          print('❌ 重新登入後仍然失敗: $retryError ${debugInfo ?? ""}');

          // 記錄重試失敗
          if (debugInfo != null && _shouldLogApiData(debugInfo)) {
            logApiRawData(debugInfo, retryError, status: 'RETRY_FAILED');
          }

          // JWT 重新登入失敗時也嘗試使用快取
          if (getCachedData != null) {
            final cachedData = getCachedData();
            if (cachedData != null) {
              print('📋 JWT 重新登入失敗，使用快取資料 ${debugInfo ?? ""}');
              return cachedData;
            }
          }

          throw retryError;
        }
      }

      return result;
    } catch (e) {
      // 記錄異常
      if (debugInfo != null && _shouldLogApiData(debugInfo)) {
        logApiRawData(debugInfo, e, status: 'EXCEPTION');
      }

      print('❌ API 調用異常: $e ${debugInfo ?? ""}');

      // 檢查是否為臨時性錯誤
      if (isTemporaryError(e)) {
        print('⚠️ 檢測到臨時性異常，使用快取資料 ${debugInfo ?? ""}');

        // 嘗試使用快取資料
        if (getCachedData != null) {
          final cachedData = getCachedData();
          if (cachedData != null) {
            print('📋 使用快取資料避免異常錯誤 ${debugInfo ?? ""}');
            return cachedData;
          }
        }
      }

      // 檢查是否為 JWT 相關錯誤
      if (isJwtError(e)) {
        print('❌ 檢測到 JWT 異常錯誤，開始自動重新登入: $e ${debugInfo ?? ""}');

        // 執行自動重新登入
        await _performAutoRelogin();

        // 重試 API 調用
        try {
          final retryResult = await apiCall();

          // 記錄重試成功的資料
          if (debugInfo != null && _shouldLogApiData(debugInfo)) {
            logApiRawData(debugInfo, retryResult, status: 'JWT_RETRY_SUCCESS');
          }

          return retryResult;
        } catch (retryError) {
          print('❌ 重新登入後仍然失敗: $retryError ${debugInfo ?? ""}');

          // 記錄重試失敗
          if (debugInfo != null && _shouldLogApiData(debugInfo)) {
            logApiRawData(debugInfo, retryError, status: 'JWT_RETRY_FAILED');
          }

          // JWT 重新登入失敗時也嘗試使用快取
          if (getCachedData != null) {
            final cachedData = getCachedData();
            if (cachedData != null) {
              print('📋 JWT 重新登入失敗，使用快取資料 ${debugInfo ?? ""}');
              return cachedData;
            }
          }

          throw retryError;
        }
      } else {
        // 其他錯誤，嘗試使用快取
        if (getCachedData != null) {
          final cachedData = getCachedData();
          if (cachedData != null) {
            print('📋 API 錯誤，使用快取資料: $e ${debugInfo ?? ""}');
            return cachedData;
          }
        }

        // 非 JWT 錯誤且無快取，直接拋出
        throw e;
      }
    }
  }

  /// 包裝 API 調用，自動處理 JWT 過期（保持向後兼容）
  Future<T> wrapApiCall<T>(Future<T> Function() apiCall, {String? debugInfo}) async {
    return wrapApiCallWithFallback<T>(apiCall, null, debugInfo: debugInfo);
  }

  /// 判斷是否應該記錄 API 資料
  bool _shouldLogApiData(String debugInfo) {
    final info = debugInfo.toLowerCase();
    return info.contains('dashboard') ||
        info.contains('mesh') ||
        info.contains('throughput');
  }

  /// 執行自動重新登入
  Future<void> _performAutoRelogin() async {
    // 防止重複執行
    if (_isRelogging) {
      print('🔄 已在重新登入中，等待完成...');
      while (_isRelogging) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    if (_lastUsername == null || _lastPassword == null) {
      print('❌ 無法自動重新登入：缺少儲存的登入憑證');
      throw Exception('JWT 過期且無法自動重新登入');
    }

    _isRelogging = true;

    try {
      print('🔐 開始自動重新登入...');
      print('👤 使用者：$_lastUsername');

      // 關鍵：使用現有的 LoginProcess
      final loginProcess = LoginProcess(
          _lastUsername!,
          _lastPassword!,
          baseUrl: WifiApiService.baseUrl
      );

      // 執行 SRP 登入流程
      final loginResult = await loginProcess.startSRPLoginProcess();

      if (loginResult.returnStatus && loginResult.session.jwtToken != null) {
        // 設置新的 JWT token
        WifiApiService.setJwtToken(loginResult.session.jwtToken!);

        print('✅ 自動重新登入成功');
        print('🔐 新 JWT Token 已設置');
      } else {
        print('❌ 自動重新登入失敗：${loginResult.msg}');
        throw Exception('自動重新登入失敗：${loginResult.msg}');
      }
    } catch (e) {
      print('❌ 重新登入過程中發生錯誤：$e');
      throw Exception('重新登入失敗：$e');
    } finally {
      _isRelogging = false;

      // 恢復所有等待的 API 請求
      _resumeWaitingCalls();
    }
  }

  /// 恢復等待中的 API 請求
  void _resumeWaitingCalls() {
    print('🚀 恢復 ${_waitingCalls.length} 個等待中的 API 請求');

    final completers = List<Completer>.from(_waitingCalls);
    _waitingCalls.clear();

    for (final completer in completers) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  /// 清除憑證（登出時使用）
  void clearCredentials() {
    _lastUsername = null;
    _lastPassword = null;
    _isRelogging = false;

    // 完成所有等待的請求
    for (final completer in _waitingCalls) {
      if (!completer.isCompleted) {
        completer.completeError('登入憑證已清除');
      }
    }
    _waitingCalls.clear();

    print('🗑️ JWT 自動重新登入：已清除登入憑證');
  }

  /// 檢查是否有儲存的憑證
  bool get hasCredentials => _lastUsername != null && _lastPassword != null;

  /// 檢查是否正在重新登入
  bool get isRelogging => _isRelogging;
}