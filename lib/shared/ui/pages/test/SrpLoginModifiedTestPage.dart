import 'package:flutter/material.dart';
import 'package:whitebox/shared/api/login_process.dart'; // 引入新的登入處理類

class SrpLoginModifiedTestPage extends StatefulWidget {
  final String initialPassword;

  const SrpLoginModifiedTestPage({Key? key}) : initialPassword = "", super(key: key);

  // 添加具有初始密碼的構造函數
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

  String _sessionId = "";
  String _csrfToken = "";

  @override
  void initState() {
    super.initState();
    // 初始化控制器並設置初始值
    _usernameController = TextEditingController(text: "admin");
    _passwordController = TextEditingController(
        text: widget.initialPassword.isNotEmpty ? widget.initialPassword : "ceb81a924d4b2ece0f552a2a1d56c3c5cbfd864107a69c9a3acbde5e71727b9c"
    );
    _baseUrlController = TextEditingController(text: "http://192.168.1.1");

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

  // 開始 SRP 登入流程
  Future<void> startSRPLoginProcess() async {
    if (_isLoading) return;
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
      _loginSuccess = false;
      _logOutput = "開始 SRP 登入流程...";
      _sessionId = "";
      _csrfToken = "";
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

      // 創建 LoginProcess 實例
      final loginProcess = LoginProcess(username, password, baseUrl: baseUrl);

      // 使用重定向將所有調試輸出添加到日誌中
      FlutterError.onError = (FlutterErrorDetails details) {
        _logAdd("錯誤: ${details.exception}");
      };

      // 開始登入流程
      _updateStatus("正在執行 SRP 登入流程...");
      _logAdd("啟動 SRP 登入流程...");

      // 調用 LoginProcess 中的 startSRPLoginProcess 方法
      final loginResult = await loginProcess.startSRPLoginProcess();

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
        title: const Text('SRP 登入測試 (使用 LoginProcess)'),
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