import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:whitebox/shared/api/wifi_api_service.dart';
import 'package:whitebox/shared/ui/pages/test/SrpLoginModifiedTestPage.dart';

class TestPasswordPage extends StatefulWidget {
  const TestPasswordPage({super.key});

  @override
  State<TestPasswordPage> createState() => _TestPasswordPageState();
}

class _TestPasswordPageState extends State<TestPasswordPage> {
  // 存儲測試日誌
  List<String> logs = [];
  String calculatedPassword = '';
  bool isCalculating = false;
  bool isLoadingData = false;
  String _statusMessage = "點擊按鈕開始測試";
  final _scrollController = ScrollController();

  // 系統資訊
  String apiSalt = ''; // 從API獲取的salt值

  // 固定參數
  final String deviceModel = '8C16451AF919';  // 設備型號
  final String ssid = 'EG65BE_5G';  // SSID

  // 預設 Hash 數組（與規則一致）
  static const List<String> DEFAULT_HASHES = [
    '1a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d5e6f708192a3b4c5d6e7f809',
    '9876543210abcdef9876543210abcdef9876543210abcdef9876543210abcdef',
    'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef', // 這是索引 3 的 hash
    'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
    '7890abcdef1234567890abcdef1234567890abcdef1234567890abcdef123456',
  ];

  @override
  void initState() {
    super.initState();
    // 自動開始加載系統資訊
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSystemInfo();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 更新狀態消息
  void _updateStatus(String status) {
    setState(() {
      _statusMessage = status;
    });
  }

  // 添加日誌
  void _addLog(String message) {
    setState(() {
      logs.add(message);
    });

    // 確保日誌滾動到底部
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    print(message);
  }

  // 加載系統資訊
  Future<void> _loadSystemInfo() async {
    setState(() {
      logs = [];
      calculatedPassword = '';
      isLoadingData = true;
      _updateStatus("正在從 API 獲取系統資訊...");
      _addLog('正在從 API 獲取系統資訊...');
    });

    try {
      // 從 API 獲取系統資訊，但只取 salt 值
      final result = await WifiApiService.call('getSystemInfo');

      setState(() {
        apiSalt = result['login_salt'] ?? '';
        isLoadingData = false;
      });

      _updateStatus("成功獲取系統資訊");
      _addLog('成功從 API 獲取 salt 值：');
      _addLog('  API salt: $apiSalt');

      // 自動開始密碼計算
      _calculatePassword();
    } catch (e) {
      setState(() {
        isLoadingData = false;
      });
      _updateStatus("獲取系統資訊失敗");
      _addLog('獲取系統資訊出錯: $e');
      _addLog('無法繼續計算密碼');
    }
  }

  // 計算組合編號
  int _calculateCombinationIndex(String serialNumber) {
    Digest digest = sha256.convert(utf8.encode(serialNumber));
    String hexDigest = digest.toString();
    _addLog('型號 SHA256: $hexDigest');

    String lastByte = hexDigest.substring(hexDigest.length - 2);
    int lastByteValue = int.parse(lastByte, radix: 16);
    _addLog('最後字節（十六進制）: $lastByte, 十進制: $lastByteValue');

    int combinationIndex = lastByteValue % 6;
    _addLog('計算得到的組合編號: $combinationIndex');

    // 使用計算出的組合編號，不強制使用固定值
    return combinationIndex;
  }

  // 執行密碼計算
  Future<void> _calculatePassword() async {
    if (apiSalt.isEmpty) {
      _updateStatus("無法計算密碼：缺少 Salt 值");
      _addLog('錯誤：缺少 Salt 值，無法計算密碼');
      return;
    }

    setState(() {
      calculatedPassword = '';
      isCalculating = true;
      _updateStatus("正在計算初始密碼...");
    });

    _addLog('開始密碼計算...');

    try {
      _addLog('使用以下參數計算密碼:');
      _addLog('設備型號: $deviceModel');
      _addLog('SSID: $ssid');
      _addLog('鹽值: $apiSalt');

      // 步驟 1: 計算組合編號
      _addLog('\n步驟 1: 計算組合編號');
      int combinationIndex = _calculateCombinationIndex(deviceModel);

      // 步驟 2: 選擇預設 Hash
      _addLog('\n步驟 2: 選擇預設 Hash');
      String selectedHash = DEFAULT_HASHES[combinationIndex];
      _addLog('選擇的 Hash (組合編號 $combinationIndex): $selectedHash');

      // 步驟 3: 拆分 Salt
      _addLog('\n步驟 3: 拆分 Salt');
      String saltFront = apiSalt.substring(0, 32);
      String saltBack = apiSalt.substring(32);
      _addLog('Salt 前段 (前 128 位元): $saltFront');
      _addLog('Salt 後段 (後 128 位元): $saltBack');

      // 步驟 4: 根據組合編號生成消息
      _addLog('\n步驟 4: 根據組合編號生成消息');
      String message = '';
      String messageDesc = '';

      switch (combinationIndex) {
        case 0:
          message = ssid + saltFront + saltBack;
          messageDesc = 'SSID + Salt 前段 + Salt 後段';
          break;
        case 1:
          message = ssid + saltBack + saltFront;
          messageDesc = 'SSID + Salt 後段 + Salt 前段';
          break;
        case 2:
          message = saltFront + ssid + saltBack;
          messageDesc = 'Salt 前段 + SSID + Salt 後段';
          break;
        case 3:
          message = saltFront + saltBack + ssid;
          messageDesc = 'Salt 前段 + Salt 後段 + SSID';
          break;
        case 4:
          message = saltBack + ssid + saltFront;
          messageDesc = 'Salt 後段 + SSID + Salt 前段';
          break;
        case 5:
          message = saltBack + saltFront + ssid;
          messageDesc = 'Salt 後段 + Salt 前段 + SSID';
          break;
      }

      _addLog('消息組合方式: $messageDesc');
      _addLog('生成的消息: $message');

      // 步驟 5: 計算 HMAC-SHA256
      _addLog('\n步驟 5: 計算 HMAC-SHA256');
      List<int> keyBytes = utf8.encode(selectedHash);
      List<int> messageBytes = utf8.encode(message);
      Hmac hmacSha256 = Hmac(sha256, keyBytes);
      Digest digest = hmacSha256.convert(messageBytes);
      String result = digest.toString();

      _addLog('HMAC-SHA256 結果: $result');

      setState(() {
        calculatedPassword = result;
        isCalculating = false;
        _updateStatus("密碼計算完成！");
      });

      _addLog('\n計算完成!');
    } catch (e) {
      _addLog('計算出錯: $e');
      setState(() {
        isCalculating = false;
        _updateStatus("密碼計算失敗!");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('初始化階段密碼生成測試'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 狀態顯示
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              color: calculatedPassword.isNotEmpty ? Colors.green[100] : Colors.blue[50],
              child: Column(
                children: [
                  Icon(
                    calculatedPassword.isNotEmpty ? Icons.check_circle : Icons.info,
                    size: 50,
                    color: calculatedPassword.isNotEmpty ? Colors.green : Colors.blue,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _statusMessage,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: calculatedPassword.isNotEmpty ? Colors.green[800] : Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // 輸入表單及結果顯示
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '初始化階段密碼生成測試',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '從 API 獲取 salt 並使用固定參數計算初始密碼',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '固定參數：\n型號: $deviceModel\nSSID: $ssid',
                    style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 20),

                  // 如果計算出密碼，顯示結果
                  if (calculatedPassword.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 0),
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
                            '計算結果',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Text('用戶名: ', style: TextStyle(fontWeight: FontWeight.bold)),
                              SelectableText('admin', style: const TextStyle(fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Text('密碼: ', style: TextStyle(fontWeight: FontWeight.bold)),
                              Expanded(
                                child: SelectableText(
                                  calculatedPassword,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: calculatedPassword.isEmpty ? null : () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => SrpLoginModifiedTestPage.withPassword(calculatedPassword)
                                    )
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('使用此密碼測試登入', style: TextStyle(fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 操作按鈕
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isLoadingData || isCalculating ? null : _loadSystemInfo,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: isLoadingData
                                ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                                : const Text('重新加載系統資訊', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isCalculating || isLoadingData || apiSalt.isEmpty ? null : _calculatePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: isCalculating
                                ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                                : const Text('重新計算密碼', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 測試日誌標題
                  const Text(
                    '測試日誌',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // 日誌輸出區域
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
                  logs.join('\n'),
                  style: const TextStyle(
                    color: Colors.green,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}