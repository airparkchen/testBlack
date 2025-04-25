import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:whitebox/shared/api/wifi_api_service.dart';
// 需要額外導入網絡信息套件
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  // 用於儲存 API 回傳的結果
  Map<String, dynamic> _apiResult = {};

  // 用於顯示加載狀態
  bool _isLoading = false;
  bool _isCalculatingPassword = false;

  // 用於顯示錯誤資訊
  String? _errorMessage;

  // 儲存原始回應
  String _rawResponse = '';

  // 儲存計算出的密碼和使用的SSID
  String _calculatedPassword = '';
  String _usedSSID = '';

  // 直接使用 http 測試 API 呼叫的方法
  Future<void> _testSystemInfoApi() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _rawResponse = '';
      _apiResult = {};
    });

    try {
      // 直接使用 http 套件發送請求
      final url = Uri.parse('${WifiApiService.baseUrl}${WifiApiService.systemInfoPath}');
      print('請求 URL: $url');

      final response = await http.get(
        url,
        headers: WifiApiService.getHeaders(),
      ).timeout(const Duration(seconds: WifiApiService.timeoutSeconds));

      // 保存原始回應內容
      _rawResponse = response.body;
      print('原始回應內容：$_rawResponse');
      print('狀態碼：${response.statusCode}');
      print('回應標頭：${response.headers}');

      // 嘗試解析 JSON - 處理特殊格式
      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          // 如果回應包含多行，嘗試找到 JSON 部分
          String jsonString = _rawResponse;

          // 查找 JSON 可能的起始位置（從最後一行尋找 JSON 開頭 '{'）
          final lines = _rawResponse.split('\n');
          for (int i = 0; i < lines.length; i++) {
            final line = lines[i].trim();
            if (line.startsWith('{') && line.contains('}')) {
              jsonString = line;
              break;
            } else if (line.startsWith('{')) {
              // 找到了 JSON 開頭，組合剩餘行
              jsonString = lines.sublist(i).join('\n');
              break;
            }
          }

          final jsonResult = json.decode(jsonString);

          setState(() {
            _apiResult = jsonResult;
            _isLoading = false;
          });

          print('解析後的 JSON 結果：$jsonResult');
        } catch (jsonError) {
          setState(() {
            _errorMessage = '無法解析 JSON: $jsonError\n原始回應內容保留在下方';
            _isLoading = false;
          });

          print('JSON 解析錯誤：$jsonError');
        }
      } else {
        setState(() {
          _errorMessage = '請求失敗: 狀態碼 ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      // 處理錯誤情況
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });

      print('HTTP 請求錯誤：$e');
    }
  }

  // 獲取當前連接的 SSID
  Future<String?> _getCurrentSSID() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.wifi) {
        final info = NetworkInfo();
        final ssid = await info.getWifiName();

        if (ssid != null && ssid.isNotEmpty) {
          // 去除SSID兩端可能的引號
          return ssid.replaceAll('"', '');
        }
      }
      return null;
    } catch (e) {
      print('獲取SSID錯誤: $e');
      return null;
    }
  }

  // 計算初始密碼的方法
  Future<void> _calculateInitialPassword() async {
    setState(() {
      _isCalculatingPassword = true;
      _errorMessage = null;
      _calculatedPassword = '';
      _usedSSID = '';
    });

    try {
      // 先獲取系統資訊，以便獲取必要的參數
      if (_apiResult.isEmpty) {
        // 如果還沒有獲取系統資訊，先獲取
        final url = Uri.parse('${WifiApiService.baseUrl}${WifiApiService.systemInfoPath}');
        final response = await http.get(
          url,
          headers: WifiApiService.getHeaders(),
        ).timeout(const Duration(seconds: WifiApiService.timeoutSeconds));

        // 處理響應，提取JSON部分
        String jsonString = response.body;
        int jsonStart = jsonString.indexOf('{');
        if (jsonStart > 0) {
          jsonString = jsonString.substring(jsonStart);
        }
        _apiResult = json.decode(jsonString);
      }

      // 從API結果中提取所需數據
      String serialNumber = _apiResult['serial_number'] ?? '';
      String loginSalt = _apiResult['login_salt'] ?? '';

      // 獲取當前連接的SSID
      String? currentSSID = await _getCurrentSSID();
      String modelName = _apiResult['model_name'] ?? '';

      // 優先使用當前連接的SSID，如果獲取失敗則使用設備型號作為替代
      String ssid = currentSSID ?? modelName;

      // 儲存使用的SSID以便顯示
      _usedSSID = ssid;

      // 如果缺少必要資訊，則報錯
      if (serialNumber.isEmpty || loginSalt.isEmpty) {
        throw Exception('無法獲取序號或登入鹽值，請先獲取系統資訊');
      }

      // 計算初始密碼
      final password = await WifiApiService.calculateInitialPassword(
        providedSSID: ssid,
        serialNumber: serialNumber,
        loginSalt: loginSalt,
      );

      setState(() {
        _calculatedPassword = password;
        _isCalculatingPassword = false;
      });

      print('計算得到的初始密碼: $password (使用SSID: $ssid)');
    } catch (e) {
      setState(() {
        _errorMessage = '計算密碼錯誤: $e';
        _isCalculatingPassword = false;
      });

      print('計算密碼錯誤: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API 測試頁面'),
        backgroundColor: Colors.grey[300],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 測試按鈕
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _testSystemInfoApi,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDDDDDD),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(0),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text(
                  '測試 getSystemInfo API',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.normal),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 計算密碼按鈕
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (_isCalculatingPassword || _apiResult.isEmpty) ? null : _calculateInitialPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDDDDDD),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(0),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                  disabledBackgroundColor: Colors.grey[200],
                ),
                child: _isCalculatingPassword
                    ? const CircularProgressIndicator()
                    : const Text(
                  '計算初始密碼',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.normal),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // API URL 顯示
            Text(
              '請求 URL: ${WifiApiService.baseUrl}${WifiApiService.systemInfoPath}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            // 顯示計算出的密碼
            if (_calculatedPassword.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '計算得到的初始密碼：',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      border: Border.all(color: Colors.green[400]!),
                    ),
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          _calculatedPassword,
                          style: const TextStyle(
                            fontSize: 16,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '使用設備序號: ${_apiResult['serial_number'] ?? '未知'}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text(
                          '使用SSID: $_usedSSID',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 20),

            // 顯示 API 回傳結果的標題
            const Text(
              'API 回傳結果：',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            // 如果有錯誤，顯示錯誤訊息
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(10),
                color: Colors.red[100],
                width: double.infinity,
                child: Text(
                  '錯誤：$_errorMessage',
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            // 顯示 API 結果
            if (_apiResult.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.grey[400]!),
                ),
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 遍歷 API 回傳的結果顯示在畫面上
                    ..._apiResult.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          '${entry.key}: ${entry.value}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),

            // 如果 API 尚未呼叫或是空結果，顯示提示資訊
            if (_apiResult.isEmpty && _errorMessage == null && !_isLoading && _rawResponse.isEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                color: Colors.grey[200],
                width: double.infinity,
                child: const Text(
                  '尚未取得任何結果，請點擊上方按鈕測試 API',
                  style: TextStyle(fontSize: 16),
                ),
              ),

            // 顯示原始回應內容
            if (_rawResponse.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 30),
                  const Text(
                    '原始回應內容：',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border.all(color: Colors.grey[800]!),
                    ),
                    width: double.infinity,
                    child: Text(
                      _rawResponse,
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'monospace',
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),

            // 格式化顯示 JSON
            if (_apiResult.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 30),
                  const Text(
                    '解析後的 JSON 資料：',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    width: double.infinity,
                    child: Text(
                      _apiResult.toString(),
                      style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}