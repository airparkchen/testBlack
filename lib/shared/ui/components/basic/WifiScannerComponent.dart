import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:whitebox/shared/theme/app_theme.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import 'package:app_settings/app_settings.dart';
import 'package:whitebox/shared/config/language/app_localizations.dart';
import 'package:flutter/cupertino.dart';

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
    this.maxDevicesToShow = 10,
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

class _WifiScannerComponentState extends State<WifiScannerComponent>
    with WidgetsBindingObserver {

  // Scroll bar可滑動變數
  late ScrollController _scrollController;
  // 狀態變數
  List<WiFiAccessPoint> discoveredDevices = [];
  bool isScanning = false;
  String? errorMessage;
  bool _isRequestingPermissions = false;
  bool _permissionDeniedPermanently = false;
  bool _permissionRequested = false;

  // AppTheme 實例
  final AppTheme _appTheme = AppTheme();

  @override
  void initState() {
    super.initState();
    // 註冊生命週期觀察者
    WidgetsBinding.instance.addObserver(this);

    // 註冊控制器
    if (widget.controller != null) {
      widget.controller!._registerState(this);
    }

    // 自動掃描
    if (widget.autoScan) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        startScan();
      });
    }

    //scroll bar滑動功能
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    // 移除生命週期觀察者
    WidgetsBinding.instance.removeObserver(this);

    // 取消註冊控制器
    if (widget.controller != null) {
      widget.controller!._unregisterState();
    }

    _scrollController.dispose();

    super.dispose();
  }

  // 監聽 App 生命週期變化
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 當 App 從背景回到前台時
    if (state == AppLifecycleState.resumed) {
      print('App 回到前台，重新檢查權限狀態');
      _checkPermissionStatusOnResume();
    }
  }

  // 當 App 回到前台時檢查權限狀態
  Future<void> _checkPermissionStatusOnResume() async {
    // 如果之前權限被拒絕，現在重新檢查
    if (_permissionDeniedPermanently || errorMessage != null) {
      try {
        if (Platform.isAndroid) {
          final deviceInfo = DeviceInfoPlugin();
          final androidInfo = await deviceInfo.androidInfo;

          // 重新檢查位置權限
          var locationStatus = await Permission.locationWhenInUse.status;
          print('App 回到前台時位置權限狀態: $locationStatus');

          bool hasLocationPermission = locationStatus == PermissionStatus.granted;
          bool hasNearbyDevicesPermission = true;

          // 檢查 Android 13+ 的附近設備權限
          if (androidInfo.version.sdkInt >= 33) {
            var nearbyDevicesStatus = await Permission.nearbyWifiDevices.status;
            print('App 回到前台時附近設備權限狀態: $nearbyDevicesStatus');
            hasNearbyDevicesPermission = nearbyDevicesStatus == PermissionStatus.granted;
          }

          // 如果權限已經被授予，重置狀態並清除錯誤
          if (hasLocationPermission && hasNearbyDevicesPermission) {
            print('權限已授予，重置狀態');
            setState(() {
              _permissionDeniedPermanently = false;
              _permissionRequested = false;
              errorMessage = null;
            });

            // 如果沒有掃描結果，自動開始掃描
            if (discoveredDevices.isEmpty && !isScanning) {
              print('權限已授予，自動開始掃描');
              startScan();
            }
          }
        }
      } catch (e) {
        print('檢查權限狀態時發生錯誤: $e');
      }
    }
  }

  // 檢查並請求必要權限
  Future<bool> _checkAndRequestPermissions() async {
    try {
      // 避免重複請求權限
      if (_isRequestingPermissions) {
        return false;
      }

      setState(() {
        _isRequestingPermissions = true;
      });

      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;

        print('Android SDK 版本: ${androidInfo.version.sdkInt}');

        // 檢查位置權限
        var locationStatus = await Permission.locationWhenInUse.status;
        print('位置權限狀態: $locationStatus');

        // 如果權限被永久拒絕，不要再次請求
        if (locationStatus == PermissionStatus.permanentlyDenied) {
          setState(() {
            _permissionDeniedPermanently = true;
            _isRequestingPermissions = false;
          });
          return false;
        }

        if (locationStatus != PermissionStatus.granted) {
          // 只在尚未被永久拒絕時才請求權限
          locationStatus = await Permission.locationWhenInUse.request();
          print('請求位置權限後狀態: $locationStatus');

          // 如果用戶拒絕權限，標記為永久拒絕以避免重複請求
          if (locationStatus == PermissionStatus.denied ||
              locationStatus == PermissionStatus.permanentlyDenied) {
            setState(() {
              _permissionDeniedPermanently = true;
              _isRequestingPermissions = false;
            });
            return false;
          }
        }

        // Android 13+ 需要額外權限
        if (androidInfo.version.sdkInt >= 33) {
          var nearbyDevicesStatus = await Permission.nearbyWifiDevices.status;
          print('附近 WiFi 設備權限狀態: $nearbyDevicesStatus');

          if (nearbyDevicesStatus == PermissionStatus.permanentlyDenied) {
            setState(() {
              _permissionDeniedPermanently = true;
              _isRequestingPermissions = false;
            });
            return false;
          }

          if (nearbyDevicesStatus != PermissionStatus.granted) {
            nearbyDevicesStatus = await Permission.nearbyWifiDevices.request();
            print('請求附近 WiFi 設備權限後狀態: $nearbyDevicesStatus');

            if (nearbyDevicesStatus == PermissionStatus.denied ||
                nearbyDevicesStatus == PermissionStatus.permanentlyDenied) {
              setState(() {
                _permissionDeniedPermanently = true;
                _isRequestingPermissions = false;
              });
              return false;
            }
          }

          setState(() {
            _isRequestingPermissions = false;
          });

          return locationStatus == PermissionStatus.granted &&
              nearbyDevicesStatus == PermissionStatus.granted;
        }

        setState(() {
          _isRequestingPermissions = false;
        });

        return locationStatus == PermissionStatus.granted;
      }

      setState(() {
        _isRequestingPermissions = false;
      });
      return true;
    } catch (e) {
      print('權限檢查錯誤: $e');
      setState(() {
        _isRequestingPermissions = false;
      });
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

        // 詳細的清理和格式化 SSID
        if (currentSSID != null && currentSSID.isNotEmpty) {
          String cleanedSSID = currentSSID
              .replaceAll('"', '') // 移除引號
              .replaceAll("'", '') // 移除單引號
              .replaceAll('<', '') // 移除 < 符號
              .replaceAll('>', '') // 移除 > 符號
              .trim(); // 移除前後空白

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
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.wifiConnectionRequired,
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
                '${AppLocalizations.of(context)!.pleaseConnectTo} "$selectedSSID" ${AppLocalizations.of(context)!.first}.',
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
              child:  Text(
                AppLocalizations.of(context)!.cancel,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await AppSettings.openAppSettingsPanel(
                    AppSettingsPanelType.wifi);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9747FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                AppLocalizations.of(context)!.goToSettings,
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  // **新增：iOS WiFi 設定引導對話框 - 只有 "Connect in Settings" 選項**
  void _showIOSWifiGuidanceDialog(BuildContext context) {
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
                Icons.wifi_off_rounded,
                color: const Color(0xFF9747FF),
                size: 24,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'WiFi Network Setup',
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
              const Text(
                'iOS does not support automatic WiFi scanning.\nPlease connect to WiFi manually in Settings.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.3,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: const TextStyle(
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
              child: Text(
                AppLocalizations.of(context)!.goToSettings,
                style: const TextStyle(fontSize: 16),
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
        return AppLocalizations.of(context)!.deviceNotSupportWifiScanning;
      case CanStartScan.noLocationPermissionRequired:
        return AppLocalizations.of(context)!.locationPermissionRequired;
      case CanStartScan.noLocationPermissionDenied:
        return AppLocalizations.of(context)!.locationPermissionDenied;
      case CanStartScan.noLocationPermissionUpgradeAccuracy:
        return AppLocalizations.of(context)!.preciseLocationPermissionRequired;
      case CanStartScan.noLocationServiceDisabled:
        return AppLocalizations.of(context)!.pleaseTurnOnLocationService;
      case CanStartScan.failed:
        return AppLocalizations.of(context)!.wifiScanFailed;
      default:
        return '${AppLocalizations.of(context)!.unableToStartWifiScan}: $canStart';
    }
  }

// 獲取掃描結果錯誤訊息
  String _getScanResultsErrorMessage(CanGetScannedResults canGet) {
    switch (canGet) {
      case CanGetScannedResults.notSupported:
        return AppLocalizations.of(context)!.deviceNotSupportGettingWifiScanResults;
      case CanGetScannedResults.noLocationPermissionRequired:
        return AppLocalizations.of(context)!.locationPermissionRequired;
      case CanGetScannedResults.noLocationPermissionDenied:
        return AppLocalizations.of(context)!.locationPermissionDenied;
      case CanGetScannedResults.noLocationPermissionUpgradeAccuracy:
        return AppLocalizations.of(context)!.preciseLocationPermissionRequired;
      case CanGetScannedResults.noLocationServiceDisabled:
        return AppLocalizations.of(context)!.pleaseTurnOnLocationService;
      default:
        return '${AppLocalizations.of(context)!.unableToGetWifiScanResults}: $canGet';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    double cardHeight = widget.height;

    return _appTheme.whiteBoxTheme.buildStandardCard(
      width: screenSize.width * 0.9,
      height: cardHeight,
      child: Padding(
        padding: const EdgeInsets.only(right: 12.0), // 在整個卡片右邊預留空間
        child: CupertinoScrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          thickness: 4.0,
          radius: const Radius.circular(2.0),
          mainAxisMargin: 3.0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: ListView.separated(
              controller: _scrollController,
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
          ),
        ),
      ),
    );
  }

  // 修改 UI 建構方法，添加 iOS 支援但保持原本結構
  Widget _buildContent() {
    if (isScanning || _isRequestingPermissions) {
      return  Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.scanningWifiNetworks,
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
                // 只有在非永久拒絕的情況下才顯示重試按鈕
                if (!_permissionDeniedPermanently)
                  ElevatedButton(
                    onPressed: () {
                      // 重置權限請求狀態以允許重試
                      setState(() {
                        _permissionRequested = false;
                        _isRequestingPermissions = false;
                      });
                      startScan();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9747FF).withOpacity(0.7),
                      foregroundColor: Colors.white,
                    ),
                    child:  Text(AppLocalizations.of(context)!.retry),
                  ),

                if (!_permissionDeniedPermanently)
                  const SizedBox(width: 12),

                ElevatedButton(
                  onPressed: () async {
                    await openAppSettings();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9747FF).withOpacity(0.7),
                    foregroundColor: Colors.white,
                  ),
                  child:  Text(AppLocalizations.of(context)!.settings),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (discoveredDevices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // **修改：在 iOS 平台且無設備時，顯示 WiFi 設定按鈕**
            if (Platform.isIOS) ...[
              Icon(
                Icons.wifi_off_rounded,
                color: const Color(0xFF9747FF).withOpacity(0.8),
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'WiFi Network Setup Required',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'iOS does not support automatic WiFi scanning',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  _showIOSWifiGuidanceDialog(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9747FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Connect to WiFi',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ] else ...[
              // Android 原本的顯示
              Text(
                AppLocalizations.of(context)!.noWifiNetworksFound,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: CupertinoScrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        thickness: 4.0,
        radius: const Radius.circular(2.0),
        child: ListView.separated(
          controller: _scrollController,
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
      ),
    );
  }

  Widget _buildDeviceListItem(WiFiAccessPoint device) {
    bool hasPassword = device.capabilities != null &&
        device.capabilities.isNotEmpty;
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
                  bool isCurrentWifi = snapshot.hasData &&
                      _compareSSID(snapshot.data, device.ssid);

                  return Text(
                    device.ssid.isNotEmpty ? device.ssid : 'Unknown Network',
                    style: TextStyle(
                      fontSize: 16,
                      color: const Color.fromRGBO(255, 255, 255, 0.8),
                      fontWeight: isCurrentWifi ? FontWeight.bold : FontWeight.normal,
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
    if (isScanning || _isRequestingPermissions) return;

    setState(() {
      isScanning = true;
      errorMessage = null;
    });

    try {
      // 先檢查並請求權限（只執行一次）
      if (!_permissionRequested && !_permissionDeniedPermanently) {
        bool permissionsGranted = await _checkAndRequestPermissions();
        _permissionRequested = true;

        if (!permissionsGranted) {
          setState(() {
            // 使用更友善的錯誤訊息，避免閃爍
            if (_permissionDeniedPermanently) {
              errorMessage = AppLocalizations.of(context)!.locationPermissionRequiredForWifiScanning;
            } else {
              errorMessage = AppLocalizations.of(context)!.wifiScanningRequiresLocationPermission;
            }
            isScanning = false;
          });

          if (widget.onScanComplete != null) {
            widget.onScanComplete!([], errorMessage);
          }
          return;
        }
      } else if (_permissionDeniedPermanently) {
        // 如果權限已被永久拒絕，直接顯示錯誤而不再請求
        setState(() {
          errorMessage = AppLocalizations.of(context)!.locationPermissionRequiredForWifiScanning;
          isScanning = false;
        });

        if (widget.onScanComplete != null) {
          widget.onScanComplete!([], errorMessage);
        }
        return;
      }

      // 繼續原有的掃描邏輯...
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
      final currentSSID = await _getCurrentWifiSSID();

      for (var result in results) {
        if (result.ssid.isNotEmpty && seenSsids.add(result.ssid)) {
          uniqueResults.add(result);
        }
      }

      uniqueResults.sort((a, b) {
        // 第一優先：已連線的 SSID
        bool aIsConnected = _compareSSID(currentSSID, a.ssid);
        bool bIsConnected = _compareSSID(currentSSID, b.ssid);

        if (aIsConnected && !bIsConnected) return -1;
        if (!aIsConnected && bIsConnected) return 1;

        // 第二優先：配置完成的 SSID
        bool aIsConfigured = WifiScannerComponent.configuredSSID != null &&
            a.ssid == WifiScannerComponent.configuredSSID;
        bool bIsConfigured = WifiScannerComponent.configuredSSID != null &&
            b.ssid == WifiScannerComponent.configuredSSID;

        if (aIsConfigured && !bIsConfigured) return -1;
        if (!aIsConfigured && bIsConfigured) return 1;

        // 第三優先：EG180 開頭的 SSID
        bool aIsEG180 = a.ssid.startsWith('EG180');
        bool bIsEG180 = b.ssid.startsWith('EG180');

        if (aIsEG180 && !bIsEG180) return -1;
        if (!aIsEG180 && bIsEG180) return 1;

        // 第四優先：信號強度
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
      final error = '${AppLocalizations.of(context)!.errorOccurredWhileScanningWifi}: $e';
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