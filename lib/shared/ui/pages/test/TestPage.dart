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
  bool _isLogingIn = false;

  // 用於顯示錯誤資訊
  String? _errorMessage;

  // 儲存原始回應
  String _rawResponse = '';

  // 儲存計算出的密碼和使用的SSID
  String _calculatedPassword = '';
  String _usedSSID = '';
  String _defaultUser = '';

  // 用於存儲登入結果
  Map<String, dynamic> _loginResult = {};

  // 使用新的 API 服務測試 getSystemInfo
  Future<void> _testSystemInfoApi() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _rawResponse = '';
      _apiResult = {};
    });

    try {
      // 使用動態方法調用
      final systemInfoEndpoint = WifiApiService.getEndpoint('systemInfo');
      final url = Uri.parse('${WifiApiService.baseUrl}$systemInfoEndpoint');
      print('請求 URL: $url');

      final response = await http.get(
        url,
        headers: WifiApiService.getHeaders(),
      ).timeout(Duration(seconds: WifiApiService.timeoutSeconds));

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
            // 保存默認用戶名
            if (jsonResult.containsKey('default_user')) {
              _defaultUser = jsonResult['default_user'];
            }
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

  // 使用新的 API 服務直接獲取系統信息
  Future<void> _testSystemInfoApiDirect() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _apiResult = {};
    });

    try {
      // 使用新的動態調用方式
      final result = await WifiApiService.call('getSystemInfo');

      setState(() {
        _apiResult = result;
        _isLoading = false;
        // 保存默認用戶名
        if (result.containsKey('default_user')) {
          _defaultUser = result['default_user'];
        }
      });

      print('API調用成功，結果：$result');
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });

      print('API調用錯誤：$e');
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
        // 如果還沒有獲取系統資訊，使用新的 API 方式獲取
        final systemInfo = await WifiApiService.call('getSystemInfo');
        setState(() {
          _apiResult = systemInfo;
          // 保存默認用戶名
          if (systemInfo.containsKey('default_user')) {
            _defaultUser = systemInfo['default_user'];
          }
        });
      }

      // 從API結果中提取所需數據
      String serialNumber = _apiResult['serial_number'] ?? '';
      String loginSalt = _apiResult['login_salt'] ?? '';

      // 獲取當前連接的SSID
      String? currentSSID = await WifiApiService.getCurrentSSID();
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

  // 使用計算出的密碼嘗試登入
  Future<void> _testLogin() async {
    // 檢查是否已經有密碼和用戶名
    if (_calculatedPassword.isEmpty) {
      setState(() {
        _errorMessage = '請先計算初始密碼';
      });
      return;
    }

    if (_defaultUser.isEmpty) {
      setState(() {
        _defaultUser = 'admin'; // 預設使用admin作為用戶名
      });
    }

    setState(() {
      _isLogingIn = true;
      _errorMessage = null;
      _loginResult = {};
    });

    try {
      // 準備登入參數
      final loginData = {
        'method': 'basic',
        'user': _defaultUser,
        'password': _calculatedPassword,
      };

      print('嘗試使用以下資訊登入：');
      print('用戶名: $_defaultUser');
      print('密碼: $_calculatedPassword');

      // 調用登入API
      final result = await WifiApiService.call('postUserLogin', loginData);

      setState(() {
        _loginResult = result;
        _isLogingIn = false;
      });

      // 如果登入成功且返回了token，儲存到API服務中
      if (result.containsKey('jwt')) {
        WifiApiService.setJwtToken(result['jwt']);
        _showSuccessDialog('登入成功！已獲取JWT令牌。');
      } else {
        _showSuccessDialog('API請求已完成，但未獲取到JWT令牌。請檢查返回的資訊。');
      }

      print('登入API調用成功，結果：$result');
    } catch (e) {
      setState(() {
        _errorMessage = '登入失敗: $e';
        _isLogingIn = false;
      });

      print('登入錯誤：$e');
    }
  }

  // 顯示成功對話框
  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('成功'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  // 顯示所有可用的API方法
  void _showAvailableMethods() {
    final methods = WifiApiService.getAllMethodNames();
    setState(() {
      _apiResult = {'可用API方法': methods};
    });
  }

  // 一鍵自動化處理：獲取系統信息 -> 計算密碼 -> 登入
  Future<void> _autoLoginProcess() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      // 步驟1：獲取系統信息
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('步驟1: 獲取系統信息...'))
      );
      final systemInfo = await WifiApiService.call('getSystemInfo');
      setState(() {
        _apiResult = systemInfo;
        if (systemInfo.containsKey('default_user')) {
          _defaultUser = systemInfo['default_user'];
        } else {
          _defaultUser = 'admin';
        }
      });

      // 步驟2：計算初始密碼
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('步驟2: 計算初始密碼...'))
      );

      String serialNumber = systemInfo['serial_number'] ?? '';
      String loginSalt = systemInfo['login_salt'] ?? '';

      // 獲取當前連接的SSID
      String? currentSSID = await WifiApiService.getCurrentSSID();
      String modelName = systemInfo['model_name'] ?? '';
      String ssid = currentSSID ?? modelName;

      _usedSSID = ssid;

      if (serialNumber.isEmpty || loginSalt.isEmpty) {
        throw Exception('無法獲取序號或登入鹽值');
      }

      final password = await WifiApiService.calculateInitialPassword(
        providedSSID: ssid,
        serialNumber: serialNumber,
        loginSalt: loginSalt,
      );

      setState(() {
        _calculatedPassword = password;
      });

      // 步驟3：嘗試登入
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('步驟3: 嘗試登入...'))
      );

      final loginData = {
        'method': 'basic',
        'user': _defaultUser,
        'password': password,
      };

      final loginResult = await WifiApiService.call('postUserLogin', loginData);

      setState(() {
        _loginResult = loginResult;
        _isLoading = false;
      });

      if (loginResult.containsKey('jwt')) {
        WifiApiService.setJwtToken(loginResult['jwt']);
        _showSuccessDialog('自動登入成功！已獲取JWT令牌。');
      } else {
        _showSuccessDialog('API請求已完成，但未獲取到JWT令牌。請檢查返回的資訊。');
      }

    } catch (e) {
      setState(() {
        _errorMessage = '自動登入失敗: $e';
        _isLoading = false;
      });

      print('自動登入過程錯誤：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 獲取最新 API 端點
    final systemInfoEndpoint = WifiApiService.getEndpoint('systemInfo');

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
            // 一鍵自動化按鈕
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading || _isCalculatingPassword || _isLogingIn ? null : _autoLoginProcess,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50), // 綠色按鈕
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(0),
                    side: BorderSide(color: Colors.green.shade600),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                    : const Text(
                  '一鍵自動登入 (系統信息 -> 計算密碼 -> 登入)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 30),
            const Text('單步驟測試：', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // 測試按鈕 (直接HTTP呼叫)
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
                  '1. 測試 HTTP 直接呼叫 API',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.normal),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 測試按鈕 (使用動態方法)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _testSystemInfoApiDirect,
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
                  '1. 使用動態方法呼叫 API',
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
                onPressed: (_isCalculatingPassword || _isLoading) ? null : _calculateInitialPassword,
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
                  '2. 計算初始密碼',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.normal),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 登入按鈕
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (_isLogingIn || _calculatedPassword.isEmpty) ? null : _testLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDDDDDD),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(0),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                  disabledBackgroundColor: Colors.grey[200],
                ),
                child: _isLogingIn
                    ? const CircularProgressIndicator()
                    : const Text(
                  '3. 使用初始密碼登入',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.normal),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 顯示可用方法按鈕
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _showAvailableMethods,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDDDDDD),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(0),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                ),
                child: const Text(
                  '顯示所有可用 API 方法',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.normal),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // API URL 顯示
            Text(
              '請求 URL: ${WifiApiService.baseUrl}$systemInfoEndpoint',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            // 顯示登入資訊
            if (_loginResult.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '登入結果：',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      border: Border.all(color: Colors.blue[400]!),
                    ),
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ..._loginResult.entries.map((entry) {
                          if (entry.key == 'jwt') {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'JWT Token:',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SelectableText(
                                  '${entry.value}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return Text(
                              '${entry.key}: ${entry.value}',
                              style: const TextStyle(fontSize: 16),
                            );
                          }
                        }).toList(),
                      ],
                    ),
                  ),
                ],
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
                        if (_defaultUser.isNotEmpty) Text(
                          '默認用戶名: $_defaultUser',
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
                      // 如果值是陣列，特別處理顯示
                      if (entry.value is List) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${entry.key}:',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 5),
                            ...List.generate((entry.value as List).length, (index) {
                              return Padding(
                                padding: const EdgeInsets.only(left: 20.0, bottom: 5.0),
                                child: Text(
                                  '${index + 1}. ${(entry.value as List)[index]}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }),
                          ],
                        );
                      } else if (entry.value is Map) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${entry.key}:',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 5),
                            ...(entry.value as Map).entries.map((subEntry) {
                              return Padding(
                                padding: const EdgeInsets.only(left: 20.0, bottom: 5.0),
                                child: Text(
                                  '${subEntry.key}: ${subEntry.value}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }),
                          ],
                        );
                      } else {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            '${entry.key}: ${entry.value}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        );
                      }
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