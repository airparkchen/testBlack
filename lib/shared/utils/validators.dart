import 'dart:io';
import 'dart:ui';

class Validators {
  static const primary = Color(0xFF346b7d);
  /// 驗證 IP 地址格式是否有效 (支持 IPv4 和 IPv6)
  bool isIpValidate(String ipAddr) {
      final parsedIp = InternetAddress.tryParse(ipAddr);
      return parsedIp != null? true : false;
  }

  /// 驗證是否為廣播 IP 地址 (僅支持 IPv4)
  bool isBroadcastIp(String ipAddr) {
    if (!isIpValidate(ipAddr)) return false;

    final parsedIp = InternetAddress(ipAddr);
    if (parsedIp.type != InternetAddressType.IPv4) return false;

    final segments = parsedIp.rawAddress;

    // 如果最後一段為 255，則是廣播地址 (IPv4)
    return segments.length == 4 && segments.last == 255;
  }

  /// 驗證是否為合法的 DNS 或 IP 地址 (支持 IPv4 和 IPv6)
  bool isValidDnsOrIp(String url) {
    // 嘗試解析是否為合法的 IP
    if (isIpValidate(url)) return true;

    // 檢查是否為合法的 DNS
    final regex = RegExp(
        r'^(?!-)[A-Za-z0-9-]{1,63}(?<!-)\.(?!-)[A-Za-z0-9-]{1,63}(?<!-)$');
    return regex.hasMatch(url);
  }

  /// 驗證兩個 IP 是否屬於同一子網 (支持 IPv4 和 IPv6)
  bool isSameSubnet(String ipAddr1, String ipAddr2, String mask) {
    if (!isIpValidate(ipAddr1) || !isIpValidate(ipAddr2) || !isIpValidate(mask)) {
      return false;
    }

    final subnet1 = _ipToBinary(ipAddr1) & _ipToBinary(mask);
    final subnet2 = _ipToBinary(ipAddr2) & _ipToBinary(mask);

    return subnet1 == subnet2;
  }

  /// 私有方法：將 IP 地址轉換為二進制格式 (支持 IPv4 和 IPv6)
  BigInt _ipToBinary(String ipAddr) {
    final segments = InternetAddress(ipAddr).rawAddress;

    // IPv6 地址有 16 個字節，IPv4 地址有 4 個字節
    return segments.fold(BigInt.zero, (previous, current) {
      return (previous << 8) | BigInt.from(current);
    });
  }

  static bool hasUpperCaseLetter(String value){
    return RegExp(r'^(?=.*[A-Z])').hasMatch(value);
  }

  static bool hasLowerCaseLetter(String value){
    return RegExp(r'^(?=.*[a-z])').hasMatch(value);
  }

  static bool hasDigit(String value){
    return RegExp(r'^(?=.*\d)').hasMatch(value);
  }

  static bool hasSpecialChar(String value){
    return RegExp(r'^(?=.*[!@#\$%^&*(),.?":{}|<>])').hasMatch(value);
  }
}