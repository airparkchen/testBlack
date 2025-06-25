class WiFiQRParser {
  String? ssid;
  String? password;
  String? security;
  bool? hidden;

  WiFiQRParser.fromQRString(String qrString) {
    if (qrString.startsWith('WIFI:')) {
      _parseWiFiString(qrString);
    }
  }

  /// 解析 WiFi QR Code 字串格式
  /// 格式: WIFI:S:<SSID>;T:<加密類型>;P:<密碼>;H:<是否隱藏>;
  void _parseWiFiString(String wifiString) {
    try {
      // 移除 WIFI: 前綴
      String content = wifiString.substring(5);

      // 使用正則表達式解析各個字段
      // S: 表示 SSID (網路名稱)
      RegExp ssidRegex = RegExp(r'S:([^;]*);');
      // T: 表示加密類型 (WPA, WEP, nopass 等)
      RegExp securityRegex = RegExp(r'T:([^;]*);');
      // P: 表示密碼
      RegExp passwordRegex = RegExp(r'P:([^;]*);');
      // H: 表示是否為隱藏網路
      RegExp hiddenRegex = RegExp(r'H:([^;]*);');

      // 解析 SSID
      final ssidMatch = ssidRegex.firstMatch(content);
      ssid = ssidMatch?.group(1);

      // 解析加密類型
      final securityMatch = securityRegex.firstMatch(content);
      security = securityMatch?.group(1);

      // 解析密碼
      final passwordMatch = passwordRegex.firstMatch(content);
      password = passwordMatch?.group(1);

      // 解析是否隱藏
      final hiddenMatch = hiddenRegex.firstMatch(content);
      String? hiddenStr = hiddenMatch?.group(1);
      hidden = hiddenStr?.toLowerCase() == 'true';

    } catch (e) {
      print('WiFi QR 解析錯誤: $e');
    }
  }

  /// 檢查是否為有效的 WiFi QR Code
  bool get isWiFiQR => ssid != null && ssid!.isNotEmpty;

  /// 取得加密類型的顯示文字
  String get securityDisplayText {
    switch (security?.toUpperCase()) {
      case 'WPA':
        return 'WPA/WPA2';
      case 'WEP':
        return 'WEP';
      case 'NOPASS':
      case '':
        return '無密碼';
      default:
        return security ?? '未知';
    }
  }

  /// 檢查是否需要密碼
  bool get needsPassword {
    return security?.toUpperCase() != 'NOPASS' &&
        security?.isNotEmpty == true &&
        password?.isNotEmpty == true;
  }

  @override
  String toString() {
    return 'WiFiQRParser{ssid: $ssid, security: $security, hasPassword: ${password?.isNotEmpty}, hidden: $hidden}';
  }
}