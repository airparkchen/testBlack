import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:srp/client.dart' as client;
import 'package:crypto/crypto.dart';
import 'dart:typed_data';

// 連接工具和會話信息的簡化版本
class SessionInfo {
  final String sessionId;
  final String csrfToken;

  SessionInfo({required this.sessionId, required this.csrfToken});
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
      print("error body is :  ${response?.body}");
      return {};
    }
  }
}

class SrpLoginModifiedTestPage extends StatefulWidget {
  const SrpLoginModifiedTestPage({Key? key}) : super(key: key);

  @override
  State<SrpLoginModifiedTestPage> createState() => _SrpLoginModifiedTestPageState();
}

class _SrpLoginModifiedTestPageState extends State<SrpLoginModifiedTestPage> {
  String _statusMessage = "點擊按鈕開始測試";
  bool _isLoading = false;
  String _csrfToken = "";
  bool _loginSuccess = false;
  String _logOutput = "準備開始測試...";
  final _scrollController = ScrollController();

  final TextEditingController _usernameController = TextEditingController(text: "admin");
  final TextEditingController _passwordController = TextEditingController(text: "3033b8c2f480de5d01a310d198e74b84d5ddeb73a40b04bef95a7ce167cce6f7");
  final TextEditingController _baseUrlController = TextEditingController(text: "http://192.168.1.1");

  @override
  void dispose() {
    _scrollController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  // 日誌輸出並滾動
  void _logAdd(String msg) {
    setState(() {
      _logOutput += "\n$msg";
    });

    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // 更新狀態消息
  void _updateStatus(String status) {
    setState(() {
      _statusMessage = status;
    });
  }

  // 驗證表單
  bool _validateForm() {
    if (_usernameController.text.isEmpty) {
      _updateStatus("請輸入用戶名");
      return false;
    }
    if (_passwordController.text.isEmpty) {
      _updateStatus("請輸入密碼");
      return false;
    }
    if (_baseUrlController.text.isEmpty) {
      _updateStatus("請輸入基本 URL");
      return false;
    }
    return true;
  }

  // 從 headers 中獲取 SessionID
  String? getSessionIDFromHeaders(Map<String, String> headers) {
    String? cookie = headers['set-cookie'];
    if (cookie == null) {
      return null;
    }
    return getSessionID(cookie);
  }

  // 從 Cookie 字符串中提取 SessionID
  String? getSessionID(String cookieHeader) {
    if (cookieHeader.isEmpty) return null;
    final RegExp regExp = RegExp(r'sessionID=([^;]+)');
    final match = regExp.firstMatch(cookieHeader);
    return match?.group(1);
  }

  // 從響應中提取 CSRF 令牌
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

  // 檢查會話是否已滿
  bool isSessionFull(Map<String, String> headers) {
    String? sessionFull = headers['retry-after'];
    return sessionFull != null;
  }

  // 預檢查響應
  LoginResult preCheck(http.Response res) {
    SessionInfo emptySession = SessionInfo(sessionId: "", csrfToken: "");

    if (res.statusCode == 200) {
      return LoginResult(response: res, returnStatus: true, session: emptySession, msg: "access success");
    } else if (res.statusCode == 302) {
      return LoginResult(response: res, returnStatus: false, session: emptySession, msg: "redirect to somewhere");
    } else if (res.statusCode == 503) {
      return LoginResult(response: res, returnStatus: false, session: emptySession, msg: isSessionFull(res.headers) ? "The connection limit has been reached!" : "Unknown 503");
    } else {
      return LoginResult(response: res, returnStatus: false, session: emptySession, msg: "unknown ${res.statusCode}");
    }
  }

  // 從 wizard.html 獲取 CSRF 令牌
  Future<void> getCsrfFromWizard(String baseUrl) async {
    final String wizPage = '$baseUrl/wizard.html';
    _logAdd("嘗試從 $wizPage 獲取 CSRF 令牌");
    print("嘗試從 $wizPage 獲取 CSRF 令牌");

    try {
      final response = await http.get(Uri.parse(wizPage));

      if (response.statusCode == 200) {
        _logAdd("成功取得 wizard.html 回應");
        print("成功取得 wizard.html 回應");
        _csrfToken = getCSRFToken(response.body);
        _logAdd("CSRF 令牌 = $_csrfToken");
        print("CSRF 令牌 = $_csrfToken");
      } else {
        _logAdd("無法取得 wizard.html: ${response.statusCode}");
        print("無法取得 wizard.html: ${response.statusCode}");
      }
    } catch (e) {
      _logAdd("獲取 wizard.html 時出錯: $e");
      print("獲取 wizard.html 時出錯: $e");
    }
  }

  // 登入步驟 1: 獲取登入頁面和 Session ID
  Future<LoginResult> loginStep1(String baseUrl) async {
    final String loginPath = '$baseUrl/login.html';
    _logAdd("取得登入頁面: ${Uri.parse(loginPath)}");
    print("取得登入頁面: ${Uri.parse(loginPath)}");

    try {
      final response = await http.get(Uri.parse(loginPath));
      _logAdd("登入頁面狀態碼: ${response.statusCode}");
      print("登入頁面狀態碼: ${response.statusCode}");

      // 打印頭部以幫助調試
      response.headers.forEach((key, value) {
        _logAdd("$key: $value");
        print("$key: $value");
      });

      return preCheck(response);
    } catch (e) {
      _logAdd("登入步驟 1 出錯: $e");
      print("登入步驟 1 出錯: $e");
      return LoginResult(
          response: null,
          returnStatus: false,
          session: SessionInfo(sessionId: "", csrfToken: ""),
          msg: "step1 error: $e"
      );
    }
  }

  // 登入步驟 2: 發送公鑰到服務器
  Future<LoginResult> loginStep2(String baseUrl, Map<String, String> headers, Map<String, dynamic> data) async {
    _logAdd("發送公鑰到服務器");
    print("發送公鑰到服務器");
    _logAdd("數據: ${json.encode(data)}");
    print("數據: ${json.encode(data)}");

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/cgi-bin/webPost.plua?csrftoken=$_csrfToken'),
        headers: headers,
        body: json.encode(data),
      );

      _logAdd("步驟 2 狀態碼: ${response.statusCode}");
      print("步驟 2 狀態碼: ${response.statusCode}");
      response.headers.forEach((key, value) {
        _logAdd("$key: $value");
        print("$key: $value");
      });

      return preCheck(response);
    } catch (e) {
      _logAdd("登入步驟 2 出錯: $e");
      print("登入步驟 2 出錯: $e");
      return LoginResult(
          response: null,
          returnStatus: false,
          session: SessionInfo(sessionId: "", csrfToken: ""),
          msg: "step2 error: $e"
      );
    }
  }

  // 登入步驟 3: 發送 M1 證明到服務器 (修改了參數名從 M 到 M1)
  Future<LoginResult> loginStep3(String baseUrl, Map<String, String> headers, Map<String, dynamic> data) async {
    _logAdd("發送 M1 證明到服務器");
    print("發送 M1 證明到服務器");
    _logAdd("數據: ${json.encode(data)}");
    print("數據: ${json.encode(data)}");

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/cgi-bin/webPost.plua?csrftoken=$_csrfToken'),
        headers: headers,
        body: json.encode(data),
      );

      _logAdd("步驟 3 狀態碼: ${response.statusCode}");
      print("步驟 3 狀態碼: ${response.statusCode}");

      var result = preCheck(response);

      try {
        if (result.returnStatus && result.response != null) {
          var responseData = json.decode(result.response!.body);
          _logAdd("回應數據: $responseData");
          print("回應數據: $responseData");

          if (responseData.containsKey('error')) {
            return LoginResult(
                response: result.response,
                returnStatus: false,
                session: SessionInfo(sessionId: "", csrfToken: ""),
                msg: responseData['error']['msg'] ?? 'Unknown error'
            );
          }
        }
      } catch (e) {
        _logAdd("步驟 3 回應解析錯誤: $e");
        print("步驟 3 回應解析錯誤: $e");
      }

      return result;
    } catch (e) {
      _logAdd("登入步驟 3 出錯: $e");
      print("登入步驟 3 出錯: $e");
      return LoginResult(
          response: null,
          returnStatus: false,
          session: SessionInfo(sessionId: "", csrfToken: ""),
          msg: "step3 error: $e"
      );
    }
  }

  // 獲取儀表板頁面
  Future<bool> getDashboard(String baseUrl, String sessionId) async {
    final dashboardUrl = "$baseUrl/dashboard.html?csrftoken=$_csrfToken";
    _logAdd("嘗試獲取儀表板: $dashboardUrl");
    print("嘗試獲取儀表板: $dashboardUrl");

    try {
      final headers = {
        'Cookie': 'sessionID=$sessionId',
      };

      final response = await http.get(
        Uri.parse(dashboardUrl),
        headers: headers,
      );

      if (response.statusCode == 200) {
        _logAdd("儀表板加載成功");
        print("儀表板加載成功");
        return true;
      } else {
        _logAdd("無法加載儀表板: ${response.statusCode}");
        print("無法加載儀表板: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      _logAdd("獲取儀表板時出錯: $e");
      print("獲取儀表板時出錯: $e");
      return false;
    }
  }

  // 開始 SRP 登入流程
  Future<void> startSRPLoginProcess() async {
    if (_isLoading) return;
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
      _loginSuccess = false;
      _logOutput = "開始 SRP 登入流程...";
    });

    try {
      // 設定參數
      final baseUrl = _baseUrlController.text;
      final username = _usernameController.text;
      final password = _passwordController.text;

      _updateStatus("步驟 1/3: 獲取登入頁面...");

      // 1. 獲取登入頁面，提取 CSRF 令牌和會話 ID
      var result = await loginStep1(baseUrl);
      if (!result.returnStatus) {
        _updateStatus("獲取登入頁面失敗: ${result.msg}");
        setState(() { _isLoading = false; });
        return;
      }

      // 第一個修改：從 response headers 獲取 sessionId
      String sessionId = getSessionIDFromHeaders(result.response!.headers) ?? "";
      _logAdd("從回應標頭獲取會話 ID: $sessionId");
      print("從回應標頭獲取會話 ID: $sessionId");

      _csrfToken = getCSRFToken(result.response!.body);
      _logAdd("獲取到 CSRF 令牌: $_csrfToken");
      print("獲取到 CSRF 令牌: $_csrfToken");

      if (_csrfToken.isEmpty) {
        _logAdd("未找到 CSRF 令牌，嘗試從精靈頁面獲取...");
        print("未找到 CSRF 令牌，嘗試從精靈頁面獲取...");
        await getCsrfFromWizard(baseUrl);

        if (_csrfToken.isEmpty) {
          _updateStatus("無法獲取 CSRF 令牌，登入失敗");
          setState(() { _isLoading = false; });
          return;
        }
      }

      _updateStatus("步驟 2/3: 生成並發送公鑰...");

      // 2. 生成 SRP 參數並發送公鑰
      final salt = client.generateSalt();
      _logAdd("生成鹽值: $salt");
      print("生成鹽值: $salt");

      final clientEphemeral = client.generateEphemeral();
      _logAdd("客戶端臨時密鑰: 公鑰=${clientEphemeral.public}, 私鑰=${clientEphemeral.secret}");
      print("客戶端臨時密鑰: 公鑰=${clientEphemeral.public}, 私鑰=${clientEphemeral.secret}");

      final step2PostData = {
        'function': 'authenticate',
        'data': {
          'CSRFtoken': _csrfToken,
          'I': username,
          'A': clientEphemeral.public,
        }
      };

      final step2Header = {
        'Content-Type': 'application/json',
        'Referer': '$baseUrl/login.html',
        'Cookie': 'sessionID=$sessionId',
      };

      result = await loginStep2(baseUrl, step2Header, step2PostData);
      if (!result.returnStatus) {
        _updateStatus("發送公鑰失敗: ${result.msg}");
        setState(() { _isLoading = false; });
        return;
      }

      var dataFromStep2 = result.getJson();
      _logAdd("從服務器接收: $dataFromStep2");
      print("從服務器接收: $dataFromStep2");

      if (!dataFromStep2.containsKey('s') || !dataFromStep2.containsKey('B')) {
        _updateStatus("服務器未返回必要參數");
        setState(() { _isLoading = false; });
        return;
      }

      String saltFromHost = dataFromStep2['s'];
      String BFromHost = dataFromStep2['B'];

      _updateStatus("步驟 3/3: 計算並發送驗證證明...");

      // 3. 計算 SRP 會話參數
      final privateKey = client.derivePrivateKey(saltFromHost, username, password);
      final verifier = client.deriveVerifier(privateKey);
      final clientSession = client.deriveSession(
          clientEphemeral.secret,
          BFromHost,
          saltFromHost,
          username,
          privateKey
      );

      _logAdd("計算的驗證證明 M1: ${clientSession.proof}");
      print("計算的驗證證明 M1: ${clientSession.proof}");

      final step3Header = {
        'Content-Type': 'application/json',
        'Origin': baseUrl,
        'Referer': '$baseUrl/login.html',
        'Cookie': 'sessionID=$sessionId',
      };

      // 第二個修改：將參數名從 M 改為 M1
      final step3PostData = {
        'function': 'authenticate',
        'data': {
          'CSRFtoken': '',
          'M1': clientSession.proof,  // 這裡已修改從 M 到 M1
        }
      };

      result = await loginStep3(baseUrl, step3Header, step3PostData);
      if (!result.returnStatus) {
        _updateStatus("發送驗證證明失敗: ${result.msg}");
        setState(() { _isLoading = false; });
        return;
      }

      var dataFromStep3 = result.getJson();
      _logAdd("從服務器接收 M2: $dataFromStep3");
      print("從服務器接收 M2: $dataFromStep3");

      if (dataFromStep3.containsKey('M')) {
        String M2 = dataFromStep3['M'];
        _logAdd("驗證服務器證明 M2...");
        print("驗證服務器證明 M2...");

        try {
          // 驗證服務器的證明
          client.verifySession(clientEphemeral.public, clientSession, M2);
          _logAdd("服務器驗證成功!");
          print("服務器驗證成功!");

          // 嘗試獲取儀表板以確認登入成功
          bool dashboardSuccess = await getDashboard(baseUrl, sessionId);

          if (dashboardSuccess) {
            _updateStatus("登入成功！已載入儀表板");
            setState(() {
              _loginSuccess = true;
            });
          } else {
            _updateStatus("驗證成功但無法載入儀表板");
          }
        } catch (e) {
          _logAdd("服務器驗證失敗: $e");
          print("服務器驗證失敗: $e");
          _updateStatus("服務器驗證失敗");
        }
      } else {
        _logAdd("服務器未返回 M2 證明，但步驟 3 成功完成");
        print("服務器未返回 M2 證明，但步驟 3 成功完成");
        _updateStatus("登入可能成功，但缺少服務器證明");
      }
    } catch (e) {
      _logAdd("登入過程出錯: $e");
      print("登入過程出錯: $e");
      _updateStatus("登入過程出錯: ${e.toString().split('\n')[0]}");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SRP 登入測試 (修改版)'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 狀態顯示
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              color: _loginSuccess ? Colors.green[100] : Colors.blue[50],
              child: Column(
                children: [
                  Icon(
                    _loginSuccess ? Icons.check_circle : Icons.info,
                    size: 50,
                    color: _loginSuccess ? Colors.green : Colors.blue,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _statusMessage,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _loginSuccess ? Colors.green[800] : Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // 輸入表單
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('基本 URL', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(
                    controller: _baseUrlController,
                    decoration: const InputDecoration(
                      hintText: 'http://192.168.1.1',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('用戶名', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      hintText: '用戶名',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('密碼', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: '密碼',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : startSRPLoginProcess,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                          : const Text('執行 SRP 登入測試', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),

            // 日誌輸出
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(8),
              height: 300,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(5),
              ),
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Text(
                  _logOutput,
                  style: const TextStyle(
                    color: Colors.green,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}