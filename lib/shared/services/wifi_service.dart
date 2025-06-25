import 'package:wifi_iot/wifi_iot.dart';

class SimpleWiFiParser {
  static Map<String, String> parseWiFiQR(String qrCode) {
    try {
      // 例如: 'WIFI:S:SUPERIOR;T:WPA;P:12345678;H:false;;'
      List<String> qrCodeSplit = qrCode.split(';');

      String ssid = '';
      String password = '';

      for (String part in qrCodeSplit) {
        if (part.startsWith('S:')) {
          ssid = part.substring(2); // 移除 'S:'
        } else if (part.startsWith('P:')) {
          password = part.substring(2); // 移除 'P:'
        }
      }

      return {
        'ssid': ssid,
        'password': password,
      };
    } catch (e) {
      print('解析 QR Code 失敗: $e');
      return {'ssid': '', 'password': ''};
    }
  }

  static Future<bool> connectToWiFi(String qrCode) async {
    try {
      Map<String, String> wifiInfo = parseWiFiQR(qrCode);
      String ssid = wifiInfo['ssid'] ?? '';
      String password = wifiInfo['password'] ?? '';

      print('SSID: "$ssid"');
      print('Password: "$password"');

      if (ssid.isEmpty) {
        print('SSID 是空的');
        return false;
      }

      // 使用最簡單的連接方式
      bool connected;
      if (password.isEmpty) {
        connected = await WiFiForIoTPlugin.connect(ssid);
      } else {
        connected = await WiFiForIoTPlugin.connect(ssid, password: password);
      }

      print('連接結果: $connected');
      return connected;

    } catch (e) {
      print('連接失敗: $e');
      return false;
    }
  }
}