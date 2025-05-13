import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

// 模擬API服務
class ApiService {
  final String baseUrl = 'http://localhost:8080'; // 模擬的API地址
}

// 模擬PrintUtil類別
class PrintUtil {
  static void printMap(String title, Map<String, dynamic> map) {
    print('$title:');
    map.forEach((key, value) {
      print('  $key: $value');
    });
  }
}

// 會話資訊類別
class SessionInfo {
  final String sessionId;
  final String csrfToken;

  SessionInfo({required this.sessionId, required this.csrfToken});
}

// 模擬SRP客戶端
class SrpClient {
  static String generateSalt() {
    return 'simulated_salt_123456';
  }

  static Map<String, String> generateEphemeral() {
    return {
      'public': 'simulated_public_key_abcdef',
      'secret': 'simulated_secret_key_123456'
    };
  }

  static String derivePrivateKey(String salt, String username, String password) {
    return 'simulated_private_key_${username}_$password';
  }

  static String deriveVerifier(String privateKey) {
    return 'simulated_verifier_$privateKey';
  }

  static Map<String, String> deriveSession(
      String secret, String B, String salt, String username, String privateKey) {
    return {
      'proof': 'simulated_proof_$username',
      'key': 'simulated_session_key_$username'
    };
  }

  static bool verifySession(String publicKey, Map<String, String> session, String M2) {
    return true; // 模擬驗證成功
  }
}

// 創建不安全的HTTP客戶端（允許自簽證書）
http.Client createUnsafeClient() {
  final ioClient = HttpClient()
    ..badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;

  return IOClient(ioClient);
}

// 登入結果類別
class LoginResult {
  http.Response? response;
  bool returnStatus;
  String msg;
  SessionInfo session;

  LoginResult({
    required this.response,
    required this.returnStatus,
    required this.session,
    required this.msg
  });

  Map<String, dynamic> getJson() {
    try {
      return json.decode(response!.body);
    } catch (e) {
      print("解析回應內容時出錯: ${response?.body}");
      return {};
    }
  }
}

// 模擬HTTP回應
http.Response mockResponse(int statusCode, dynamic body, {Map<String, String>? headers}) {
  return http.Response(
    body is String ? body : json.encode(body),
    statusCode,
    headers: headers ?? {'content-type': 'application/json'},
  );
}

// 登入處理類別
class LoginProcess {
  final String baseUrl = ApiService().baseUrl;

  String _username = '';
  String _password = '';
  String _token = '';
  SessionInfo emptySession = SessionInfo(sessionId: "", csrfToken: "");

  LoginProcess(this._username, this._password);

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
      print('CSRF_TOKEN not found in response body, could be a blank state?');
      return "simulated_csrf_token_abcdef"; // 模擬CSRF令牌
    }
  }

  String? getSessionID(String cookieHeader) {
    final RegExp regExp = RegExp(r'sessionID=([^;]+)');
    final match = regExp.firstMatch(cookieHeader);
    return match?.group(1);
  }

  LoginResult preCheck(http.Response res) {
    if (res.statusCode == 200) {
      return LoginResult(
          response: res,
          returnStatus: true,
          session: emptySession,
          msg: "access success"
      );
    } else if (res.statusCode == 302) {
      return LoginResult(
          response: res,
          returnStatus: false,
          session: emptySession,
          msg: "redirect to somewhere"
      );
    } else if (res.statusCode == 503) {
      return LoginResult(
          response: res,
          returnStatus: false,
          session: emptySession,
          msg: isSessionFull(res.headers) ? "The connection limit has been reached!" : "Unknown 503"
      );
    } else {
      return LoginResult(
          response: res,
          returnStatus: false,
          session: emptySession,
          msg: "unknown ${res.statusCode}"
      );
    }
  }

  // 模擬獲取登入頁面
  Future<LoginResult> loginStep1() async {
    print("模擬獲取登入頁面: $baseUrl/login.html");

    // 模擬HTTP回應
    final response = mockResponse(
        200,
        '<html><script>var CSRF_TOKEN = "abcdef1234567890abcdef1234567890";</script></html>',
        headers: {'set-cookie': 'sessionID=mock_session_123456; Path=/;'}
    );

    PrintUtil.printMap(' [STEP1] HEADER', response.headers);
    return preCheck(response);
  }

  // 模擬發送公鑰
  Future<LoginResult> loginStep2(Map<String, String> headers, Map<String, dynamic> data) async {
    print("模擬發送公鑰: $baseUrl/api/v1/user/login");
    print("請求數據: ${json.encode(data)}");

    // 模擬HTTP回應
    final response = mockResponse(
        200,
        {
          's': 'server_salt_123456',
          'B': 'server_public_key_abcdef'
        },
        headers: {'set-cookie': 'sessionID=mock_session_updated; Path=/;'}
    );

    PrintUtil.printMap(' [STEP2] HEADER', response.headers);
    return preCheck(response);
  }

  // 模擬發送證明
  Future<LoginResult> loginStep3(Map<String, String> headers, Map<String, dynamic> data) async {
    print("模擬發送證明: $baseUrl/api/v1/user/login");
    print("請求數據: ${json.encode(data)}");

    // 檢查證明是否與模擬值匹配
    if (data['srp']['M1'] == 'simulated_proof_$_username') {
      // 模擬成功登入
      final response = mockResponse(
          200,
          {
            'M': 'server_proof_123456',
            'jwt': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c'
          }
      );
      return preCheck(response);
    } else {
      // 模擬登入失敗
      final response = mockResponse(
          200,
          {
            'error': {
              'waitTime': 0,
              'msg': "M didn't match",
              'wrongCount': 1
            }
          }
      );
      var result = preCheck(response);
      try {
        var tmp = json.decode(result.response!.body);
        if (tmp['error'] != null) {
          return LoginResult(
              response: result.response,
              returnStatus: false,
              session: emptySession,
              msg: tmp['error']['msg']
          );
        }
      } catch (e) {
        print("step3 response parsing error!");
      }
      return result;
    }
  }

  // 模擬SRP登入流程
  Future<LoginResult> startSRPLoginProcess() async {
    try {
      // 步驟1: 獲取登入頁面
      var result = await loginStep1();
      if (!result.returnStatus) return result;

      _token = getCSRFToken(result.response!.body);
      String sessionId = getSessionIDFromHeaders(result.response!.headers) ?? "";
      print("獲取會話ID = $sessionId, CSRF令牌 = $_token");

      // 步驟2: 生成鹽值和密鑰
      final salt = SrpClient.generateSalt();
      print('生成鹽值: $salt');

      final clientEphemeral = SrpClient.generateEphemeral();
      print('客戶端臨時密鑰: 公鑰: ${clientEphemeral['public']}, 私鑰: ${clientEphemeral['secret']}');

      final step2PostData = {
        'method': 'srp',
        'srp': {
          'I': _username,
          'A': clientEphemeral['public'],
        }
      };

      final step2Header = {
        'Content-Type': 'application/json',
      };

      // 步驟3: 向伺服器發送公鑰
      result = await loginStep2(step2Header, step2PostData);
      sessionId = getSessionIDFromHeaders(result.response!.headers) ?? sessionId;
      print("更新會話ID = $sessionId");

      if (!result.returnStatus) return result;
      var dataFromStep2 = result.getJson();
      print('從伺服器接收到的鹽值和公鑰: $dataFromStep2');

      // 從伺服器接收的鹽值和公鑰
      String saltFromHost = dataFromStep2['s'];
      String BFromHost = dataFromStep2['B'];

      // 步驟4: 計算私鑰和會話
      final privateKey = SrpClient.derivePrivateKey(saltFromHost, _username, _password);
      final verifier = SrpClient.deriveVerifier(privateKey);
      final clientSession = SrpClient.deriveSession(
          clientEphemeral['secret']!,
          BFromHost,
          saltFromHost,
          _username,
          privateKey
      );

      print('客戶端會話證明: ${clientSession['proof']}');

      final step3Header = {
        'Content-Type': 'application/json',
        'Cookie': 'sessionID=$sessionId',
      };

      final step3PostData = {
        'method': 'srp',
        'srp': {
          'M1': clientSession['proof'],
        }
      };

      // 步驟5: 向伺服器發送證明
      result = await loginStep3(step3Header, step3PostData);
      if (!result.returnStatus) return result;

      var dataFromStep3 = result.getJson();
      print('從伺服器接收到的證明: $dataFromStep3');

      String M2 = dataFromStep3['M'];
      String jwt = dataFromStep3['jwt'];

      // 步驟6: 驗證伺服器回應
      bool verified = SrpClient.verifySession(clientEphemeral['public']!, clientSession, M2);
      if (verified) {
        print('伺服器驗證成功');
        return LoginResult(
            response: null,
            returnStatus: true,
            session: SessionInfo(sessionId: sessionId, csrfToken: _token),
            msg: "登入成功"
        );
      } else {
        return LoginResult(
            response: null,
            returnStatus: false,
            session: emptySession,
            msg: "伺服器驗證失敗"
        );
      }
    } catch (e) {
      print('錯誤: $e');
      return LoginResult(
          response: null,
          returnStatus: false,
          session: emptySession,
          msg: "登入錯誤: $e"
      );
    }
  }
}

// 主函數
void main() async {
  print('開始模擬API登入流程');

  // 創建登入處理實例
  final loginProcess = LoginProcess('test_user', 'test_password');

  // 啟動SRP登入流程
  final result = await loginProcess.startSRPLoginProcess();

  // 輸出結果
  print('\n登入結果:');
  print('狀態: ${result.returnStatus ? '成功' : '失敗'}');
  print('訊息: ${result.msg}');
  if (result.returnStatus) {
    print('會話ID: ${result.session.sessionId}');
    print('CSRF令牌: ${result.session.csrfToken}');
  }
}