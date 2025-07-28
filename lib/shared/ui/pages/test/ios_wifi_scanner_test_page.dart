// ios_wifi_scanner_test_page.dart
// 模擬真實 WifiScannerComponent 的獨立測試頁面
// 完全符合原始程式的 UI 設計和行為模式

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

/// =============================================================================
/// 配置模組 - 統一管理所有 UI 參數和常數
/// =============================================================================
class WifiScannerTestConfig {
  // 顏色配置 - 完全符合原始程式
  static const Color primaryPurple = Color(0xFF9747FF);
  static const Color errorPink = Color(0xFFFF00E5);
  static const Color backgroundDark = Color(0xFF2A2A2A);
  static const Color textPrimary = Colors.white;
  static Color textSecondary = Colors.white.withOpacity(0.8);
  static Color borderColor = primaryPurple.withOpacity(0.5);
  static Color dividerColor = Colors.white.withOpacity(0.1);

  // 卡片配置 - 模擬 AppTheme.whiteBoxTheme.buildStandardCard
  static const double cardBorderRadius = 16.0;
  static const double cardPadding = 20.0;
  static const double itemHeight = 52.0;

  // 文字樣式配置 - 與原始程式一致
  static const TextStyle loadingTextStyle = TextStyle(
      fontSize: 14,
      color: textPrimary
  );

  static const TextStyle errorTextStyle = TextStyle(
      fontSize: 14,
      color: errorPink
  );

  static const TextStyle emptyTextStyle = TextStyle(
      fontSize: 16,
      color: textPrimary
  );

  static TextStyle deviceNameStyle = TextStyle(
    fontSize: 16,
    color: textPrimary.withOpacity(0.8),
    fontWeight: FontWeight.normal,
  );

  static TextStyle connectedDeviceNameStyle = TextStyle(
    fontSize: 16,
    color: textPrimary.withOpacity(0.8),
    fontWeight: FontWeight.bold,
  );

  // iOS 特有的樣式
  static const TextStyle iosGuidanceTitleStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static TextStyle iosGuidanceSubtitleStyle = TextStyle(
    fontSize: 16,
    color: textSecondary,
    height: 1.4,
  );
}

/// =============================================================================
/// 數據模型 - 模擬 WiFiAccessPoint 結構
/// =============================================================================
class MockWiFiAccessPoint {
  final String ssid;
  final int level;
  final String capabilities;

  const MockWiFiAccessPoint({
    required this.ssid,
    required this.level,
    required this.capabilities,
  });

  bool get hasPassword => capabilities.isNotEmpty;
}

/// =============================================================================
/// 平台檢測服務 - 與原始程式 PlatformHelper 對應
/// =============================================================================
class PlatformDetectionService {
  static bool get isIOS => Platform.isIOS;
  static bool get isAndroid => Platform.isAndroid;
  static bool get supportsWifiScanning => Platform.isAndroid;
}

/// =============================================================================
/// WiFi 掃描模擬服務 - 模擬原始程式的掃描邏輯
/// =============================================================================
class WifiScanSimulationService {
  /// 模擬的 WiFi 網路數據 - 符合原始程式的排序邏輯
  static List<MockWiFiAccessPoint> getMockWifiNetworks(String? currentSSID) {
    final networks = [
      const MockWiFiAccessPoint(ssid: 'EG180_Device_001', level: -45, capabilities: 'WPA2'),
      const MockWiFiAccessPoint(ssid: 'EG180_Device_002', level: -55, capabilities: 'WPA2'),
      const MockWiFiAccessPoint(ssid: 'Home_WiFi_5G', level: -60, capabilities: 'WPA2'),
      const MockWiFiAccessPoint(ssid: 'Office_Network', level: -70, capabilities: ''),
      const MockWiFiAccessPoint(ssid: 'Public_WiFi', level: -75, capabilities: ''),
      const MockWiFiAccessPoint(ssid: 'Neighbor_Router', level: -80, capabilities: 'WPA2'),
    ];

    // 應用與原始程式相同的排序邏輯
    networks.sort((a, b) {
      // 第一優先：已連線的 SSID
      bool aIsConnected = currentSSID != null && a.ssid == currentSSID;
      bool bIsConnected = currentSSID != null && b.ssid == currentSSID;

      if (aIsConnected && !bIsConnected) return -1;
      if (!aIsConnected && bIsConnected) return 1;

      // 第二優先：EG180 開頭的 SSID
      bool aIsEG180 = a.ssid.startsWith('EG180');
      bool bIsEG180 = b.ssid.startsWith('EG180');

      if (aIsEG180 && !bIsEG180) return -1;
      if (!aIsEG180 && bIsEG180) return 1;

      // 第三優先：信號強度
      return b.level.compareTo(a.level);
    });

    return networks;
  }

  /// 模擬掃描過程
  static Future<List<MockWiFiAccessPoint>> simulateWifiScan(String? currentSSID) async {
    await Future.delayed(const Duration(milliseconds: 2000));
    return getMockWifiNetworks(currentSSID);
  }
}

/// =============================================================================
/// UI 組件服務 - 建構符合原始程式風格的 UI 組件
/// =============================================================================
class WifiScannerUIService {
  /// 建構標準卡片容器 - 模擬 AppTheme.whiteBoxTheme.buildStandardCard
  static Widget buildStandardCard({
    required double width,
    required double height,
    required Widget child,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: WifiScannerTestConfig.backgroundDark,
        borderRadius: BorderRadius.circular(WifiScannerTestConfig.cardBorderRadius),
        border: Border.all(
          color: WifiScannerTestConfig.borderColor,
          width: 1,
        ),
      ),
      child: child,
    );
  }

  /// 建構 WiFi 信號圖示 - 與原始程式邏輯一致
  static IconData getWifiIcon(int signalStrength) {
    if (signalStrength >= -65) {
      return Icons.wifi;
    } else if (signalStrength >= -75) {
      return Icons.wifi_2_bar;
    } else {
      return Icons.wifi_1_bar;
    }
  }

  /// 建構設備列表項目 - 完全符合原始程式的佈局
  static Widget buildDeviceListItem({
    required MockWiFiAccessPoint device,
    required String? currentSSID,
    required VoidCallback onTap,
  }) {
    bool isConnected = currentSSID != null && device.ssid == currentSSID;
    IconData wifiIcon = getWifiIcon(device.level);

    return InkWell(
      onTap: onTap,
      child: Container(
        height: WifiScannerTestConfig.itemHeight,
        child: Row(
          children: [
            // SSID 名稱 - 使用 Expanded 讓它佔用剩餘空間
            Expanded(
              child: Text(
                device.ssid.isNotEmpty ? device.ssid : 'Unknown Network',
                style: isConnected
                    ? WifiScannerTestConfig.connectedDeviceNameStyle
                    : WifiScannerTestConfig.deviceNameStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 鎖定圖示 - 使用 ColorFiltered 模擬原始程式
            if (device.hasPassword)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Colors.white.withOpacity(0.8),
                    BlendMode.srcIn,
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: Colors.white.withOpacity(0.8),
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

  /// 建構 iOS 引導介面選項卡片
  static Widget buildIOSOptionCard({
    required IconData icon,
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: WifiScannerTestConfig.primaryPurple.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // 圖示容器
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: WifiScannerTestConfig.primaryPurple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              icon,
              size: 30,
              color: WifiScannerTestConfig.primaryPurple,
            ),
          ),
          const SizedBox(height: 16),

          // 標題
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: WifiScannerTestConfig.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // 描述
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: WifiScannerTestConfig.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // 按鈕
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: WifiScannerTestConfig.primaryPurple,
                foregroundColor: WifiScannerTestConfig.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// =============================================================================
/// 主要元件 - 模擬 WifiScannerComponent 的完整行為
/// =============================================================================
class WifiScannerTestPage extends StatefulWidget {
  const WifiScannerTestPage({super.key});

  @override
  State<WifiScannerTestPage> createState() => _WifiScannerTestPageState();
}

class _WifiScannerTestPageState extends State<WifiScannerTestPage>
    with SingleTickerProviderStateMixin {

  // 狀態變數 - 與原始程式完全一致
  List<MockWiFiAccessPoint> discoveredDevices = [];
  bool isScanning = false;
  String? errorMessage;
  bool _isRequestingPermissions = false;
  bool _permissionDeniedPermanently = false;
  bool _permissionRequested = false;

  // 模擬當前連線的 WiFi
  String? _currentConnectedSSID;

  // 平台模擬控制
  bool _isSimulatingIOS = true;

  // 動畫控制器
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // 初始化動畫
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // 模擬自動掃描 - 如同原始程式的 autoScan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isSimulatingIOS) {
        startScan();
      }
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 開始掃描 - 模擬原始程式的 startScan() 邏輯
  Future<void> startScan() async {
    if (isScanning || _isRequestingPermissions) return;

    setState(() {
      isScanning = true;
      errorMessage = null;
    });

    try {
      // 模擬平台檢測
      if (_isSimulatingIOS) {
        // iOS 平台：顯示引導介面
        setState(() {
          discoveredDevices = [];
          isScanning = false;
        });
        return;
      }

      // Android 平台：模擬權限檢查
      if (!_permissionRequested && !_permissionDeniedPermanently) {
        bool permissionsGranted = await _simulatePermissionCheck();
        _permissionRequested = true;

        if (!permissionsGranted) {
          setState(() {
            if (_permissionDeniedPermanently) {
              errorMessage = 'Location permission is required for WiFi scanning\nPlease enable it in Settings';
            } else {
              errorMessage = 'WiFi scanning requires location permission\nPlease allow "Location" and "Nearby devices" permissions';
            }
            isScanning = false;
          });
          return;
        }
      } else if (_permissionDeniedPermanently) {
        setState(() {
          errorMessage = 'Location permission is required for WiFi scanning\nPlease enable it in Settings';
          isScanning = false;
        });
        return;
      }

      // 模擬 WiFi 掃描
      final results = await WifiScanSimulationService.simulateWifiScan(_currentConnectedSSID);

      setState(() {
        discoveredDevices = results.take(10).toList(); // maxDevicesToShow = 10
        isScanning = false;
      });

    } catch (e) {
      setState(() {
        errorMessage = 'Error occurred while scanning WiFi: $e';
        isScanning = false;
      });
    }
  }

  /// 模擬權限檢查
  Future<bool> _simulatePermissionCheck() async {
    setState(() {
      _isRequestingPermissions = true;
    });

    await Future.delayed(const Duration(milliseconds: 800));

    setState(() {
      _isRequestingPermissions = false;
    });

    // 模擬權限結果（可以手動調整測試不同情況）
    return true; // 預設允許權限，可以改為 false 測試權限拒絕情況
  }

  /// 模擬 WiFi 連線檢查對話框 - 與原始程式一致
  void _showWifiConnectionDialog(String selectedSSID) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: WifiScannerTestConfig.primaryPurple.withOpacity(0.5),
              width: 1,
            ),
          ),
          title: Row(
            children: [
              Icon(
                Icons.wifi_off,
                color: WifiScannerTestConfig.errorPink,
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
              onPressed: () {
                Navigator.of(context).pop();
                _simulateOpenWifiSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: WifiScannerTestConfig.primaryPurple,
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

  /// 模擬開啟 WiFi 設定
  void _simulateOpenWifiSettings() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('模擬開啟 WiFi 設定'),
        backgroundColor: WifiScannerTestConfig.primaryPurple,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 模擬開啟 QR 掃描器
  void _simulateOpenQRScanner() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('模擬開啟 QR 掃描器'),
        backgroundColor: WifiScannerTestConfig.primaryPurple,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A), // 深色背景
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 平台切換控制區
              _buildPlatformControls(),
              const SizedBox(height: 20),

              // 主要卡片 - 模擬 AppTheme.whiteBoxTheme.buildStandardCard
              WifiScannerUIService.buildStandardCard(
                width: screenSize.width * 0.9,
                height: 400,
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 建構應用欄
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1A1A1A),
      elevation: 0,
      title: Row(
        children: [
          Icon(
            Icons.wifi_find,
            color: WifiScannerTestConfig.primaryPurple,
            size: 24,
          ),
          const SizedBox(width: 8),
          const Text(
            'WiFi Scanner Test',
            style: TextStyle(
              color: WifiScannerTestConfig.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 建構平台切換控制區
  Widget _buildPlatformControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: WifiScannerTestConfig.backgroundDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isSimulatingIOS
              ? WifiScannerTestConfig.primaryPurple.withOpacity(0.5)
              : Colors.green.withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isSimulatingIOS ? Icons.phone_iphone : Icons.phone_android,
            color: _isSimulatingIOS
                ? WifiScannerTestConfig.primaryPurple
                : Colors.green,
          ),
          const SizedBox(width: 8),
          Text(
            '目前模擬：${_isSimulatingIOS ? "iOS" : "Android"} 平台',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _isSimulatingIOS
                  ? WifiScannerTestConfig.primaryPurple
                  : Colors.green,
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isSimulatingIOS = !_isSimulatingIOS;
                // 重置狀態
                discoveredDevices = [];
                isScanning = false;
                errorMessage = null;
                _permissionRequested = false;
                _permissionDeniedPermanently = false;
              });

              // 如果切換到 Android，自動開始掃描
              if (!_isSimulatingIOS) {
                Future.delayed(const Duration(milliseconds: 300), () {
                  startScan();
                });
              }

              HapticFeedback.lightImpact();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isSimulatingIOS
                  ? WifiScannerTestConfig.primaryPurple
                  : Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('切換平台'),
          ),
        ],
      ),
    );
  }

  /// 建構主要內容 - 完全模擬原始程式的 _buildContent()
  Widget _buildContent() {
    // 載入狀態
    if (isScanning || _isRequestingPermissions) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Scanning WiFi networks...',
              style: WifiScannerTestConfig.loadingTextStyle,
            ),
          ],
        ),
      );
    }

    // 錯誤狀態
    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              color: WifiScannerTestConfig.errorPink,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: WifiScannerTestConfig.errorTextStyle,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_permissionDeniedPermanently)
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _permissionRequested = false;
                        _isRequestingPermissions = false;
                      });
                      startScan();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WifiScannerTestConfig.primaryPurple.withOpacity(0.7),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                if (!_permissionDeniedPermanently)
                  const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _simulateOpenWifiSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WifiScannerTestConfig.primaryPurple.withOpacity(0.7),
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

    // iOS 平台：顯示引導介面
    if (_isSimulatingIOS && discoveredDevices.isEmpty) {
      return _buildIOSGuidanceInterface();
    }

    // 無結果狀態
    if (discoveredDevices.isEmpty) {
      return const Center(
        child: Text(
          'No WiFi networks found\nPlease scan again',
          textAlign: TextAlign.center,
          style: WifiScannerTestConfig.emptyTextStyle,
        ),
      );
    }

    // WiFi 列表 - 完全模擬原始程式的佈局
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: RawScrollbar(
        thumbVisibility: false,
        thickness: 4.0,
        radius: const Radius.circular(2.0),
        thumbColor: WifiScannerTestConfig.primaryPurple.withOpacity(0.6),
        trackVisibility: false,
        crossAxisMargin: -12.0,
        mainAxisMargin: 0.0,
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: discoveredDevices.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: WifiScannerTestConfig.dividerColor,
          ),
          itemBuilder: (context, index) {
            final device = discoveredDevices[index];
            return WifiScannerUIService.buildDeviceListItem(
              device: device,
              currentSSID: _currentConnectedSSID,
              onTap: () {
                // 模擬原始程式的點擊檢查邏輯
                if (_currentConnectedSSID != device.ssid) {
                  _showWifiConnectionDialog(device.ssid);
                } else {
                  // 已連線到正確網路
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('選擇了 ${device.ssid}'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }

  /// 建構 iOS 引導介面
  Widget _buildIOSGuidanceInterface() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          // 主要圖示
          Icon(
            Icons.wifi_off_rounded,
            size: 48,
            color: WifiScannerTestConfig.primaryPurple.withOpacity(0.8),
          ),
          const SizedBox(height: 16),

          // 標題
          const Text(
            'WiFi Network Setup',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: WifiScannerTestConfig.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // 說明文字
          Text(
            'iOS does not support automatic WiFi scanning.\nPlease choose one of the following options:',
            style: TextStyle(
              fontSize: 14,
              color: WifiScannerTestConfig.textSecondary,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // 選項 1: 手動連接
          _buildCompactIOSOptionCard(
            icon: Icons.settings,
            title: 'Connect in Settings',
            description: 'Go to WiFi settings and connect manually',
            buttonText: 'Open WiFi Settings',
            onPressed: _simulateOpenWifiSettings,
          ),

          const SizedBox(height: 16),

          // 選項 2: QR Code 掃描
          _buildCompactIOSOptionCard(
            icon: Icons.qr_code_scanner,
            title: 'Scan QR Code',
            description: 'Use QR code to get WiFi information',
            buttonText: 'Open QR Scanner',
            onPressed: _simulateOpenQRScanner,
          ),

          const SizedBox(height: 20),

          // 底部提示
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: WifiScannerTestConfig.primaryPurple.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: WifiScannerTestConfig.primaryPurple,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'After connecting to WiFi, return to this app to continue setup.',
                    style: TextStyle(
                      fontSize: 12,
                      color: WifiScannerTestConfig.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 建構緊湊版的 iOS 選項卡片
  Widget _buildCompactIOSOptionCard({
    required IconData icon,
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: WifiScannerTestConfig.primaryPurple.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // 圖示容器
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: WifiScannerTestConfig.primaryPurple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: WifiScannerTestConfig.primaryPurple,
                ),
              ),
              const SizedBox(width: 12),

              // 標題和描述
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: WifiScannerTestConfig.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: WifiScannerTestConfig.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 按鈕
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: WifiScannerTestConfig.primaryPurple,
                foregroundColor: WifiScannerTestConfig.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}