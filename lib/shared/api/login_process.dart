import 'dart:developer';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:srp/client.dart' as client;
import 'package:http/io_client.dart';
import '../connection/connection_utils.dart';
import '../utils/utility.dart';

http.Client createUnsafeClient() {
  final ioClient = HttpClient()
    ..badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;

  return IOClient(ioClient);
}

class SessionInfo {
  final String sessionId;
  final String csrfToken;

  SessionInfo({required this.sessionId, required this.csrfToken});
}

class LoginProcess {
  final String baseUrl;
  String _username = '';
  String _password = '';
  String _token = '';
  SessionInfo emptySession = SessionInfo(sessionId: "", csrfToken: "");

  LoginProcess(this._username, this._password, {required this.baseUrl});

  // 新增 getSessionID 方法
  String? getSessionID(String cookieHeader) {
    if (cookieHeader.isEmpty) return null;
    final RegExp regExp = RegExp(r'sessionID=([^;]+)');
    final match = regExp.firstMatch(cookieHeader);
    return match?.group(1);
  }

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
      return "";
    }
  }

  Future<void> getCsrfFromWizard() async {
    final String wizPage = '$baseUrl/wizard.html';
    print("print get from : ${Uri.parse(wizPage)}");
    final response = await http.get(Uri.parse(wizPage));
    if (response.statusCode == 200) {
      PrintUtil.printMap('HEADER', response.headers);
      print("_token is getting from wizard.html");
      _token = getCSRFToken(response.body);
    }
  }

  LoginResult preCheck(http.Response res) {
    if (res.statusCode == 200) {
      return LoginResult(response: res, returnStatus: true, session: emptySession, msg: "access success");
    } else if (res.statusCode == 302) {
      return LoginResult(response: res, returnStatus: false, session: emptySession, msg: "redirect to somewhere");
    } else if (res.statusCode == 503) {
      return LoginResult(
          response: res,
          returnStatus: false,
          session: emptySession,
          msg: isSessionFull(res.headers) ? "The connection limit has been reached!" : "Unknown 503");
    } else {
      return LoginResult(response: res, returnStatus: false, session: emptySession, msg: "unknown ${res.statusCode}");
    }
  }

  static int rCount = 1;

  Future<LoginResult> loginStep1() async {
    final String loginPath = '$baseUrl/login.html';
    print("print get : ${Uri.parse(loginPath)}");
    final response = await http.get(Uri.parse(loginPath));
    PrintUtil.printMap(' [STEP1] HEADER', response.headers);
    return preCheck(response);
  }

  Future<LoginResult> loginStep2(Map<String, String> headers, Map<String, dynamic> data) async {
    final client = createUnsafeClient();
    final response = await client.post(
      Uri.parse('$baseUrl/api/v1/user/login'),
      headers: headers,
      body: json.encode(data),
    );
    PrintUtil.printMap(' [STEP2] HEADER', response.headers);
    return preCheck(response);
  }

  Future<LoginResult> loginStep3(Map<String, String> headers, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/user/login'),
      headers: headers,
      body: json.encode(data),
    );
    var result = preCheck(response);
    try {
      var tmp = json.decode(result.response!.body);
      if (tmp['error'] != null) {
        return LoginResult(
            response: result.response, returnStatus: false, session: emptySession, msg: tmp['error']['msg']);
      }
    } catch (e) {
      print("step3 response parsing error!");
    }
    return result;
  }

  Future<dynamic> getDashboard(Map<String, String> headers) async {
    final response = await http.post(
      Uri.parse('$baseUrl/dashboard.html?csrftoken=$_token'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      print(response.body);
      return response.body;
    } else {
      print("Code : ${response.statusCode}");
      throw Exception('Failed to send data to login get Dashboard');
    }
  }

  Future<LoginResult> startSRPLoginProcess() async {
    try {
      // 步驟 1：調用 loginStep1 獲取 sessionId 和 CSRF 令牌
      var result = await loginStep1();
      if (!result.returnStatus) {
        return result;
      }

      _token = getCSRFToken(result.response!.body);
      var sessionId = getSessionIDFromHeaders(result.response!.headers) ?? "";
      print("get session = $sessionId, token = $_token");

      // 若 CSRF 令牌為空，嘗試從 wizard.html 獲取
      if (_token.isEmpty) {
        print("CSRF token is empty, attempting to fetch from wizard.html");
        await getCsrfFromWizard();
        if (_token.isEmpty) {
          return LoginResult(
            response: null,
            returnStatus: false,
            session: SessionInfo(sessionId: sessionId, csrfToken: _token),
            msg: "Failed to retrieve CSRF token from wizard.html",
          );
        }
      }

      // 步驟 2：進行 SRP 登錄流程
      final salt = client.generateSalt();
      print('generateSalt : $salt');

      final clientEphemeral = client.generateEphemeral();
      print('clientEphemeral : public : ${clientEphemeral.public} \n secret : ${clientEphemeral.secret}');

      final step2PostData = {
        'method': 'srp',
        'srp': {
          'I': _username,
          'A': clientEphemeral.public,
        }
      };

      final step2Header = {
        'Content-Type': 'application/json',
      };

      result = await loginStep2(step2Header, step2PostData);
      sessionId = getSessionIDFromHeaders(result.response!.headers) ?? sessionId;
      print("get session = $sessionId");
      if (!result.returnStatus) return result;
      var dataFromStep2 = result.getJson();
      print('salt and B received from server : $dataFromStep2');

      String saltFromHost = dataFromStep2['s'];
      String BFromHost = dataFromStep2['B'];

      final privateKey = client.derivePrivateKey(saltFromHost, _username, _password);
      final verifier = client.deriveVerifier(privateKey);
      final clientSession =
      client.deriveSession(clientEphemeral.secret, BFromHost, saltFromHost, _username, privateKey);
      print('clientSession : M1: ${clientSession.proof} ');

      final step3Header = {
        'Content-Type': 'application/json',
        'Cookie': 'sessionID=$sessionId',
      };

      final step3PostData = {
        'method': 'srp',
        'srp': {
          'M1': clientSession.proof,
        }
      };

      result = await loginStep3(step3Header, step3PostData);
      if (!result.returnStatus) return result;
      var dataFromStep3 = result.getJson();
      print('Received M2 from server : $dataFromStep3');

      if (dataFromStep3['M'] == null) {
        return LoginResult(
          response: null,
          returnStatus: false,
          session: SessionInfo(sessionId: sessionId, csrfToken: _token),
          msg: "Login failed: M2 not received from server, ${dataFromStep3['message'] ?? 'Unknown error'}",
        );
      }

      String M2 = dataFromStep3['M'];
      client.verifySession(clientEphemeral.public, clientSession, M2);
      print('client.verifySession : public = ${clientEphemeral.public}, clientSession = ${clientSession}, M2 = $M2');
      return LoginResult(
          response: null,
          returnStatus: true,
          session: SessionInfo(sessionId: sessionId, csrfToken: _token),
          msg: "login success");
    } catch (e) {
      print('Error: $e');
      return LoginResult(
          response: null,
          returnStatus: false,
          session: SessionInfo(sessionId: "", csrfToken: ""),
          msg: "login error $e");
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
      return json.decode(response!.body);
    } catch (e) {
      print("error body is : ${response?.body}");
      return {};
    }
  }
}