import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:whitebox/shared/theme/app_theme.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:whitebox/shared/api/wifi_api_service.dart';
import 'package:whitebox/shared/ui/pages/initialization/LoginPage.dart';
import 'package:whitebox/shared/ui/pages/initialization/WifiSettingFlowPage.dart';

class QrCodeScannerPage extends StatefulWidget {
  const QrCodeScannerPage({super.key});

  @override
  State<QrCodeScannerPage> createState() => _QrCodeScannerPageState();
}

class _QrCodeScannerPageState extends State<QrCodeScannerPage>
    with WidgetsBindingObserver {
  final AppTheme _appTheme = AppTheme();
  MobileScannerController? _controller;
  String qrResult = '';
  bool isScanning = true;
  bool _isCameraInitFailed = false;
  bool _permissionsRequested = false;

  // QR Code WiFi 相關變數
  String? _scannedSSID;
  String? _scannedPassword;
  String? _scannedSecurity;
  bool _showNextButton = false; // 控制是否顯示 Next 按鈕
  bool _waitingForConnection = false; // 新增：等待用戶連接 WiFi 的狀態
  bool _isDialogShowing = false; // 🎯 新增：追蹤是否有對話框正在顯示

  // ========== Auto Focus 相關變數 ==========
  Timer? _autoFocusTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScanner();
    _requestPermissionsQuietly();
  }

  @override
  void dispose() {
    print('🔍 QR Scanner 頁面銷毀');
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _autoFocusTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      print('🔍 QR Scanner 頁面回到前台');
      // 重新啟動 Auto Focus
      _startAutoFocus();

      // 🎯 新增：如果正在等待連接，自動檢測 WiFi
      if (_waitingForConnection && _scannedSSID != null) {
        print('🔍 檢測到回到前台，開始自動檢測 WiFi 連接');
        _autoCheckWiFiConnection();
      }
    } else if (state == AppLifecycleState.paused) {
      // 暫停 Auto Focus
      _stopAutoFocus();
    }
  }

  // 🎯 新增：自動檢測 WiFi 連接
  Future<void> _autoCheckWiFiConnection() async {
    // 🎯 如果已經有對話框在顯示，不要重複檢查
    if (_isDialogShowing) {
      print('🔍 對話框已經在顯示中，跳過自動檢查');
      return;
    }

    // 延遲一點時間讓系統穩定
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted || _scannedSSID == null) return;

    print('🔍 開始自動檢測 WiFi 連接狀態');

    // 🎯 設置對話框顯示狀態
    _isDialogShowing = true;

    // 顯示載入狀態
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      },
    );

    try {
      // 檢查當前連接的 WiFi
      final currentSSID = await _getCurrentWifiSSID();
      print('🔍 當前 SSID: "$currentSSID", 目標 SSID: "$_scannedSSID"');

      // 關閉載入對話框
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (currentSSID != null && _compareSSID(currentSSID, _scannedSSID!)) {
        print('🔍 ✅ SSID 比對成功！自動執行系統檢查');

        // 🎯 重置狀態
        _waitingForConnection = false;
        _isDialogShowing = false;

        // 執行系統資訊檢查（等同於點擊 Next）
        await _performSystemInfoCheck();
      } else {
        // SSID 比對失敗，顯示增強版的連接失敗對話框
        _showEnhancedConnectionFailureDialog(currentSSID);
      }

    } catch (e) {
      // 關閉載入對話框
      if (mounted) {
        Navigator.of(context).pop();
      }

      print('🔍 自動檢查連接時發生錯誤: $e');

      // 🎯 重置對話框狀態
      _isDialogShowing = false;

      _showErrorDialog('檢查失敗', '無法檢查當前 WiFi 連接狀態');
    }
  }

  // 靜默請求權限
  Future<void> _requestPermissionsQuietly() async {
    if (!_permissionsRequested) {
      try {
        await Permission.camera.request();
        await Permission.locationWhenInUse.request();
        _permissionsRequested = true;
      } catch (e) {
        print('🔍 預先權限請求失敗: $e');
      }
    }
  }

  void _initializeScanner() {
    try {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false,
        returnImage: false,
        detectionTimeoutMs: 1000,
        formats: [BarcodeFormat.qrCode], // 只掃描 QR Code，提升效能
      );

      // 啟動 Auto Focus
      _startAutoFocus();
    } catch (e) {
      print('🔍 Camera initialization failed: $e');
      setState(() {
        _isCameraInitFailed = true;
      });
    }
  }

  void _startAutoFocus() {
    _autoFocusTimer?.cancel();
    _autoFocusTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        if (_controller != null && mounted) {
          await _controller!.resetZoomScale();
        }
      } catch (e) {
        print('🔍 Auto focus 錯誤: $e');
      }
    });
  }

  void _stopAutoFocus() {
    _autoFocusTimer?.cancel();
    _autoFocusTimer = null;
  }

  // 手動對焦
  Future<void> _handleTapToFocus() async {
    print('🎯 觸發手動對焦');

    try {
      if (_controller != null) {
        // 暫停自動對焦
        _stopAutoFocus();

        // 執行對焦操作
        await _controller!.resetZoomScale();

        print('🎯 對焦完成');

        // 1秒後重新啟動自動對焦
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _startAutoFocus();
          }
        });
      }
    } catch (e) {
      print('🎯 對焦失敗: $e');
      // 即使失敗也要重新啟動自動對焦
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _startAutoFocus();
        }
      });
    }
  }

  // 處理 WiFi QR Code
  void _handleWiFiQR(String qrCode) async {
    print('🔍 QR Code: $qrCode');

    // 解析 QR Code 資訊
    String ssid = '';
    String password = '';
    String security = '';

    RegExp ssidRegex = RegExp(r'S:([^;]+)');
    RegExp passwordRegex = RegExp(r'P:([^;]+)');
    RegExp securityRegex = RegExp(r'T:([^;]+)');

    var ssidMatch = ssidRegex.firstMatch(qrCode);
    var passwordMatch = passwordRegex.firstMatch(qrCode);
    var securityMatch = securityRegex.firstMatch(qrCode);

    if (ssidMatch != null) {
      ssid = ssidMatch.group(1) ?? '';
    }

    if (passwordMatch != null) {
      password = passwordMatch.group(1) ?? '';
    }

    if (securityMatch != null) {
      security = securityMatch.group(1) ?? '';
    }

    print('🔍 SSID: "$ssid"');
    print('🔍 Password: "$password"');
    print('🔍 Security: "$security"');

    if (ssid.isNotEmpty) {
      // 保存掃描到的 WiFi 資訊
      _scannedSSID = ssid;
      _scannedPassword = password;
      _scannedSecurity = security;

      // 設置 QR 結果但不停止掃描，並顯示 Next 按鈕
      setState(() {
        qrResult = qrCode;
        _showNextButton = true;
        // 不設置 isScanning = false，讓相機繼續運作
      });

      // 🎯 新增：立即檢查當前 WiFi 連接狀態
      await _checkInitialWiFiConnection(ssid, password, security);
    } else {
      print('🔍 SSID 解析失敗');
      _showErrorDialog('QR Code 解析失敗', '無法從 QR Code 中獲取有效的 WiFi 資訊');
    }
  }

  // 🎯 新增：檢查初始 WiFi 連接狀態
  Future<void> _checkInitialWiFiConnection(String ssid, String password, String security) async {
    print('🔍 檢查初始 WiFi 連接狀態...');

    // 顯示載入狀態
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      },
    );

    try {
      // 檢查當前連接的 WiFi
      final currentSSID = await _getCurrentWifiSSID();
      print('🔍 當前 SSID: "$currentSSID", 目標 SSID: "$ssid"');

      // 關閉載入對話框
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (currentSSID != null && _compareSSID(currentSSID, ssid)) {
        print('🔍 ✅ 已經連接到正確的 WiFi！直接執行系統檢查');

        // 直接執行系統資訊檢查
        await _performSystemInfoCheck();
      } else {
        print('🔍 ❌ 尚未連接到正確的 WiFi，顯示設定對話框');

        // 設置等待連接狀態
        setState(() {
          _waitingForConnection = true;
        });

        // 顯示 "Go to Settings" 對話框
        _showWiFiInfoDialogModified(ssid, password, security);
      }

    } catch (e) {
      // 關閉載入對話框
      if (mounted) {
        Navigator.of(context).pop();
      }

      print('🔍 檢查初始連接時發生錯誤: $e');

      // 發生錯誤時也顯示設定對話框
      setState(() {
        _waitingForConnection = true;
      });

      _showWiFiInfoDialogModified(ssid, password, security);
    }
  }

  // 🎯 修改：只有 "Go to Settings" 按鈕的對話框
  void _showWiFiInfoDialogModified(String ssid, String password, String security) {
    if (!mounted) return;

    // 🎯 設置對話框顯示狀態
    _isDialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false, // 🎯 不允許點擊外部關閉
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
                Icons.wifi,
                color: const Color(0xFF9747FF),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'WiFi QR Code detected',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: MediaQuery.of(context).size.width * 0.045,
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
                'QR Code information:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoRow('SSID:', ssid),
              _buildInfoRow('Password:', password.isNotEmpty ? password : 'No password'),
              const SizedBox(height: 16),
              const Text(
                'Please go to Settings and connect to this WiFi network. The app will automatically detect the connection when you return.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          actions: [
            // 🎯 只保留 "Go to Settings" 按鈕
            ElevatedButton(
              onPressed: () async {
                // 🎯 關閉對話框時重置狀態
                _isDialogShowing = false;
                Navigator.of(context).pop();
                try {
                  await AppSettings.openAppSettingsPanel(AppSettingsPanelType.wifi);
                } catch (e) {
                  print('🔍 開啟 WiFi 設定失敗: $e');
                }
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

  // 構建資訊行
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 使用 IntrinsicWidth 讓標籤寬度自動適應文字長度
          IntrinsicWidth(
            child: Container(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width * 0.25, // 最小寬度保持一致性
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12), // 固定間距
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 重置掃描狀態
  void _resetScanningState() {
    setState(() {
      qrResult = '';
      isScanning = true;
      _showNextButton = false;
      _waitingForConnection = false; // 🎯 重置等待狀態
      _isDialogShowing = false; // 🎯 重置對話框狀態
      _scannedSSID = null;
      _scannedPassword = null;
      _scannedSecurity = null;
    });

    // 重新開始掃描
    if (_controller != null) {
      _controller!.start();
    }
  }

  // 獲取當前 WiFi SSID
  Future<String?> _getCurrentWifiSSID() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult.contains(ConnectivityResult.wifi)) {
        final info = NetworkInfo();
        final currentSSID = await info.getWifiName();

        if (currentSSID != null && currentSSID.isNotEmpty) {
          String cleanedSSID = currentSSID
              .replaceAll('"', '')
              .replaceAll("'", '')
              .replaceAll('<', '')
              .replaceAll('>', '')
              .trim();

          return cleanedSSID.isEmpty ? null : cleanedSSID;
        }
      }
      return null;
    } catch (e) {
      print('🔍 取得當前 WiFi SSID 時發生錯誤: $e');
      return null;
    }
  }

  // SSID 比較函數
  bool _compareSSID(String? currentSSID, String selectedSSID) {
    if (currentSSID == null || selectedSSID.isEmpty) {
      return false;
    }

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

  // 處理 Next 按鈕點擊（保留原有邏輯）
  void _handleNext() async {
    if (_scannedSSID == null) return;

    // 顯示載入狀態
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      },
    );

    try {
      // 檢查當前連接的 WiFi
      final currentSSID = await _getCurrentWifiSSID();
      print('🔍 當前 SSID: "$currentSSID", 目標 SSID: "$_scannedSSID"');

      // 關閉載入對話框
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (currentSSID != null && _compareSSID(currentSSID, _scannedSSID!)) {
        print('🔍 ✅ SSID 比對成功！');

        // 呼叫 API 獲取系統資訊
        await _performSystemInfoCheck();
      } else {
        // SSID 比對失敗，顯示增強版的提示對話框
        _showEnhancedConnectionFailureDialog(currentSSID);
      }

    } catch (e) {
      // 關閉載入對話框
      if (mounted) {
        Navigator.of(context).pop();
      }

      print('🔍 檢查連接時發生錯誤: $e');
      _showErrorDialog('檢查失敗', '無法檢查當前 WiFi 連接狀態');
    }
  }

  // 執行系統資訊檢查
  Future<void> _performSystemInfoCheck() async {
    // 顯示載入狀態
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      },
    );

    try {
      // 呼叫 API 獲取系統資訊
      final systemInfo = await WifiApiService.getSystemInfo();

      // 關閉載入對話框
      if (mounted) {
        Navigator.of(context).pop();
      }

      // 檢查 blank_state 的值
      final blankState = systemInfo['blank_state'];

      if (blankState == "0") {
        // 跳轉到 LoginPage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LoginPage(
              onBackPressed: () {
                // 修復：Back 按鈕返回到 QR Scanner 頁面
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QrCodeScannerPage(),
                  ),
                );
              },
            ),
          ),
        );
      } else {
        // 跳轉到 WifiSettingFlowPage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const WifiSettingFlowPage(
              preserveDataOnBack: true,
              preserveDataOnNext: true,
            ),
          ),
        );
      }

    } catch (e) {
      // 關閉載入對話框
      if (mounted) {
        Navigator.of(context).pop();
      }

      print('🔍 獲取系統資訊失敗: $e');
      _showErrorDialog('連接失敗', '無法獲取系統資訊，請稍後重試');
    }
  }

  // 🎯 新增：顯示增強版的連接失敗對話框
  void _showEnhancedConnectionFailureDialog(String? currentSSID) {
    if (!mounted) return;

    String currentWifiText = currentSSID ?? 'No WiFi connected';

    showDialog(
      context: context,
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
                    fontSize: 16,
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
                'Please connect to the scanned WiFi network to continue.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              // 🎯 新增：QR Code WiFi 資訊
              const Text(
                'QR Code WiFi:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _scannedSSID ?? 'Unknown',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              // 原有的 Current WiFi 資訊
              const Text(
                'Current WiFi:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                currentWifiText,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // 🎯 關閉對話框時重置狀態
                _isDialogShowing = false;
                Navigator.of(context).pop();
                // 🎯 保持等待狀態，不重置
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
                // 🎯 關閉對話框時重置狀態
                _isDialogShowing = false;
                Navigator.of(context).pop();
                try {
                  await AppSettings.openAppSettingsPanel(AppSettingsPanelType.wifi);
                } catch (e) {
                  print('🔍 開啟 WiFi 設定失敗: $e');
                }
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
    ).then((_) {
      // 🎯 對話框關閉後重置狀態（防止意外情況）
      _isDialogShowing = false;
    });
  }

  // 顯示錯誤對話框
  void _showErrorDialog(String title, String message) {
    if (!mounted) return;

    showDialog(
      context: context,
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
                Icons.error_outline,
                color: const Color(0xFFFF00E5),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9747FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final safeAreaPadding = MediaQuery.of(context).padding;

    // 計算安全區域內的可用高度
    final availableHeight = size.height - safeAreaPadding.top - safeAreaPadding.bottom;

    // 文字高度比例：225-36-695 (總計956)
    const textHeightTotal = 201 + 60 + 695; // 956
    final topTextMargin = availableHeight * (201 / textHeightTotal);
    final textHeight = availableHeight * (60 / textHeightTotal);

    // 相機高度比例：281-394-281 (總計956)
    const cameraHeightTotal = 281 + 394 + 281; // 956
    final cameraAreaTop = availableHeight * (281 / cameraHeightTotal);
    final cameraHeight = availableHeight * (394 / cameraHeightTotal);

    // 相機寬度比例：20-400-20 (總計440)
    const cameraWidthProportion = 20 + 400 + 20; // 440
    final leftCameraMargin = size.width * (20 / cameraWidthProportion);
    final cameraWidth = size.width * (400 / cameraWidthProportion);

    // 按鈕寬度比例：20-150-100-150-20 (總計440)
    const buttonWidthProportion = 20 + 150 + 100 + 150 + 20; // 440
    final leftButtonMargin = size.width * (20 / buttonWidthProportion);
    final backButtonWidth = size.width * (150 / buttonWidthProportion);
    final nextButtonWidth = size.width * (150 / buttonWidthProportion);

    final titleFontSize = size.width < 375 ? 20.0 : 26.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          child: SizedBox(
            height: availableHeight,
            child: Column(
              children: [
                // 標題前的空間
                SizedBox(height: topTextMargin),

                // 標題文字
                SizedBox(
                  height: textHeight,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Wi-Fi QR Code Scanner',
                        style: AppTextStyles.heading1.copyWith(
                          fontSize: titleFontSize,
                        ),
                      ),
                    ),
                  ),
                ),

                // 標題與相機之間的空間
                SizedBox(height: cameraAreaTop - topTextMargin - textHeight),

                // 相機預覽容器
                SizedBox(
                  height: cameraHeight,
                  child: Row(
                    children: [
                      // 左邊距
                      SizedBox(width: leftCameraMargin),

                      // 相機預覽
                      SizedBox(
                        width: cameraWidth,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey[400]!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: _buildCameraView(cameraWidth, cameraHeight),
                          ),
                        ),
                      ),

                      // 右邊距
                      SizedBox(width: leftCameraMargin),
                    ],
                  ),
                ),

                // 底部空間 - 用於放置按鈕
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 按鈕區域
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: _showNextButton
                            ? Row(
                          children: [
                            // 左側留白
                            SizedBox(width: leftButtonMargin),

                            // Back 按鈕
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  print('🔍 返回按鈕被點擊');
                                  Navigator.pop(context, qrResult.isNotEmpty ? qrResult : null);
                                },
                                child: Container(
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                                    color: const Color(0xFF9747FF).withOpacity(0.2),
                                    border: Border.all(
                                      color: const Color(0xFF9747FF),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text('Back', style: AppTextStyles.buttonText),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 16),

                            // Next 按鈕
                            Expanded(
                              child: GestureDetector(
                                onTap: _handleNext,
                                child: Container(
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                                    color: const Color(0xFF9747FF),
                                  ),
                                  child: Center(
                                    child: Text('Next', style: AppTextStyles.buttonText),
                                  ),
                                ),
                              ),
                            ),

                            // 右側留白
                            SizedBox(width: leftButtonMargin),
                          ],
                        )
                            : Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            // 左側留白
                            SizedBox(width: leftButtonMargin),

                            // 只有 Back 按鈕
                            SizedBox(
                              width: backButtonWidth,
                              child: GestureDetector(
                                onTap: () {
                                  print('🔍 返回按鈕被點擊');
                                  Navigator.pop(context, qrResult.isNotEmpty ? qrResult : null);
                                },
                                child: Container(
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                                    color: const Color(0xFF9747FF).withOpacity(0.2),
                                    border: Border.all(
                                      color: const Color(0xFF9747FF),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text('Back', style: AppTextStyles.buttonText),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 🎯 移除：原本的 QR Code WiFi Info 顯示區域
                      // 這個部分已經被完全移除，不再顯示在 UI 中
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraView(double width, double height) {
    // 如果相機初始化失敗，顯示錯誤信息
    if (_isCameraInitFailed) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              'Camera initialization failed',
              style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Please check camera permissions',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      );
    }

    // 如果相機控制器為空，顯示加載動畫
    if (_controller == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      );
    }

    // 整個相機視圖都可以點擊對焦
    return GestureDetector(
      onTap: _handleTapToFocus, // 點擊整個區域都會觸發對焦
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 相機視圖
          MobileScanner(
            controller: _controller!,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && isScanning) {
                final String rawValue = barcodes.first.rawValue ?? 'Unable to read';

                print('🔍 偵測到 QR Code: $rawValue');

                // 檢查是否為 WiFi QR Code
                if (rawValue.startsWith('WIFI:')) {
                  // 暫停掃描但不停止相機
                  setState(() {
                    isScanning = false;
                  });
                  _handleWiFiQR(rawValue);
                }
              }
            },
          ),

          // 掃描框
          if (isScanning)
            Container(
              width: width * 0.6,
              height: height * 0.6,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),

          // Tap to Focus 提示
          if (isScanning)
            Positioned(
              bottom: 10,
              left: 10,
              child: GestureDetector(
                onTap: _handleTapToFocus, // 點擊文字也會觸發對焦
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app,
                        color: const Color(0xFF9747FF),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Tap to Focus',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 掃描成功指示（不阻擋相機視圖）
          if (!isScanning && qrResult.isNotEmpty)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'WiFi QR Code detected!',
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: MediaQuery.of(context).size.width * 0.035,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // 重新掃描按鈕
                    GestureDetector(
                      onTap: _resetScanningState,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Scan Again',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}