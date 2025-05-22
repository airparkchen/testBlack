import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:srp/client.dart' as client;
import 'package:http/io_client.dart';
import '../../connection/api_service.dart';
import '../../connection/connection_utils.dart';
import '../../utils/utility.dart';

http.Client createUnsafeClient() {
  final ioClient = HttpClient()
    ..badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;

  return IOClient(ioClient);
}

// SessionInfo 類，支援 JWT 令牌
class SessionInfo {
  final String sessionId;
  final String csrfToken;
  final String? jwtToken; // JWT token

  SessionInfo({
    required this.sessionId,
    required this.csrfToken,
    this.jwtToken
  });
}

class LoginProcess {
  final String baseUrl;
  String _username = '';
  String _password = '';
  String _token = '';
  SessionInfo emptySession = SessionInfo(sessionId: "", csrfToken: "");

  // 構造函數，支援自訂 baseUrl
  LoginProcess(this._username, this._password, {String? baseUrl})
      : this.baseUrl = baseUrl ?? ApiService().baseUrl;

  bool isSessionFull(Map<String, String> headers) {
    String? sessionFull = headers['retry-after'];
    return sessionFull != null;
  }

  String? getSessionIDFromHeaders(Map<String, String> headers) {
    String? cookie = headers['set-cookie'];
    if (cookie == null) {
      return null;
    }
    String? sessionId = getSessionID(cookie);
    return sessionId;
  }

  String getCSRFToken(String responseBody) {
    final csrfTokenRegex = RegExp(r'CSRF_TOKEN\s*=\s*"([a-f0-9]{32})"');
    final match = csrfTokenRegex.firstMatch(responseBody);

    if (match != null && match.groupCount >= 1) {
      print('CSRF token = ${match.group(1)}');
      return match.group(1)!;
    } else {
      //blank state, we need to get csrf from wizard;
      print('CSRF_TOKEN not found in response body, could be a blank state?');
      return "";
    }
  }

  String? getSessionID(String cookieHeader) {
    if (cookieHeader.isEmpty) return null; // 正確檢查空字串
    final RegExp regExp = RegExp(r'sessionID=([^;]+)');
    final match = regExp.firstMatch(cookieHeader);
    return match?.group(1);
  }

  // 獲取 wizard.html 以取得 CSRF token
  Future<void> getCsrfFromWizard() async {
    final String wizPage = '$baseUrl/wizard.html';
    print("print get from : ${Uri.parse(wizPage)}");
    final response = await http.get(Uri.parse(wizPage));
    if (response.statusCode == 200) {
      PrintUtil.printMap(
          'HEADER', response.headers.map((k, v) => MapEntry(k, v)));
      print("_token is getting from wizard.html");
      _token = getCSRFToken(response.body);
    }
  }

  LoginResult preCheck(http.Response res) {
    //check status code first;
    if (res.statusCode == 200) {
      return LoginResult(response: res,
          returnStatus: true,
          session: emptySession,
          msg: "access success");
    } else if (res.statusCode == 302) {
      return LoginResult(response: res,
          returnStatus: false,
          session: emptySession,
          msg: "redirect to somewhere");
    } else if (res.statusCode == 503) {
      return LoginResult(
          response: res,
          returnStatus: false,
          session: emptySession,
          msg: isSessionFull(res.headers)
              ? "The connection limit has been reached!"
              : "Unknown 503");
    } else {
      return LoginResult(response: res,
          returnStatus: false,
          session: emptySession,
          msg: "unknown ${res.statusCode}");
    }
  }

  static int rCount = 1;

  // 獲取 login.html 以取得 header 中的 sessionID
  Future<LoginResult> loginStep1() async {
    final String loginPath = '$baseUrl/login.html';
    print("print get : ${Uri.parse(loginPath)}");
    final response = await http.get(Uri.parse(loginPath));
    PrintUtil.printMap(
        ' [STEP1] HEADER', response.headers.map((k, v) => MapEntry(k, v)));
    return preCheck(response);
  }

  // 向伺服器發送公鑰
  Future<LoginResult> loginStep2(Map<String, String> headers,
      Map<String, dynamic> data) async {
    final client = createUnsafeClient();

    // 確保使用正確的端點
    final endpoint = '$baseUrl/api/v1/user/login';

    try {
      print("嘗試發送公鑰到: $endpoint");
      print("請求數據: ${json.encode(data)}");

      final response = await client.post(
        Uri.parse(endpoint),
        headers: headers,
        body: json.encode(data),
      );

      // 詳細記錄響應
      print("公鑰請求的響應狀態碼: ${response.statusCode}");
      PrintUtil.printMap(
          ' [STEP2] HEADER', response.headers.map((k, v) => MapEntry(k, v)));
      if (response.body.isNotEmpty) {
        try {
          final jsonData = json.decode(response.body);
          print("響應體(JSON): ${jsonEncode(jsonData)}");
        } catch (e) {
          print("響應體(非JSON): ${response.body}");
        }
      }

      return preCheck(response);
    } catch (e) {
      print("發送公鑰請求時出錯: $e");
      return LoginResult(
          response: null,
          returnStatus: false,
          session: emptySession,
          msg: "發送公鑰請求失敗: $e"
      );
    }
  }

  // 向伺服器發送證明
  Future<LoginResult> loginStep3(Map<String, String> headers,
      Map<String, dynamic> data) async {
    try {
      print("嘗試發送證明到: $baseUrl/api/v1/user/login");
      print("請求數據: ${json.encode(data)}");

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/user/login'),
        headers: headers,
        body: json.encode(data),
      );

      // 詳細記錄響應
      print("證明請求的響應狀態碼: ${response.statusCode}");
      PrintUtil.printMap(
          ' [STEP3] HEADER', response.headers.map((k, v) => MapEntry(k, v)));
      if (response.body.isNotEmpty) {
        try {
          final jsonData = json.decode(response.body);
          print("響應體(JSON): ${jsonEncode(jsonData)}");

          // 檢查JWT令牌
          if (jsonData.containsKey('jwt')) {
            print("發現JWT令牌: ${jsonData['jwt']}");
          } else if (jsonData.containsKey('token')) {
            print("發現令牌: ${jsonData['token']}");
          }
        } catch (e) {
          print("響應體(非JSON): ${response.body}");
        }
      }

      var result = preCheck(response);

      try {
        if (result.response != null && result.response!.body.isNotEmpty) {
          var tmp = json.decode(result.response!.body);
          if (tmp['error'] != null) {
            print("錯誤信息: ${tmp['error']['msg']}");
            result = LoginResult(
                response: result.response,
                returnStatus: false,
                session: emptySession,
                msg: tmp['error']['msg'] ?? "Unknown error"
            );
          }
        }
      } catch (e) {
        print("step3 response parsing error: $e");
      }

      return result;
    } catch (e) {
      print("發送證明請求時出錯: $e");
      return LoginResult(
          response: null,
          returnStatus: false,
          session: emptySession,
          msg: "發送證明請求失敗: $e"
      );
    }
  }

  // 使用JWT令牌測試API
  Future<dynamic> testApiWithJwt(String jwt, String endpoint) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwt'
      };

      print("使用 JWT 測試 API: $endpoint");
      print("Authorization: Bearer $jwt");

      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );

      print("API 測試結果: ${response.statusCode}");
      PrintUtil.printMap(
          ' [API測試] HEADER', response.headers.map((k, v) => MapEntry(k, v)));

      if (response.statusCode == 200) {
        try {
          final jsonData = json.decode(response.body);
          print("API響應體(JSON): ${jsonEncode(jsonData)}");
          return jsonData;
        } catch (e) {
          print("API回應解析錯誤: $e");
          print("API響應體(非JSON): ${response.body}");
          return response.body;
        }
      } else {
        print("API響應體: ${response.body}");
        return {
          "status": "error",
          "code": response.statusCode,
          "body": response.body
        };
      }
    } catch (e) {
      print("API 測試錯誤: $e");
      return {"status": "error", "message": e.toString()};
    }
  }

  // 測試網絡接口
  Future<void> loginStep4(String jwt) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwt'
      };

      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/wireless/basic'),
        headers: headers,
      );

      print("網絡接口測試結果: ${response.statusCode}");
      if (response.body.isNotEmpty) {
        try {
          final jsonData = json.decode(response.body);
          print("網絡接口響應(JSON): ${jsonEncode(jsonData)}");
        } catch (e) {
          print("網絡接口響應(非JSON): ${response.body}");
        }
      }
    } catch (e) {
      print("Error in loginStep4: $e");
    }
  }

  // 獲取儀表板
  Future<dynamic> getDashboard(Map<String, String> headers) async {
    try {
      print("嘗試獲取儀表板...");

      // 優先嘗試標準方法
      final url = '$baseUrl/dashboard.html?csrftoken=$_token';
      print("嘗試URL: $url");

      final response = await http.get(
          Uri.parse(url),
          headers: headers
      );

      if (response.statusCode == 200) {
        print("成功載入儀表板");
        return response.body;
      } else {
        // 如果失敗，嘗試POST方法
        print("GET儀表板請求返回狀態碼: ${response.statusCode}，嘗試POST方法");
        final postResponse = await http.post(
            Uri.parse(url),
            headers: headers
        );

        if (postResponse.statusCode == 200) {
          print("使用POST成功載入儀表板");
          return postResponse.body;
        } else {
          print("POST儀表板請求返回狀態碼: ${postResponse.statusCode}");
          throw Exception('無法載入儀表板，狀態碼: ${postResponse.statusCode}');
        }
      }
    } catch (e) {
      print("獲取儀表板失敗: $e");
      throw Exception('獲取儀表板失敗: $e');
    }
  }

  // 啟動 SRP 登入流程
  Future<LoginResult> startSRPLoginProcess() async {
    try {
      print("\n============ 開始SRP登入流程 ============");

      // 步驟1: 獲取登入頁面和CSRF令牌（10秒超時）
      print("第1步: 獲取登入頁面和CSRF令牌");
      var result = await loginStep1().timeout(
          Duration(seconds: 10),
          onTimeout: () {
            print("步驟1超時：獲取登入頁面超過10秒");
            return LoginResult(
                response: null,
                returnStatus: false,
                session: emptySession,
                msg: "獲取登入頁面超時"
            );
          }
      );

      if (!result.returnStatus) {
        print("獲取登入頁面失敗: ${result.msg}");
        return result;
      }

      _token = getCSRFToken(result.response!.body);
      String sessionId = getSessionIDFromHeaders(result.response!.headers) ??
          "";
      print("獲取到會話ID = $sessionId, 令牌 = $_token");

      if (_token.isEmpty) {
        // 如果沒有找到CSRF令牌，嘗試從向導頁面獲取（10秒超時）
        print("未找到CSRF令牌，嘗試從向導頁面獲取");
        try {
          await getCsrfFromWizard().timeout(
              Duration(seconds: 10),
              onTimeout: () {
                print("從向導頁面獲取CSRF令牌超時");
                throw TimeoutException(
                    "獲取CSRF令牌超時", Duration(seconds: 10));
              }
          );
        } catch (e) {
          print("從向導頁面獲取CSRF令牌失敗: $e");
          return LoginResult(
              response: null,
              returnStatus: false,
              session: SessionInfo(sessionId: sessionId, csrfToken: ""),
              msg: "無法獲取CSRF令牌: $e"
          );
        }

        if (_token.isEmpty) {
          print("無法獲取CSRF令牌");
          return LoginResult(
              response: null,
              returnStatus: false,
              session: SessionInfo(sessionId: sessionId, csrfToken: ""),
              msg: "無法獲取CSRF令牌"
          );
        }
      }

      // 步驟2: 生成SRP參數
      print("\n第2步: 生成SRP參數");
      final salt = client.generateSalt();
      print('生成的鹽值: $salt');

      final clientEphemeral = client.generateEphemeral();
      print('客戶端臨時密鑰: public = ${clientEphemeral.public.substring(
          0, Math.min(20, clientEphemeral.public.length))}... (已截斷)');

      // 設置發送到伺服器的數據
      final postData = {
        'method': 'srp',
        'srp': {
          'I': _username,
          'A': clientEphemeral.public,
        }
      };

      // 設置HTTP頭
      final step2Header = {
        'Content-Type': 'application/json',
      };

      // 步驟3: 發送公鑰（10秒超時）
      print("\n第3步: 發送公鑰");
      final step2Result = await loginStep2(step2Header, postData).timeout(
          Duration(seconds: 10),
          onTimeout: () {
            print("步驟3超時：發送公鑰超過10秒");
            return LoginResult(
                response: null,
                returnStatus: false,
                session: emptySession,
                msg: "發送公鑰超時"
            );
          }
      );

      // 從響應頭中更新會話ID
      if (step2Result.response != null) {
        final newSessionId = getSessionIDFromHeaders(
            step2Result.response!.headers) ?? sessionId;
        if (newSessionId != sessionId) {
          print("會話ID已更新: $newSessionId");
          sessionId = newSessionId;
        }
      }

      if (!step2Result.returnStatus) {
        print("發送公鑰失敗: ${step2Result.msg}");
        return step2Result;
      }

      // 解析返回的數據
      var dataFromStep2 = step2Result.getJson();
      print('從伺服器獲取的鹽值和B值: $dataFromStep2');

      // 檢查必要參數
      if (!dataFromStep2.containsKey('s') || !dataFromStep2.containsKey('B')) {
        print("伺服器響應缺少必要的SRP參數");
        return LoginResult(
            response: step2Result.response,
            returnStatus: false,
            session: SessionInfo(sessionId: sessionId, csrfToken: _token),
            msg: "伺服器響應缺少必要的SRP參數"
        );
      }

      // 獲取伺服器提供的鹽值和公鑰
      String saltFromHost = dataFromStep2['s'];
      String BFromHost = dataFromStep2['B'];
      print("從伺服器獲取的鹽值: $saltFromHost");
      print("從伺服器獲取的B值: ${BFromHost.substring(
          0, Math.min(20, BFromHost.length))}... (已截斷)");

      // 步驟4: 計算SRP認證參數
      print("\n第4步: 計算SRP認證參數");
      final privateKey = client.derivePrivateKey(
          saltFromHost, _username, _password);
      final verifier = client.deriveVerifier(privateKey);
      final clientSession = client.deriveSession(
          clientEphemeral.secret, BFromHost, saltFromHost, _username,
          privateKey);
      print('生成的客戶端證明: ${clientSession.proof.substring(
          0, Math.min(20, clientSession.proof.length))}... (已截斷)');

      // 設置發送到伺服器的證明數據
      final step3PostData = {
        'method': 'srp',
        'srp': {
          'M1': clientSession.proof,
        }
      };

      // 設置HTTP頭
      final step3Header = {
        'Content-Type': 'application/json',
        'Cookie': 'sessionID=$sessionId',
      };

      // 步驟5: 發送客戶端證明（10秒超時）
      print("\n第5步: 發送客戶端證明");
      final step3Result = await loginStep3(step3Header, step3PostData).timeout(
          Duration(seconds: 10),
          onTimeout: () {
            print("步驟5超時：發送客戶端證明超過10秒");
            return LoginResult(
                response: null,
                returnStatus: false,
                session: emptySession,
                msg: "發送客戶端證明超時"
            );
          }
      );

      if (!step3Result.returnStatus) {
        print("發送証明失敗: ${step3Result.msg}");
        return step3Result;
      }

      // 解析返回的數據
      var dataFromStep3 = step3Result.getJson();
      print('從伺服器接收的數據: $dataFromStep3');

      // 步驟6: 獲取JWT令牌
      print("\n第6步: 獲取JWT令牌");
      String? jwtToken = null;
      if (dataFromStep3.containsKey('jwt')) {
        jwtToken = dataFromStep3['jwt'];
        print('成功獲取到JWT令牌: ${jwtToken!.substring(
            0, Math.min(20, jwtToken.length))}... (已截斷)');
      } else if (dataFromStep3.containsKey('token')) {
        jwtToken = dataFromStep3['token'];
        print('成功獲取到令牌: ${jwtToken!.substring(
            0, Math.min(20, jwtToken.length))}... (已截斷)');
      } else {
        print('警告: 伺服器回應中未找到JWT令牌');
      }

      // 步驟7: 驗證伺服器證明
      print("\n第7步: 驗證伺服器證明");
      if (dataFromStep3.containsKey('M') || dataFromStep3.containsKey('M2')) {
        String M2 = dataFromStep3.containsKey('M')
            ? dataFromStep3['M']
            : dataFromStep3['M2'];
        try {
          client.verifySession(clientEphemeral.public, clientSession, M2);
          print('伺服器證明驗證成功');
        } catch (e) {
          print('伺服器證明驗證警告: $e');
        }
      } else {
        print('伺服器未提供證明');
      }

      // 步驟8: 使用JWT令牌測試API（10秒超時）
      if (jwtToken != null) {
        print("\n第8步: 使用JWT令牌測試API");
        try {
          await loginStep4(jwtToken).timeout(
              Duration(seconds: 10),
              onTimeout: () {
                print("步驟8超時：JWT API測試超過10秒");
                // 這個步驟超時不影響登入成功，只是警告
              }
          );
          print("JWT API測試完成");
        } catch (e) {
          print('JWT API測試失敗: $e');
        }
      }

      // 步驟9: 確認登入成功（10秒超時）
      print("\n第9步: 確認登入成功");
      final dashboardHeaders = {
        'Cookie': 'sessionID=$sessionId',
      };

      try {
        await getDashboard(dashboardHeaders).timeout(
            Duration(seconds: 10),
            onTimeout: () {
              print("步驟9超時：訪問儀表板超過10秒");
              throw TimeoutException("訪問儀表板超時", Duration(seconds: 10));
            }
        );
        print("成功訪問儀表板，登入已確認");
      } catch (e) {
        print("警告: 無法訪問儀表板，但登入可能仍然成功: $e");
      }

      print("\n============ SRP登入流程完成 ============");
      return LoginResult(
          response: null,
          returnStatus: true,
          session: SessionInfo(
              sessionId: sessionId, csrfToken: _token, jwtToken: jwtToken),
          msg: "登入成功"
      );
    } catch (e) {
      print('SRP登入過程中發生錯誤: $e');
      return LoginResult(
          response: null,
          returnStatus: false,
          session: SessionInfo(sessionId: "", csrfToken: ""),
          msg: "登入錯誤: $e"
      );
    }
  }
}

class LoginResult {
  http.Response? response;
  bool returnStatus;
  String msg;
  SessionInfo session;

  LoginResult({required this.response, required this.returnStatus, required this.session, required this.msg});

  Map<String, dynamic> getJson() {
    try {
      if (response != null && response!.body.isNotEmpty) {
        return json.decode(response!.body);
      }
    } catch (e) {
      print("解析響應體時出錯: ${response?.body}");
    }
    return {};
  }
}

// Math 工具類用於截斷字串時保持安全
class Math {
  static int min(int a, int b) {
    return a < b ? a : b;
  }
}