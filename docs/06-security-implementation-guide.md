# 安全機制實現指南 - Wi-Fi 5G IOT APP

本文檔詳細介紹框架中的安全機制實現方式，包括初始密碼計算、SRP登入流程、JWT身份驗證和其他重要的安全特性。

## 安全架構概述

本框架的安全架構設計考慮到IoT設備的特殊安全需求，主要包括以下幾個方面：

1. **初始密碼安全機制** - 基於設備序號和鹽值的密碼生成
2. **SRP登入協議** - 提供零知識證明的安全登入
3. **JWT身份驗證** - 基於令牌的API訪問授權
4. **安全數據傳輸** - 加密通訊確保數據安全

![安全架構圖](https://i.imgur.com/nY5wG3D.png)

## 初始密碼計算機制

設備在初始化階段需要一個安全的方式計算初始密碼。本框架使用基於設備序號、登入鹽值和SSID的HMAC-SHA256算法來生成安全的初始密碼。

### 計算流程

1. 根據設備序號計算組合編號
2. 根據組合編號選擇預設HMAC密鑰
3. 使用選定的密鑰、設備鹽值和SSID生成HMAC-SHA256

```dart
// 計算組合編號
int _calculateCombinationIndex(String serialNumber) {
  // 計算序號的SHA256
  Digest digest = sha256.convert(utf8.encode(serialNumber));
  String hexDigest = digest.toString();
  
  // 取最後一個字節
  String lastByte = hexDigest.substring(hexDigest.length - 2);
  int lastByteValue = int.parse(lastByte, radix: 16);
  
  // 對 6 取餘
  return lastByteValue % 6;
}

// 計算初始密碼
Future<String> calculateInitialPassword({
  String? providedSSID,
  String? serialNumber,
  String? loginSalt,
}) async {
  // 獲取必要參數
  String ssid = providedSSID ?? await getCurrentSSID() ?? 'DEFAULT_SSID';
  String serial = serialNumber ?? (await getSystemInfo())['serial_number'];
  String salt = loginSalt ?? (await getSystemInfo())['login_salt'];
  
  // 計算組合編號
  int combinationIndex = _calculateCombinationIndex(serial);
  
  // 選擇預設HMAC密鑰
  String defaultHash = DEFAULT_HASHES[combinationIndex];
  
  // 生成消息（根據組合編號決定排列順序）
  String message = salt + ssid;  // 實際組合方式依賴於特定實現
  
  // 計算HMAC-SHA256
  List<int> keyBytes = utf8.encode(defaultHash);
  List<int> messageBytes = utf8.encode(message);
  Hmac hmacSha256 = Hmac(sha256, keyBytes);
  Digest digest = hmacSha256.convert(messageBytes);
  
  return digest.toString();
}
```

### 安全考慮

1. **組合的唯一性** - 設備序號和鹽值的組合確保每個設備的密碼唯一
2. **不可預測性** - HMAC-SHA256確保結果無法被猜測或反向工程
3. **離線計算** - 密碼可在設備無網絡連接時計算

## SRP (Secure Remote Password) 登入機制

本框架實現了SRP-6a版本的協議，提供零知識證明的安全認證方式，即使在不安全的網絡環境下也能保證密碼安全。

### SRP流程

1. **第一階段** - 客戶端向服務器發送用戶名和公鑰A
2. **第二階段** - 服務器返回鹽值和服務器公鑰B
3. **第三階段** - 客戶端計算並發送證明M，服務器驗證並返回確認

```dart
// SRP登入服務示例
class SrpLoginService {
  final String baseUrl;
  final String username;
  final String password;
  
  SrpLoginService({
    required this.baseUrl,
    required this.username,
    required this.password,
  });
  
  Future<SrpLoginResult> login() async {
    try {
      // 步驟 1: 獲取登入頁面，提取CSRF令牌和會話ID
      var result = await _loginStep1();
      if (!result.success) return result;
      
      String sessionId = _getSessionIDFromHeaders(result.response!.headers) ?? "";
      String csrfToken = _getCSRFToken(result.response!.body);
      
      // 步驟 2: 生成客戶端臨時密鑰對
      final clientEphemeral = _generateEphemeral();
      
      // 發送公鑰到服務器
      result = await _loginStep2(
        sessionId, 
        csrfToken, 
        clientEphemeral['public']!
      );
      if (!result.success) return result;
      
      var dataFromStep2 = result.getJson();
      
      // 獲取服務器發送的鹽值和公鑰
      String saltFromHost = dataFromStep2['s'];
      String BFromHost = dataFromStep2['B'];
      
      // 計算證明M
      final proof = _computeSrpProof(
        username: username,
        password: password,
        salt: _hexToBytes(saltFromHost),
        serverPublic: _hexToBytes(BFromHost),
        clientPublic: _hexToBytes(clientEphemeral['public']!),
        privateKey: BigInt.parse(clientEphemeral['secret']!, radix: 16)
      );
      
      // 發送證明M到服務器
      result = await _loginStep3(
        sessionId, 
        csrfToken, 
        _bytesToHex(proof)
      );
      
      return result;
    } catch (e) {
      return SrpLoginResult(
        success: false,
        message: "Login error: $e",
      );
    }
  }
  
  // 其他輔助方法...
}
```

### SRP安全優勢

1. **零知識證明** - 客戶端不需發送密碼到服務器
2. **防重放攻擊** - 每次認證使用不同的隨機值
3. **防中間人攻擊** - 相互認證機制防止中間人攻擊
4. **離線字典攻擊耐受性** - 即使獲取通訊內容也無法推導出密碼

## JWT身份驗證

成功登入後，框架使用JWT (JSON Web Token) 機制進行API授權。

### JWT處理

```dart
// 設置JWT令牌
static void setJwtToken(String token) {
  _jwtToken = token;
}

// 獲取包含JWT的Headers
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
```

### JWT使用示例

```dart
// 登入獲取JWT令牌
final loginResult = await WifiApiService.call('postUserLogin', loginData);
if (loginResult.containsKey('jwt')) {
  // 儲存JWT令牌
  WifiApiService.setJwtToken(loginResult['jwt']);
  
  // 之後的所有API請求都會自動帶上該令牌
  final wirelessSettings = await WifiApiService.call('getWirelessBasic');
}
```

## 安全最佳實踐

### 1. 密碼複雜度驗證

```dart
bool validatePassword(String password) {
  // 檢查長度
  if (password.length < 8 || password.length > 32) {
    return false;
  }
  
  // 檢查字元複雜度
  bool hasLower = password.contains(RegExp(r'[a-z]'));
  bool hasUpper = password.contains(RegExp(r'[A-Z]'));
  bool hasDigit = password.contains(RegExp(r'[0-9]'));
  bool hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
  
  return (hasLower && hasUpper && hasDigit) || 
         (hasLower && hasDigit && hasSpecial) ||
         (hasUpper && hasDigit && hasSpecial);
}
```

### 2. 敏感數據處理

```dart
// 安全地儲存敏感數據
Future<void> secureStoreCredential(String key, String value) async {
  // 使用加密儲存庫或安全鑰匙圈儲存
  // 實際實現會使用 flutter_secure_storage 等套件
}

// 從安全儲存中獲取數據
Future<String?> secureRetrieveCredential(String key) async {
  // 從加密儲存庫獲取
  // 返回解密後的值或null
}
```

### 3. API請求安全

```dart
// 添加API請求防篡改保護
Future<Map<String, dynamic>> secureAPIRequest(String endpoint, Map<String, dynamic> data) async {
  // 添加時間戳防止重放攻擊
  data['timestamp'] = DateTime.now().millisecondsSinceEpoch.toString();
  
  // 添加請求簽名
  String payload = json.encode(data);
  String signature = _calculateSignature(payload, secretKey);
  
  // 發送請求
  final response = await http.post(
    Uri.parse(endpoint),
    headers: {
      'Content-Type': 'application/json',
      'X-Signature': signature,
      'Authorization': 'Bearer $_jwtToken'
    },
    body: payload
  );
  
  // 驗證響應簽名
  String serverSignature = response.headers['X-Server-Signature'] ?? '';
  if (!_verifySignature(response.body, serverKey, serverSignature)) {
    throw SecurityException('響應簽名驗證失敗');
  }
  
  return json.decode(response.body);
}
```

## 安全威脅與對策

| 威脅類型 | 對策 |
|---------|------|
| 密碼猜測攻擊 | 強制密碼複雜度、帳戶鎖定機制 |
| 中間人攻擊 | SRP協議、HTTPS、請求簽名驗證 |
| 會話劫持 | JWT令牌、短期會話有效期 |
| 數據竊取 | 敏感數據加密儲存 |
| API濫用 | 請求限流、異常檢測 |

## 開發指南

### 1. 安全配置檢查清單

- [ ] 所有API端點使用HTTPS
- [ ] JWT令牌有合理的過期時間
- [ ] 敏感配置不直接硬編碼在源代碼中
- [ ] 調試日誌不包含敏感信息
- [ ] 使用安全的加密算法和足夠強度的密鑰

### 2. 安全測試方法

```dart
// 單元測試密碼計算
void testPasswordCalculation() {
  // 給定固定輸入
  const serialNumber = '8C16451AF919';
  const loginSalt = 'bcaab16272c7819b855755157fa679ad60cf733fbc7bfc37b883381bef31886f';
  const ssid = 'EG65BE_5G';
  
  // 預期輸出
  const expectedPassword = '4744889708859b259d7d8e695bc7b5723e834a5c81d1534bb9ab4d370198829a';
  
  // 執行計算
  final password = calculateInitialPassword(
    providedSSID: ssid,
    serialNumber: serialNumber,
    loginSalt: loginSalt
  );
  
  // 驗證結果
  assert(password == expectedPassword, '密碼計算不正確');
}
```

## 安全更新與維護

1. **定期安全審查** - 每季度進行代碼安全審查
2. **依賴庫更新** - 及時更新第三方安全庫
3. **漏洞響應** - 建立漏洞響應流程
4. **安全日誌** - 實現安全事件日誌和監控
5. **密碼輪換** - 建立密鑰和密碼定期輪換機制

## 下一步安全強化計劃

1. **生物識別整合** - 添加指紋/面部識別支持
2. **證書鑰匙固定** - 實現證書固定防止DNS劫持
3. **安全啟動檢查** - 添加啟動時的安全環境檢查
4. **應用代碼混淆** - 實現代碼混淆防止靜態分析
5. **端到端加密** - 加強敏感功能的端到端加密