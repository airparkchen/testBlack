import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:hex/hex.dart';
import 'package:convert/convert.dart';

/// SRP 協議幫助類
/// 實現 SRP-6a 協議，用於安全遠程密碼認證
class SrpHelper {
  // SRP 參數 - RFC 5054 中定義的 1024 位元素模安全數
  static final BigInt N = BigInt.parse(
    'EEAF0AB9ADB38DD69C33F80AFA8FC5E86072618775FF3C0B9EA2314C9C256576D674DF7496EA81D3383B4813D692C6E0E0D5D8E250B98BE48E495C1D6089DAD15DC7D7B46154D6B6CE8EF4AD69B15D4982559B297BCF1885C529F566660E57EC68EDBC3C05726CC02FD4CBF4976EAA9AFD5138FE8376435B9FC61D2FC0EB06E3',
    radix: 16,
  );
  static final BigInt g = BigInt.from(2);
  static final BigInt k = BigInt.from(3);

  /// 生成 SRP 私鑰和公鑰對
  static Map<String, String> generateKeys(String username, String password) {
    // 生成隨機私鑰 a (32 字節隨機數)
    final a = _generateRandomBigInt(32);

    // 計算公鑰 A = g^a % N
    final A = g.modPow(a, N);

    return {
      'privateKey': a.toRadixString(16),  // 十六進制字符串
      'publicKey': A.toRadixString(16),   // 十六進制字符串
    };
  }

  /// 計算 SRP 客戶端證明值 M1
  static String calculateM1(
      String username,
      String password,
      String salt,
      String clientPublicKey,
      String serverPublicKey,
      String privateKey
      ) {
    // 轉換輸入為 BigInt
    final BigInt s = BigInt.parse(salt, radix: 16);
    final BigInt A = BigInt.parse(clientPublicKey, radix: 16);
    final BigInt B = BigInt.parse(serverPublicKey, radix: 16);
    final BigInt a = BigInt.parse(privateKey, radix: 16);

    // 計算 u = H(A | B)
    final uHash = sha1.convert(
        utf8.encode(
            _padLeftZeros(A.toRadixString(16)) +
                _padLeftZeros(B.toRadixString(16))
        )
    );
    final BigInt u = BigInt.parse(uHash.toString(), radix: 16);

    // 計算 x = H(s | H(I | ":" | P))
    final identityHash = sha1.convert(
        utf8.encode('$username:$password')
    ).toString();

    final xHash = sha1.convert(
        utf8.encode(
            _padLeftZeros(s.toRadixString(16)) +
                identityHash
        )
    );
    final BigInt x = BigInt.parse(xHash.toString(), radix: 16);

    // 計算 v = g^x % N
    final BigInt v = g.modPow(x, N);

    // 計算 S = (B - k * v) ^ (a + u * x) % N
    final BigInt kv = (k * v) % N;
    BigInt S;

    if (B > kv) {
      S = (B - kv).modPow(a + u * x, N);
    } else {
      // 處理溢出情況
      S = (B + N - kv).modPow(a + u * x, N);
    }

    // 計算會話密鑰 K = H(S)
    final K = sha1.convert(
        utf8.encode(_padLeftZeros(S.toRadixString(16)))
    ).toString();

    // 計算 M1 = H(A | B | K)
    final M1 = sha1.convert(
        utf8.encode(
            _padLeftZeros(A.toRadixString(16)) +
                _padLeftZeros(B.toRadixString(16)) +
                K
        )
    ).toString();

    return M1;
  }

  /// 生成隨機 BigInt
  static BigInt _generateRandomBigInt(int bytes) {
    final random = Random.secure();
    final randomBytes = List<int>.generate(
        bytes, (_) => random.nextInt(256)
    );
    return BigInt.parse(hex.encode(randomBytes), radix: 16);
  }

  /// 左填充零，確保十六進制字符串長度為偶數
  static String _padLeftZeros(String hexString) {
    return hexString.length % 2 == 1 ? '0$hexString' : hexString;
  }

  /// 使用參考代碼中的方法生成 SRP 參數
  static Map<String, dynamic> generateSrpParameters(String username, String password) {
    // 生成客戶端密鑰對
    final keys = generateKeys(username, password);
    final clientPrivateKey = keys['privateKey']!;
    final clientPublicKey = keys['publicKey']!;

    return {
      'username': username,
      'password': password,
      'clientPrivateKey': clientPrivateKey,
      'clientPublicKey': clientPublicKey,
    };
  }

  /// 從伺服器回應處理 SRP 會話，計算證明值
  static String calculateProof(
      String username,
      String password,
      String salt,
      String serverPublicKey,
      String clientPrivateKey,
      String clientPublicKey
      ) {
    return calculateM1(
        username,
        password,
        salt,
        clientPublicKey,
        serverPublicKey,
        clientPrivateKey
    );
  }
}