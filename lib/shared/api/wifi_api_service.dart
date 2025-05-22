// lib/shared/api/wifi_api_service.dart
// 簡化後的 WiFi API 服務，引入資料夾內的功能

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:srp/client.dart' as client;

// 引入 wifi_api 資料夾內的功能
import 'wifi_api/login_process.dart';
import 'wifi_api/password_service.dart';

// 保留原本的結果類
class FirstLoginResult {
  final bool success;
  final String message;
  final String? sessionId;
  final String? csrfToken;
  final String? jwtToken;
  final String? calculatedPassword;
  final Map<String, dynamic>? systemInfo;
  final Map<String, dynamic>? loginResponse;

  FirstLoginResult({
    required this.success,
    required this.message,
    this.sessionId,
    this.csrfToken,
    this.jwtToken,
    this.calculatedPassword,
    this.systemInfo,
    this.loginResponse,
  });
}

/// SRP 登入結果類
class SrpLoginResult {
  final bool success;
  final String message;
  final String? sessionId;
  final String? csrfToken;
  final String? jwtToken;

  SrpLoginResult({
    required this.success,
    required this.message,
    this.sessionId,
    this.csrfToken,
    this.jwtToken,
  });

  // 從 LoginResult 創建 SrpLoginResult
  factory SrpLoginResult.fromLoginResult(LoginResult result) {
    return SrpLoginResult(
      success: result.returnStatus,
      message: result.msg,
      sessionId: result.session.sessionId,
      csrfToken: result.session.csrfToken,
      jwtToken: result.session.jwtToken,
    );
  }
}

/// WiFi API 服務類 - 簡化版
class WifiApiService {
  // API 相關設定
  static String baseUrl = 'http://192.168.1.1';
  static String apiVersion = '/api/v1';

  // JWT Token 儲存
  static String? _jwtToken;

// 在 WifiApiService 類中修改端點映射
  static final Map<String, String> _endpoints = {
    'systemInfo': '/api/v1/system/info',
    'networkStatus': '/api/v1/network/status',
    'wirelessBasic': '/api/v1/wireless/basic',
    'wanEth': '/api/v1/network/wan_eth',
    'userLogin': '/api/v1/user/login',
    // 使用確定存在的端點 - 修改為 "wizard/start" 而不是 "/wizard/start"
    'wizardStart': '/api/v1/wizard/start',
    'wizardFinish': '/api/v1/wizard/finish',
    'wizardChangePassword': '/api/v1/user/change_password',
  };

// 確保動態方法映射正確
  static final Map<String, Function> _dynamicMethods = {
    'getSystemInfo': () => _get(_endpoints['systemInfo'] ?? ''),
    'getNetworkStatus': () => _get(_endpoints['networkStatus'] ?? ''),
    'getWirelessBasic': () => _get(_endpoints['wirelessBasic'] ?? ''),
    'getWanEth': () => _get(_endpoints['wanEth'] ?? ''),
    'postWizardStart': () => _post(_endpoints['wizardStart'] ?? '', {}),
    'postWizardFinish': () => _post(_endpoints['wizardFinish'] ?? '', {}),
    'postUserLogin': (data) => _post(_endpoints['userLogin'] ?? '', data),
    'updateWirelessBasic': (data) => _put(_endpoints['wirelessBasic'] ?? '', data),
    'updateWanEth': (data) => _put(_endpoints['wanEth'] ?? '', data),
    'updateWizardChangePassword': (data) => _put(_endpoints['wizardChangePassword'] ?? '', data),
  };
  /// 設置 JWT Token
  static void setJwtToken(String token) {
    _jwtToken = token;
  }

  /// 獲取 JWT Token
  static String? getJwtToken() {
    return _jwtToken;
  }

  /// 獲取標準請求標頭
  static Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (_jwtToken != null && _jwtToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_jwtToken';
    }

    return headers;
  }

  /// 發送 GET 請求（安全版本）
  static Future<Map<String, dynamic>> _get(String endpoint) async {
    try {
      if (endpoint.isEmpty) {
        print('GET 請求錯誤: 端點為空');
        return {'error': '端點為空'};
      }

      print('發送 GET 請求到 $endpoint');

      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(),
      );

      print('GET 請求響應狀態碼: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          if (response.body.isEmpty) return {};
          return json.decode(response.body);
        } catch (e) {
          print('解析 GET 響應JSON時出錯: $e');
          return {'error': '解析JSON失敗'};
        }
      } else {
        print('GET 請求失敗: ${response.statusCode}');
        return {'error': '請求失敗，狀態碼: ${response.statusCode}'};
      }
    } catch (e) {
      print('GET 請求錯誤: $e');
      return {'error': '$e'};
    }
  }

  /// 發送 POST 請求（增強版）
  static Future<Map<String, dynamic>> _post(String endpoint, Map<String, dynamic> data) async {
    try {
      if (endpoint.isEmpty) {
        print('POST 請求錯誤: 端點為空');
        return {'error': '端點為空'};
      }

      final headers = _getHeaders();

      // 檢查 JWT 令牌是否存在
      if (!headers.containsKey('Authorization')) {
        print('警告: 發送 POST 請求到 $endpoint 時沒有提供認證令牌');
      }

      print('發送 POST 請求到 $endpoint，數據: ${json.encode(data)}');
      print('請求標頭: $headers');

      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: json.encode(data),
      );

      print('POST 請求響應狀態碼: ${response.statusCode}');

      // 對於 4xx 錯誤，檢查是否有響應體提供更多信息
      if (response.statusCode >= 400 && response.statusCode < 500) {
        String errorBody = '無響應體';
        try {
          if (response.body.isNotEmpty) {
            errorBody = response.body;
            print('POST 請求錯誤響應體: $errorBody');
          }
        } catch (e) {
          print('解析錯誤響應時出錯: $e');
        }

        if (response.statusCode == 401 || response.statusCode == 403) {
          print('認證錯誤: JWT 令牌可能已失效');
          return {'error': '認證錯誤', 'needReAuthentication': true};
        }

        return {'error': '請求失敗，狀態碼: ${response.statusCode}', 'errorBody': errorBody};
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          if (response.body.isEmpty) return {};
          return json.decode(response.body);
        } catch (e) {
          print('解析 POST 響應JSON時出錯: $e');
          return {'error': '解析JSON失敗'};
        }
      } else {
        print('POST 請求失敗: ${response.statusCode}');
        return {'error': '請求失敗，狀態碼: ${response.statusCode}'};
      }
    } catch (e) {
      print('POST 請求錯誤: $e');
      return {'error': '$e'};
    }
  }

  /// 發送 PUT 請求（增強版）
  static Future<Map<String, dynamic>> _put(String endpoint, Map<String, dynamic> data) async {
    try {
      if (endpoint.isEmpty) {
        print('PUT 請求錯誤: 端點為空');
        return {'error': '端點為空'};
      }

      final headers = _getHeaders();

      // 檢查 JWT 令牌是否存在
      if (!headers.containsKey('Authorization')) {
        print('警告: 發送 PUT 請求到 $endpoint 時沒有提供認證令牌');
      }

      print('發送 PUT 請求到 $endpoint，數據: ${json.encode(data)}');
      print('請求標頭: $headers');

      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: json.encode(data),
      );

      print('PUT 請求響應狀態碼: ${response.statusCode}');

      // 對於 4xx 錯誤，檢查是否有響應體提供更多信息
      if (response.statusCode >= 400 && response.statusCode < 500) {
        String errorBody = '無響應體';
        try {
          if (response.body.isNotEmpty) {
            errorBody = response.body;
            print('PUT 請求錯誤響應體: $errorBody');
          }
        } catch (e) {
          print('解析錯誤響應時出錯: $e');
        }

        if (response.statusCode == 401 || response.statusCode == 403) {
          print('認證錯誤: JWT 令牌可能已失效');
          return {'error': '認證錯誤', 'needReAuthentication': true};
        }

        return {'error': '請求失敗，狀態碼: ${response.statusCode}', 'errorBody': errorBody};
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          if (response.body.isEmpty) return {};
          return json.decode(response.body);
        } catch (e) {
          print('解析 PUT 響應JSON時出錯: $e');
          return {'error': '解析JSON失敗'};
        }
      } else {
        print('PUT 請求失敗: ${response.statusCode}');
        return {'error': '請求失敗，狀態碼: ${response.statusCode}'};
      }
    } catch (e) {
      print('PUT 請求錯誤: $e');
      return {'error': '$e'};
    }
  }

  /// 動態調用方法 - 保留原有的 call 功能
  static Future<Map<String, dynamic>> call(String methodName, [dynamic params]) async {
    if (!_dynamicMethods.containsKey(methodName)) {
      throw Exception('方法 "$methodName" 不存在');
    }

    if (params != null) {
      return await _dynamicMethods[methodName]!(params);
    } else {
      return await _dynamicMethods[methodName]!();
    }
  }



  // ============ 簡化的 API 方法 ============

  /// 獲取系統資訊（增強錯誤處理版本）
  static Future<Map<String, dynamic>> getSystemInfo() async {
    try {
      // 先檢查連接
      if (!await _isApiReachable()) {
        throw Exception('Unable to connect to router. Please check network connection');
      }

      return await _get(_endpoints['systemInfo']!);
    } catch (e) {
      print('Failed to get system information: $e');

      // 提供更具體的錯誤信息
      if (e.toString().contains('Connection timed out')) {
        throw Exception('Connection to router timed out. Please check if connected to the correct WiFi network');
      } else if (e.toString().contains('Connection refused')) {
        throw Exception('Router refused connection. Please check router status');
      } else {
        throw Exception('Unable to get system information: $e');
      }
    }
  }

  /// 獲取網路狀態
  static Future<Map<String, dynamic>> getNetworkStatus() async {
    return await _get(_endpoints['networkStatus']!);
  }

  /// 獲取無線基本設定
  static Future<Map<String, dynamic>> getWirelessBasic() async {
    return await _get(_endpoints['wirelessBasic']!);
  }

  /// 更新無線基本設定
  static Future<Map<String, dynamic>> updateWirelessBasic(Map<String, dynamic> config) async {
    return await _put(_endpoints['wirelessBasic']!, config);
  }

  /// 獲取以太網廣域網路設定
  static Future<Map<String, dynamic>> getWanEth() async {
    return await _get(_endpoints['wanEth']!);
  }

  /// 更新以太網廣域網路設定
  static Future<Map<String, dynamic>> updateWanEth(Map<String, dynamic> config) async {
    return await _put(_endpoints['wanEth']!, config);
  }

  /// 開始設定
  static Future<Map<String, dynamic>> configStart() async {
    // 使用正確的鍵名 'wizardStart'，並添加空值檢查
    final endpoint = _endpoints['wizardStart'] ?? '';
    if (endpoint.isEmpty) {
      print('錯誤: wizardStart 端點未定義或為空');
      return {'error': '端點未定義'};
    }
    return await _post(endpoint, {});
  }

  /// 完成設定
  static Future<Map<String, dynamic>> configFinish() async {
    // 使用正確的鍵名 'wizardFinish'，並添加空值檢查
    final endpoint = _endpoints['wizardFinish'] ?? '';
    if (endpoint.isEmpty) {
      print('錯誤: wizardFinish 端點未定義或為空');
      return {'error': '端點未定義'};
    }
    return await _post(endpoint, {});
  }

  /// 使用 SRP 協議變更密碼
  static Future<Map<String, dynamic>> changePasswordWithSRP({
    required String username,
    required String newPassword,
  }) async {
    try {

      // 生成新的 Salt
      final newSalt = client.generateSalt();
      print('生成新的 Salt: $newSalt');

      // 根據新的 Salt 和密碼生成私鑰
      final newPrivateKey = client.derivePrivateKey(newSalt, username, newPassword);

      // 根據私鑰生成驗證器
      final newVerifier = client.deriveVerifier(newPrivateKey);
      print('生成的 Verifier: $newVerifier');

      // 準備請求數據
      final requestData = {
        'method': 'srp',
        'srp': {
          'salt': newSalt,
          'verifier': newVerifier
        }
      };

      // 發送請求到變更密碼的 API 端點
      print('發送變更密碼請求...');
      final response = await _put(_endpoints['wizardChangePassword'] ?? '/api/v1/user/change_password', requestData);

      if (response.containsKey('error')) {
        print('變更密碼失敗: ${response['error']}');
        return {
          'success': false,
          'message': '變更密碼失敗: ${response['error']}',
          'data': response
        };
      }

      print('變更密碼成功!');
      return {
        'success': true,
        'message': '密碼已成功變更',
        'data': response
      };
    } catch (e) {
      print('變更密碼過程中發生錯誤: $e');
      return {
        'success': false,
        'message': '變更密碼錯誤: $e',
        'data': null
      };
    }
  }

  /// 使用舊密碼變更新密碼
  static Future<Map<String, dynamic>> changePassword({
    required String username,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      // 確保已經登入
      if (getJwtToken() == null || getJwtToken()!.isEmpty) {
        // 先使用舊密碼登入
        final loginResult = await loginWithSRP(username, oldPassword);

        if (!loginResult.success) {
          return {
            'success': false,
            'message': '舊密碼驗證失敗，無法變更密碼',
            'data': null
          };
        }
      }

      // 使用 SRP 協議變更密碼
      return await changePasswordWithSRP(
        username: username,
        newPassword: newPassword,
      );
    } catch (e) {
      return {
        'success': false,
        'message': '變更密碼錯誤: $e',
        'data': null
      };
    }
  }

  /// 新增：快速連接測試方法
  static Future<bool> _isApiReachable() async {
    try {
      print('正在測試 API 連接...');

      // 設置較短的超時時間進行快速測試
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/system/info'),
        headers: _getHeaders(),
      ).timeout(
        const Duration(seconds: 3), // 3秒超時
        onTimeout: () {
          throw Exception('連接超時');
        },
      );

      print('API 連接測試完成，狀態碼: ${response.statusCode}');
      return response.statusCode >= 200 && response.statusCode < 500; // 包括4xx錯誤，因為至少表示服務可達

    } catch (e) {
      print('API 連接測試失敗: $e');
      return false;
    }
  }

  /// 計算初始密碼 - 使用 PasswordService（增強驗證版本）
  static Future<String> calculateInitialPassword({
    String? providedSSID,
    String? serialNumber,
    String? loginSalt,
  }) async {
    // 早期驗證 - 如果已知參數不足，立即嘗試獲取
    bool needSystemInfo = (serialNumber == null || serialNumber.isEmpty) ||
        (loginSalt == null || loginSalt.isEmpty);

    if (needSystemInfo) {
      print('缺少必要參數，嘗試獲取系統資訊...');

      // 先做一個快速的連接測試
      if (!await _isApiReachable()) {
        throw Exception('無法連接到路由器 API 服務');
      }

      try {
        final systemInfo = await getSystemInfo();

        // 檢查系統資訊是否包含必要欄位
        if (!systemInfo.containsKey('serial_number') ||
            systemInfo['serial_number'] == null ||
            systemInfo['serial_number'].toString().isEmpty) {
          throw Exception('無法從系統資訊獲取序列號');
        }

        if (!systemInfo.containsKey('login_salt') ||
            systemInfo['login_salt'] == null ||
            systemInfo['login_salt'].toString().isEmpty) {
          throw Exception('無法從系統資訊獲取登入鹽值');
        }

        serialNumber ??= systemInfo['serial_number'];
        loginSalt ??= systemInfo['login_salt'];

        print('成功從系統資訊獲取: 序列號=${serialNumber}, 登入鹽值=${loginSalt}');

      } catch (e) {
        print('獲取系統資訊失敗: $e');
        throw Exception('無法獲取計算密碼所需的系統資訊: $e');
      }
    }

    // 最終驗證所有必要參數
    if (serialNumber == null || serialNumber.isEmpty) {
      throw Exception('序列號不能為空');
    }

    if (loginSalt == null || loginSalt.isEmpty) {
      throw Exception('登入鹽值不能為空');
    }

    // 使用 PasswordService 計算初始密碼
    return PasswordService.calculateInitialPassword(
      providedSSID: providedSSID,
      serialNumber: serialNumber,
      loginSalt: loginSalt,
    );
  }

  /// 獲取當前連接的 WiFi SSID
  /// 簡化版且經過驗證可用的實現
  static Future<String> getCurrentWifiSSID() async {
    try {
      print("嘗試獲取當前連接的 WiFi SSID...");

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
          print("獲取到的是 MAC 地址而非 SSID，將使用預設 SSID");
          ssid = "DefaultSSID"; // 使用預設值代替 MAC 地址
        } else {
          print("成功獲取 SSID: $ssid");
        }
      } else {
        print("無法獲取 SSID，使用預設值");
        ssid = "DefaultSSID"; // 使用預設值
      }

      return ssid;
    } catch (e) {
      print("獲取 SSID 時出錯: $e");
      // 發生錯誤時返回預設值
      return "DefaultSSID";
    }
  }

  /// 獲取系統資訊並處理狀態訊息
  static Future<Map<String, dynamic>> getSystemInfoWithStatus() async {
    try {
      print("正在獲取系統資訊...");

      final systemInfo = await getSystemInfo();
      print("成功獲取系統資訊: ${json.encode(systemInfo)}");

      return systemInfo;
    } catch (e) {
      print("獲取系統資訊時出錯: $e");
      rethrow;
    }
  }

  /// 計算初始密碼並提供詳細日誌（增強版本）
  static Future<String> calculatePasswordWithLogs({
    String? providedSSID,
    String? serialNumber,
    String? loginSalt,
  }) async {
    // 早期 SSID 驗證
    if (providedSSID == null || providedSSID.isEmpty) {
      print("無法計算密碼: 缺少 SSID");
      throw Exception('SSID 不能為空');
    }

    try {
      print("正在計算初始密碼...");
      print("使用的 SSID: $providedSSID");

      // 檢查是否需要獲取系統資訊
      if ((serialNumber == null || serialNumber.isEmpty) ||
          (loginSalt == null || loginSalt.isEmpty)) {
        print("需要從系統獲取額外參數...");
      }

      final password = await calculateInitialPassword(
        providedSSID: providedSSID,
        serialNumber: serialNumber,
        loginSalt: loginSalt,
      );

      if (password.isEmpty) {
        throw Exception('計算出的密碼為空');
      }

      print("成功計算初始密碼");
      return password;

    } catch (e) {
      print("計算初始密碼時出錯: $e");
      rethrow; // 重新拋出異常，保持錯誤信息
    }
  }

  /// 執行完整的登入流程，包含 SRP 和傳統登入嘗試
  static Future<Map<String, dynamic>> performFullLogin({
    required String userName,
    required String calculatedPassword
  }) async {
    if (calculatedPassword.isEmpty) {
      print("無法登入: 缺少密碼");
      return {'success': false, 'message': '無法登入: 缺少密碼'};
    }

    final result = {
      'success': false,
      'message': '',
      'jwtToken': null,
      'isAuthenticated': false
    };

    try {
      print("正在使用計算出的密碼登入...");

      // 嘗試使用 SRP 登入 (更安全)
      try {
        print("嘗試 SRP 登入方式...");
        final srpResult = await loginWithSRP(
            userName,
            calculatedPassword
        );

        if (srpResult.success) {
          print("SRP 登入成功");

          result['success'] = true;
          result['message'] = 'SRP 登入成功';
          result['jwtToken'] = srpResult.jwtToken;
          result['isAuthenticated'] = true;

          return result;
        } else {
          print("SRP 登入失敗，嘗試傳統登入");
        }
      } catch (e) {
        print("SRP 登入時出錯: $e，嘗試傳統登入");
      }

      // 如果 SRP 登入失敗，嘗試使用傳統登入方式
      try {
        print("嘗試傳統登入方式...");
        final response = await loginWithInitialPassword(
          providedSSID: null, // 這裡不需要 SSID，因為已經有計算好的密碼
          username: userName,
        );

        if (response.containsKey('token') || response.containsKey('jwt')) {
          String token = response.containsKey('token') ? response['token'] : response['jwt'];
          print("傳統方式登入成功");

          result['success'] = true;
          result['message'] = '傳統方式登入成功';
          result['jwtToken'] = token;
          result['isAuthenticated'] = true;

          return result;
        } else if (response.containsKey('status') && response['status'] == 'success') {
          print("登入成功，但未獲取到令牌");

          result['success'] = true;
          result['message'] = '登入成功，但未獲取到令牌';
          result['isAuthenticated'] = true;

          return result;
        } else {
          print("登入失敗: ${json.encode(response)}");

          result['message'] = '登入失敗: ${json.encode(response)}';
          return result;
        }
      } catch (e) {
        print("傳統登入時出錯: $e");

        result['message'] = '傳統登入時出錯: $e';
        return result;
      }
    } catch (e) {
      print("執行登入操作時出錯: $e");

      result['message'] = '執行登入操作時出錯: $e';
      return result;
    }
  }
  /// 開始精靈配置（帶安全檢查）
  static Future<Map<String, dynamic>> wizardStart() async {
    try {
      final endpoint = _endpoints['wizardStart'];

      // 安全檢查，確保端點存在
      if (endpoint == null || endpoint.isEmpty) {
        print('錯誤: wizardStart 端點未定義或為空');
        return {'status_code': 'error', 'message': 'Endpoint not defined'};
      }

      print('開始精靈配置流程，調用 POST $endpoint');

      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(),
        body: json.encode({}),
      );

      print('wizardStart 請求響應狀態碼: ${response.statusCode}');

      if (response.body.isNotEmpty) {
        print('wizardStart 請求響應體: ${response.body}');
      } else {
        print('wizardStart 請求響應體為空');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          return response.body.isNotEmpty
              ? json.decode(response.body)
              : {'status_code': 'success', 'message': 'No response body'};
        } catch (e) {
          print('解析 wizardStart 響應JSON時出錯: $e');
          return {'status_code': 'error', 'message': 'Failed to parse response'};
        }
      } else {
        print('wizardStart 請求失敗，狀態碼: ${response.statusCode}');
        return {
          'status_code': 'error',
          'message': 'Request failed with status: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('執行 wizardStart 時發生錯誤: $e');
      return {'status_code': 'error', 'message': 'Exception: $e'};
    }
  }

  /// 完成精靈配置（帶安全檢查）
  static Future<Map<String, dynamic>> wizardFinish() async {
    try {
      final endpoint = _endpoints['wizardFinish'];

      // 安全檢查，確保端點存在
      if (endpoint == null || endpoint.isEmpty) {
        print('錯誤: wizardFinish 端點未定義或為空');
        return {'status_code': 'error', 'message': 'Endpoint not defined'};
      }

      print('完成精靈配置流程，調用 POST $endpoint');

      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(),
        body: json.encode({}),
      );

      print('wizardFinish 請求響應狀態碼: ${response.statusCode}');

      if (response.body.isNotEmpty) {
        print('wizardFinish 請求響應體: ${response.body}');
      } else {
        print('wizardFinish 請求響應體為空');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          return response.body.isNotEmpty
              ? json.decode(response.body)
              : {'status_code': 'success', 'message': 'No response body'};
        } catch (e) {
          print('解析 wizardFinish 響應JSON時出錯: $e');
          return {'status_code': 'error', 'message': 'Failed to parse response'};
        }
      } else if (response.statusCode == 500) {
        // 如果返回 500，可能是設備正在重啟
        print('wizardFinish 返回 500，這可能是正常的（設備正在重啟）');
        return {
          'status_code': 'reboot',
          'message': 'Device is applying settings and may reboot',
          'isRebootExpected': true
        };
      } else {
        print('wizardFinish 請求失敗，狀態碼: ${response.statusCode}');
        return {
          'status_code': 'error',
          'message': 'Request failed with status: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('執行 wizardFinish 時發生錯誤: $e');

      // 如果是連接異常，可能是設備正在重啟
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('Connection reset')) {
        print('連接異常，可能是設備正在重啟');
        return {
          'status_code': 'reboot',
          'message': 'Device appears to be rebooting',
          'isRebootExpected': true
        };
      }

      return {'status_code': 'error', 'message': 'Exception: $e'};
    }
  }
  /// 使用初始密碼登入
  static Future<Map<String, dynamic>> loginWithInitialPassword({
    String? providedSSID,
    String? serialNumber,
    String? loginSalt,
    String? username,
  }) async {
    try {
      // 計算初始密碼
      String password = await calculateInitialPassword(
        providedSSID: providedSSID,
        serialNumber: serialNumber,
        loginSalt: loginSalt,
      );

      // 如果沒有提供用戶名，嘗試從系統資訊獲取
      if (username == null) {
        final systemInfo = await getSystemInfo();
        username = systemInfo['default_user'] ?? 'admin';
      }

      // 執行登入
      Map<String, dynamic> loginData = {
        'user': username,
        'password': password,
      };

      final response = await _post(_endpoints['userLogin']!, loginData);

      // 儲存 JWT 令牌
      if (response.containsKey('token')) {
        setJwtToken(response['token']);
      } else if (response.containsKey('jwt')) {
        setJwtToken(response['jwt']);
      }

      return response;
    } catch (e) {
      print('初始密碼登入錯誤: $e');
      rethrow;
    }
  }

  /// 執行 SRP 登入流程 - 使用 LoginProcess
  static Future<SrpLoginResult> loginWithSRP(String username, String password) async {
    // 創建 LoginProcess 實例並執行登入流程
    final loginProcess = LoginProcess(username, password, baseUrl: baseUrl);
    final result = await loginProcess.startSRPLoginProcess();

    // 如果登入成功並獲取到 JWT 令牌，儲存它
    if (result.returnStatus && result.session.jwtToken != null) {
      setJwtToken(result.session.jwtToken!);
    }

    // 返回轉換後的結果
    return SrpLoginResult.fromLoginResult(result);
  }

  /// 執行完整的首次登入流程
  static Future<FirstLoginResult> performFirstLogin({
    String? providedSSID,
    String username = 'admin',
  }) async {
    try {
      // 步驟 1: 獲取系統資訊
      final systemInfo = await getSystemInfo();

      // 檢查系統資訊是否完整
      if (!systemInfo.containsKey('serial_number') || !systemInfo.containsKey('login_salt')) {
        return FirstLoginResult(
            success: false,
            message: '無法從系統資訊中獲取序列號或登入鹽值',
            systemInfo: systemInfo
        );
      }

      // 獲取必要參數
      final serialNumber = systemInfo['serial_number'];
      final loginSalt = systemInfo['login_salt'];
      final defaultUser = systemInfo['default_user'] ?? username;

      // 步驟 2: 計算初始密碼
      final password = await calculateInitialPassword(
        providedSSID: providedSSID,
        serialNumber: serialNumber,
        loginSalt: loginSalt,
      );

      // 步驟 3: 嘗試登入
      final loginData = {
        'user': defaultUser,
        'password': password,
      };

      final loginResponse = await _post(_endpoints['userLogin']!, loginData);

      // 檢查登入結果
      bool loginSuccess = false;
      String message = '登入失敗';

      if (loginResponse.containsKey('token')) {
        loginSuccess = true;
        message = '登入成功，獲取到 JWT 令牌';
        setJwtToken(loginResponse['token']);
      } else if (loginResponse.containsKey('jwt')) {
        loginSuccess = true;
        message = '登入成功，獲取到 JWT 令牌';
        setJwtToken(loginResponse['jwt']);
      } else if (loginResponse.containsKey('status') && loginResponse['status'] == 'success') {
        loginSuccess = true;
        message = '登入成功';
      }

      return FirstLoginResult(
        success: loginSuccess,
        message: message,
        jwtToken: getJwtToken(),
        calculatedPassword: password,
        systemInfo: systemInfo,
        loginResponse: loginResponse,
      );
    } catch (e) {
      return FirstLoginResult(
        success: false,
        message: '首次登入過程中發生錯誤: $e',
      );
    }
  }
}