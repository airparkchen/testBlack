// lib/shared/wifi_api/services/srp_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:srp/client.dart' as srp_client;

import '../models/login_result.dart';
import './http_service.dart';
import '../models/session_info.dart';

/// SRP認證相關服務類，專門處理安全遠程密碼認證協議
class SrpService {
  /// HTTP服務
  final HttpService _httpService;

  /// 空的會話信息，用於表示未登入狀態
  final SessionInfo emptySession = SessionInfo(sessionId: "", csrfToken: "");

  /// 建構函數
  SrpService(this._httpService);

  /// 從HTTP響應頭部獲取會話ID
  String? getSessionIDFromHeaders(Map<String, String> headers) {
    String? cookie = headers['set-cookie'];
    if (cookie == null || cookie.isEmpty) {
      return null;
    }
    return getSessionID(cookie);
  }

  /// 從Cookie字符串中提取會話ID
  String? getSessionID(String cookieHeader) {
    if (cookieHeader.isEmpty) return null;
    final RegExp regExp = RegExp(r'sessionID=([^;]+)');
    final match = regExp.firstMatch(cookieHeader);
    return match?.group(1);
  }

  /// 從響應體中提取CSRF令牌
  String getCSRFToken(String responseBody) {
    final csrfTokenRegex = RegExp(r'CSRF_TOKEN\s*=\s*"([a-f0-9]{32})"');
    final match = csrfTokenRegex.firstMatch(responseBody);

    if (match != null && match.groupCount >= 1) {
      debugPrint('CSRF token = ${match.group(1)}');
      return match.group(1)!;
    } else {
      debugPrint('CSRF_TOKEN not found in response body, could be a blank state?');
      return "";
    }
  }

  /// 獲取CSRF令牌
  Future<String> getCsrfToken() async {
    try {
      // 先嘗試從登入頁獲取CSRF令牌
      final loginPath = '/login.html';
      final response = await _httpService.get(loginPath);

      String token = getCSRFToken(response.body);

      // 如果登入頁沒有CSRF令牌，再嘗試從向導頁獲取
      if (token.isEmpty) {
        final wizPath = '/wizard.html';
        final wizResponse = await _httpService.get(wizPath);
        token = getCSRFToken(wizResponse.body);
      }

      return token;
    } catch (e) {
      debugPrint('獲取CSRF令牌錯誤: $e');
      return "";
    }
  }

  /// 預檢查HTTP響應
  LoginResult preCheck(http.Response res) {
    // 根據狀態碼檢查響應
    if (res.statusCode == 200) {
      return LoginResult(
          response: res,
          success: true,
          session: emptySession,
          message: "access success"
      );
    } else if (res.statusCode == 302) {
      return LoginResult(
          response: res,
          success: false,
          session: emptySession,
          message: "redirect to somewhere"
      );
    } else if (res.statusCode == 503) {
      final bool isSessionFull = res.headers['retry-after'] != null;
      return LoginResult(
          response: res,
          success: false,
          session: emptySession,
          message: isSessionFull ? "The connection limit has been reached!" : "Unknown 503"
      );
    } else {
      return LoginResult(
          response: res,
          success: false,
          session: emptySession,
          message: "unknown ${res.statusCode}"
      );
    }
  }

  /// 登入步驟1：獲取登入頁面和會話ID
  Future<LoginResult> loginStep1() async {
    try {
      final loginPath = '/login.html';
      final response = await _httpService.get(loginPath);

      debugPrint(" [STEP1] 獲取登入頁面: ${response.statusCode}");

      return preCheck(response);
    } catch (e) {
      debugPrint('登入步驟1錯誤: $e');
      return LoginResult(
          response: null,
          success: false,
          session: emptySession,
          message: "登入步驟1錯誤: $e"
      );
    }
  }

  /// 登入步驟2：發送公鑰
  Future<LoginResult> loginStep2(Map<String, String> headers, Map<String, dynamic> data, String csrfToken) async {
    try {
      final client = _httpService.createUnsafeClient();

      // 嘗試不同的端點路徑
      final endpoints = [
        '/api/v1/user/login',
        '/cgi-bin/webPost.plua?csrftoken=$csrfToken'
      ];

      LoginResult? finalResult;

      for (final endpoint in endpoints) {
        try {
          debugPrint("嘗試發送公鑰到: ${_httpService.baseUrl}$endpoint");
          debugPrint("請求數據: ${json.encode(data)}");

          final response = await client.post(
            Uri.parse('${_httpService.baseUrl}$endpoint'),
            headers: headers,
            body: json.encode(data),
          );

          debugPrint(" [STEP2] 公鑰請求狀態: ${response.statusCode}");

          final result = preCheck(response);
          if (result.success) {
            return result;
          }

          finalResult = result;
        } catch (e) {
          debugPrint("嘗試端點 $endpoint 時出錯: $e");
          // 繼續嘗試下一個端點
        }
      }

      // 所有端點均失敗，返回最後一個結果或默認錯誤結果
      return finalResult ?? LoginResult(
          response: null,
          success: false,
          session: emptySession,
          message: "所有端點均失敗"
      );
    } catch (e) {
      debugPrint('登入步驟2錯誤: $e');
      return LoginResult(
          response: null,
          success: false,
          session: emptySession,
          message: "登入步驟2錯誤: $e"
      );
    }
  }

  /// 登入步驟3：發送證明
  Future<LoginResult> loginStep3(Map<String, String> headers, Map<String, dynamic> data, String csrfToken) async {
    try {
      // 嘗試不同的端點路徑
      final endpoints = [
        '/api/v1/user/login',
        '/cgi-bin/webPost.plua?csrftoken=$csrfToken'
      ];

      LoginResult? finalResult;

      for (final endpoint in endpoints) {
        try {
          debugPrint("嘗試發送證明到: ${_httpService.baseUrl}$endpoint");
          debugPrint("請求數據: ${json.encode(data)}");

          final response = await http.post(
            Uri.parse('${_httpService.baseUrl}$endpoint'),
            headers: headers,
            body: json.encode(data),
          );

          debugPrint(" [STEP3] 證明請求狀態: ${response.statusCode}");

          final result = preCheck(response);

          // 檢查錯誤信息
          try {
            if (result.response != null && result.response!.body.isNotEmpty) {
              var responseData = json.decode(result.response!.body);
              if (responseData['error'] != null) {
                finalResult = LoginResult(
                    response: result.response,
                    success: false,
                    session: emptySession,
                    message: responseData['error']['msg'] ?? "Unknown error",
                    data: responseData
                );
                continue;  // 嘗試下一個端點
              }
            }
          } catch (e) {
            debugPrint("解析步驟3響應時出錯: $e");
          }

          if (result.success) {
            // 嘗試提取JSON數據
            var responseData = {};
            try {
              if (result.response!.body.isNotEmpty) {
                responseData = json.decode(result.response!.body);
              }
            } catch (e) {
              debugPrint("解析成功響應時出錯: $e");
            }

            return LoginResult(
                response: result.response,
                success: true,
                session: emptySession,  // 稍後會更新
                message: "Authentication successful",
            );
          }

          finalResult = result;
        } catch (e) {
          debugPrint("嘗試端點 $endpoint 時出錯: $e");
          // 繼續嘗試下一個端點
        }
      }

      // 所有端點均失敗，返回最後一個結果或默認錯誤結果
      return finalResult ?? LoginResult(
          response: null,
          success: false,
          session: emptySession,
          message: "所有端點均失敗"
      );
    } catch (e) {
      debugPrint('登入步驟3錯誤: $e');
      return LoginResult(
          response: null,
          success: false,
          session: emptySession,
          message: "登入步驟3錯誤: $e"
      );
    }
  }

  /// 獲取儀表板
  Future<bool> getDashboard(String sessionId, String csrfToken) async {
    try {
      final headers = {
        'Cookie': 'sessionID=$sessionId',
      };

      // 嘗試GET和POST兩種方法
      for (final method in ['GET', 'POST']) {
        try {
          final url = '${_httpService.baseUrl}/dashboard.html?csrftoken=$csrfToken';
          final uri = Uri.parse(url);

          final response = method == 'GET'
              ? await http.get(uri, headers: headers)
              : await http.post(uri, headers: headers);

          if (response.statusCode == 200) {
            debugPrint("成功訪問儀表板，使用方法: $method");
            return true;
          }
        } catch (e) {
          debugPrint("使用 $method 訪問儀表板時出錯: $e");
        }
      }

      debugPrint("無法訪問儀表板");
      return false;
    } catch (e) {
      debugPrint("獲取儀表板錯誤: $e");
      return false;
    }
  }

  /// 使用SRP協議登入
  Future<LoginResult> loginWithSRP(String username, String password) async {
    try {
      debugPrint("\n============ 開始SRP登入流程 ============");

      // 步驟1: 獲取登入頁面和CSRF令牌
      debugPrint("第1步: 獲取登入頁面和CSRF令牌");
      var result = await loginStep1();
      if (!result.success) {
        debugPrint("獲取登入頁面失敗: ${result.message}");
        return result;
      }

      String csrfToken = getCSRFToken(result.response!.body);
      String sessionId = getSessionIDFromHeaders(result.response!.headers) ?? "";
      debugPrint("獲取到會話ID = $sessionId, 令牌 = $csrfToken");

      if (csrfToken.isEmpty) {
        // 如果沒有找到CSRF令牌，嘗試從向導頁面獲取
        debugPrint("未找到CSRF令牌，嘗試從向導頁面獲取");
        csrfToken = await getCsrfToken();

        if (csrfToken.isEmpty) {
          debugPrint("無法獲取CSRF令牌");
          return LoginResult(
              response: null,
              success: false,
              session: SessionInfo(sessionId: sessionId, csrfToken: ""),
              message: "無法獲取CSRF令牌"
          );
        }
      }

      // 步驟2: 生成SRP參數
      debugPrint("\n第2步: 生成SRP參數");
      final salt = srp_client.generateSalt();
      debugPrint('生成的鹽值: $salt');

      final clientEphemeral = srp_client.generateEphemeral();
      debugPrint('客戶端臨時密鑰: public = ${clientEphemeral.public.substring(0, clientEphemeral.public.length > 20 ? 20 : clientEphemeral.public.length)}... (已截斷)');

      // 嘗試不同的請求數據格式
      final postData = {
        'method': 'srp',
        'srp': {
          'I': username,
          'A': clientEphemeral.public,
        }
      };

      final postDataAlt = {
        'function': 'authenticate',
        'data': {
          'CSRFtoken': csrfToken,
          'I': username,
          'A': clientEphemeral.public,
        }
      };

      // 設置HTTP頭
      final step2Header = {
        'Content-Type': 'application/json',
        'Referer': '${_httpService.baseUrl}/login.html',
      };

      if (sessionId.isNotEmpty) {
        step2Header['Cookie'] = 'sessionID=$sessionId';
      }

      // 步驟3: 發送公鑰
      debugPrint("\n第3步: 發送公鑰");
      var step2Result = await loginStep2(step2Header, postData, csrfToken);

      // 如果第一種格式失敗，嘗試第二種格式
      if (!step2Result.success) {
        debugPrint("使用主要格式發送公鑰失敗，嘗試備用格式");
        step2Result = await loginStep2(step2Header, postDataAlt, csrfToken);
      }

      // 從響應頭中更新會話ID
      if (step2Result.response != null) {
        final newSessionId = getSessionIDFromHeaders(step2Result.response!.headers) ?? sessionId;
        if (newSessionId != sessionId) {
          debugPrint("會話ID已更新: $newSessionId");
          sessionId = newSessionId;
        }
      }

      if (!step2Result.success) {
        debugPrint("發送公鑰失敗: ${step2Result.message}");
        return step2Result;
      }

      // 解析返回的數據
      var dataFromStep2 = step2Result.getJson();
      debugPrint('從伺服器獲取的鹽值和B值: $dataFromStep2');

      // 檢查必要參數
      if (!dataFromStep2.containsKey('s') || !dataFromStep2.containsKey('B')) {
        debugPrint("伺服器響應缺少必要的SRP參數");
        return LoginResult(
            response: step2Result.response,
            success: false,
            session: SessionInfo(sessionId: sessionId, csrfToken: csrfToken),
            message: "伺服器響應缺少必要的SRP參數"
        );
      }

      // 獲取伺服器提供的鹽值和公鑰
      String saltFromHost = dataFromStep2['s'];
      String BFromHost = dataFromStep2['B'];
      debugPrint("從伺服器獲取的鹽值: $saltFromHost");
      debugPrint("從伺服器獲取的B值: ${BFromHost.substring(0, BFromHost.length > 20 ? 20 : BFromHost.length)}... (已截斷)");

      // 步驟4: 計算SRP認證參數
      debugPrint("\n第4步: 計算SRP認證參數");
      final privateKey = srp_client.derivePrivateKey(saltFromHost, username, password);
      final verifier = srp_client.deriveVerifier(privateKey);
      final clientSession = srp_client.deriveSession(clientEphemeral.secret, BFromHost, saltFromHost, username, privateKey);
      debugPrint('生成的客戶端證明: ${clientSession.proof.substring(0, clientSession.proof.length > 20 ? 20 : clientSession.proof.length)}... (已截斷)');

      // 嘗試不同的證明格式
      final step3PostData = {
        'method': 'srp',
        'srp': {
          'M1': clientSession.proof,
        }
      };

      final step3PostDataAlt = {
        'method': 'srp',
        'srp': {
          'M': clientSession.proof,
        }
      };

      final step3PostDataAlt2 = {
        'function': 'authenticate',
        'data': {
          'CSRFtoken': csrfToken,
          'M1': clientSession.proof,
        }
      };

      final step3PostDataAlt3 = {
        'function': 'authenticate',
        'data': {
          'CSRFtoken': csrfToken,
          'M': clientSession.proof,
        }
      };

      // 設置HTTP頭
      final step3Header = {
        'Content-Type': 'application/json',
        'Origin': _httpService.baseUrl,
        'Referer': '${_httpService.baseUrl}/login.html',
        'Cookie': 'sessionID=$sessionId',
      };

      // 步驟5: 發送客戶端證明
      debugPrint("\n第5步: 發送客戶端證明");
      var step3Result = await loginStep3(step3Header, step3PostData, csrfToken);

      // 如果主要格式失敗，嘗試備用格式
      if (!step3Result.success) {
        debugPrint("主要證明格式失敗，嘗試備用格式");
        for (final data in [step3PostDataAlt, step3PostDataAlt2, step3PostDataAlt3]) {
          step3Result = await loginStep3(step3Header, data, csrfToken);
          if (step3Result.success) {
            break;
          }
        }
      }

      if (!step3Result.success) {
        debugPrint("發送証明失敗: ${step3Result.message}");
        return step3Result;
      }

      // 解析返回的數據
      var dataFromStep3 = step3Result.getJson();
      debugPrint('從伺服器接收的數據: $dataFromStep3');

      // 步驟6: 獲取JWT令牌
      debugPrint("\n第6步: 獲取JWT令牌");
      String? jwtToken;
      if (dataFromStep3.containsKey('jwt')) {
        jwtToken = dataFromStep3['jwt'];
        debugPrint('成功獲取到JWT令牌: ${jwtToken!.substring(0, jwtToken.length > 20 ? 20 : jwtToken.length)}... (已截斷)');
      } else if (dataFromStep3.containsKey('token')) {
        jwtToken = dataFromStep3['token'];
        debugPrint('成功獲取到令牌: ${jwtToken!.substring(0, jwtToken.length > 20 ? 20 : jwtToken.length)}... (已截斷)');
      } else {
        debugPrint('警告: 伺服器回應中未找到JWT令牌');
      }

      // 步驟7: 驗證伺服器證明
      debugPrint("\n第7步: 驗證伺服器證明");
      if (dataFromStep3.containsKey('M') || dataFromStep3.containsKey('M2')) {
        String M2 = dataFromStep3.containsKey('M') ? dataFromStep3['M'] : dataFromStep3['M2'];
        try {
          srp_client.verifySession(clientEphemeral.public, clientSession, M2);
          debugPrint('伺服器證明驗證成功');
        } catch (e) {
          debugPrint('伺服器證明驗證警告: $e');
        }
      } else {
        debugPrint('伺服器未提供證明');
      }

      // 步驟9: 確認登入成功
      debugPrint("\n第9步: 確認登入成功");
      bool dashboardAccess = await getDashboard(sessionId, csrfToken);
      if (dashboardAccess) {
        debugPrint("成功訪問儀表板，登入已確認");
      } else {
        debugPrint("警告: 無法訪問儀表板，但登入可能仍然成功");
      }

      debugPrint("\n============ SRP登入流程完成 ============");
      return LoginResult(
          response: null,
          success: true,
          session: SessionInfo(sessionId: sessionId, csrfToken: csrfToken, jwtToken: jwtToken),
          message: "登入成功",
          data: dataFromStep3
      );
    } catch (e) {
      debugPrint('SRP登入過程中發生錯誤: $e');
      return LoginResult(
          response: null,
          success: false,
          session: SessionInfo(sessionId: "", csrfToken: ""),
          message: "登入錯誤: $e"
      );
    }
  }
}