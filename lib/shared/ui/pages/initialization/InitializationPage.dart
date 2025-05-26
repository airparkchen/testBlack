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

class _InitializationPageState extends State<InitializationPage> {
  List<WiFiAccessPoint> discoveredDevices = [];
  bool isScanning = false;
  String? scanError;

  // WifiScannerComponent 的控制器
  final WifiScannerController _scannerController = WifiScannerController();

  // 創建 AppTheme 實例
  final AppTheme _appTheme = AppTheme();

  // 處理掃描完成
  void _handleScanComplete(List<WiFiAccessPoint> devices, String? error) {
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
        width: width, // 使用比例計算的寬度
        height: height, // 使用比例計算的高度
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              imagePath,
              width: height * 0.45, // 圖片寬度為按鈕高度的45%
              height: height * 0.45, // 圖片高度為按鈕高度的45%
              color: Colors.white,
            ),
            SizedBox(height: height * 0.02), // 間距為按鈕高度的2%
            Text(
              label,
              style: TextStyle(
                fontSize: height * 0.1, // 字體大小為按鈕高度的10%
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
        // blank_state 為 0，開啟 LoginPage
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      } else {
        // blank_state 為 1 或其他值，開啟原來的 WifiSettingFlowPage
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const WifiSettingFlowPage()),
        );
      }

    } catch (e) {
      // 關閉載入對話框
      if (mounted) {
        Navigator.of(context).pop();
      }

      // 失敗時只印出 log，不顯示任何訊息，維持在當前頁面
      print('獲取系統資訊失敗: $e');

      // 不做任何導航，維持在當前頁面
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
        // blank_state 為 0，開啟 LoginPage
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      } else {
        // blank_state 為 1 或其他值，開啟原來的 WifiSettingFlowPage
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const WifiSettingFlowPage()),
        );
      }

    } catch (e) {
      // 關閉載入對話框
      if (mounted) {
        Navigator.of(context).pop();
      }

      // 失敗時只印出 log，不顯示任何訊息，維持在當前頁面
      print('獲取系統資訊失敗: $e');

      // 不做任何導航，維持在當前頁面
    }
  }

  @override
  Widget build(BuildContext context) {
    // 獲取螢幕尺寸
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // 計算各元素尺寸與位置
    final buttonWidth = screenWidth * 0.25; // 按鈕寬度為螢幕寬度的25%
    final buttonHeight = buttonWidth; // 按鈕為正方形
    final buttonSpacing = screenWidth * 0.08; // 按鈕間距為螢幕寬度的8%

    // 頂部按鈕距離頂部的比例
    final topButtonsTopPosition = screenHeight * 0.12; // 大約佔螢幕高度的12%
    final topButtonsLeftPosition = screenWidth * 0.05; // 左側邊距為螢幕寬度的5%

    // WiFi列表區域的位置與尺寸
    final wifiListTopPosition = screenHeight * 0.28; // 大約佔螢幕高度的28%
    final wifiListHeight = screenHeight * 0.45; // 高度為螢幕高度的50%
    final wifiListWidth = screenWidth * 0.9; // 寬度為螢幕寬度的90%

    // 底部搜尋按鈕的位置與尺寸
    final searchButtonHeight = screenHeight * 0.065; // 高度為螢幕高度的6.5%
    final searchButtonBottomPosition = screenHeight * 0.06; // 距離底部為螢幕高度的6%
    final searchButtonHorizontalMargin = screenWidth * 0.1; // 水平邊距為螢幕寬度的10%

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
                left: (screenWidth - wifiListWidth) / 2, // 居中
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

                    SizedBox(width: buttonSpacing), // 按鈕間距

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
        height: height, // 使用比例計算的高度
        decoration: BoxDecoration(
          color: const Color(0xFF9747FF),
          borderRadius: BorderRadius.circular(height * 0.08), // 圓角為高度的8%
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isScanning ? 'Scanning...' : 'Search',
                style: TextStyle(
                  fontSize: height * 0.4, // 字體大小為按鈕高度的40%
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