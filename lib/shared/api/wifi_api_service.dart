import 'dart:convert';
import 'package:http/http.dart' as http;

/// 簡化版的 WiFi API 服務類
/// 提供基本的 HTTP 方法和常用 API 端點
class WifiApiService {
  // API 基礎 URL，可以根據環境配置更改
  static String baseUrl = 'http://192.168.1.1';

  // API 版本
  static const String apiVersion = '/api/v1';

  // HTTP 請求超時時間（秒）
  static const int timeoutSeconds = 10;

  // JWT Token，用於身份驗證
  static String? _jwtToken;

  /// 設置 JWT Token
  static void setJwtToken(String token) {
    _jwtToken = token;
  }

  /// 獲取 JWT Token
  static String? getJwtToken() {
    return _jwtToken;
  }

  /// 獲取通用的 Headers
  static Map<String, String> getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (_jwtToken != null && _jwtToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_jwtToken';
    }

    return headers;
  }

  /// 發送 GET 請求
  static Future<Map<String, dynamic>> get(String path) async {
    try {
      final url = Uri.parse('$baseUrl$path');
      final response = await http.get(
        url,
        headers: getHeaders(),
      ).timeout(Duration(seconds: timeoutSeconds));

      return _handleResponse(response);
    } catch (e) {
      print('GET 請求錯誤: $e');
      rethrow;
    }
  }

  /// 發送 POST 請求
  static Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? data}) async {
    try {
      final url = Uri.parse('$baseUrl$path');
      final response = await http.post(
        url,
        headers: getHeaders(),
        body: data != null ? json.encode(data) : null,
      ).timeout(Duration(seconds: timeoutSeconds));

      return _handleResponse(response);
    } catch (e) {
      print('POST 請求錯誤: $e');
      rethrow;
    }
  }

  /// 發送 PUT 請求
  static Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? data}) async {
    try {
      final url = Uri.parse('$baseUrl$path');
      final response = await http.put(
        url,
        headers: getHeaders(),
        body: data != null ? json.encode(data) : null,
      ).timeout(Duration(seconds: timeoutSeconds));

      return _handleResponse(response);
    } catch (e) {
      print('PUT 請求錯誤: $e');
      rethrow;
    }
  }

  /// 發送 DELETE 請求
  static Future<Map<String, dynamic>> delete(String path, {Map<String, dynamic>? data}) async {
    try {
      final url = Uri.parse('$baseUrl$path');
      final response = await http.delete(
        url,
        headers: getHeaders(),
        body: data != null ? json.encode(data) : null,
      ).timeout(Duration(seconds: timeoutSeconds));

      return _handleResponse(response);
    } catch (e) {
      print('DELETE 請求錯誤: $e');
      rethrow;
    }
  }

  /// 處理 HTTP 回應
  static Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return json.decode(response.body);
    } else {
      try {
        final errorData = json.decode(response.body);
        throw ApiException(
          statusCode: response.statusCode,
          errorCode: errorData['status_code'] ?? 'unknown',
          message: errorData['message'] ?? 'Unknown error',
        );
      } catch (e) {
        // 如果無法解析錯誤回應
        throw ApiException(
          statusCode: response.statusCode,
          errorCode: 'parse_error',
          message: 'Failed to parse error response: ${response.body}',
        );
      }
    }
  }

  // ========== API 路徑定義 ==========
  // 您可以在這裡新增更多 API 路徑

  static const String configStartPath = '$apiVersion/config/start';
  static const String configFinishPath = '$apiVersion/config/finish';
  static const String systemInfoPath = '$apiVersion/system/info';
  static const String wan5gPath = '$apiVersion/network/wan_5g';
  static const String wanEthPath = '$apiVersion/network/wan_eth';
  static const String networkStatusPath = '$apiVersion/network/status';
  static const String wirelessBasicPath = '$apiVersion/wireless/basic';
  static const String wirelessAdvancedPath = '$apiVersion/wireless/advanced';
  static const String wizardChangePasswordPath = '$apiVersion/wizard/change_password';
  static const String wizardWanEthPath = '$apiVersion/wizard/wan_eth';
  static const String userLoginPath = '$apiVersion/user/login';

  // ========== API 功能實現 ==========
  // 這些函數封裝了 API 呼叫，使用上面定義的路徑

  /// 獲取系統資訊
  static Future<Map<String, dynamic>> getSystemInfo() async {
    return await get(systemInfoPath);
  }

  /// 獲取網路狀態
  static Future<Map<String, dynamic>> getNetworkStatus() async {
    return await get(networkStatusPath);
  }

  /// 獲取無線基本設定
  static Future<Map<String, dynamic>> getWirelessBasic() async {
    return await get(wirelessBasicPath);
  }

  /// 更新無線基本設定
  static Future<Map<String, dynamic>> updateWirelessBasic(Map<String, dynamic> config) async {
    return await put(wirelessBasicPath, data: config);
  }

  /// 獲取以太網廣域網路設定
  static Future<Map<String, dynamic>> getWanEth() async {
    return await get(wanEthPath);
  }

  /// 更新以太網廣域網路設定
  static Future<Map<String, dynamic>> updateWanEth(Map<String, dynamic> config) async {
    return await put(wanEthPath, data: config);
  }

  /// 開始設定
  static Future<Map<String, dynamic>> configStart() async {
    return await post(configStartPath);
  }

  /// 完成設定
  static Future<Map<String, dynamic>> configFinish() async {
    return await post(configFinishPath);
  }

  /// 登入（SRP 方式）
  static Future<Map<String, dynamic>> login(Map<String, dynamic> loginData) async {
    return await post(userLoginPath, data: loginData);
  }

  /// 變更密碼（精靈模式）
  static Future<Map<String, dynamic>> changePassword(Map<String, dynamic> passwordData) async {
    return await put(wizardChangePasswordPath, data: passwordData);
  }
}

/// API 異常類，用於處理 API 錯誤
class ApiException implements Exception {
  final int statusCode;
  final String errorCode;
  final String message;

  ApiException({required this.statusCode, required this.errorCode, required this.message});

  @override
  String toString() => 'ApiException: [$statusCode][$errorCode] $message';
}