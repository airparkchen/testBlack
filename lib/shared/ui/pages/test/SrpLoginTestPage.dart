import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hex/hex.dart';
import 'package:whitebox/shared/utils/srp_helper.dart'; // 確保導入 SRP 幫助類

class SrpLoginTestPage extends StatefulWidget {
  const SrpLoginTestPage({Key? key}) : super(key: key);

  @override
  State<SrpLoginTestPage> createState() => _SrpLoginTestPageState();
}

class _SrpLoginTestPageState extends State<SrpLoginTestPage> {
  final TextEditingController _ipController = TextEditingController(text: "192.168.1.1");
  final TextEditingController _usernameController = TextEditingController(text: "admin");
  final TextEditingController _passwordController = TextEditingController();

  String _logOutput = "等待操作...";
  bool _isLoading = false;
  String _csrfToken = "";
  String _sessionId = "";
  Map<String, String> _srpData = {};
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // 自動檢測網絡狀態，確定是否連接到正確的 WiFi
    _checkNetworkConnection();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 檢查網絡連接
  Future<void> _checkNetworkConnection() async {
    _appendLog("檢查網絡連接...");

    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.wifi) {
      _appendLog("已連接到 WiFi");
    } else {
      _appendLog("警告: 未連接到 WiFi，請先連接到路由器的 WiFi");
    }
  }

  // 向日誌添加訊息並自動捲動到底部
  void _appendLog(String message) {
    setState(() {
      _logOutput += "\n$message";
    });

    // 確保捲動到底部
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // 獲取 CSRF 令牌
  Future<void> _getCsrfToken() async {
    setState(() {
      _isLoading = true;
      _logOutput = "開始獲取 CSRF 令牌...";
    });

    try {
      final ipAddress = _ipController.text;
      final url = 'http://$ipAddress/login.html';

      _appendLog("請求 URL: $url");

      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      _appendLog("收到回應: 狀態碼 ${response.statusCode}");

      if (response.statusCode == 200) {
        // 從回應中提取 CSRF 令牌
        final csrfRegex = RegExp(r'CSRF_TOKEN\s*=\s*"([a-f0-9]{32})"');
        final match = csrfRegex.firstMatch(response.body);

        if (match != null) {
          _csrfToken = match.group(1)!;
          _appendLog("成功獲取 CSRF 令牌: $_csrfToken");

          // 提取 sessionID
          if (response.headers.containsKey('set-cookie')) {
            final cookieHeader = response.headers['set-cookie']!;
            final sessionMatch = RegExp(r'sessionID=([^;]+)').firstMatch(cookieHeader);
            if (sessionMatch != null) {
              _sessionId = sessionMatch.group(1)!;
              _appendLog("成功獲取 SessionID: $_sessionId");
            }
          }
        } else {
          _appendLog("在回應中未找到 CSRF 令牌，嘗試獲取 wizard.html");
          await _getCsrfFromWizard();
        }
      } else if (response.statusCode == 302) {
        _appendLog("收到重定向，嘗試獲取 wizard.html");
        await _getCsrfFromWizard();
      } else {
        _appendLog("錯誤: 不支援的回應代碼 ${response.statusCode}");
      }
    } catch (e) {
      _appendLog("錯誤: 獲取 CSRF 令牌失敗 - $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 從 wizard.html 獲取 CSRF 令牌
  Future<void> _getCsrfFromWizard() async {
    try {
      final ipAddress = _ipController.text;
      final url = 'http://$ipAddress/wizard.html';

      _appendLog("請求 URL: $url");

      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      _appendLog("收到回應: 狀態碼 ${response.statusCode}");

      if (response.statusCode == 200) {
        // 從回應中提取 CSRF 令牌
        final csrfRegex = RegExp(r'CSRF_TOKEN\s*=\s*"([a-f0-9]{32})"');
        final match = csrfRegex.firstMatch(response.body);

        if (match != null) {
          _csrfToken = match.group(1)!;
          _appendLog("從 wizard.html 成功獲取 CSRF 令牌: $_csrfToken");

          // 提取 sessionID
          if (response.headers.containsKey('set-cookie')) {
            final cookieHeader = response.headers['set-cookie']!;
            final sessionMatch = RegExp(r'sessionID=([^;]+)').firstMatch(cookieHeader);
            if (sessionMatch != null) {
              _sessionId = sessionMatch.group(1)!;
              _appendLog("成功獲取 SessionID: $_sessionId");
            }
          }
        } else {
          _appendLog("在 wizard.html 回應中未找到 CSRF 令牌");
        }
      } else {
        _appendLog("從 wizard.html 獲取 CSRF 令牌失敗: ${response.statusCode}");
      }
    } catch (e) {
      _appendLog("從 wizard.html 獲取 CSRF 令牌錯誤: $e");
    }
  }

  // 執行 SRP 登入
  Future<void> _performSrpLogin() async {
    if (_csrfToken.isEmpty) {
      _appendLog("請先獲取 CSRF 令牌");
      return;
    }

    setState(() {
      _isLoading = true;
      _appendLog("\n開始 SRP 登入流程...");
    });

    try {
      final ipAddress = _ipController.text;
      final username = _usernameController.text;
      final password = _passwordController.text.isEmpty
          ? "3033b8c2f480de5d01a310d198e74b84d5ddeb73a40b04bef95a7ce167cce6f7"  // 默認密碼
          : _passwordController.text;

      _appendLog("使用用戶名: $username");
      _appendLog("使用 CSRF 令牌: $_csrfToken");

      // 步驟 1: 生成 SRP 密鑰
      _appendLog("步驟 1: 生成客戶端 SRP 密鑰...");
      final keys = SrpHelper.generateKeys(username, password);
      final clientPrivateKey = keys['privateKey']!;
      final clientPublicKey = keys['publicKey']!;

      _srpData = {
        'username': username,
        'password': password,
        'privateKey': clientPrivateKey,
        'publicKey': clientPublicKey,
      };

      _appendLog("生成客戶端公鑰 (A): $clientPublicKey");

      // 步驟 2: 發送公鑰到服務器
      final step2Url = Uri.parse('http://$ipAddress/cgi-bin/webPost.plua?csrftoken=$_csrfToken');
      final step2Headers = {
        'Content-Type': 'application/json',
        'Referer': 'http://$ipAddress/login.html',
      };

      final step2Data = {
        'function': 'authenticate',
        'data': {
          'CSRFtoken': _csrfToken,
          'I': username,
          'A': clientPublicKey,
        }
      };

      _appendLog("步驟 2: 發送公鑰到 $step2Url");
      _appendLog("數據: ${json.encode(step2Data)}");

      final step2Response = await http.post(
        step2Url,
        headers: step2Headers,
        body: json.encode(step2Data),
      ).timeout(const Duration(seconds: 10));

      _appendLog("步驟 2 回應: 狀態碼 ${step2Response.statusCode}");

      if (step2Response.statusCode == 200) {
        final step2Result = json.decode(step2Response.body);
        _appendLog("收到服務器數據: $step2Result");

        if (step2Result.containsKey('s') && step2Result.containsKey('B')) {
          final saltHex = step2Result['s'];
          final serverPublicHex = step2Result['B'];

          _appendLog("接收到鹽值 (s): $saltHex");
          _appendLog("接收到服務器公鑰 (B): $serverPublicHex");

          // 步驟 3: 計算客戶端證明 M1
          try {
            _appendLog("步驟 3: 計算客戶端證明 M1...");

            final clientProofHex = SrpHelper.calculateM1(
                username,
                password,
                saltHex,
                clientPublicKey,
                serverPublicHex,
                clientPrivateKey
            );

            _appendLog("生成客戶端證明 (M1): $clientProofHex");

            // 步驟 4: 發送 M1 到服務器
            final step3Url = Uri.parse('http://$ipAddress/cgi-bin/webPost.plua?csrftoken=$_csrfToken');
            final step3Headers = {
              'Content-Type': 'application/json',
              'Origin': 'http://$ipAddress',
              'Referer': 'http://$ipAddress/login.html',
            };

            // 嘗試使用 M 參數
            final step3DataM = {
              'function': 'authenticate',
              'data': {
                'CSRFtoken': _csrfToken,
                'M': clientProofHex,
              }
            };

            _appendLog("步驟 4: 發送證明 (使用 M)...");
            _appendLog("數據: ${json.encode(step3DataM)}");

            final step3Response = await http.post(
              step3Url,
              headers: step3Headers,
              body: json.encode(step3DataM),
            ).timeout(const Duration(seconds: 10));

            _appendLog("步驟 4 回應: 狀態碼 ${step3Response.statusCode}");

            if (step3Response.statusCode == 200) {
              try {
                final step3Result = json.decode(step3Response.body);
                _appendLog("步驟 4 解析結果: $step3Result");

                if (step3Result.containsKey('error')) {
                  _appendLog("錯誤: ${step3Result['error']['msg']}");

                  // 如果使用 M 參數失敗，嘗試使用 M1 參數
                  _appendLog("嘗試使用 M1 參數...");
                  final step3DataM1 = {
                    'function': 'authenticate',
                    'data': {
                      'CSRFtoken': _csrfToken,
                      'M1': clientProofHex,
                    }
                  };

                  _appendLog("步驟 4 (使用 M1): 發送證明...");
                  _appendLog("數據: ${json.encode(step3DataM1)}");

                  final step3ResponseM1 = await http.post(
                    step3Url,
                    headers: step3Headers,
                    body: json.encode(step3DataM1),
                  ).timeout(const Duration(seconds: 10));

                  _appendLog("步驟 4 (M1) 回應: 狀態碼 ${step3ResponseM1.statusCode}");

                  if (step3ResponseM1.statusCode == 200) {
                    try {
                      final step3ResultM1 = json.decode(step3ResponseM1.body);
                      _appendLog("步驟 4 (M1) 解析結果: $step3ResultM1");

                      if (step3ResultM1.containsKey('error')) {
                        _appendLog("錯誤: ${step3ResultM1['error']['msg']}");
                      } else {
                        _appendLog("登入成功!");
                        await _getDashboard();
                      }
                    } catch (e) {
                      _appendLog("解析 M1 回應出錯: $e");

                      // 嘗試檢查是否登入成功
                      if (step3ResponseM1.body.toLowerCase().contains('success')) {
                        _appendLog("檢測到 'success' 字符串，可能登入成功");
                        await _getDashboard();
                      }
                    }
                  }
                } else {
                  _appendLog("登入成功!");
                  await _getDashboard();
                }
              } catch (e) {
                _appendLog("解析回應出錯: $e");

                // 嘗試檢查是否登入成功
                if (step3Response.body.toLowerCase().contains('success')) {
                  _appendLog("檢測到 'success' 字符串，可能登入成功");
                  await _getDashboard();
                }
              }
            } else {
              _appendLog("步驟 4 失敗: ${step3Response.body}");
            }
          } catch (e) {
            _appendLog("生成證明時出錯: $e");
          }
        } else {
          _appendLog("錯誤: 服務器沒有返回必要的 's' 和 'B' 值");
        }
      } else {
        _appendLog("步驟 2 失敗: ${step2Response.body}");
      }
    } catch (e) {
      _appendLog("SRP 登入流程錯誤: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 獲取儀表板頁面 (驗證登入是否成功)
  Future<void> _getDashboard() async {
    try {
      final ipAddress = _ipController.text;
      final url = Uri.parse('http://$ipAddress/dashboard.html?csrftoken=$_csrfToken');

      _appendLog("獲取儀表板頁面: $url");

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'sessionID=$_sessionId',
        },
      ).timeout(const Duration(seconds: 10));

      _appendLog("儀表板回應: 狀態碼 ${response.statusCode}");

      if (response.statusCode == 200) {
        _appendLog("成功加載儀表板!");

        // 保存儀表板的前 200 個字符作為預覽
        final preview = response.body.length > 200
            ? response.body.substring(0, 200) + "..."
            : response.body;

        _appendLog("儀表板預覽: $preview");
      } else {
        _appendLog("加載儀表板失敗: ${response.statusCode}");
      }
    } catch (e) {
      _appendLog("加載儀表板錯誤: $e");
    }
  }

  // 清除日誌
  void _clearLog() {
    setState(() {
      _logOutput = "日誌已清除...";
    });
  }

  // 保存日誌到文件
  Future<void> _saveLogToFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/srp_login_log.txt');
      await file.writeAsString(_logOutput);

      setState(() {
        _logOutput += "\n日誌已保存到 ${file.path}";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('日誌已保存到: ${file.path}')),
      );
    } catch (e) {
      setState(() {
        _logOutput += "\n保存日誌失敗: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SRP 路由器登入測試'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveLogToFile,
            tooltip: '保存日誌',
          ),
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            onPressed: _clearLog,
            tooltip: '清除日誌',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // IP 地址輸入
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: '路由器 IP 地址',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.router),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 16),

            // 用戶名輸入
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: '用戶名',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),

            // 密碼輸入
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: '密碼 (留空使用默認值)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
                helperText: '如果不確定，請留空使用默認值',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),

            // 操作按鈕
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _getCsrfToken,
                    icon: const Icon(Icons.token),
                    label: const Text('1. 獲取 CSRF 令牌'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isLoading || _csrfToken.isEmpty) ? null : _performSrpLogin,
                    icon: const Icon(Icons.login),
                    label: const Text('2. SRP 登入'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 自動運行按鈕
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () async {
                await _getCsrfToken();
                if (_csrfToken.isNotEmpty) {
                  await _performSrpLogin();
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('自動執行全部步驟'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 24),

            // 日誌輸出
            const Text(
              '操作日誌:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              height: 300,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(5),
              ),
              child: _isLoading
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      '處理中...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              )
                  : SingleChildScrollView(
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

            // CSRF 令牌顯示
            if (_csrfToken.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.token, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CSRF 令牌:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _csrfToken,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _csrfToken));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('CSRF 令牌已複製到剪貼板')),
                        );
                      },
                      tooltip: '複製',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}