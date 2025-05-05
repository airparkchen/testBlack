import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

/// SRP 登入結果類
class SrpLoginResult {
  /// 登入是否成功
  final bool success;

  /// 返回的消息
  final String message;

  /// 會話ID
  final String sessionId;

  /// CSRF令牌
  final String csrfToken;

  /// 原始HTTP響應（可選）
  final http.Response? response;

  /// JSON解析後的資料（如果有）
  final Map<String, dynamic>? data;

  SrpLoginResult({
    required this.success,
    required this.message,
    this.sessionId = '',
    this.csrfToken = '',
    this.response,
    this.data,
  });

  /// 從JSON解析數據
  Map<String, dynamic> getJson() {
    if (data != null) {
      return data!;
    }

    try {
      if (response != null && response!.body.isNotEmpty) {
        return json.decode(response!.body);
      }
    } catch (e) {
      debugPrint("解析JSON時出錯: ${response?.body}");
    }
    return {};
  }
}

/// SRP 會話信息類
class SrpSessionInfo {
  final String sessionId;
  final String csrfToken;

  SrpSessionInfo({
    required this.sessionId,
    required this.csrfToken,
  });
}

/// SRP 登入服務類
class SrpLoginService {
  /// 基礎URL
  final String baseUrl;

  /// 用戶名
  final String username;

  /// 密碼
  final String password;

  /// CSRF令牌
  String _token = '';

  /// HTTP客戶端
  final http.Client _client = http.Client();

  /// 建構函數
  SrpLoginService({
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  /// 檢查會話是否已滿
  bool _isSessionFull(Map<String, String> headers) {
    String? sessionFull = headers['retry-after'];
    return sessionFull != null;
  }

  /// 從headers中獲取會話ID
  String? _getSessionIDFromHeaders(Map<String, String> headers) {
    String? cookie = headers['set-cookie'];
    if (cookie == null) {
      return null;
    }
    return _getSessionID(cookie);
  }

  /// 從cookie字符串中提取會話ID
  String? _getSessionID(String cookieHeader) {
    if (cookieHeader.isEmpty) return null;
    final RegExp regExp = RegExp(r'sessionID=([^;]+)');
    final match = regExp.firstMatch(cookieHeader);
    return match?.group(1);
  }

  /// 從響應主體中提取CSRF令牌
  String _getCSRFToken(String responseBody) {
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

  /// 從向導頁面獲取CSRF令牌
  Future<void> _getCsrfFromWizard() async {
    final String wizPage = '$baseUrl/wizard.html';
    debugPrint("Getting CSRF from: ${Uri.parse(wizPage)}");
    final response = await _client.get(Uri.parse(wizPage));
    if (response.statusCode == 200) {
      debugPrint("Got response from wizard.html");
      _token = _getCSRFToken(response.body);
    }
  }

  /// 檢查HTTP響應狀態
  SrpLoginResult _preCheck(http.Response res) {
    if (res.statusCode == 200) {
      return SrpLoginResult(
          success: true,
          message: "access success",
          response: res
      );
    } else if (res.statusCode == 302) {
      return SrpLoginResult(
          success: false,
          message: "redirect to somewhere",
          response: res
      );
    } else if (res.statusCode == 503) {
      return SrpLoginResult(
          success: false,
          message: _isSessionFull(res.headers) ? "The connection limit has been reached!" : "Unknown 503",
          response: res
      );
    } else {
      return SrpLoginResult(
          success: false,
          message: "unknown ${res.statusCode}",
          response: res
      );
    }
  }

  /// 登入步驟1：獲取登入頁面以及會話ID
  Future<SrpLoginResult> _loginStep1() async {
    final String loginPath = '$baseUrl/login.html';
    debugPrint("Getting: ${Uri.parse(loginPath)}");
    final response = await _client.get(Uri.parse(loginPath));
    debugPrint("Step 1 status: ${response.statusCode}");

    // 列印headers以幫助調試
    response.headers.forEach((key, value) {
      debugPrint("$key: $value");
    });

    return _preCheck(response);
  }

  /// 登入步驟2：發送公鑰到服務器
  Future<SrpLoginResult> _loginStep2(Map<String, String> headers, Map<String, dynamic> data) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/cgi-bin/webPost.plua?csrftoken=$_token'),
      headers: headers,
      body: json.encode(data),
    );

    debugPrint("Step 2 status: ${response.statusCode}");
    response.headers.forEach((key, value) {
      debugPrint("$key: $value");
    });

    return _preCheck(response);
  }

  /// 登入步驟3：發送證明M到服務器
  Future<SrpLoginResult> _loginStep3(Map<String, String> headers, Map<String, dynamic> data) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/cgi-bin/webPost.plua?csrftoken=$_token'),
      headers: headers,
      body: json.encode(data),
    );

    var result = _preCheck(response);

    try {
      if (result.success && result.response != null) {
        var responseData = json.decode(result.response!.body);

        if (responseData.containsKey('error')) {
          return SrpLoginResult(
              success: false,
              message: responseData['error']['msg'] ?? 'Unknown error',
              response: result.response,
              data: responseData
          );
        }

        return SrpLoginResult(
            success: true,
            message: "Authentication successful",
            response: result.response,
            data: responseData
        );
      }
    } catch (e) {
      debugPrint("Step 3 response parsing error: $e");
    }

    return result;
  }

  /// 獲取儀表板頁面
  Future<String?> _getDashboard(Map<String, String> headers) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/dashboard.html?csrftoken=$_token'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      debugPrint("Dashboard loaded successfully");
      return response.body;
    } else {
      debugPrint("Failed to load dashboard: ${response.statusCode}");
      return null;
    }
  }

  /// 生成隨機BigInt
  BigInt _generateRandomBigInt(int bytes) {
    final random = Random.secure();
    final randomBytes = List<int>.generate(bytes, (_) => random.nextInt(256));
    return BigInt.parse(
        randomBytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(''),
        radix: 16
    );
  }

  /// 十六進制字符串轉換為位元組數組
  Uint8List _hexToBytes(String hex) {
    // 確保長度為偶數
    if (hex.length % 2 != 0) {
      hex = '0$hex';
    }

    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      final value = int.parse(hex.substring(i, i + 2), radix: 16);
      result[i ~/ 2] = value;
    }
    return result;
  }

  /// 位元組數組轉換為十六進制字符串
  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  }

  /// SRP-6a 參數 - RFC 5054 中定義的 1024 位元素模安全數
  static final BigInt N = BigInt.parse(
    'EEAF0AB9ADB38DD69C33F80AFA8FC5E86072618775FF3C0B9EA2314C9C256576D674DF7496EA81D3383B4813D692C6E0E0D5D8E250B98BE48E495C1D6089DAD15DC7D7B46154D6B6CE8EF4AD69B15D4982559B297BCF1885C529F566660E57EC68EDBC3C05726CC02FD4CBF4976EAA9AFD5138FE8376435B9FC61D2FC0EB06E3',
    radix: 16,
  );
  static final BigInt g = BigInt.from(2);
  static final BigInt k = BigInt.from(3);

  /// 計算SRP證明
  Uint8List _computeSrpProof({
    required String username,
    required String password,
    required Uint8List salt,
    required Uint8List serverPublic,
    required Uint8List clientPublic,
    required BigInt privateKey
  }) {
    // 計算 u = H(A | B)
    final clientPublicHex = _bytesToHex(clientPublic);
    final serverPublicHex = _bytesToHex(serverPublic);

    final u = BigInt.parse(
        sha1.convert(utf8.encode(clientPublicHex + serverPublicHex)).toString(),
        radix: 16
    );

    // 計算 x = H(s | H(I | ":" | P))
    final identityHash = sha1.convert(utf8.encode('$username:$password')).toString();
    final saltHex = _bytesToHex(salt);

    final x = BigInt.parse(
        sha1.convert(utf8.encode(saltHex + identityHash)).toString(),
        radix: 16
    );

    // 計算 v = g^x % N
    final v = g.modPow(x, N);

    // 計算 S = (B - k * v) ^ (a + u * x) % N
    final B = BigInt.parse(_bytesToHex(serverPublic), radix: 16);
    final kv = (k * v) % N;

    late BigInt S;
    if (B > kv) {
      S = (B - kv).modPow(privateKey + u * x, N);
    } else {
      S = (B + N - kv).modPow(privateKey + u * x, N);
    }

    // 計算 K = H(S)
    final K = Uint8List.fromList(
        sha1.convert(utf8.encode(S.toRadixString(16))).bytes
    );

    // 計算 M = H(A | B | K)
    final M = sha1.convert(utf8.encode(
        clientPublicHex + serverPublicHex + _bytesToHex(K)
    )).bytes;

    return Uint8List.fromList(M);
  }

  /// 開始SRP登入流程
  Future<SrpLoginResult> login() async {
    try {
      // 1. 獲取登入頁面，提取CSRF令牌和會話ID
      var result = await _loginStep1();
      if (!result.success) return result;

      _token = _getCSRFToken(result.response!.body);
      String sessionId = _getSessionIDFromHeaders(result.response!.headers) ?? "";
      debugPrint("Session ID: $sessionId, CSRF Token: $_token");

      if (_token.isEmpty) {
        // 可能是空狀態，嘗試從向導頁面獲取CSRF令牌
        await _getCsrfFromWizard();

        return SrpLoginResult(
            success: true,
            message: "Got CSRF from wizard",
            sessionId: sessionId,
            csrfToken: _token
        );
      }

      // 2. 生成客戶端臨時密鑰對
      final clientEphemeral = _generateEphemeral();
      debugPrint('Client public key: ${clientEphemeral['public']}, private key: ${clientEphemeral['secret']}');

      // 構建步驟2的請求數據
      final step2PostData = {
        'function': 'authenticate',
        'data': {
          'CSRFtoken': _token,
          'I': username,
          'A': clientEphemeral['public'],
        }
      };

      final step2Header = {
        'Content-Type': 'application/json',
        'Referer': '$baseUrl/login.html',
        'Cookie': 'sessionID=$sessionId',
      };

      // 3. 發送公鑰到服務器
      result = await _loginStep2(step2Header, step2PostData);
      if (!result.success) return result;

      var dataFromStep2 = result.getJson();
      debugPrint('Server response: $dataFromStep2');

      // 獲取服務器發送的鹽值和公鑰
      String saltFromHost = dataFromStep2['s'];
      String BFromHost = dataFromStep2['B'];

      // 計算私鑰、驗證器和會話密鑰
      final privateKey = _derivePrivateKey(saltFromHost, username, password);
      final proof = _computeSrpProof(
          username: username,
          password: password,
          salt: _hexToBytes(saltFromHost),
          serverPublic: _hexToBytes(BFromHost),
          clientPublic: _hexToBytes(clientEphemeral['public']!),
          privateKey: BigInt.parse(clientEphemeral['secret']!, radix: 16)
      );

      // 構建步驟3的請求數據
      final step3Header = {
        'Content-Type': 'application/json',
        'Origin': baseUrl,
        'Referer': '$baseUrl/login.html',
        'Cookie': 'sessionID=$sessionId',
      };

      final step3PostData = {
        'function': 'authenticate',
        'data': {
          'CSRFtoken': '',
          'M': _bytesToHex(proof),
        }
      };

      // 發送證明M到服務器
      result = await _loginStep3(step3Header, step3PostData);
      if (!result.success) return result;

      var dataFromStep3 = result.getJson();
      debugPrint('M2 from server: $dataFromStep3');

      // 現在嘗試獲取儀表板來確認登入成功
      final dashboardHeaders = {
        'Cookie': 'sessionID=$sessionId',
      };

      final dashboard = await _getDashboard(dashboardHeaders);

      if (dashboard != null) {
        return SrpLoginResult(
            success: true,
            message: "Login successful, dashboard loaded",
            sessionId: sessionId,
            csrfToken: _token,
            data: dataFromStep3
        );
      } else {
        return SrpLoginResult(
            success: true,
            message: "Authentication successful but dashboard not loaded",
            sessionId: sessionId,
            csrfToken: _token,
            data: dataFromStep3
        );
      }
    } catch (e) {
      debugPrint('SRP login error: $e');
      return SrpLoginResult(
        success: false,
        message: "Login error: $e",
      );
    }
  }

  /// 生成臨時密鑰對
  Map<String, String> _generateEphemeral() {
    final secret = _generateRandomBigInt(32).toRadixString(16);
    final secretBigInt = BigInt.parse(secret, radix: 16);
    final publicBigInt = g.modPow(secretBigInt, N);
    final public = publicBigInt.toRadixString(16);

    return {
      'secret': secret,
      'public': public,
    };
  }

  /// 從鹽值和密碼導出私鑰
  String _derivePrivateKey(String salt, String username, String password) {
    final identity = '$username:$password';
    final identityHash = sha1.convert(utf8.encode(identity)).toString();
    final saltedIdentity = salt + identityHash;
    final privateKey = sha1.convert(utf8.encode(saltedIdentity)).toString();
    return privateKey;
  }

  /// 釋放資源
  void dispose() {
    _client.close();
  }
}