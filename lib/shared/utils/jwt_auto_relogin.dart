// lib/shared/utils/jwt_auto_relogin.dart
// JWT 自動重新登入管理器 - 使用現有 LoginProcess 的最小修改版本

import 'dart:async';
import 'dart:convert';
import 'package:whitebox/shared/api/wifi_api/login_process.dart';
import 'package:whitebox/shared/api/wifi_api_service.dart';

/// 輕量級 JWT 自動重新登入管理器
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
            responseBodyStr.contains('jwt') && responseBodyStr.contains('expired') ||
            responseBodyStr.contains('token') && responseBodyStr.contains('expired')) {
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

  /// 包裝 API 調用，自動處理 JWT 過期
  Future<T> wrapApiCall<T>(Future<T> Function() apiCall, {String? debugInfo}) async {
    // 如果正在重新登入，等待完成
    if (_isRelogging) {
      print('⏸️ API 調用等待重新登入完成... ${debugInfo ?? ""}');
      final completer = Completer<void>();
      _waitingCalls.add(completer);
      await completer.future;
    }

    try {
      final result = await apiCall();

      // 🔥 關鍵修正：檢查回應是否包含 JWT 錯誤
      if (isJwtErrorResponse(result)) {
        print('❌ 檢測到回應中的 JWT 錯誤: $result ${debugInfo ?? ""}');

        // 執行自動重新登入
        await _performAutoRelogin();

        // 重試 API 調用
        try {
          return await apiCall();
        } catch (retryError) {
          print('❌ 重新登入後仍然失敗: $retryError ${debugInfo ?? ""}');
          throw retryError;
        }
      }

      return result;
    } catch (e) {
      // 檢查是否為 JWT 相關錯誤
      if (isJwtError(e)) {
        print('❌ 檢測到 JWT 異常錯誤，開始自動重新登入: $e ${debugInfo ?? ""}');

        // 執行自動重新登入
        await _performAutoRelogin();

        // 重試 API 調用
        try {
          return await apiCall();
        } catch (retryError) {
          print('❌ 重新登入後仍然失敗: $retryError ${debugInfo ?? ""}');
          throw retryError;
        }
      } else {
        // 非 JWT 錯誤，直接拋出
        throw e;
      }
    }
  }

  /// 執行自動重新登入
  Future<void> _performAutoRelogin() async {
    // 防止重複執行
    if (_isRelogging) {
      print('🔄 已在重新登入中，等待完成...');
      while (_isRelogging) {
        await Future.delayed(Duration(milliseconds: 100));
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

      // 🔥 關鍵：使用現有的 LoginProcess
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