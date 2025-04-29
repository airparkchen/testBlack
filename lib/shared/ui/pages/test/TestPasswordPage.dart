import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:whitebox/shared/api/wifi_api_service.dart';

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

  // 照片中提供的測試參數
  final String testSalt = 'bcaab16272c7819b855755157fa679ad60cf733fbc7bfc37b883381bef31886f';
  final String testSSID = 'EG65BE_5G';
  final String testSerialNumber = '8C16451AF919';
  final String expectedPassword = 'ce07fda6c9b793bc6d5c0685542c682014c2c93b3f692383f43b6ead0a796c30';

  // 預設 Hash 數組（與規則一致）
  static const List<String> DEFAULT_HASHES = [
    '1a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d5e6f708192a3b4c5d6e7f809',
    '9876543210abcdef9876543210abcdef9876543210abcdef9876543210abcdef',
    'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
    '7890abcdef1234567890abcdef1234567890abcdef1234567890abcdef123456',
  ];

  @override
  void initState() {
    super.initState();
    // 自動開始測試
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runTest();
    });
  }

  // 添加日誌
  void _addLog(String message) {
    setState(() {
      logs.add(message);
    });
    print(message);
  }

  // 計算組合編號
  int _calculateCombinationIndex(String serialNumber) {
    Digest digest = sha256.convert(utf8.encode(serialNumber));
    String hexDigest = digest.toString();
    _addLog('序號 SHA256: $hexDigest');
    String lastByte = hexDigest.substring(hexDigest.length - 2);
    int lastByteValue = int.parse(lastByte, radix: 16);
    _addLog('最後字節（十六進制）: $lastByte, 十進制: $lastByteValue');
    int combinationIndex = lastByteValue % 6;
    _addLog('組合編號: $combinationIndex');
    return combinationIndex;
  }

  // 16進制字符串轉換為位元組數組
  List<int> _hexToBytes(String hex) {
    List<int> bytes = [];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  // 執行測試
  Future<void> _runTest() async {
    setState(() {
      logs = [];
      calculatedPassword = '';
      isCalculating = true;
    });

    _addLog('開始測試初始化階段密碼生成...');
    _addLog('========== 測試參數 ==========');
    _addLog('Salt值: $testSalt');
    _addLog('SSID: $testSSID');
    _addLog('設備序號: $testSerialNumber');
    _addLog('預期密碼: $expectedPassword');
    _addLog('==============================');

    try {
      // 步驟 1: 計算組合編號
      _addLog('\n步驟 1: 計算組合編號');
      int combinationIndex = _calculateCombinationIndex(testSerialNumber);

      // 步驟 2: 選擇預設 Hash
      _addLog('\n步驟 2: 選擇預設 Hash');
      String selectedHash = DEFAULT_HASHES[combinationIndex];
      _addLog('選擇的 Hash (組合編號 $combinationIndex): $selectedHash');

      // 步驟 3: 拆分 Salt
      _addLog('\n步驟 3: 拆分 Salt');
      String saltFront = testSalt.substring(0, 32);
      String saltBack = testSalt.substring(32);
      _addLog('Salt 前段 (前 128 位元): $saltFront');
      _addLog('Salt 後段 (後 128 位元): $saltBack');

      // 步驟 4: 根據組合編號生成消息
      _addLog('\n步驟 4: 根據組合編號生成消息');
      String message = '';
      String messageDesc = '';
      switch (combinationIndex) {
        case 0:
          message = testSSID + saltFront + saltBack;
          messageDesc = 'SSID + Salt 前段 + Salt 後段';
          break;
        case 1:
          message = testSSID + saltBack + saltFront;
          messageDesc = 'SSID + Salt 後段 + Salt 前段';
          break;
        case 2:
          message = saltFront + testSSID + saltBack;
          messageDesc = 'Salt 前段 + SSID + Salt 後段';
          break;
        case 3:
          message = saltFront + saltBack + testSSID;
          messageDesc = 'Salt 前段 + Salt 後段 + SSID';
          break;
        case 4:
          message = saltBack + testSSID + saltFront;
          messageDesc = 'Salt 後段 + SSID + Salt 前段';
          break;
        case 5:
          message = saltBack + saltFront + testSSID;
          messageDesc = 'Salt 後段 + Salt 前段 + SSID';
          break;
      }
      _addLog('生成的規則消息 (組合編號 $combinationIndex): $message');
      _addLog('消息組合方式: $messageDesc');

      // 步驟 5: 計算 HMAC-SHA256（使用 UTF-8 編碼的 Hash）
      _addLog('\n步驟 5: 計算 HMAC-SHA256（使用 UTF-8 編碼的 Hash）');
      List<int> keyBytes = utf8.encode(selectedHash);
      List<int> messageBytes = utf8.encode(message);
      Hmac hmacSha256 = Hmac(sha256, keyBytes);
      Digest digest = hmacSha256.convert(messageBytes);
      String result = digest.toString();
      _addLog('HMAC-SHA256 結果: $result');

      // 步驟 6: 比較結果
      _addLog('\n步驟 6: 比較結果');
      _addLog('計算的密碼: $result');
      _addLog('預期的密碼: $expectedPassword');
      if (result == expectedPassword) {
        _addLog('✅ 計算結果與預期相符！');
      } else {
        _addLog('❌ 計算結果與預期不符');
        _addLog('\n進一步分析：');

        // 額外測試：使用開發者給定的消息和 Hash
        _addLog('\n測試開發者給定的消息和 Hash：');
        String devHash = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
        String devMessage = testSalt + testSSID;
        _addLog('開發者給定的 Hash (組合編號 3): $devHash');
        _addLog('開發者給定的消息: $devMessage (Salt + SSID)');

        // 使用 UTF-8 編碼
        List<int> devKeyBytes = utf8.encode(devHash);
        List<int> devMessageBytes = utf8.encode(devMessage);
        Hmac devHmacSha256 = Hmac(sha256, devKeyBytes);
        Digest devDigest = devHmacSha256.convert(devMessageBytes);
        String devResult = devDigest.toString();
        _addLog('HMAC-SHA256 結果（開發者格式，UTF-8 編碼）: $devResult');
        _addLog('與預期比較: ' + (devResult == expectedPassword ? '匹配' : '不匹配'));

        // 測試 hexToBytes 編碼
        List<int> devKeyBytesHex = _hexToBytes(devHash);
        Hmac devHmacSha256Hex = Hmac(sha256, devKeyBytesHex);
        Digest devDigestHex = devHmacSha256Hex.convert(devMessageBytes);
        String devResultHex = devDigestHex.toString();
        _addLog('HMAC-SHA256 結果（開發者格式，hexToBytes 編碼）: $devResultHex');
        _addLog('與預期比較: ' + (devResultHex == expectedPassword ? '匹配' : '不匹配'));
      }

      setState(() {
        calculatedPassword = result;
      });
    } catch (e) {
      _addLog('測試出錯: $e');
    }

    _addLog('\n測試完成!');

    setState(() {
      isCalculating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('初始化階段密碼生成測試'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '初始化階段密碼生成測試頁面',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '根據規則測試密碼生成是否正確。',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            if (calculatedPassword.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  border: Border.all(color: Colors.blue),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '計算結果',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      calculatedPassword,
                      style: const TextStyle(
                        fontSize: 16,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 8),
                    calculatedPassword == expectedPassword
                        ? const Text('✅ 計算結果與預期相符', style: TextStyle(color: Colors.green))
                        : const Text('❌ 計算結果與預期不符', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isCalculating ? null : _runTest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: isCalculating
                    ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                    : const Text('重新測試', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              '測試日誌',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: isCalculating
                    ? const Center(child: CircularProgressIndicator())
                    : logs.isEmpty
                    ? Center(
                  child: Text(
                    '尚無日誌',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                )
                    : SingleChildScrollView(
                  child: SelectableText(
                    logs.join('\n'),
                    style: const TextStyle(
                      color: Colors.lightGreenAccent,
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
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