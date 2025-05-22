import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:whitebox/shared/theme/app_theme.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

// WiFi掃描元件回調函數類型
typedef OnWifiScanComplete = void Function(List<WiFiAccessPoint> devices, String? error);
typedef OnDeviceSelected = void Function(WiFiAccessPoint device);
typedef OnWifiConnectRequested = void Function(WiFiAccessPoint device);
// WiFi掃描控制器
class WifiScannerController {
  _WifiScannerComponentState? _state;

  void _registerState(_WifiScannerComponentState state) {
    _state = state;
  }

  void _unregisterState() {
    _state = null;
  }

  void startScan() {
    _state?.startScan();
  }

  List<WiFiAccessPoint> getDiscoveredDevices() {
    return _state?.discoveredDevices ?? [];
  }

  bool isScanning() {
    return _state?.isScanning ?? false;
  }
}

class WifiScannerComponent extends StatefulWidget {
  final int maxDevicesToShow;
  final OnWifiScanComplete? onScanComplete;
  final OnDeviceSelected? onDeviceSelected;
  final OnWifiConnectRequested? onConnectRequested; // 新增這行
  final bool autoScan;
  final WifiScannerController? controller;
  final double height;

  const WifiScannerComponent({
    Key? key,
    this.maxDevicesToShow = 10,
    this.onScanComplete,
    this.onDeviceSelected,
    this.onConnectRequested, // 新增這行
    this.autoScan = true,
    this.controller,
    this.height = 400,
  }) : super(key: key);

  @override
  State<WifiScannerComponent> createState() => _WifiScannerComponentState();
}

class _WifiScannerComponentState extends State<WifiScannerComponent> {
  List<WiFiAccessPoint> discoveredDevices = [];
  bool isScanning = false;
  String? errorMessage;
  bool _permissionRequested = false;

  final AppTheme _appTheme = AppTheme();

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      widget.controller!._registerState(this);
    }

    if (widget.autoScan) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        startScan();
      });
    }
  }

  @override
  void dispose() {
    if (widget.controller != null) {
      widget.controller!._unregisterState();
    }
    super.dispose();
  }

  // 檢查並請求必要權限
  Future<bool> _checkAndRequestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;

        print('Android SDK 版本: ${androidInfo.version.sdkInt}');

        // 檢查位置權限
        var locationStatus = await Permission.locationWhenInUse.status;
        print('位置權限狀態: $locationStatus');

        if (locationStatus != PermissionStatus.granted) {
          locationStatus = await Permission.locationWhenInUse.request();
          print('請求位置權限後狀態: $locationStatus');
        }

        // Android 13+ 需要額外權限
        if (androidInfo.version.sdkInt >= 33) {
          var nearbyDevicesStatus = await Permission.nearbyWifiDevices.status;
          print('附近 WiFi 設備權限狀態: $nearbyDevicesStatus');

          if (nearbyDevicesStatus != PermissionStatus.granted) {
            nearbyDevicesStatus = await Permission.nearbyWifiDevices.request();
            print('請求附近 WiFi 設備權限後狀態: $nearbyDevicesStatus');
          }

          return locationStatus == PermissionStatus.granted &&
              nearbyDevicesStatus == PermissionStatus.granted;
        }

        return locationStatus == PermissionStatus.granted;
      }
      return true;
    } catch (e) {
      print('權限檢查錯誤: $e');
      return false;
    }
  }

  Future<void> startScan() async {
    if (isScanning) return;

    setState(() {
      isScanning = true;
      errorMessage = null;
    });

    try {
      // 先檢查並請求權限
      if (!_permissionRequested) {
        bool permissionsGranted = await _checkAndRequestPermissions();
        _permissionRequested = true;

        if (!permissionsGranted) {
          setState(() {
            errorMessage = 'WiFi scanning requires location permission\nPlease allow "Location" and "Nearby devices" in settings';
            isScanning = false;
          });

          if (widget.onScanComplete != null) {
            widget.onScanComplete!([], errorMessage);
          }
          return;
        }
      }

      // 檢查是否可以開始掃描
      final canStart = await WiFiScan.instance.canStartScan();
      print('canStartScan 狀態: $canStart');

      if (canStart != CanStartScan.yes) {
        String detailedError = _getStartScanErrorMessage(canStart);
        setState(() {
          errorMessage = detailedError;
          isScanning = false;
        });

        if (widget.onScanComplete != null) {
          widget.onScanComplete!([], detailedError);
        }
        return;
      }

      // 檢查是否可以獲取掃描結果
      final canGetResults = await WiFiScan.instance.canGetScannedResults();
      print('canGetScannedResults 狀態: $canGetResults');

      if (canGetResults != CanGetScannedResults.yes) {
        String detailedError = _getScanResultsErrorMessage(canGetResults);
        setState(() {
          errorMessage = detailedError;
          isScanning = false;
        });

        if (widget.onScanComplete != null) {
          widget.onScanComplete!([], detailedError);
        }
        return;
      }

      // 開始掃描
      print('開始 WiFi 掃描...');
      await WiFiScan.instance.startScan();

      // 等待掃描完成
      await Future.delayed(const Duration(milliseconds: 2000));

      // 獲取掃描結果
      final results = await WiFiScan.instance.getScannedResults();
      print('掃描到 ${results.length} 個 WiFi 網路');

      // 過濾和處理結果
      final seenSsids = <String>{};
      final uniqueResults = <WiFiAccessPoint>[];

      for (var result in results) {
        if (result.ssid.isNotEmpty && seenSsids.add(result.ssid)) {
          uniqueResults.add(result);
        }
      }

      uniqueResults.sort((a, b) => b.level.compareTo(a.level));
      final limitedResults = uniqueResults.take(widget.maxDevicesToShow).toList();

      setState(() {
        discoveredDevices = limitedResults;
        isScanning = false;
      });

      if (widget.onScanComplete != null) {
        widget.onScanComplete!(limitedResults, null);
      }
    } catch (e) {
      print('WiFi 掃描錯誤: $e');
      final error = 'Error occurred while scanning WiFi: $e';
      setState(() {
        errorMessage = error;
        isScanning = false;
      });

      if (widget.onScanComplete != null) {
        widget.onScanComplete!([], error);
      }
    }
  }

  // 獲取開始掃描錯誤訊息
  String _getStartScanErrorMessage(CanStartScan canStart) {
    switch (canStart) {
      case CanStartScan.notSupported:
        return 'Device does not support WiFi scanning';
      case CanStartScan.noLocationPermissionRequired:
        return 'Location permission required\nPlease allow location access';
      case CanStartScan.noLocationPermissionDenied:
        return 'Location permission denied\nPlease manually allow location permission in settings';
      case CanStartScan.noLocationPermissionUpgradeAccuracy:
        return 'Precise location permission required\nPlease select "Precise location" in settings';
      case CanStartScan.noLocationServiceDisabled:
        return 'Please turn on location service (GPS)';
      case CanStartScan.failed:
        return 'WiFi scan failed\nPlease try again';
      default:
        return 'Unable to start WiFi scan: $canStart';
    }
  }
// 顯示連線確認對話框
  void _showConnectionDialog(WiFiAccessPoint device) {
    bool hasPassword = device.capabilities != null && device.capabilities.isNotEmpty;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(
                Icons.wifi,
                color: const Color(0xFF9747FF),
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Connect to WiFi',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF9747FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF9747FF).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        device.ssid.isNotEmpty ? device.ssid : 'Unknown Network',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (hasPassword)
                      Icon(
                        Icons.lock,
                        color: const Color(0xFFFF00E5),
                        size: 16,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                hasPassword
                    ? 'This network is password protected. You will be redirected to WiFi settings to enter the password and connect.'
                    : 'You will be redirected to WiFi settings to connect to this network.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleWifiConnection(device);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9747FF).withOpacity(0.7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

// 處理 WiFi 連線請求
  Future<void> _handleWifiConnection(WiFiAccessPoint device) async {
    try {
      // 先執行外部回調（如果有的話）
      if (widget.onDeviceSelected != null) {
        widget.onDeviceSelected!(device);
      }

      if (widget.onConnectRequested != null) {
        widget.onConnectRequested!(device);
      }

      // 開啟 WiFi 設定
      await _openWifiSettings();

      // 顯示成功訊息
      _showMessage('Redirected to WiFi settings\nPlease select "${device.ssid}" to connect');

    } catch (e) {
      print('開啟 WiFi 設定時發生錯誤: $e');
      _showMessage('Unable to open WiFi settings\nPlease go to Settings manually');
    }
  }

// 開啟 WiFi 設定（簡化版）
  Future<void> _openWifiSettings() async {
    try {
      if (Platform.isAndroid) {
        // Android: 嘗試開啟 WiFi 設定
        final Uri uri = Uri.parse('android.settings.WIFI_SETTINGS');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          // 回退到一般設定
          await openAppSettings();
        }
      } else if (Platform.isIOS) {
        // iOS: 開啟 WiFi 設定
        const wifiUrl = 'App-Prefs:WIFI';
        final Uri uri = Uri.parse(wifiUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          // 回退到一般設定
          await openAppSettings();
        }
      } else {
        // 其他平台回退到一般設定
        await openAppSettings();
      }
    } catch (e) {
      print('無法開啟 WiFi 設定: $e');
      // 最終回退
      await openAppSettings();
    }
  }

// 顯示訊息
  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF9747FF).withOpacity(0.8),
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
  // 獲取掃描結果錯誤訊息
  String _getScanResultsErrorMessage(CanGetScannedResults canGet) {
    switch (canGet) {
      case CanGetScannedResults.notSupported:
        return 'Device does not support getting WiFi scan results';
      case CanGetScannedResults.noLocationPermissionRequired:
        return 'Location permission required\nPlease allow location access';
      case CanGetScannedResults.noLocationPermissionDenied:
        return 'Location permission denied\nPlease manually allow location permission in settings';
      case CanGetScannedResults.noLocationPermissionUpgradeAccuracy:
        return 'Precise location permission required\nPlease select "Precise location" in settings';
      case CanGetScannedResults.noLocationServiceDisabled:
        return 'Please turn on location service (GPS)';
      default:
        return 'Unable to get WiFi scan results: $canGet';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    double cardHeight = widget.height;

    return _appTheme.whiteBoxTheme.buildStandardCard(
      width: screenSize.width * 0.9,
      height: cardHeight,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (isScanning) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Scanning WiFi networks...',
              style: TextStyle(fontSize: 14, color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              color: const Color(0xFFFF00E5),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFFFF00E5)),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: startScan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9747FF).withOpacity(0.7),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    await openAppSettings();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9747FF).withOpacity(0.7),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Settings'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (discoveredDevices.isEmpty) {
      return const Center(
        child: Text(
          'No WiFi networks found\nPlease scan again',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: discoveredDevices.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.white.withOpacity(0.1),
        ),
        itemBuilder: (context, index) {
          return _buildDeviceListItem(discoveredDevices[index]);
        },
      ),
    );
  }

  Widget _buildDeviceListItem(WiFiAccessPoint device) {
    bool hasPassword = device.capabilities != null && device.capabilities.isNotEmpty;
    int signalStrength = device.level;
    IconData wifiIcon;

    if (signalStrength >= -65) {
      wifiIcon = Icons.wifi;
    } else if (signalStrength >= -75) {
      wifiIcon = Icons.wifi_2_bar;
    } else {
      wifiIcon = Icons.wifi_1_bar;
    }

    return InkWell(
      onTap: () {
        // 修改這裡：顯示連線對話框而不是直接回調
        _showConnectionDialog(device);
      },
      child: Container(
        height: 52,
        child: Row(
          children: [
            Expanded(
              child: Text(
                device.ssid.isNotEmpty ? device.ssid : 'Unknown Network',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color.fromRGBO(255, 255, 255, 0.8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasPassword)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Colors.white.withOpacity(0.8),
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    'assets/images/icon/lock_icon.png',
                    width: 16,
                    height: 16,
                  ),
                ),
              ),
            Icon(
              wifiIcon,
              color: Colors.white.withOpacity(0.8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}