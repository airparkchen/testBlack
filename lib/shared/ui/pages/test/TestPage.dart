// lib/shared/ui/pages/test/TestPage.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:whitebox/shared/api/wifi_api_service.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  // 日誌和狀態
  List<String> logs = [];
  bool isLoading = false;
  String statusMessage = "請選擇測試操作";

  // 輸入控制器
  final TextEditingController _usernameController = TextEditingController(text: 'admin');
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _ssidController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // API 端點列表
  Map<String, dynamic> apiConfig = {};
  List<String> endpoints = [];
  String? selectedEndpoint;
  String? selectedMethod;

  // 會話信息
  String? jwtToken;
  String? sessionId;
  String? csrfToken;
  bool isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    // 載入可用的 API 端點
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadApiEndpoints();
      _getCurrentWifiSSID();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _ssidController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  // 更新狀態消息
  void _updateStatus(String message) {
    setState(() {
      statusMessage = message;
    });
  }

  // 獲取當前連接的 WiFi SSID - 簡化版
  Future<void> _getCurrentWifiSSID() async {
    try {
      _addLog("嘗試獲取當前連接的 WiFi SSID...");

      // 使用 NetworkInfo 獲取 SSID
      final info = NetworkInfo();
      String? ssid = await info.getWifiName();

      // 清理 SSID 字符串 (移除引號等)
      if (ssid != null && ssid.isNotEmpty) {
        // 移除 SSID 字符串中的引號（如果有）
        ssid = ssid.replaceAll('"', '');

        // 檢查這是否看起來像 MAC 地址 (六組冒號分隔的十六進制數)
        bool isMacAddress = RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$').hasMatch(ssid);

        if (isMacAddress) {
          _addLog("獲取到的是 MAC 地址而非 SSID，將使用預設 SSID");
          ssid = "DefaultSSID"; // 使用預設值代替 MAC 地址
        } else {
          _addLog("成功獲取 SSID: $ssid");
        }
      } else {
        _addLog("無法獲取 SSID，使用預設值");
        ssid = "DefaultSSID"; // 使用預設值
      }

      // 設置 SSID 到輸入框
      setState(() {
        _ssidController.text = ssid!;
      });

    } catch (e) {
      _addLog("獲取 SSID 時出錯: $e");
      // 確保始終有一個預設值
      setState(() {
        if (_ssidController.text.isEmpty) {
          _ssidController.text = "DefaultSSID";
        }
      });
    }
  }

// 手動設置 SSID
  void _setCustomSSID() {
    // 顯示輸入對話框
    showDialog(
      context: context,
      builder: (context) {
        String customSSID = _ssidController.text;
        return AlertDialog(
          title: const Text('設置自定義 SSID'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'SSID',
              hintText: '請輸入 WiFi 名稱',
            ),
            onChanged: (value) {
              customSSID = value;
            },
            controller: TextEditingController(text: _ssidController.text),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _ssidController.text = customSSID;
                });
                _addLog("已設置自定義 SSID: $customSSID");
                Navigator.pop(context);
              },
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
  }

  // 載入 API 端點 - 修復版
  Future<void> _loadApiEndpoints() async {
    setState(() {
      isLoading = true;
      _updateStatus("載入 API 端點中...");
    });

    try {
      // 清空日誌以開始新的測試
      _clearLogs();
      _addLog("開始載入 API 配置...");

      // 嘗試從 JSON 檔案讀取端點配置
      final jsonString = await rootBundle.loadString('lib/shared/config/api/wifi.json');
      _addLog("成功讀取 JSON 配置文件");

      // 嘗試解析 JSON
      final config = json.decode(jsonString);
      _addLog("成功解析 JSON 數據");

      // 確保配置中包含 endpoints
      if (!config.containsKey('endpoints')) {
        throw Exception("配置中缺少 'endpoints' 字段");
      }

      // 提取端點名稱和完整配置
      final endpointsMap = config['endpoints'] as Map<String, dynamic>;
      _addLog("找到 ${endpointsMap.length} 個 API 端點");

      // 更新 WifiApiService 的配置
      if (config.containsKey('baseUrl')) {
        WifiApiService.baseUrl = config['baseUrl'];
        _addLog("設置 baseUrl: ${config['baseUrl']}");
      }

      // 更新狀態
      setState(() {
        apiConfig = config;
        endpoints = endpointsMap.keys.toList();
        isLoading = false;
        _updateStatus("已載入 ${endpoints.length} 個 API 端點");

        // 如果有端點，自動選擇第一個
        if (endpoints.isNotEmpty) {
          selectedEndpoint = endpoints.first;
          selectedMethod = endpointsMap[selectedEndpoint]['method'] ?? 'get';
        }
      });

      // 打印端點詳情
      _addLog("可用的 API 端點:");
      for (var endpoint in endpoints) {
        var method = endpointsMap[endpoint]['method'] ?? 'get';
        var path = endpointsMap[endpoint]['path'] ?? '';
        var desc = endpointsMap[endpoint]['description'] ?? '';

        _addLog("- $endpoint: [$method] $path ($desc)");
      }
    } catch (e) {
      _addLog("載入 API 端點錯誤: $e");
      setState(() {
        isLoading = false;
        _updateStatus("載入 API 端點失敗");
      });
    }
  }

// API 測試區域 UI - 修復版
  Widget _buildApiTestSection() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 標題和載入按鈕
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'API 測試',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: '重新載入 API 配置',
                  onPressed: isLoading ? null : _loadApiEndpoints,
                ),
              ],
            ),

            // 顯示當前 API 端點數量
            Text(
              '已載入 ${endpoints.length} 個端點',
              style: TextStyle(
                color: endpoints.isEmpty ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // 端點選擇下拉框
            endpoints.isEmpty
                ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '未載入任何 API 端點，請點擊重新載入',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: isLoading ? null : _loadApiEndpoints,
                    child: const Text('載入'),
                  ),
                ],
              ),
            )
                : DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: '選擇 API 端點',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.api),
              ),
              value: selectedEndpoint,
              items: endpoints.map((endpoint) {
                // 從配置中獲取方法和描述信息
                String method = '';
                String description = '';
                if (apiConfig.containsKey('endpoints')) {
                  final endpointsMap = apiConfig['endpoints'] as Map<String, dynamic>;
                  if (endpointsMap.containsKey(endpoint) && endpointsMap[endpoint] is Map<String, dynamic>) {
                    method = endpointsMap[endpoint]['method'] ?? '';
                    description = endpointsMap[endpoint]['description'] ?? '';
                  }
                }

                // 顯示方法和描述
                String displayText = endpoint;
                if (method.isNotEmpty) {
                  displayText = '[$method] $displayText';
                }
                if (description.isNotEmpty) {
                  displayText = '$displayText - $description';
                }

                return DropdownMenuItem<String>(
                  value: endpoint,
                  child: Text(displayText, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedEndpoint = value;
                  // 更新選中的方法
                  if (value != null && apiConfig.containsKey('endpoints')) {
                    final endpointsMap = apiConfig['endpoints'] as Map<String, dynamic>;
                    if (endpointsMap.containsKey(value)) {
                      selectedMethod = endpointsMap[value]['method'] ?? 'get';
                    }
                  }
                });
              },
            ),
            const SizedBox(height: 16),

            // 顯示選中的 API 詳情（如果有選中的端點）
            if (selectedEndpoint != null && apiConfig.containsKey('endpoints'))
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('選中的 API: $selectedEndpoint',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                        '方法: ${apiConfig['endpoints'][selectedEndpoint]['method'] ?? 'get'}'),
                    Text(
                        '路徑: ${apiConfig['endpoints'][selectedEndpoint]['path'] ?? ''}'),
                    if (apiConfig['endpoints'][selectedEndpoint]
                        .containsKey('description'))
                      Text(
                          '描述: ${apiConfig['endpoints'][selectedEndpoint]['description']}'),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // 執行按鈕
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (isLoading || selectedEndpoint == null || endpoints.isEmpty)
                    ? null
                    : _callSelectedApi,
                icon: const Icon(Icons.send),
                label: const Text('執行 API 請求'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 獲取系統資訊
  Future<void> _getSystemInfo() async {
    setState(() {
      isLoading = true;
      _updateStatus("獲取系統資訊中...");
    });

    try {
      final systemInfo = await WifiApiService.getSystemInfo();
      _addLog("系統資訊: ${json.encode(systemInfo)}");

      setState(() {
        isLoading = false;
        _updateStatus("成功獲取系統資訊");
      });
    } catch (e) {
      _addLog("獲取系統資訊錯誤: $e");
      setState(() {
        isLoading = false;
        _updateStatus("獲取系統資訊失敗");
      });
    }
  }

  // 計算初始密碼
  Future<void> _calculatePassword() async {
    if (_ssidController.text.isEmpty) {
      _addLog("錯誤: SSID 不能為空");
      _updateStatus("SSID 不能為空");
      return;
    }

    setState(() {
      isLoading = true;
      _updateStatus("計算初始密碼中...");
    });

    try {
      final password = await WifiApiService.calculateInitialPassword(
        providedSSID: _ssidController.text,
      );

      _addLog("計算的初始密碼: $password");
      setState(() {
        _passwordController.text = password;
        isLoading = false;
        _updateStatus("成功計算初始密碼");
      });
    } catch (e) {
      _addLog("計算初始密碼錯誤: $e");
      setState(() {
        isLoading = false;
        _updateStatus("計算初始密碼失敗");
      });
    }
  }

  // 使用初始密碼登入
  Future<void> _loginWithPassword() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      _addLog("錯誤: 用戶名或密碼不能為空");
      _updateStatus("用戶名或密碼不能為空");
      return;
    }

    setState(() {
      isLoading = true;
      _updateStatus("嘗試使用密碼登入中...");
    });

    try {
      // 構建登入數據
      Map<String, dynamic> loginData = {
        'user': _usernameController.text,
        'password': _passwordController.text,
      };

      // 發送登入請求
      final response = await WifiApiService.call('postUserLogin', loginData);
      _addLog("登入響應: ${json.encode(response)}");

      // 檢查登入結果
      if (response.containsKey('token') || response.containsKey('jwt')) {
        String token = response.containsKey('token') ? response['token'] : response['jwt'];
        setState(() {
          jwtToken = token;
          isAuthenticated = true;
          _updateStatus("登入成功！獲取到 JWT 令牌");
        });
        _addLog("JWT 令牌: $token");
        WifiApiService.setJwtToken(token);
      } else if (response.containsKey('status') && response['status'] == 'success') {
        setState(() {
          isAuthenticated = true;
          _updateStatus("登入成功！未獲取到 JWT 令牌");
        });
      } else {
        _addLog("登入失敗: ${json.encode(response)}");
        _updateStatus("登入失敗");
      }
    } catch (e) {
      _addLog("登入錯誤: $e");
      _updateStatus("登入請求錯誤");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loginWithSRP() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      _addLog("錯誤: 用戶名或密碼不能為空");
      _updateStatus("用戶名或密碼不能為空");
      return;
    }

    setState(() {
      isLoading = true;
      _updateStatus("嘗試使用 SRP 方法登入中...");
    });

    try {
      // 使用 SRP 登入
      final result = await WifiApiService.loginWithSRP(
          _usernameController.text,
          _passwordController.text
      );

      _addLog("SRP 登入結果: ${result.message}");

      if (result.success) {  // 現在使用 success 而非 returnStatus
        setState(() {
          sessionId = result.sessionId;
          csrfToken = result.csrfToken;
          jwtToken = result.jwtToken;
          isAuthenticated = true;
          _updateStatus("SRP 登入成功");
        });

        _addLog("會話 ID: $sessionId");
        _addLog("CSRF 令牌: $csrfToken");

        if (jwtToken != null && jwtToken!.isNotEmpty) {
          _addLog("JWT 令牌: $jwtToken");
          WifiApiService.setJwtToken(jwtToken!);
        }
      } else {
        _updateStatus("SRP 登入失敗");
      }
    } catch (e) {
      _addLog("SRP 登入錯誤: $e");
      _updateStatus("SRP 登入請求錯誤");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // 執行首次登入流程
  Future<void> _performFirstLogin() async {
    setState(() {
      isLoading = true;
      _updateStatus("執行首次登入流程中...");
    });

    try {
      final ssid = _ssidController.text.isNotEmpty ? _ssidController.text : null;

      FirstLoginResult result = await WifiApiService.performFirstLogin(
        providedSSID: ssid,
        username: _usernameController.text.isNotEmpty ? _usernameController.text : 'admin',
      );

      _addLog("首次登入結果: ${result.message}");

      if (result.success) {
        setState(() {
          jwtToken = result.jwtToken;
          isAuthenticated = true;
          _updateStatus("首次登入成功");
        });

        if (result.calculatedPassword != null) {
          setState(() {
            _passwordController.text = result.calculatedPassword!;
          });
          _addLog("計算的密碼: ${result.calculatedPassword}");
        }

        if (result.jwtToken != null && result.jwtToken!.isNotEmpty) {
          _addLog("JWT 令牌: ${result.jwtToken}");
        }
      } else {
        _updateStatus("首次登入失敗");
      }
    } catch (e) {
      _addLog("首次登入錯誤: $e");
      _updateStatus("首次登入請求錯誤");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // 構建適當的 API 函數名稱
  String _buildApiMethodName(String endpoint, String method) {
    // 例如: 將 "wanEthGet" 轉換為 "getWanEth"
    String methodName = '';

    if (endpoint.endsWith('Get')) {
      // 處理 wanEthGet -> getWanEth
      String baseName = endpoint.substring(0, endpoint.length - 3);
      methodName = 'get${_capitalizeFirstLetter(baseName)}';
    } else if (endpoint.endsWith('Update')) {
      // 處理 wanEthUpdate -> updateWanEth
      String baseName = endpoint.substring(0, endpoint.length - 6);
      methodName = 'update${_capitalizeFirstLetter(baseName)}';
    } else {
      // 使用標準格式: get/post/update + Endpoint
      String prefix = method.toLowerCase() == 'get' ? 'get' :
      method.toLowerCase() == 'post' ? 'post' :
      method.toLowerCase() == 'put' ? 'update' :
      method.toLowerCase() == 'delete' ? 'delete' : 'get';

      methodName = '$prefix${_capitalizeFirstLetter(endpoint)}';
    }

    return methodName;
  }

  // 首字母大寫
  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  // 執行 API 請求 - 最終版
  Future<void> _callSelectedApi() async {
    if (selectedEndpoint == null) {
      _addLog("錯誤: 未選擇 API 端點");
      _updateStatus("請選擇一個 API 端點");
      return;
    }

    setState(() {
      isLoading = true;
      _updateStatus("呼叫 API: $selectedEndpoint");
    });

    try {
      // 從配置中獲取 API 方法
      final endpointsMap = apiConfig['endpoints'] as Map<String, dynamic>;
      final endpointConfig = endpointsMap[selectedEndpoint];
      String method = endpointConfig['method'] ?? 'get';
      String path = endpointConfig['path'] ?? '';
      String description = endpointConfig['description'] ?? '';

      // 去除路徑中的變量替換
      path = path.replaceAll('\$apiVersion', apiConfig['apiVersion'] ?? '/api/v1');

      _addLog("準備呼叫 API - 端點: $selectedEndpoint");
      _addLog("HTTP方法: $method, 路徑: $path");
      _addLog("描述: $description");

      // 根據端點名稱和方法確定對應的 WifiApiService 方法名
      String? methodName;

      // 直接映射表 - 基於 wifi.json 中的定義
      Map<String, String> mappings = {
        'systemInfo': 'getSystemInfo',
        'systemMeshTopology': 'getSystemMeshTopology',
        'wizardStart': 'postWizardStart',
        'wizardFinish': 'postWizardFinish',
        'wanEthGet': 'getWanEth',
        'wanEthUpdate': 'updateWanEth',
        'wirelessBasicGet': 'getWirelessBasic',
        'wirelessBasicUpdate': 'updateWirelessBasic',
        'userChangePassword': 'updateUserChangePassword',
        'userLogin': 'postUserLogin'
      };

      // 從映射表中獲取方法名
      methodName = mappings[selectedEndpoint];

      // 如果找不到映射，則使用通用規則
      if (methodName == null) {
        String prefix = method.toLowerCase() == 'get' ? 'get' :
        method.toLowerCase() == 'post' ? 'post' :
        method.toLowerCase() == 'put' ? 'update' :
        method.toLowerCase() == 'delete' ? 'delete' : 'get';

        methodName = '$prefix${_capitalizeFirstLetter(selectedEndpoint!)}';
      }

      _addLog("使用 WifiApiService 方法名: $methodName");

      // 準備調用參數
      Map<String, dynamic>? params;
      if (method.toLowerCase() == 'post' || method.toLowerCase() == 'put') {
        // 打開對話框讓用戶輸入 JSON 參數
        params = await _promptForJsonParams();
        if (params == null) {
          _addLog("用戶取消了操作");
          setState(() {
            isLoading = false;
            _updateStatus("API 呼叫已取消");
          });
          return;
        }
      }

      // 呼叫 API
      _addLog("開始執行 API 呼叫...");

      final response = params != null
          ? await WifiApiService.call(methodName, params)
          : await WifiApiService.call(methodName);

      _addLog("API 呼叫成功");
      _addLog("響應內容: ${json.encode(response)}");

      setState(() {
        isLoading = false;
        _updateStatus("API 呼叫成功");
      });
    } catch (e) {
      _addLog("API 呼叫錯誤: $e");
      setState(() {
        isLoading = false;
        _updateStatus("API 呼叫失敗");
      });
    }
  }

// 提示用戶輸入 JSON 參數
  Future<Map<String, dynamic>?> _promptForJsonParams() async {
    String jsonStr = '{}';
    bool isValidJson = true;
    String errorMessage = '';

    return await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('輸入 API 參數 (JSON 格式)'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: '{ "key": "value" }',
                      errorText: isValidJson ? null : errorMessage,
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 5,
                    onChanged: (value) {
                      jsonStr = value;
                      try {
                        if (value.trim().isNotEmpty) {
                          json.decode(value);
                        }
                        setState(() {
                          isValidJson = true;
                          errorMessage = '';
                        });
                      } catch (e) {
                        setState(() {
                          isValidJson = false;
                          errorMessage = '無效的 JSON 格式';
                        });
                      }
                    },
                  ),
                  if (!isValidJson)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      child: Text(
                        errorMessage,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(null);
                  },
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: isValidJson
                      ? () {
                    try {
                      Map<String, dynamic> params = jsonStr.trim().isEmpty
                          ? {}
                          : json.decode(jsonStr);
                      Navigator.of(context).pop(params);
                    } catch (e) {
                      setState(() {
                        isValidJson = false;
                        errorMessage = '無效的 JSON 格式: $e';
                      });
                    }
                  }
                      : null,
                  child: const Text('確定'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 清除日誌
  void _clearLogs() {
    setState(() {
      logs = [];
    });
    _addLog("日誌已清除");
  }

  // 登出
  void _logout() {
    setState(() {
      jwtToken = null;
      sessionId = null;
      csrfToken = null;
      isAuthenticated = false;
      _updateStatus("已登出");
    });
    WifiApiService.setJwtToken('');
    _addLog("已清除身份驗證信息");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WiFi API 測試平台'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : _loadApiEndpoints,
            tooltip: '重新載入端點',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearLogs,
            tooltip: '清除日誌',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 狀態卡片
              Card(
                elevation: 3,
                color: isAuthenticated ? Colors.green[100] : Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        isAuthenticated ? Icons.verified_user : Icons.info,
                        size: 40,
                        color: isAuthenticated ? Colors.green : Colors.blue,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        statusMessage,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isAuthenticated ? Colors.green[800] : Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (isAuthenticated) ...[
                        const SizedBox(height: 8),
                        Text(
                          '已登入',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[800],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _logout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('登出'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 認證區域
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '登入測試',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: '用戶名',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: '密碼',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy),
                            tooltip: '複製密碼',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _passwordController.text));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('密碼已複製到剪貼板')),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _ssidController,
                        decoration: InputDecoration(
                          labelText: 'SSID (用於密碼計算)',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.wifi),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                tooltip: '獲取當前 WiFi SSID',
                                onPressed: _getCurrentWifiSSID,
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                tooltip: '手動設置 SSID',
                                onPressed: _setCustomSSID,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isLoading ? null : _calculatePassword,
                              icon: const Icon(Icons.calculate),
                              label: const Text('計算密碼'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isLoading ? null : _getSystemInfo,
                              icon: const Icon(Icons.info),
                              label: const Text('獲取系統資訊'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isLoading ? null : _loginWithPassword,
                              icon: const Icon(Icons.login),
                              label: const Text('標準登入'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isLoading ? null : _loginWithSRP,
                              icon: const Icon(Icons.security),
                              label: const Text('SRP 登入'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isLoading ? null : _performFirstLogin,
                          icon: const Icon(Icons.vpn_key),
                          label: const Text('執行首次登入流程'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[800],
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // API 測試區域
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'API 測試',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: '選擇 API 端點',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.api),
                        ),
                        value: selectedEndpoint,
                        items: endpoints.map((endpoint) {
                          // 從配置中獲取方法和描述信息
                          String method = '';
                          String description = '';
                          if (apiConfig.containsKey('endpoints')) {
                            final endpointsMap = apiConfig['endpoints'] as Map<String, dynamic>;
                            if (endpointsMap.containsKey(endpoint) && endpointsMap[endpoint] is Map<String, dynamic>) {
                              method = endpointsMap[endpoint]['method'] ?? '';
                              description = endpointsMap[endpoint]['description'] ?? '';
                            }
                          }

                          // 顯示方法和描述
                          String displayText = endpoint;
                          if (method.isNotEmpty) {
                            displayText = '[$method] $displayText';
                          }
                          if (description.isNotEmpty) {
                            displayText = '$displayText - $description';
                          }

                          return DropdownMenuItem<String>(
                            value: endpoint,
                            child: Text(displayText, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedEndpoint = value;
                            // 更新選中的方法
                            if (value != null && apiConfig.containsKey('endpoints')) {
                              final endpointsMap = apiConfig['endpoints'] as Map<String, dynamic>;
                              if (endpointsMap.containsKey(value)) {
                                selectedMethod = endpointsMap[value]['method'] ?? 'get';
                              }
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: (isLoading || selectedEndpoint == null) ? null : _callSelectedApi,
                          icon: const Icon(Icons.send),
                          label: const Text('執行 API 請求'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 日誌區域
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '測試日誌',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _clearLogs,
                            tooltip: '清除日誌',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 300,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: logs.length,
                            itemBuilder: (context, index) {
                              return Text(
                                logs[index],
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}