import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:hex/hex.dart';
import 'package:convert/convert.dart';

/// SRP 協議幫助類
/// 實現 SRP-6a 協議，用於安全遠程密碼認證
class SrpHelper {
  // SRP 參數
  static final BigInt N = BigInt.parse(
    'EEAF0AB9ADB38DD69C33F80AFA8FC5E86072618775FF3C0B9EA2314C9C256576D674DF7496EA81D3383B4813D692C6E0E0D5D8E250B98BE48E495C1D6089DAD15DC7D7B46154D6B6CE8EF4AD69B15D4982559B297BCF1885C529F566660E57EC68EDBC3C05726CC02FD4CBF4976EAA9AFD5138FE8376435B9FC61D2FC0EB06E3',
    radix: 16,
  );
  static final BigInt g = BigInt.from(2);
  static final BigInt k = BigInt.from(3);

  // 生成 SRP 密鑰
  static Map<String, String> generateKeys(String username, String password) {
    // 生成隨機私鑰 a
    final a = _generateRandomBigInt(32);

    // 計算公鑰 A = g^a % N
    final A = g.modPow(a, N);

    return {
      'privateKey': a.toRadixString(16),
      'publicKey': A.toRadixString(16),
    };
  }

  // 生成 SRP 客戶端證明 M1
  static String calculateM1(
      String username,
      String password,
      String salt,
      String clientPublicKey,
      String serverPublicKey,
      String privateKey
      ) {
    try {
      // 轉換輸入為 BigInt
      final BigInt s = BigInt.parse(salt, radix: 16);
      final BigInt A = BigInt.parse(clientPublicKey, radix: 16);
      final BigInt B = BigInt.parse(serverPublicKey, radix: 16);
      final BigInt a = BigInt.parse(privateKey, radix: 16);

      // 檢查 B 不為 0
      if (B % N == BigInt.zero) {
        throw Exception('無效的伺服器公鑰 B');
      }

      // 計算 u = H(A | B)
      final uHash = sha1.convert(
          utf8.encode(
              _padLeftZeros(A.toRadixString(16)) +
                  _padLeftZeros(B.toRadixString(16))
          )
      );
      final BigInt u = BigInt.parse(uHash.toString(), radix: 16);

      // 計算 x = H(s | H(I | ":" | P))
      final usernamePasswordHash = sha1.convert(
          utf8.encode('$username:$password')
      ).toString();

      final xHash = sha1.convert(
          utf8.encode(
              _padLeftZeros(s.toRadixString(16)) +
                  usernamePasswordHash
          )
      );
      final BigInt x = BigInt.parse(xHash.toString(), radix: 16);

      // 計算 v = g^x % N
      final BigInt v = g.modPow(x, N);

      // 計算 S = (B - k * g^x) ^ (a + u * x) % N
      final BigInt kgx = (k * v) % N;
      BigInt S;
      if (B > kgx) {
        S = (B - kgx).modPow(a + u * x, N);
      } else {
        S = (B + N - kgx).modPow(a + u * x, N);
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
    } catch (e) {
      print('計算 M1 時出錯: $e');
      rethrow;
    }
  }

  // 生成隨機 BigInt
  static BigInt _generateRandomBigInt(int bytes) {
    final random = Random.secure();
    final randomBytes = List<int>.generate(
        bytes, (_) => random.nextInt(256)
    );
    return BigInt.parse(hex.encode(randomBytes), radix: 16);
  }

  // 左填充零，確保十六進制字符串長度為偶數
  static String _padLeftZeros(String hexString) {
    return hexString.length % 2 == 1 ? '0$hexString' : hexString;
  }
}