// lib/shared/models/StaticIpConfig.dart
class StaticIpConfig {
  String ipAddress = '';
  String subnetMask = '';
  String gateway = '';
  String primaryDns = '';
  String secondaryDns = '';

  // 檢查必填項是否有值
  bool isValid() {
    return ipAddress.isNotEmpty &&
        subnetMask.isNotEmpty &&
        gateway.isNotEmpty &&
        primaryDns.isNotEmpty;
  }
}