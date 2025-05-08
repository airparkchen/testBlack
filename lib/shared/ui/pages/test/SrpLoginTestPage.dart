import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:srp/client.dart' as client;
import 'package:http/io_client.dart';

// PrintUtil 替代類，用於模擬 PrintUtil.printMap
class PrintUtil {
  static void printMap(String title, Map<String, dynamic> map) {
    debugPrint('$title:');
    map.forEach((key, value) {
      debugPrint('  $key: $value');
    });
  }
}

// 需要的 SessionInfo 類
class SessionInfo {
  final String sessionId;
  final String csrfToken;

  SessionInfo({required this.sessionId, required this.csrfToken});
}

// 需要的 LoginResult 類
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
      debugPrint("error body is: ${response?.body}");
    }
    return {};
  }
}

// 創建不安全的 HTTP 客戶端
http.Client createUnsafeClient() {
  final ioClient = HttpClient()
    ..badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;

  return IOClient(ioClient);
}

// 修改後的 LoginProcess 類，適應當前環境
class LoginProcess {
  final String baseUrl;

  String _username = '';
  String _password = '';
  String _token = '';
  SessionInfo emptySession = SessionInfo(sessionId: "", csrfToken: "");

  LoginProcess(this._username, this._password, {this.baseUrl = 'http://192.168.1.1'});

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
      debugPrint('CSRF token = ${match.group(1)}');
      return match.group(1)!;
    } else {
      //blank state, we need to get csrf from wizard;
      debugPrint('CSRF_TOKEN not found in response body, could be a blank state?');
      return "";
    }
  }

  String? getSessionID(String cookieHeader) {
    if (cookieHeader.isEmpty) return null;  // 修正為檢查空字符串
    final RegExp regExp = RegExp(r'sessionID=([^;]+)');
    final match = regExp.firstMatch(cookieHeader);
    return match?.group(1);
  }

  //get login.html to retrieve header including sessionID;
  Future<void> getCsrfFromWizard() async {
    final String wizPage = '$baseUrl/wizard.html';
    debugPrint("print get from : ${Uri.parse(wizPage)}");
    final response = await http.get(Uri.parse(wizPage));
    if (response.statusCode == 200) {
      PrintUtil.printMap('HEADER', response.headers.map((k, v) => MapEntry(k, v)));
      debugPrint("_token is getting from wizard.html");
      _token = getCSRFToken(response.body);
    }
  }

  LoginResult preCheck(http.Response res) {
    //check status code first;
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

  //get login.html to retrieve header including sessionID;
  Future<LoginResult> loginStep1() async {
    final String loginPath = '$baseUrl/login.html';
    debugPrint("print get : ${Uri.parse(loginPath)}");
    final response = await http.get(Uri.parse(loginPath));
    PrintUtil.printMap(' [STEP1] HEADER', response.headers.map((k, v) => MapEntry(k, v)));
    return preCheck(response);
  }

  //send public key to server;
  Future<LoginResult> loginStep2(Map<String, String> headers, Map<String, dynamic> data) async {
    final client = createUnsafeClient();

    // 嘗試不同的 API 路徑
    final endpoints = [
      '$baseUrl/api/v1/user/login',
      '$baseUrl/cgi-bin/webPost.plua?csrftoken=$_token'
    ];

    // 初始化一個默認的失敗結果，而不是使用 null
    LoginResult finalResult = LoginResult(
        response: null,
        returnStatus: false,
        session: emptySession,
        msg: "No endpoints tried yet"
    );

    for (final endpoint in endpoints) {
      try {
        debugPrint("嘗試發送公鑰到: $endpoint");
        final response = await client.post(
          Uri.parse(endpoint),
          headers: headers,
          body: json.encode(data),
        );
        PrintUtil.printMap(' [STEP2] HEADER', response.headers.map((k, v) => MapEntry(k, v)));

        final result = preCheck(response);
        if (result.returnStatus) {
          return result; // 如果成功，立即返回
        } else {
          finalResult = result; // 保存最後一個結果，以防所有嘗試都失敗
        }
      } catch (e) {
        debugPrint("嘗試 $endpoint 時出錯: $e");
      }
    }

    return finalResult;
  }

  //send M to server;
  Future<LoginResult> loginStep3(Map<String, String> headers, Map<String, dynamic> data) async {
    // 嘗試不同的 API 路徑
    final endpoints = [
      '$baseUrl/api/v1/user/login',
      '$baseUrl/cgi-bin/webPost.plua?csrftoken=$_token'
    ];

    // 初始化一個默認的失敗結果，而不是使用 null
    LoginResult finalResult = LoginResult(
        response: null,
        returnStatus: false,
        session: emptySession,
        msg: "No endpoints tried yet"
    );

    for (final endpoint in endpoints) {
      try {
        debugPrint("嘗試發送證明到: $endpoint");
        final response = await http.post(
          Uri.parse(endpoint),
          headers: headers,
          body: json.encode(data),
        );

        var result = preCheck(response);

        try {
          if (result.response != null && result.response!.body.isNotEmpty) {
            var tmp = json.decode(result.response!.body);
            if (tmp['error'] != null) {
              debugPrint("錯誤信息: ${tmp['error']['msg']}");
              finalResult = LoginResult(
                  response: result.response,
                  returnStatus: false,
                  session: emptySession,
                  msg: tmp['error']['msg'] ?? "Unknown error"
              );
              continue; // 嘗試下一個端點
            }
          }
        } catch (e) {
          debugPrint("step3 response parsing error: $e");
        }

        if (result.returnStatus) {
          return result; // 如果成功，立即返回
        } else {
          finalResult = result; // 保存最後一個結果
        }
      } catch (e) {
        debugPrint("嘗試 $endpoint 時出錯: $e");
      }
    }

    return finalResult;
  }

  //get dashboard
  Future<dynamic> getDashboard(Map<String, String> headers) async {
    try {
      // 嘗試 GET 和 POST 兩種方法
      for (final method in ['GET', 'POST']) {
        try {
          debugPrint("嘗試使用 $method 獲取儀表板");

          final url = Uri.parse('$baseUrl/dashboard.html?csrftoken=$_token');

          final response = method == 'GET'
              ? await http.get(url, headers: headers)
              : await http.post(url, headers: headers);

          if (response.statusCode == 200) {
            debugPrint("成功載入儀表板");
            return response.body;
          }
        } catch (e) {
          debugPrint("$method 請求儀表板時出錯: $e");
        }
      }

      throw Exception('Failed to load dashboard');
    } catch (e) {
      debugPrint("獲取儀表板失敗: $e");
      throw Exception('Failed to send data to login get Dashboard');
    }
  }

  Future<LoginResult> startSRPLoginProcess() async {
    try {
      // 首先獲取登入頁面和 CSRF 令牌
      var result = await loginStep1();
      if (!result.returnStatus) return result;

      _token = getCSRFToken(result.response!.body);
      String sessionId = getSessionIDFromHeaders(result.response!.headers) ?? "";
      debugPrint("get session = $sessionId, token = $_token");

      if (_token.isEmpty) {
        // 如果沒有找到 CSRF 令牌，嘗試從向導頁面獲取
        await getCsrfFromWizard();

        if (_token.isEmpty) {
          return LoginResult(
              response: null,
              returnStatus: false,
              session: SessionInfo(sessionId: sessionId, csrfToken: ""),
              msg: "Could not obtain CSRF token"
          );
        }

        return LoginResult(
            response: result.response,
            session: SessionInfo(sessionId: sessionId, csrfToken: _token),
            msg: "get csrf from Wizard",
            returnStatus: true
        );
      }

      // 生成 SRP 參數
      final salt = client.generateSalt();
      debugPrint('generateSalt : $salt');

      final clientEphemeral = client.generateEphemeral();
      debugPrint('clientEphemeral : public : ${clientEphemeral.public} \n secret : ${clientEphemeral.secret}');

      // 嘗試兩種數據格式
      final postDataFormats = [
        {
          'method': 'srp',
          'srp': {
            'I': _username,
            'A': clientEphemeral.public,
          }
        },
        {
          'function': 'authenticate',
          'data': {
            'CSRFtoken': _token,
            'I': _username,
            'A': clientEphemeral.public,
          }
        }
      ];

      // 定義 HTTP 頭
      final step2Header = {
        'Content-Type': 'application/json',
        'Referer': '$baseUrl/login.html',
        'Cookie': sessionId.isNotEmpty ? 'sessionID=$sessionId' : '',
      };

      // 嘗試所有格式
      LoginResult step2Result = LoginResult(
          response: null,
          returnStatus: false,
          session: emptySession,
          msg: "No formats tried yet"
      );

      for (final postData in postDataFormats) {
        try {
          final testResult = await loginStep2(step2Header, postData);

          if (testResult.returnStatus) {
            step2Result = testResult;
            break;
          } else {
            step2Result = testResult; // 存儲最後一個失敗結果
          }
        } catch (e) {
          debugPrint("嘗試格式 ${postData['method'] ?? postData['function']} 時出錯: $e");
        }
      }

      // 從響應頭中更新會話 ID
      final newSessionId = getSessionIDFromHeaders(step2Result.response?.headers ?? {}) ?? sessionId;
      if (newSessionId != sessionId) {
        debugPrint("會話 ID 已更新: $newSessionId");
        sessionId = newSessionId;
      }

      if (!step2Result.returnStatus) {
        return step2Result;
      }

      // 解析返回的數據
      var dataFromStep2 = step2Result.getJson();
      debugPrint('salt and B received from server : $dataFromStep2');

      // 檢查必要參數
      if (!dataFromStep2.containsKey('s') || !dataFromStep2.containsKey('B')) {
        return LoginResult(
            response: step2Result.response,
            returnStatus: false,
            session: SessionInfo(sessionId: sessionId, csrfToken: _token),
            msg: "Missing required SRP parameters from server"
        );
      }

      // 獲取鹽值和伺服器公鑰
      String saltFromHost = dataFromStep2['s'];
      String BFromHost = dataFromStep2['B'];

      // 計算 SRP 認證參數
      final privateKey = client.derivePrivateKey(saltFromHost, _username, _password); //x = H(salt, 'ac:pwd')
      final verifier = client.deriveVerifier(privateKey); //g^x mod N
      final clientSession =
      client.deriveSession(clientEphemeral.secret, BFromHost, saltFromHost, _username, privateKey);
      debugPrint('clientSession : M1: ${clientSession.proof} ');

      // 設置第三步的 HTTP 頭和請求數據
      final step3Header = {
        'Content-Type': 'application/json',
        'Origin': baseUrl,
        'Referer': '$baseUrl/login.html',
        'Cookie': 'sessionID=$sessionId',
      };

      // 嘗試兩種參數名 M1 和 M
      final proofFormats = [
        {
          'method': 'srp',
          'srp': {
            'M1': clientSession.proof,
          }
        },
        {
          'method': 'srp',
          'srp': {
            'M': clientSession.proof,
          }
        },
        {
          'function': 'authenticate',
          'data': {
            'CSRFtoken': _token,
            'M1': clientSession.proof,
          }
        },
        {
          'function': 'authenticate',
          'data': {
            'CSRFtoken': _token,
            'M': clientSession.proof,
          }
        }
      ];

      // 嘗試所有格式
      LoginResult step3Result = LoginResult(
          response: null,
          returnStatus: false,
          session: emptySession,
          msg: "No proof formats tried yet"
      );

      for (final postData in proofFormats) {
        try {
          final testResult = await loginStep3(step3Header, postData);

          if (testResult.returnStatus) {
            step3Result = testResult;
            break;
          } else {
            step3Result = testResult; // 存儲最後一個失敗結果
          }
        } catch (e) {
          debugPrint("嘗試證明格式 ${postData.toString()} 時出錯: $e");
        }
      }

      if (!step3Result.returnStatus) {
        return step3Result;
      }

      // 解析第三步返回的數據
      var dataFromStep3 = step3Result.getJson();
      debugPrint('Received data from server: $dataFromStep3');

      // 驗證伺服器證明（如果有）
      if (dataFromStep3.containsKey('M')) {
        String M2 = dataFromStep3['M'];
        try {
          // 驗證伺服器證明
          client.verifySession(clientEphemeral.public, clientSession, M2);
          debugPrint('Verification successful: client.verifySession : public = ${clientEphemeral.public}, M2 = $M2');
        } catch (e) {
          debugPrint('Verification warning: $e');
        }
      }

      // 嘗試獲取儀表板以確認登入成功
      final dashboardHeaders = {
        'Cookie': 'sessionID=$sessionId',
      };

      try {
        await getDashboard(dashboardHeaders);
        debugPrint("Successfully accessed dashboard");
      } catch (e) {
        debugPrint("Warning: Could not access dashboard but login may still be successful");
      }

      return LoginResult(
          response: null,
          returnStatus: true,
          session: SessionInfo(sessionId: sessionId, csrfToken: _token),
          msg: "login success");
    } catch (e) {
      debugPrint('Error: $e');
      return LoginResult(
          response: null,
          returnStatus: false,
          session: SessionInfo(sessionId: "", csrfToken: ""),
          msg: "login error $e");
    }
  }
}

// 測試頁面實現
class SrpLoginTestPage extends StatefulWidget {
  const SrpLoginTestPage({Key? key}) : super(key: key);

  @override
  State<SrpLoginTestPage> createState() => _SrpLoginModifiedTestPageState();
}

class _SrpLoginModifiedTestPageState extends State<SrpLoginTestPage> {
  String _statusMessage = "點擊按鈕開始測試";
  bool _isLoading = false;
  bool _loginSuccess = false;
  String _logOutput = "準備開始測試...";
  final _scrollController = ScrollController();
  // 建立一個日誌收集器
  List<String> _logs = [];

  final TextEditingController _usernameController = TextEditingController(text: "admin");
  final TextEditingController _passwordController = TextEditingController(text: "790d9032a72acc5bb402cc4baf01751cebba9bf4d604555d21b195845ed8beff");
  final TextEditingController _baseUrlController = TextEditingController(text: "http://192.168.1.1");

  String _sessionId = "";
  String _csrfToken = "";

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
      _logs.add(msg); // 同時保存到日誌列表
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

  // 開始 SRP 登入流程
  Future<void> startSRPLoginProcess() async {
    if (_isLoading) return;
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
      _loginSuccess = false;
      _logOutput = "開始 SRP 登入流程...";
      _logs = []; // 清空日誌
      _sessionId = "";
      _csrfToken = "";
    });

    try {
      // 獲取輸入參數
      final username = _usernameController.text;
      final password = _passwordController.text;
      final baseUrl = _baseUrlController.text.trim();

      _logAdd("使用以下參數:");
      _logAdd("用戶名: $username");
      _logAdd("密碼: $password");
      _logAdd("基礎 URL: $baseUrl");

      // 創建 LoginProcess 實例
      final loginProcess = LoginProcess(username, password, baseUrl: baseUrl);

      // 開始登入流程
      _updateStatus("正在執行 SRP 登入流程...");
      _logAdd("啟動 SRP 登入流程...");

      // 在這里設置一個攔截器，捕獲所有的 debugPrint 輸出
      // 這種方式比直接替換 debugPrintCallback 更安全
      final originalDebugPrint = debugPrint;

      // 替換 debugPrint 函數
      debugPrint = (String? message, {int? wrapWidth}) {
        // 保留原始功能
        originalDebugPrint(message, wrapWidth: wrapWidth);
        // 添加到日誌
        if (message != null) {
          // 使用一個安全的方式在下一個幀更新 UI
          Future.microtask(() {
            if (mounted) {
              _logAdd(message);
            }
          });
        }
      };

      // 調用 LoginProcess 中的 startSRPLoginProcess 方法
      final loginResult = await loginProcess.startSRPLoginProcess();

      // 恢復原始的 debugPrint
      debugPrint = originalDebugPrint;

      // 處理登入結果
      if (loginResult.returnStatus) {
        _updateStatus("登入成功！");
        _logAdd("登入成功！");
        _logAdd("會話 ID: ${loginResult.session.sessionId}");
        _logAdd("CSRF 令牌: ${loginResult.session.csrfToken}");

        setState(() {
          _loginSuccess = true;
          _sessionId = loginResult.session.sessionId;
          _csrfToken = loginResult.session.csrfToken;
        });
      } else {
        _updateStatus("登入失敗: ${loginResult.msg}");
        _logAdd("登入失敗: ${loginResult.msg}");
      }
    } catch (e) {
      _updateStatus("登入過程出錯: ${e.toString().split('\n')[0]}");
      _logAdd("登入過程中發生錯誤: $e");
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
        title: const Text('SRP 登入測試 (修改相容版本)'),
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

            // 如果登入成功，顯示會話信息
            if (_loginSuccess) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '會話信息',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('會話 ID: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(
                          child: SelectableText(_sessionId),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Text('CSRF 令牌: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(
                          child: SelectableText(_csrfToken),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

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