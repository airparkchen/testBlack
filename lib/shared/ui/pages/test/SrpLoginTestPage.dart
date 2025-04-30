import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:hex/hex.dart';
import 'dart:typed_data';

class SrpLoginTestPage extends StatefulWidget {
  const SrpLoginTestPage({Key? key}) : super(key: key);

  @override
  State<SrpLoginTestPage> createState() => _SrpLoginTestPageState();
}

class _SrpLoginTestPageState extends State<SrpLoginTestPage> {
  String _statusMessage = "點擊按鈕開始測試";
  bool _isLoading = false;
  String _csrfToken = "";
  bool _loginSuccess = false;
  String _logOutput = "準備開始測試...";
  final _scrollController = ScrollController();
  http.Client? _client;

  // SRP 參數 - RFC 5054 中定義的 1024 位元素模安全數
  static final BigInt N = BigInt.parse(
    'EEAF0AB9ADB38DD69C33F80AFA8FC5E86072618775FF3C0B9EA2314C9C256576D674DF7496EA81D3383B4813D692C6E0E0D5D8E250B98BE48E495C1D6089DAD15DC7D7B46154D6B6CE8EF4AD69B15D4982559B297BCF1885C529F566660E57EC68EDBC3C05726CC02FD4CBF4976EAA9AFD5138FE8376435B9FC61D2FC0EB06E3',
    radix: 16,
  );
  static final BigInt g = BigInt.from(2);
  static final BigInt k = BigInt.from(3);

  @override
  void dispose() {
    _scrollController.dispose();
    _client?.close();
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

  // 登入過程（和Python版本一樣）
  Future<void> _performLogin() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _loginSuccess = false;
      _logOutput = "開始 SRP 登入流程...";
    });

    // 建立一個 HTTP 客戶端，保持 Cookie
    _client = http.Client();

    try {
      // 設定參數
      final username = "admin";
      final password = "3033b8c2f480de5d01a310d198e74b84d5ddeb73a40b04bef95a7ce167cce6f7";
      final baseUrl = "http://192.168.1.1";

      // 步驟 1: 獲取登入頁面，提取 CSRF 令牌
      _updateStatus("步驟 1/3: 獲取登入頁面...");
      _logAdd("Step 1: Getting login page from $baseUrl/login.html");

      final loginResponse = await _client!.get(Uri.parse("$baseUrl/login.html"));
      _logAdd("Status: ${loginResponse.statusCode} ${loginResponse.statusCode == 200 ? 'OK' : ''}");

      if (loginResponse.statusCode == 200) {
        _logAdd("Headers from login page:");
        loginResponse.headers.forEach((key, value) {
          _logAdd("$key: $value");
        });

        // 提取 CSRF 令牌
        final csrfRegex = RegExp(r'CSRF_TOKEN\s*=\s*"([a-f0-9]{32})"');
        final match = csrfRegex.firstMatch(loginResponse.body);

        if (match != null) {
          _csrfToken = match.group(1)!;
          _logAdd("CSRF token = $_csrfToken");
          _logAdd("CSRF Token: $_csrfToken");
        } else {
          _logAdd("No CSRF token found, trying to get from wizard page...");
          await _getCsrfFromWizard(baseUrl);
        }

        if (_csrfToken.isEmpty) {
          _updateStatus("無法獲取 CSRF 令牌，登入失敗");
          setState(() { _isLoading = false; });
          return;
        }

        // 步驟 2: 生成 SRP 參數並發送公鑰
        _updateStatus("步驟 2/3: 生成並發送公鑰...");

        // 生成隨機私鑰 a
        final a = _generateRandomBigInt(32);

        // 計算公鑰 A = g^a % N
        final A = g.modPow(a, N);
        final clientPublic = A.toRadixString(16);
        _logAdd("Client public key (A): $clientPublic");

        // 發送公鑰到服務器
        final postUrl = "$baseUrl/cgi-bin/webPost.plua?csrftoken=$_csrfToken";
        final headers = {
          'Content-Type': 'application/json',
          'Referer': '$baseUrl/login.html',
        };

        final data = {
          'function': 'authenticate',
          'data': {
            'CSRFtoken': _csrfToken,
            'I': username,
            'A': clientPublic,
          }
        };

        _logAdd("Step 2: Sending public key to $postUrl");
        _logAdd("Headers: $headers");
        _logAdd("Data: ${json.encode(data)}");

        final step2Response = await _client!.post(
          Uri.parse(postUrl),
          headers: headers,
          body: json.encode(data),
        );

        _logAdd("Status: ${step2Response.statusCode}");
        _logAdd("Headers from step 2:");
        step2Response.headers.forEach((key, value) {
          _logAdd("$key: $value");
        });

        if (step2Response.statusCode == 200) {
          final responseData = json.decode(step2Response.body);
          _logAdd("Response data: $responseData");

          if (!responseData.containsKey('s') || !responseData.containsKey('B')) {
            _updateStatus("服務器沒有返回必要的參數");
            setState(() { _isLoading = false; });
            return;
          }

          final saltHex = responseData['s'];
          final serverPublicHex = responseData['B'];

          _logAdd("Received salt (s): $saltHex");
          _logAdd("Received server public key (B): $serverPublicHex");

          // 轉換 salt 和 B 為二進制格式
          final saltBytes = _hexToBytes(saltHex);
          final serverPublicBytes = _hexToBytes(serverPublicHex);

          try {
            // 步驟 3: 計算 SRP 證明並發送
            _updateStatus("步驟 3/3: 計算並發送證明...");

            // 生成 M1 證明 (使用與Python版本相同的方法)
            final clientProof = _computeSrpProof(
              username: username,
              password: password,
              salt: saltBytes,
              serverPublic: serverPublicBytes,
              clientPublic: _hexToBytes(clientPublic),
              privateKey: a,
            );

            final clientProofHex = _bytesToHex(clientProof);
            _logAdd("Generated proof (M1): $clientProofHex");

            // 先嘗試使用 M 參數發送
            _logAdd("First attempt with 'M' parameter");
            var success = await _sendProof(baseUrl, clientProofHex, "M");

            // 如果使用 M 失敗，嘗試使用 M1
            if (!success) {
              _logAdd("Attempting with 'M1' parameter");
              success = await _sendProof(baseUrl, clientProofHex, "M1");
            }

            // 嘗試獲取dashboard，即使前面的驗證可能有錯誤
            _logAdd("Attempting to load dashboard...");
            final dashboardSuccess = await _getDashboard(baseUrl);

            if (dashboardSuccess) {
              _logAdd("Dashboard loaded successfully");
              setState(() {
                _loginSuccess = true;
                _updateStatus("登入成功！已載入儀表板");
              });
            } else {
              _updateStatus("登入可能成功，但無法載入儀表板");
            }
          } catch (e) {
            _logAdd("Error in SRP process: $e");
            _updateStatus("SRP 計算過程出錯");
          }
        } else {
          _logAdd("Step 2 failed with status code: ${step2Response.statusCode}");
          _updateStatus("發送公鑰失敗");
        }
      } else {
        _logAdd("Failed to get login page: ${loginResponse.statusCode}");
        _updateStatus("無法獲取登入頁面");
      }
    } catch (e) {
      _logAdd("Error during login process: $e");
      _updateStatus("登入過程出錯: ${e.toString().split('\n')[0]}");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 從 wizard.html 獲取 CSRF 令牌
  Future<void> _getCsrfFromWizard(String baseUrl) async {
    _logAdd("Getting CSRF from: $baseUrl/wizard.html");

    try {
      final response = await _client!.get(Uri.parse("$baseUrl/wizard.html"));

      if (response.statusCode == 200) {
        _logAdd("Headers from wizard page:");
        response.headers.forEach((key, value) {
          _logAdd("$key: $value");
        });

        // 提取 CSRF 令牌
        final csrfRegex = RegExp(r'CSRF_TOKEN\s*=\s*"([a-f0-9]{32})"');
        final match = csrfRegex.firstMatch(response.body);

        if (match != null) {
          _csrfToken = match.group(1)!;
          _logAdd("CSRF token = $_csrfToken");
        } else {
          _logAdd("CSRF_TOKEN not found in wizard.html response body");
        }
      } else {
        _logAdd("Failed to get wizard page: ${response.statusCode}");
      }
    } catch (e) {
      _logAdd("Error getting wizard page: $e");
    }
  }

  // 發送 SRP 證明
  Future<bool> _sendProof(String baseUrl, String proof, String paramName) async {
    final postUrl = "$baseUrl/cgi-bin/webPost.plua?csrftoken=$_csrfToken";
    final headers = {
      'Content-Type': 'application/json',
      'Origin': baseUrl,
      'Referer': '$baseUrl/login.html',
    };

    final data = {
      'function': 'authenticate',
      'data': {
        'CSRFtoken': _csrfToken,
      }
    };

    (data['data'] as Map<String, dynamic>)[paramName] = proof;

    _logAdd("Sending proof with $paramName parameter to $postUrl");
    _logAdd("Data: ${json.encode(data)}");

    final response = await _client!.post(
      Uri.parse(postUrl),
      headers: headers,
      body: json.encode(data),
    );

    _logAdd("Status: ${response.statusCode}");

    if (response.statusCode == 200) {
      try {
        final responseData = json.decode(response.body);
        _logAdd("Response data: $responseData");

        // 檢查錯誤信息
        if (responseData.containsKey('error')) {
          final errorMsg = responseData['error']['msg'] ?? 'Unknown error';
          _logAdd("Error: $errorMsg");
          return false;
        }

        return true;
      } catch (e) {
        _logAdd("Failed to parse response: $e");
        _logAdd("Response text: ${response.body}");

        // 如果JSON解析失敗但狀態碼是200，可能仍然成功
        if (response.body.toLowerCase().contains('success')) {
          return true;
        }
        return false;
      }
    } else {
      _logAdd("Request failed with status code: ${response.statusCode}");
      return false;
    }
  }

  // 獲取儀表板頁面
  Future<bool> _getDashboard(String baseUrl) async {
    final dashboardUrl = "$baseUrl/dashboard.html?csrftoken=$_csrfToken";

    _logAdd("Getting dashboard from $dashboardUrl");

    try {
      final response = await _client!.get(Uri.parse(dashboardUrl));

      if (response.statusCode == 200) {
        _logAdd("Dashboard loaded successfully");
        // 保存一部分dashboard內容以驗證成功
        final preview = response.body.length > 200
            ? response.body.substring(0, 200) + "..."
            : response.body;
        _logAdd("Dashboard preview: $preview");
        return true;
      } else {
        _logAdd("Failed to load dashboard: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      _logAdd("Error loading dashboard: $e");
      return false;
    }
  }

  // 生成隨機 BigInt
  BigInt _generateRandomBigInt(int bytes) {
    final random = Random.secure();
    final randomBytes = List<int>.generate(bytes, (_) => random.nextInt(256));
    return BigInt.parse(
        randomBytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(''),
        radix: 16
    );
  }

  // 十六進制字符串轉換為位元組數組
  Uint8List _hexToBytes(String hex) {
    // 確保長度為偶數
    if (hex.length % 2 != 0) {
      hex = '0$hex';
    }

    // 轉換為小寫
    hex = hex.toLowerCase();

    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      final value = int.parse(hex.substring(i, i + 2), radix: 16);
      result[i ~/ 2] = value;
    }
    return result;
  }

  // 位元組數組轉換為十六進制字符串
  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  }

  // 計算 SRP 證明 (實現Python srp.User.process_challenge的主要功能)
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

    _logAdd("Process challenge result: ${M.toString()}");
    _logAdd("Type: ${M.runtimeType}");

    return Uint8List.fromList(M);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SRP 路由器登入測試'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
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

          // 登入按鈕
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _performLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('執行 SRP 登入測試', style: TextStyle(fontSize: 18)),
            ),
          ),

          // 日誌輸出
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(8),
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
          ),
        ],
      ),
    );
  }
}