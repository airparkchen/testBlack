// lib/shared/wifi_api/services/http_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../models/session_info.dart';

/// HTTP服務類，處理基本的HTTP請求
class HttpService {
  /// 基礎URL
  final String baseUrl;

  /// 超時時間（秒）
  final int timeoutSeconds;

  /// 會話信息
  SessionInfo? _sessionInfo;

  /// 建構函數
  HttpService({
    required this.baseUrl,
    this.timeoutSeconds = 10,
    SessionInfo? sessionInfo,
  }) : _sessionInfo = sessionInfo;

  /// 設置會話信息
  void setSessionInfo(SessionInfo sessionInfo) {
    _sessionInfo = sessionInfo;
  }

  /// 獲取會話信息
  SessionInfo? getSessionInfo() {
    return _sessionInfo;
  }

  /// 創建一個接受無效證書的HTTP客戶端
  http.Client createUnsafeClient() {
    final ioClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;

    return IOClient(ioClient);
  }

  /// 獲取通用的HTTP頭部
  Map<String, String> getHeaders({
    Map<String, String>? additionalHeaders,
    bool includeContentType = true,
    bool includeSessionCookie = true,
    bool includeJwtToken = false,
  }) {
    final headers = <String, String>{};

    // 添加Content-Type
    if (includeContentType) {
      headers['Content-Type'] = 'application/json';
    }

    // 添加Cookie（會話ID）
    if (includeSessionCookie && _sessionInfo != null && _sessionInfo!.sessionId.isNotEmpty) {
      headers['Cookie'] = 'sessionID=${_sessionInfo!.sessionId}';
    }

    // 添加JWT令牌
    if (includeJwtToken && _sessionInfo != null && _sessionInfo!.jwtToken != null) {
      headers['Authorization'] = 'Bearer ${_sessionInfo!.jwtToken}';
    }

    // 添加額外的頭部
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }

    return headers;
  }

  /// 發送GET請求
  Future<http.Response> get(
      String endpoint, {
        Map<String, String>? headers,
        Map<String, dynamic>? queryParams,
        bool useCsrfToken = false,
      }) async {
    try {
      var uri = Uri.parse('$baseUrl$endpoint');

      // 添加查詢參數
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams.map((key, value) => MapEntry(key, value.toString())));
      }

      // 如果需要使用CSRF令牌
      if (useCsrfToken && _sessionInfo != null) {
        final csrfToken = _sessionInfo!.csrfToken;
        if (csrfToken.isNotEmpty) {
          final uriString = uri.toString();
          final separator = uriString.contains('?') ? '&' : '?';
          uri = Uri.parse('$uriString${separator}csrftoken=$csrfToken');
        }
      }

      final response = await http.get(
        uri,
        headers: getHeaders(additionalHeaders: headers),
      ).timeout(Duration(seconds: timeoutSeconds));

      return response;
    } catch (e) {
      print('GET 請求錯誤: $e');
      rethrow;
    }
  }

  /// 發送POST請求
  Future<http.Response> post(
      String endpoint, {
        Map<String, String>? headers,
        Object? body,
        bool useCsrfToken = false,
      }) async {
    try {
      var uri = Uri.parse('$baseUrl$endpoint');

      // 如果需要使用CSRF令牌
      if (useCsrfToken && _sessionInfo != null) {
        final csrfToken = _sessionInfo!.csrfToken;
        if (csrfToken.isNotEmpty) {
          final uriString = uri.toString();
          final separator = uriString.contains('?') ? '&' : '?';
          uri = Uri.parse('$uriString${separator}csrftoken=$csrfToken');
        }
      }

      final String? bodyString = body is String ? body :
      body != null ? json.encode(body) : null;

      final response = await http.post(
        uri,
        headers: getHeaders(additionalHeaders: headers),
        body: bodyString,
      ).timeout(Duration(seconds: timeoutSeconds));

      return response;
    } catch (e) {
      print('POST 請求錯誤: $e');
      rethrow;
    }
  }

  /// 發送PUT請求
  Future<http.Response> put(
      String endpoint, {
        Map<String, String>? headers,
        Object? body,
        bool useCsrfToken = false,
      }) async {
    try {
      var uri = Uri.parse('$baseUrl$endpoint');

      // 如果需要使用CSRF令牌
      if (useCsrfToken && _sessionInfo != null) {
        final csrfToken = _sessionInfo!.csrfToken;
        if (csrfToken.isNotEmpty) {
          final uriString = uri.toString();
          final separator = uriString.contains('?') ? '&' : '?';
          uri = Uri.parse('$uriString${separator}csrftoken=$csrfToken');
        }
      }

      final String? bodyString = body is String ? body :
      body != null ? json.encode(body) : null;

      final response = await http.put(
        uri,
        headers: getHeaders(additionalHeaders: headers),
        body: bodyString,
      ).timeout(Duration(seconds: timeoutSeconds));

      return response;
    } catch (e) {
      print('PUT 請求錯誤: $e');
      rethrow;
    }
  }

  /// 發送DELETE請求
  Future<http.Response> delete(
      String endpoint, {
        Map<String, String>? headers,
        Object? body,
        bool useCsrfToken = false,
      }) async {
    try {
      var uri = Uri.parse('$baseUrl$endpoint');

      // 如果需要使用CSRF令牌
      if (useCsrfToken && _sessionInfo != null) {
        final csrfToken = _sessionInfo!.csrfToken;
        if (csrfToken.isNotEmpty) {
          final uriString = uri.toString();
          final separator = uriString.contains('?') ? '&' : '?';
          uri = Uri.parse('$uriString${separator}csrftoken=$csrfToken');
        }
      }

      final String? bodyString = body is String ? body :
      body != null ? json.encode(body) : null;

      final response = await http.delete(
        uri,
        headers: getHeaders(additionalHeaders: headers),
        body: bodyString,
      ).timeout(Duration(seconds: timeoutSeconds));

      return response;
    } catch (e) {
      print('DELETE 請求錯誤: $e');
      rethrow;
    }
  }

  /// 處理HTTP響應
  Map<String, dynamic> handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};

      String responseBody = response.body;

      // 嘗試尋找JSON開始的位置
      int jsonStart = responseBody.indexOf('{');
      if (jsonStart > 0) {
        responseBody = responseBody.substring(jsonStart);
      }

      try {
        return json.decode(responseBody);
      } catch (e) {
        print('解析JSON響應時出錯: $e');
        throw ApiException(
          statusCode: response.statusCode,
          errorCode: 'parse_error',
          message: 'Failed to parse JSON response: ${response.body}',
        );
      }
    } else {
      try {
        final errorData = json.decode(response.body);
        throw ApiException(
          statusCode: response.statusCode,
          errorCode: errorData['status_code'] ?? 'unknown',
          message: errorData['message'] ?? 'Unknown error',
        );
      } catch (e) {
        throw ApiException(
          statusCode: response.statusCode,
          errorCode: 'parse_error',
          message: 'Failed to parse error response: ${response.body}',
        );
      }
    }
  }
}

/// API異常類，用於處理API錯誤
class ApiException implements Exception {
  final int statusCode;
  final String errorCode;
  final String message;

  ApiException({
    required this.statusCode,
    required this.errorCode,
    required this.message
  });

  @override
  String toString() => 'ApiException: [$statusCode][$errorCode] $message';
}