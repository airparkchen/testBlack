import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart'; // 添加加密套件
import 'package:connectivity_plus/connectivity_plus.dart'; // 添加網絡連接套件
import 'package:network_info_plus/network_info_plus.dart'; // 添加網絡資訊套件，用於獲取SSID

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

  // 預設 Hash 數組（SHA-256，以十六進位制表示）
  static const List<String> DEFAULT_HASHES = [
    '1a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d5e6f708192a3b4c5d6e7f809',
    '9876543210abcdef9876543210abcdef9876543210abcdef9876543210abcdef',
    'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
    '7890abcdef1234567890abcdef1234567890abcdef1234567890abcdef123456',
  ];

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

      // 處理特殊格式的響應（例如帶有fdsafdsafd的前綴）
      String responseBody = response.body;
      int jsonStart = responseBody.indexOf('{');
      if (jsonStart > 0) {
        responseBody = responseBody.substring(jsonStart);
      }

      return json.decode(responseBody);
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

  /// 獲取當前連接的 SSID
  static Future<String?> getCurrentSSID() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.wifi) {
        final info = NetworkInfo();
        final ssid = await info.getWifiName(); // 返回格式可能是 "\"SSID名稱\""

        if (ssid != null && ssid.isNotEmpty) {
          // 去除可能的引號
          return ssid.replaceAll('"', '');
        }
      }
      return null;
    } catch (e) {
      print('獲取SSID錯誤: $e');
      return null;
    }
  }

  /// 計算組合編號
  static int _calculateCombinationIndex(String serialNumber) {
    // 對序號計算 SHA-256
    Digest digest = sha256.convert(utf8.encode(serialNumber));
    String hexDigest = digest.toString();

    // 取最後一個位元組（最後兩個16進制字符）
    String lastByte = hexDigest.substring(hexDigest.length - 2);

    // 轉換為整數並取餘數
    int lastByteValue = int.parse(lastByte, radix: 16);
    return lastByteValue % 6;
  }

  /// 16進制字符串轉換為位元組數組
  static List<int> _hexToBytes(String hex) {
    List<int> bytes = [];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  /// 計算初始密碼
  ///
  /// 使用設備序號、登入鹽值和SSID計算初始密碼
  /// 如果沒有提供SSID，將嘗試獲取當前連接的SSID
  /// 如果無法獲取SSID，則使用設備型號作為SSID
  static Future<String> calculateInitialPassword({
    String? providedSSID, // 可選提供的SSID
    String? serialNumber, // 可選提供的序號
    String? loginSalt, // 可選提供的鹽值
  }) async {
    Map<String, dynamic> systemInfo;
    String ssid;
    String salt;
    String serial;

    try {
      // 如果沒有提供SSID，嘗試獲取當前連接的SSID
      if (providedSSID == null) {
        final currentSSID = await getCurrentSSID();

        if (currentSSID != null) {
          ssid = currentSSID;
        } else {
          // 如果無法獲取當前SSID，則從系統信息中取得設備型號作為SSID
          systemInfo = await getSystemInfo();
          ssid = systemInfo['model_name'] ?? 'UNKNOWN';
        }
      } else {
        ssid = providedSSID;
      }

      // 如果沒有提供序號或鹽值，從系統信息中獲取
      if (serialNumber == null || loginSalt == null) {
        systemInfo = await getSystemInfo();

        salt = loginSalt ?? systemInfo['login_salt'];
        serial = serialNumber ?? systemInfo['serial_number'];

        if (salt == null || serial == null) {
          throw Exception('無法獲取必要的系統信息');
        }
      } else {
        salt = loginSalt;
        serial = serialNumber;
      }

      // 計算組合編號
      int combinationIndex = _calculateCombinationIndex(serial);

      // 選擇預設 Hash 作為 HMAC Key
      String defaultHash = DEFAULT_HASHES[combinationIndex];

      // 分割 Salt
      String saltFront = salt.substring(0, 32); // 前128位（32個16進制字符）
      String saltBack = salt.substring(32);     // 後128位

      // 根據組合編號選擇 Message 組合順序
      String message = '';
      switch (combinationIndex) {
        case 0:
          message = ssid + saltFront + saltBack;
          break;
        case 1:
          message = ssid + saltBack + saltFront;
          break;
        case 2:
          message = saltFront + ssid + saltBack;
          break;
        case 3:
          message = saltFront + saltBack + ssid;
          break;
        case 4:
          message = saltBack + ssid + saltFront;
          break;
        case 5:
          message = saltBack + saltFront + ssid;
          break;
      }

      // 計算 HMAC-SHA256
      List<int> keyBytes = _hexToBytes(defaultHash);
      List<int> messageBytes = utf8.encode(message);

      Hmac hmacSha256 = Hmac(sha256, keyBytes);
      Digest digest = hmacSha256.convert(messageBytes);

      // 返回 HEX 格式結果
      return digest.toString();
    } catch (e) {
      print('計算初始密碼錯誤: $e');
      rethrow;
    }
  }

  /// 使用初始密碼登入並獲取token
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

      // 如果沒有提供用戶名，從系統信息中獲取
      String user;
      if (username == null) {
        final systemInfo = await getSystemInfo();
        user = systemInfo['default_user'] ?? 'admin';
      } else {
        user = username;
      }

      // 執行登入
      Map<String, dynamic> loginData = {
        'user': user,
        'password': password,
      };

      final response = await login(loginData);

      // 如果登入成功，保存token
      if (response.containsKey('token')) {
        setJwtToken(response['token']);
      }

      return response;
    } catch (e) {
      print('初始密碼登入錯誤: $e');
      rethrow;
    }
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