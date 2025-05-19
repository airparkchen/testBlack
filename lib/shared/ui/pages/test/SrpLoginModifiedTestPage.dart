import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whitebox/shared/api/wifi_api/login_process.dart'; // 引入修改後的登入處理類
import 'dart:convert'; // 用於 JSON 格式化
import 'dart:io'; // 用於 HTTP 請求

class SrpLoginModifiedTestPage extends StatefulWidget {
  final String initialPassword;

  const SrpLoginModifiedTestPage({Key? key}) : initialPassword = "", super(key: key);
  const SrpLoginModifiedTestPage.withPassword(this.initialPassword, {Key? key}) : super(key: key);

  @override
  State<SrpLoginModifiedTestPage> createState() => _SrpLoginModifiedTestPageState();
}

class _SrpLoginModifiedTestPageState extends State<SrpLoginModifiedTestPage> {
  String _statusMessage = "點擊按鈕開始測試";
  bool _isLoading = false;
  bool _loginSuccess = false;
  String _logOutput = "準備開始測試...";
  final _scrollController = ScrollController();

  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _baseUrlController;
  late TextEditingController _apiPathController; // API路徑輸入框

  String _sessionId = "";
  String _jwtToken = "";

  // HttpClient 用於發送手動請求
  final HttpClient _httpClient = HttpClient();

  @override
  void initState() {
    super.initState();
    // 初始化控制器並設置初始值
    _usernameController = TextEditingController(text: "admin");
    _passwordController = TextEditingController(
        text: widget.initialPassword.isNotEmpty ? widget.initialPassword : "bee1958f48a75a44b09110a19c1cc7ad58a5d8d45c74f733016687589b612493"
    );
    _baseUrlController = TextEditingController(text: "http://192.168.1.1");
    _apiPathController = TextEditingController(text: "/api/v1/network/wan_eth"); // 默認API路徑

    if (widget.initialPassword.isNotEmpty) {
      _logAdd("已自動填入計算得到的密碼：${widget.initialPassword}");
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _baseUrlController.dispose();
    _apiPathController.dispose();
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

  // 發送 HTTP 請求並記錄
  Future<String> _makeHttpRequest(String url, String method, {Map<String, String>? headers, Object? body}) async {
    _logAdd("\n===== 發送 HTTP 請求 =====");
    _logAdd("URL: $url");
    _logAdd("方法: $method");
    if (headers != null) {
      _logAdd("請求頭: ${jsonEncode(headers)}");
    }
    if (body != null) {
      _logAdd("請求體: ${body is String ? body : jsonEncode(body)}");
    }

    try {
      final request = await _httpClient.openUrl(method, Uri.parse(url));

      // 添加請求頭
      if (headers != null) {
        headers.forEach((key, value) {
          request.headers.set(key, value);
        });
      }

      // 添加請求體
      if (body != null) {
        request.headers.contentType = ContentType.json;
        if (body is String) {
          request.write(body);
        } else {
          request.write(jsonEncode(body));
        }
      }

      // 發送請求並獲取響應
      final response = await request.close();

      _logAdd("\n===== 收到 HTTP 響應 =====");
      _logAdd("狀態碼: ${response.statusCode}");
      _logAdd("響應頭:");
      response.headers.forEach((name, values) {
        _logAdd("  $name: $values");
      });

      // 讀取響應體
      final responseBody = await response.transform(utf8.decoder).join();

      try {
        // 嘗試格式化 JSON
        final jsonData = jsonDecode(responseBody);
        _logAdd("響應體(JSON):");
        _logAdd(const JsonEncoder.withIndent('  ').convert(jsonData));
      } catch (e) {
        // 不是 JSON，直接顯示
        _logAdd("響應體:");
        _logAdd(responseBody);
      }

      _logAdd("===== HTTP 響應結束 =====");

      return responseBody;
    } catch (e) {
      _logAdd("HTTP 請求錯誤: $e");
      rethrow;
    }
  }

  // 使用 JWT 令牌測試 API
  Future<void> _testApiWithJwt() async {
    if (_jwtToken.isEmpty) {
      _logAdd("\n===== 測試 API 失敗 =====");
      _logAdd("沒有可用的 JWT 令牌");
      return;
    }

    final apiPath = _apiPathController.text.trim();
    if (apiPath.isEmpty) {
      _logAdd("\n===== 測試 API 失敗 =====");
      _logAdd("請輸入要測試的 API 路徑");
      return;
    }

    _logAdd("\n===== 使用 JWT 令牌測試 API =====");
    _logAdd("API 路徑: $apiPath");

    try {
      final baseUrl = _baseUrlController.text.trim();

      await _makeHttpRequest(
          "$baseUrl$apiPath",
          "GET",
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_jwtToken'
          }
      );

    } catch (e) {
      _logAdd("JWT API 測試錯誤: $e");
    }
  }

  // 搜索 JWT 令牌
  void _searchForJwtInLogs() {
    _logAdd("\n===== 搜索可能的 JWT 令牌 =====");

    // JWT 格式的正則表達式
    final RegExp jwtRegex = RegExp(r'[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}');

    // 搜索日誌中的所有匹配項
    final matches = jwtRegex.allMatches(_logOutput);

    if (matches.isEmpty) {
      _logAdd("未找到符合 JWT 格式的令牌");
    } else {
      _logAdd("找到 ${matches.length} 個可能的 JWT 令牌:");
      int tokenCount = 1;
      for (final match in matches) {
        final token = _logOutput.substring(match.start, match.end);
        _logAdd("令牌 $tokenCount: $token");
        tokenCount++;

        // 如果尚未设置 JWT 令牌，就保存第一个找到的令牌
        if (_jwtToken.isEmpty) {
          setState(() {
            _jwtToken = token;
          });
          _logAdd("自動保存此令牌以用於 API 測試");
        }

        // 嘗試解碼 JWT
        try {
          final parts = token.split('.');
          if (parts.length == 3) {
            // 解碼頭部
            try {
              final normalizedHeader = _base64Normalize(parts[0]);
              final headerBytes = base64Decode(normalizedHeader);
              final headerJson = utf8.decode(headerBytes);
              _logAdd("  頭部解碼: $headerJson");
            } catch (e) {
              _logAdd("  頭部解碼失敗: $e");
            }

            // 解碼載荷
            try {
              final normalizedPayload = _base64Normalize(parts[1]);
              final payloadBytes = base64Decode(normalizedPayload);
              final payloadJson = utf8.decode(payloadBytes);
              _logAdd("  載荷解碼: $payloadJson");
            } catch (e) {
              _logAdd("  載荷解碼失敗: $e");
            }
          }
        } catch (e) {
          _logAdd("  解碼失敗: $e");
        }
      }
    }
  }

  // 標準化 base64 以便解碼
  String _base64Normalize(String input) {
    String output = input.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      case 1:
        output += '===';
        break;
    }
    return output;
  }

  // 開始 SRP 登入流程
  Future<void> startSRPLoginProcess() async {
    if (_isLoading) return;
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
      _loginSuccess = false;
      _logOutput = "開始 SRP 登入流程...";
      _sessionId = "";
      _jwtToken = "";
    });

    try {
      // 獲取輸入參數
      final username = _usernameController.text;
      final password = _passwordController.text;
      final baseUrl = _baseUrlController.text;

      _logAdd("使用以下參數:");
      _logAdd("用戶名: $username");
      _logAdd("密碼: $password");
      _logAdd("基礎 URL: $baseUrl");

      // 捕獲 Flutter 錯誤
      FlutterError.onError = (FlutterErrorDetails details) {
        _logAdd("Flutter 錯誤: ${details.exception}");
      };

      // 記錄開始時間
      final startTime = DateTime.now();
      _logAdd("開始時間: $startTime");

      // 開始登入流程
      _updateStatus("正在執行 SRP 登入流程...");
      _logAdd("\n===== 開始 SRP 登入流程 =====");

      // 創建 LoginProcess 實例
      final loginProcess = LoginProcess(username, password, baseUrl: baseUrl);

      // 調用 LoginProcess 中的 startSRPLoginProcess 方法
      final loginResult = await loginProcess.startSRPLoginProcess();

      // 記錄結束時間
      final endTime = DateTime.now();
      _logAdd("結束時間: $endTime");
      _logAdd("用時: ${endTime.difference(startTime).inMilliseconds} 毫秒");

      // 處理登入結果
      if (loginResult.returnStatus) {
        _updateStatus("登入成功！");
        _logAdd("\n===== 登入成功 =====");
        _logAdd("會話 ID: ${loginResult.session.sessionId}");

        // 檢查是否有 JWT Token
        if (loginResult.session.jwtToken != null && loginResult.session.jwtToken!.isNotEmpty) {
          _jwtToken = loginResult.session.jwtToken!;
          _logAdd("JWT Token: $_jwtToken");
        }

        // 記錄完整的響應結果
        _logAdd("\n===== 完整響應結果 =====");
        _logAdd("會話 ID: ${loginResult.session.sessionId}");
        _logAdd("返回狀態: ${loginResult.returnStatus}");
        _logAdd("消息: ${loginResult.msg}");

        setState(() {
          _loginSuccess = true;
          _sessionId = loginResult.session.sessionId;
        });

        // 搜索日誌中可能的 JWT 令牌
        _searchForJwtInLogs();

        // 如果有 JWT Token，測試一些 API
        if (_jwtToken.isNotEmpty) {
          await _testApiWithJwt();
        }
      } else {
        _updateStatus("登入失敗: ${loginResult.msg}");
        _logAdd("\n===== 登入失敗 =====");
        _logAdd("失敗原因: ${loginResult.msg}");
      }
    } catch (e) {
      _updateStatus("登入過程出錯: ${e.toString().split('\n')[0]}");
      _logAdd("\n===== 登入過程中發生錯誤 =====");
      _logAdd("錯誤詳情: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });

      // 搜索日誌中可能的 JWT 令牌
      _searchForJwtInLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SRP 登入測試 (JWT)'),
        backgroundColor: Colors.blue,
        actions: [
          // 添加清除日誌按鈕
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            tooltip: '清除日誌',
            onPressed: () {
              setState(() {
                _logOutput = "日誌已清除...";
              });
            },
          ),
          // 添加複製日誌按鈕
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: '複製日誌',
            onPressed: () {
              // 使用剪貼板複製功能
              Clipboard.setData(ClipboardData(text: _logOutput));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('日誌已複製到剪貼板'))
              );
            },
          ),
        ],
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

            // 如果登入成功，顯示會話信息和 API 測試區域
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
                    if (_jwtToken.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Text('JWT 令牌: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(
                            child: SelectableText(_jwtToken),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // API 測試區域
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'JWT API 測試',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('API 路徑', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextField(
                      controller: _apiPathController,
                      decoration: const InputDecoration(
                        hintText: '/api/v1/network/wan_eth',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _jwtToken.isNotEmpty ? _testApiWithJwt : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('使用 JWT 測試 API'),
                      ),
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
              height: 400, // 增加高度
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(5),
              ),
              child: SingleChildScrollView(
                controller: _scrollController,
                child: SelectableText( // 使用 SelectableText 以便於複製
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