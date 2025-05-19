// lib/shared/wifi_api/models/session_info.dart

import 'dart:convert';

/// 會話信息類，存儲登入后的會話ID、CSRF令牌和JWT令牌
class SessionInfo {
  final String sessionId;
  final String csrfToken;
  final String? jwtToken; // JWT令牌，可能為空

  /// 建構函數
  SessionInfo({
    required this.sessionId,
    required this.csrfToken,
    this.jwtToken,
  });

  /// 檢查會話是否為空
  bool isEmpty() {
    return sessionId.isEmpty && csrfToken.isEmpty;
  }

  /// 檢查會話是否不為空
  bool isNotEmpty() {
    return !isEmpty();
  }

  /// 將CSRF令牌附加到URL
  String attachCsrfToken(String url) {
    if (csrfToken.isEmpty) return url;
    return '$url?csrftoken=$csrfToken';
  }

  @override
  String toString() {
    return 'SessionInfo{sessionId: $sessionId, csrfToken: $csrfToken, jwtToken: ${jwtToken?.substring(0, jwtToken!.length > 10 ? 10 : jwtToken!.length)}...}';
  }
}

/// 登入結果類，包含HTTP響應、返回狀態和消息
class LoginResult {
  /// HTTP響應，可能為空
  final dynamic response;

  /// 是否登入成功
  final bool success;

  /// 會話信息
  final SessionInfo session;

  /// 結果消息
  final String message;

  /// JSON數據，可能為空
  final Map<String, dynamic>? data;

  /// 建構函數
  LoginResult({
    this.response,
    required this.success,
    required this.session,
    required this.message,
    this.data,
  });

  /// 從JSON獲取數據
  Map<String, dynamic> getJson() {
    if (data != null) {
      return data!;
    }

    if (response == null) {
      return {};
    }

    try {
      if (response.body != null && response.body.isNotEmpty) {
        // 嘗試尋找JSON部分
        String jsonString = response.body;
        // 如果響應包含HTML或其他格式，查找JSON開始的位置
        int jsonStart = jsonString.indexOf('{');
        if (jsonStart > 0) {
          jsonString = jsonString.substring(jsonStart);
        }
        return Map<String, dynamic>.from(Map.castFrom(jsonDecode(jsonString)));
      }
    } catch (e) {
      print("解析JSON數據時出錯: $e");
    }
    return {};
  }

  /// 創建空的登入結果
  static LoginResult empty() {
    return LoginResult(
      success: false,
      session: SessionInfo(sessionId: "", csrfToken: ""),
      message: "沒有執行登入流程",
    );
  }
}

/// 首次登入結果，包含額外的初始化相關信息
class FirstLoginResult {
  /// 是否登入成功
  final bool success;

  /// 結果消息
  final String message;

  /// 會話ID，可能為空
  final String? sessionId;

  /// CSRF令牌，可能為空
  final String? csrfToken;

  /// JWT令牌，可能為空
  final String? jwtToken;

  /// 計算出的密碼，可能為空
  final String? calculatedPassword;

  /// 系統信息，可能為空
  final Map<String, dynamic>? systemInfo;

  /// 登入響應，可能為空
  final Map<String, dynamic>? loginResponse;

  /// 建構函數
  FirstLoginResult({
    required this.success,
    required this.message,
    this.sessionId,
    this.csrfToken,
    this.jwtToken,
    this.calculatedPassword,
    this.systemInfo,
    this.loginResponse,
  });

  /// 轉換為會話信息
  SessionInfo toSessionInfo() {
    return SessionInfo(
      sessionId: sessionId ?? '',
      csrfToken: csrfToken ?? '',
      jwtToken: jwtToken,
    );
  }
}