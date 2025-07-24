// lib/shared/utils/platform_helper.dart
import 'dart:io';

/// 平台相容性工具類
class PlatformHelper {
  /// 是否為 iOS 平台
  static bool get isIOS => Platform.isIOS;

  /// 是否為 Android 平台
  static bool get isAndroid => Platform.isAndroid;

  /// 是否支援 WiFi 掃描功能
  /// iOS 不支援第三方 WiFi 掃描
  static bool get supportsWifiScanning => Platform.isAndroid;
}