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

  // 根據您提供的新信息
  final String expectedSha256SN = '937fe0cbc16e4d192401368f00c2271a1d15b05e1b2c2244fb275059083dfab4';
  final String expectedHash = '1a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d5e6f708192a3b4c5d6e7f809';
  final String expectedMessage = 'EG65BE_5Gbcaab16272c7819b855755157fa679ad60cf733fbc7bfc37b883381bef31886f';
  final String expectedPassword = '4744889708859b259d7d8e695bc7b5723e834a5c81d1534bb9ab4d370198829a';

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
    _addLog('預期的序號 SHA256: $expectedSha256SN');
    _addLog('SHA256計算' + (hexDigest == expectedSha256SN ? '正確' : '不正確'));

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
      _addLog('預期的 Hash: $expectedHash');
      _addLog('Hash選擇' + (selectedHash == expectedHash ? '正確' : '不正確'));

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
      _addLog('生成的消息 (組合編號 $combinationIndex): $message');
      _addLog('消息組合方式: $messageDesc');
      _addLog('預期的消息: $expectedMessage');
      _addLog('消息生成' + (message == expectedMessage ? '正確' : '不正確'));

      if (message != expectedMessage) {
        _addLog('\n注意：生成的消息與預期不符，嘗試手動組合...');
        message = expectedMessage;
        _addLog('使用預期的消息進行後續計算: $message');
      }

      // 步驟 5: 計算 HMAC-SHA256（標準方法 - hexToBytes）
      _addLog('\n步驟 5.1: 計算 HMAC-SHA256（標準方法 - hexToBytes）');
      List<int> keyBytesHex = _hexToBytes(selectedHash);
      List<int> messageBytes = utf8.encode(message);
      Hmac hmacSha256Hex = Hmac(sha256, keyBytesHex);
      Digest digestHex = hmacSha256Hex.convert(messageBytes);
      String resultHex = digestHex.toString();
      _addLog('HMAC-SHA256 結果 (hexToBytes): $resultHex');
      _addLog('與預期密碼比較: ' + (resultHex == expectedPassword ? '匹配' : '不匹配'));

      // 步驟 5.2: 計算 HMAC-SHA256（UTF-8編碼方式）
      _addLog('\n步驟 5.2: 計算 HMAC-SHA256（UTF-8編碼方式）');
      List<int> keyBytesUtf8 = utf8.encode(selectedHash);
      Hmac hmacSha256Utf8 = Hmac(sha256, keyBytesUtf8);
      Digest digestUtf8 = hmacSha256Utf8.convert(messageBytes);
      String resultUtf8 = digestUtf8.toString();
      _addLog('HMAC-SHA256 結果 (UTF-8編碼): $resultUtf8');
      _addLog('與預期密碼比較: ' + (resultUtf8 == expectedPassword ? '匹配' : '不匹配'));

      // 步驟 6: 綜合分析
      _addLog('\n步驟 6: 綜合分析');

      if (resultHex == expectedPassword || resultUtf8 == expectedPassword) {
        _addLog('✅ 已找到匹配的計算方法！');

        if (resultHex == expectedPassword) {
          _addLog('正確的計算方法是：使用標準方法 (hexToBytes)');
          setState(() {
            calculatedPassword = resultHex;
          });
        }

        if (resultUtf8 == expectedPassword) {
          _addLog('正確的計算方法是：使用UTF-8編碼方式');
          setState(() {
            calculatedPassword = resultUtf8;
          });
        }

        _addLog('\n建議修改 calculateInitialPassword 方法：');
        _addLog('1. 根據文檔計算組合編號: $combinationIndex');
        _addLog('2. 選擇對應的Hash: ${DEFAULT_HASHES[combinationIndex]}');
        _addLog('3. 消息組合按照規則: $messageDesc');
        _addLog('4. HMAC計算使用 ' + (resultUtf8 == expectedPassword ? 'UTF-8編碼' : '標準 hexToBytes 方法'));
      } else {
        _addLog('❌ 未找到匹配的計算方法，繼續測試其他可能性...');

        // 測試使用完整測試集
        _addLog('\n嘗試所有可能的組合:');
        bool found = false;

        for (int i = 0; i < DEFAULT_HASHES.length; i++) {
          String hash = DEFAULT_HASHES[i];

          for (int j = 0; j < 6; j++) {
            String testMessage = '';
            switch (j) {
              case 0:
                testMessage = testSSID + saltFront + saltBack;
                break;
              case 1:
                testMessage = testSSID + saltBack + saltFront;
                break;
              case 2:
                testMessage = saltFront + testSSID + saltBack;
                break;
              case 3:
                testMessage = saltFront + saltBack + testSSID;
                break;
              case 4:
                testMessage = saltBack + testSSID + saltFront;
                break;
              case 5:
                testMessage = saltBack + saltFront + testSSID;
                break;
            }

            // 使用UTF-8編碼
            List<int> testKeyUtf8 = utf8.encode(hash);
            List<int> testMessageBytes = utf8.encode(testMessage);
            Hmac testHmacUtf8 = Hmac(sha256, testKeyUtf8);
            Digest testDigestUtf8 = testHmacUtf8.convert(testMessageBytes);
            String testResultUtf8 = testDigestUtf8.toString();

            if (testResultUtf8 == expectedPassword) {
              _addLog('\n✅ 找到匹配組合!');
              _addLog('Hash編號: $i');
              _addLog('消息組合編號: $j');
              _addLog('結果: $testResultUtf8');
              found = true;
              setState(() {
                calculatedPassword = testResultUtf8;
              });
              break;
            }

            // 使用hexToBytes
            List<int> testKeyHex = _hexToBytes(hash);
            Hmac testHmacHex = Hmac(sha256, testKeyHex);
            Digest testDigestHex = testHmacHex.convert(testMessageBytes);
            String testResultHex = testDigestHex.toString();

            if (testResultHex == expectedPassword) {
              _addLog('\n✅ 找到匹配組合!');
              _addLog('Hash編號: $i (使用hexToBytes)');
              _addLog('消息組合編號: $j');
              _addLog('結果: $testResultHex');
              found = true;
              setState(() {
                calculatedPassword = testResultHex;
              });
              break;
            }
          }

          if (found) break;
        }

        if (!found) {
          _addLog('\n❌ 測試了所有組合，仍未找到匹配方式');
        }
      }
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