// lib/shared/wifi_api/services/password_service.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:flutter/foundation.dart';

/// 密碼服務類，處理初始密碼的計算
class PasswordService {
  /// 預設 Hash 數組
  static const List<String> DEFAULT_HASHES = [
    '1a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d5e6f708192a3b4c5d6e7f809',
    '9876543210abcdef9876543210abcdef9876543210abcdef9876543210abcdef',
    'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
    '7890abcdef1234567890abcdef1234567890abcdef1234567890abcdef123456',
  ];

  /// 獲取當前連接的 SSID
  static Future<String?> getCurrentSSID() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.wifi) {
        final info = NetworkInfo();
        final ssid = await info.getWifiName();

        if (ssid != null && ssid.isNotEmpty) {
          return ssid.replaceAll('"', '');
        }
      }
      return null;
    } catch (e) {
      debugPrint('獲取SSID錯誤: $e');
      return null;
    }
  }

  /// 計算組合編號
  static int calculateCombinationIndex(String serialNumber) {
    // 計算序號的 SHA256
    Digest digest = sha256.convert(utf8.encode(serialNumber));
    String hexDigest = digest.toString();
    debugPrint('序號 SHA256: $hexDigest');

    // 取最後一個字節（最後兩個字符）
    String lastByte = hexDigest.substring(hexDigest.length - 2);
    int lastByteValue = int.parse(lastByte, radix: 16);
    debugPrint('最後字節（十六進制）: $lastByte, 十進制: $lastByteValue');

    // 對 6 取餘
    int combinationIndex = lastByteValue % 6;
    debugPrint('計算的組合編號: $combinationIndex');

    return combinationIndex;
  }

  /// 十六進制字符串轉換為位元組數組
  static List<int> hexToBytes(String hex) {
    List<int> bytes = [];
    for (int i = 0; i < hex.length; i += 2) {
      if (i + 2 <= hex.length) {
        bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
      }
    }
    return bytes;
  }

  /// 計算初始密碼
  static Future<String> calculateInitialPassword({
    String? providedSSID,
    String? serialNumber,
    String? loginSalt,
  }) async {
    try {
      String ssid = providedSSID ?? '';

      // 如果沒有提供SSID，嘗試獲取當前連接的SSID
      if (providedSSID == null || providedSSID.isEmpty) {
        final currentSSID = await getCurrentSSID();
        ssid = currentSSID ?? 'UNKNOWN';
      }

      // 檢查最終的 SSID 是否為 UNKNOWN
      if (ssid.toUpperCase() == 'UNKNOWN' || ssid.toLowerCase() == 'unknown') {
        debugPrint('WiFi information unavailable due to Connection limits. Please wait and try again.');
        throw Exception('SSID_UNKNOWN_ERROR: WiFi information unavailable due to API connection limits. Please wait and try again.');
      }

      // 確保必要參數存在
      if (serialNumber == null || serialNumber.isEmpty) {
        throw ArgumentError('序列號不能為空');
      }

      if (loginSalt == null || loginSalt.isEmpty) {
        throw ArgumentError('登入鹽值不能為空');
      }

      debugPrint('使用 SSID: $ssid');
      debugPrint('使用序號: $serialNumber');
      debugPrint('使用 Salt: $loginSalt');

      // 計算組合編號
      int combinationIndex = calculateCombinationIndex(serialNumber);

      // 選擇預設 Hash 作為 HMAC Key
      String defaultHash = DEFAULT_HASHES[combinationIndex];
      debugPrint('選擇的 Hash (組合編號 $combinationIndex): $defaultHash');

      // 拆分 Salt 為前段和後段
      String saltFront = '';
      String saltBack = '';
      if (loginSalt.length >= 64) {
        saltFront = loginSalt.substring(0, 32); // 前 128 位元 (32 個十六進位字符)
        saltBack = loginSalt.substring(32);     // 後 128 位元
      } else {
        // 如果 salt 長度不足，使用全部作為前段，後段留空
        saltFront = loginSalt;
        saltBack = '';
      }

      debugPrint('Salt 前段 (前 128 位元): $saltFront');
      debugPrint('Salt 後段 (後 128 位元): $saltBack');

      // 根據組合編號生成消息
      String message = '';
      String messageDesc = '';

      switch (combinationIndex) {
        case 0:
          message = ssid + saltFront + saltBack;
          messageDesc = 'SSID + Salt 前段 + Salt 後段';
          break;
        case 1:
          message = ssid + saltBack + saltFront;
          messageDesc = 'SSID + Salt 後段 + Salt 前段';
          break;
        case 2:
          message = saltFront + ssid + saltBack;
          messageDesc = 'Salt 前段 + SSID + Salt 後段';
          break;
        case 3:
          message = saltFront + saltBack + ssid;
          messageDesc = 'Salt 前段 + Salt 後段 + SSID';
          break;
        case 4:
          message = saltBack + ssid + saltFront;
          messageDesc = 'Salt 後段 + SSID + Salt 前段';
          break;
        case 5:
          message = saltBack + saltFront + ssid;
          messageDesc = 'Salt 後段 + Salt 前段 + SSID';
          break;
        default:
        // 預設情況使用簡單的 Salt + SSID
          message = loginSalt + ssid;
          messageDesc = 'Salt + SSID (預設)';
      }

      debugPrint('消息組合方式: $messageDesc');
      debugPrint('生成的消息: $message');

      // 計算 HMAC-SHA256
      List<int> keyBytes = utf8.encode(defaultHash);
      List<int> messageBytes = utf8.encode(message);
      Hmac hmacSha256 = Hmac(sha256, keyBytes);
      Digest digest = hmacSha256.convert(messageBytes);
      String result = digest.toString();

      debugPrint('HMAC-SHA256 結果: $result');

      // 返回 HEX 格式結果
      return result;
    } catch (e) {
      debugPrint('計算初始密碼錯誤: $e');
      rethrow;
    }
  }
}