import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:whitebox/shared/theme/app_theme.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import 'package:app_settings/app_settings.dart';

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
  final OnWifiConnectRequested? onConnectRequested;
  final bool autoScan;
  final WifiScannerController? controller;
  final double height;

  // 新增：記錄從設定流程中完成的SSID
  static String? configuredSSID;

  // 新增：設定配置完成的SSID的靜態方法
  static void setConfiguredSSID(String ssid) {
    configuredSSID = ssid;
    print('📡 記錄配置完成的SSID: $ssid');
  }

  // 新增：清除配置的SSID
  static void clearConfiguredSSID() {
    configuredSSID = null;
    print('📡 清除配置的SSID記錄');
  }

  const WifiScannerComponent({
    Key? key,
    this.maxDevicesToShow = 10,   //wifi scanner
    this.onScanComplete,
    this.onDeviceSelected,
    this.onConnectRequested,
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

// 修改：檢查當前連線的 WiFi SSID - 使用 network_info_plus
  Future<String?> _getCurrentWifiSSID() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult.contains(ConnectivityResult.wifi)) {
        final info = NetworkInfo();
        final currentSSID = await info.getWifiName();

        // print('原始獲取的 SSID: "$currentSSID"');

        // 詳細的清理和格式化 SSID
        if (currentSSID != null && currentSSID.isNotEmpty) {
          String cleanedSSID = currentSSID
              .replaceAll('"', '')           // 移除引號
              .replaceAll("'", '')           // 移除單引號
              .replaceAll('<', '')           // 移除 < 符號
              .replaceAll('>', '')           // 移除 > 符號
              .trim();                       // 移除前後空白

          // print('清理後的 SSID: "$cleanedSSID"');

          return cleanedSSID.isEmpty ? null : cleanedSSID;
        }
      }
      return null;
    } catch (e) {
      print('取得當前 WiFi SSID 時發生錯誤: $e');
      return null;
    }
  }

// 修改：SSID 比較函數
  bool _compareSSID(String? currentSSID, String selectedSSID) {
    if (currentSSID == null || selectedSSID.isEmpty) {
      return false;
    }

    // 清理兩個 SSID 進行比較
    String cleanedCurrent = currentSSID
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll('<', '')
        .replaceAll('>', '')
        .trim()
        .toLowerCase();

    String cleanedSelected = selectedSSID
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll('<', '')
        .replaceAll('>', '')
        .trim()
        .toLowerCase();

    // print('比較 SSID:');
    // print('  當前清理後: "$cleanedCurrent"');
    // print('  選擇清理後: "$cleanedSelected"');
    // print('  是否相同: ${cleanedCurrent == cleanedSelected}');

    return cleanedCurrent == cleanedSelected;
  }
  // 簡潔版本的對話框
  void _showWifiConnectionDialog(BuildContext context, String selectedSSID) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: const Color(0xFF9747FF).withOpacity(0.5),
              width: 1,
            ),
          ),
          title: Row(
            children: [
              Icon(
                Icons.wifi_off,
                color: const Color(0xFFFF00E5),
                size: 24,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'WiFi Connection Required',
                  style: TextStyle(
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
              Text(
                'Please connect to "$selectedSSID" first.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await AppSettings.openAppSettingsPanel(AppSettingsPanelType.wifi);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9747FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Go to Settings',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
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
      onTap: () async {
        try {
          // 檢查當前連線的 WiFi
          final currentSSID = await _getCurrentWifiSSID();
          final selectedSSID = device.ssid;

          print('=== WiFi 連線檢查 ===');
          print('當前連線的 WiFi: "$currentSSID"');
          print('選擇的 WiFi: "$selectedSSID"');

          // 使用比較函數
          bool isConnectedToSelected = _compareSSID(currentSSID, selectedSSID);

          print('是否已連線到選擇的網路: $isConnectedToSelected');

          // 如果沒有連線到選擇的網路，顯示對話框
          if (!isConnectedToSelected) {
            if (mounted) {
              _showWifiConnectionDialog(context, selectedSSID);
            }
            return;
          }

          // 如果已經連線到正確的網路，執行原有的選擇邏輯
          print('已連線到正確網路，執行選擇邏輯');
          if (widget.onDeviceSelected != null) {
            widget.onDeviceSelected!(device);
          }
        } catch (e) {
          print('檢查 WiFi 連線時發生錯誤: $e');
          // 發生錯誤時，直接執行選擇邏輯（容錯處理）
          if (widget.onDeviceSelected != null) {
            widget.onDeviceSelected!(device);
          }
        }
      },
      child: Container(
        height: 52,
        child: Row(
          children: [
            // SSID 名稱 - 使用 Expanded 讓它佔用剩餘空間
            Expanded(
              child: FutureBuilder<String?>(
                future: _getCurrentWifiSSID(),
                builder: (context, snapshot) {
                  bool isCurrentWifi = snapshot.hasData && _compareSSID(snapshot.data, device.ssid);

                  return Text(
                    device.ssid.isNotEmpty ? device.ssid : 'Unknown Network',
                    style: TextStyle(
                      fontSize: 16,
                      color: const Color.fromRGBO(255, 255, 255, 0.8),
                      fontWeight: isCurrentWifi ? FontWeight.bold : FontWeight.normal, // 當前連線的顯示為粗體
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
            ),
            // 鎖定圖示
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
            // WiFi 信號圖示
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

      // uniqueResults.sort((a, b) => b.level.compareTo(a.level));  //一般過濾
      uniqueResults.sort((a, b) {
        // 第一優先：配置完成的 SSID
        bool aIsConfigured = WifiScannerComponent.configuredSSID != null &&
            a.ssid == WifiScannerComponent.configuredSSID;
        bool bIsConfigured = WifiScannerComponent.configuredSSID != null &&
            b.ssid == WifiScannerComponent.configuredSSID;

        if (aIsConfigured && !bIsConfigured) return -1;
        if (!aIsConfigured && bIsConfigured) return 1;

        // 第二優先：EG180 開頭的 SSID
        bool aIsEG180 = a.ssid.startsWith('EG180');
        bool bIsEG180 = b.ssid.startsWith('EG180');

        if (aIsEG180 && !bIsEG180) return -1;
        if (!aIsEG180 && bIsEG180) return 1;

        // 第三優先：信號強度
        return b.level.compareTo(a.level);
      });

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
}