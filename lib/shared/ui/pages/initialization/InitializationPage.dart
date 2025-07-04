// lib/shared/ui/pages/initialization/InitializationPage.dart
import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:whitebox/shared/ui/pages/initialization/QrCodeScannerPage.dart';
import 'package:whitebox/shared/ui/components/basic/WifiScannerComponent.dart';
import 'package:whitebox/shared/ui/pages/initialization/WifiSettingFlowPage.dart';
import 'package:whitebox/shared/api/wifi_api_service.dart';
import 'package:whitebox/shared/theme/app_theme.dart';

import 'LoginPage.dart';

class InitializationPage extends StatefulWidget {
  const InitializationPage({super.key});

  @override
  State<InitializationPage> createState() => _InitializationPageState();
}

class _InitializationPageState extends State<InitializationPage>
    with WidgetsBindingObserver {  // 添加 WidgetsBindingObserver mixin

  List<WiFiAccessPoint> discoveredDevices = [];
  bool isScanning = false;
  String? scanError;

  // WifiScannerComponent 的控制器
  final WifiScannerController _scannerController = WifiScannerController();

  // 創建 AppTheme 實例
  final AppTheme _appTheme = AppTheme();

  @override
  void initState() {
    super.initState();

    // 註冊生命週期觀察者
    WidgetsBinding.instance.addObserver(this);

    // 頁面初次載入時自動掃描
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScan();
    });
  }

  @override
  void dispose() {
    // 移除生命週期觀察者
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
      // App 從背景恢復到前景時自動掃描
        print('App resumed - 開始自動掃描');
        _startAutoScan();
        break;
      case AppLifecycleState.paused:
        print('App paused');
        break;
      case AppLifecycleState.detached:
        print('App detached');
        break;
      case AppLifecycleState.inactive:
        print('App inactive');
        break;
      case AppLifecycleState.hidden:
        print('App hidden');
        break;
    }
  }

  // 自動掃描方法
  void _startAutoScan() {
    // 確保不會在已經掃描時重複掃描
    if (!isScanning && mounted) {
      print('開始自動 WiFi 掃描');
      setState(() {
        isScanning = true;
      });
      _scannerController.startScan();
    }
  }

  // 處理掃描完成
  void _handleScanComplete(List<WiFiAccessPoint> devices, String? error) {
    if (!mounted) return; // 確保 widget 還在樹中

    setState(() {
      discoveredDevices = devices;
      scanError = error;
      isScanning = false;
    });

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }

    print('WiFi 掃描完成 - 發現 ${devices.length} 個裝置');
  }

  // 建立使用圖片的功能按鈕
  Widget _buildImageActionButton({
    required String label,
    required String imagePath,
    required VoidCallback onPressed,
    required double width,
    required double height,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: _appTheme.whiteBoxTheme.buildStandardCard(
        width: width,
        height: height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              imagePath,
              width: height * 0.45,
              height: height * 0.45,
              color: Colors.white,
            ),
            SizedBox(height: height * 0.02),
            Text(
              label,
              style: TextStyle(
                fontSize: height * 0.1,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // 處理裝置選擇
  void _handleDeviceSelected(WiFiAccessPoint device) async {
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LoginPage(
              onBackPressed: () => Navigator.of(context).pop(),
            ),
          ),
        );
      } else {
        // blank_state 為 1 或其他值，開啟原來的 WifiSettingFlowPage
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const WifiSettingFlowPage(
              // 🔧 新增：啟用資料保留功能
              preserveDataOnBack: true,  // 返回時保留資料
              preserveDataOnNext: true,  // 前進時保留下一步資料
            ),
          ),
        );
      }

    } catch (e) {
      // 關閉載入對話框
      if (mounted) {
        Navigator.of(context).pop();
      }

      // 失敗時只印出 log，不顯示任何訊息，維持在當前頁面
      print('獲取系統資訊失敗: $e');
    }
  }

  // 開啟掃描 QR 碼頁面
  void _openQrCodeScanner() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QrCodeScannerPage()),
    );

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QR 碼掃描結果: $result')),
      );
    }
  }

  // 處理手動新增
  void _openManualAdd() async {
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LoginPage(
              onBackPressed: () {
                Navigator.of(context).pop(); // 返回到 InitializationPage
              },
            ),
          ),
        );
      } else {
        // blank_state 為 1 或其他值，開啟原來的 WifiSettingFlowPage
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const WifiSettingFlowPage(
              // 🔧 新增：啟用資料保留功能
              preserveDataOnBack: true,  // 返回時保留資料
              preserveDataOnNext: true,  // 前進時保留下一步資料
            ),
          ),
        );
      }

    } catch (e) {
      // 關閉載入對話框
      if (mounted) {
        Navigator.of(context).pop();
      }

      // 失敗時只印出 log，不顯示任何訊息，維持在當前頁面
      print('獲取系統資訊失敗: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 獲取螢幕尺寸
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // 計算各元素尺寸與位置
    final buttonWidth = screenWidth * 0.25;
    final buttonHeight = buttonWidth;
    final buttonSpacing = screenWidth * 0.08;

    // 頂部按鈕距離頂部的比例
    final topButtonsTopPosition = screenHeight * 0.12;
    final topButtonsLeftPosition = screenWidth * 0.05;

    // WiFi列表區域的位置與尺寸
    final wifiListTopPosition = screenHeight * 0.28;
    final wifiListHeight = screenHeight * 0.45;
    final wifiListWidth = screenWidth * 0.9;

    // 底部搜尋按鈕的位置與尺寸
    final searchButtonHeight = screenHeight * 0.065;
    final searchButtonBottomPosition = screenHeight * 0.06;
    final searchButtonHorizontalMargin = screenWidth * 0.1;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        // 設置背景圖片
        decoration: BackgroundDecorator.imageBackground(
          imagePath: AppBackgrounds.mainBackground,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // WiFi 裝置列表區域
              Positioned(
                top: wifiListTopPosition,
                left: (screenWidth - wifiListWidth) / 2,
                child: SizedBox(
                  width: wifiListWidth,
                  height: wifiListHeight,
                  child: WifiScannerComponent(
                    controller: _scannerController,
                    maxDevicesToShow: 8,
                    height: wifiListHeight,
                    onScanComplete: _handleScanComplete,
                    onDeviceSelected: _handleDeviceSelected,
                  ),
                ),
              ),

              // 頂部按鈕區域
              Positioned(
                top: topButtonsTopPosition,
                left: topButtonsLeftPosition,
                child: Row(
                  children: [
                    // QR 碼掃描按鈕
                    _buildImageActionButton(
                      label: 'QRcode',
                      imagePath: 'assets/images/icon/QRcode.png',
                      onPressed: _openQrCodeScanner,
                      width: buttonWidth,
                      height: buttonHeight,
                    ),

                    SizedBox(width: buttonSpacing),

                    // 手動新增按鈕
                    _buildImageActionButton(
                      label: 'Manual Input',
                      imagePath: 'assets/images/icon/manual_input.png',
                      onPressed: _openManualAdd,
                      width: buttonWidth,
                      height: buttonHeight,
                    ),
                  ],
                ),
              ),

              // 底部搜尋按鈕
              Positioned(
                bottom: searchButtonBottomPosition,
                left: searchButtonHorizontalMargin,
                right: searchButtonHorizontalMargin,
                child: _buildSearchButton(height: searchButtonHeight),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchButton({required double height}) {
    return GestureDetector(
      onTap: isScanning ? null : () {
        setState(() {
          isScanning = true;
        });
        _scannerController.startScan();
      },
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF9747FF),
          borderRadius: BorderRadius.circular(height * 0.08),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isScanning ? 'Scanning...' : 'Search',
                style: TextStyle(
                  fontSize: height * 0.4,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}