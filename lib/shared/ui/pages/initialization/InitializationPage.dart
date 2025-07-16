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
  final bool shouldAutoSearch;
  const InitializationPage({
    super.key,
    this.shouldAutoSearch = false, // 預設為 false
  });

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

  // 追蹤自動搜尋狀態
  bool _isAutoSearching = false;
  int _autoSearchAttempts = 0;
  static const int _maxAutoSearchAttempts = 5; // 最多嘗試 3 次

  // 追蹤自動搜尋是否已完成
  bool _autoSearchCompleted = false;

  @override
  void initState() {
    super.initState();

    // 註冊生命週期觀察者
    WidgetsBinding.instance.addObserver(this);

    // 頁面初次載入時自動掃描
    if (widget.shouldAutoSearch) {
      print('🔍 檢測到需要自動搜尋，延遲執行（等待設備重啟網路服務）');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 🔥 修改1：增加延遲時間到 3 秒，讓設備有時間重啟
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            print('🔍 開始第一次自動搜尋');
            _triggerAutoSearchWithRetry();
          }
        });
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startAutoScan();
      });
    }
  }

  void _triggerAutoSearchWithRetry() {
    if (!mounted || isScanning) return;

    _isAutoSearching = true;
    _autoSearchAttempts++;

    print('🔍 觸發自動搜尋（第 $_autoSearchAttempts 次嘗試）');
    setState(() {
      isScanning = true;
    });
    _scannerController.startScan();
  }

  //App 生命週期的觸發條件
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        print('App resumed - 檢查是否需要重新掃描');

        // 修改觸發條件：
        // 1. 非自動搜尋模式 OR 自動搜尋已完成
        // 2. 當前沒有在自動搜尋中
        bool shouldTriggerScan = (!widget.shouldAutoSearch || _autoSearchCompleted) && !_isAutoSearching;

        if (shouldTriggerScan) {
          print('🔍 觸發 App 回到前台的掃描');
          _startAutoScan();
        } else {
          print('🔍 跳過 App 回到前台的掃描 - shouldAutoSearch: ${widget.shouldAutoSearch}, autoSearchCompleted: $_autoSearchCompleted, isAutoSearching: $_isAutoSearching');
        }
        break;
      case AppLifecycleState.paused:
        print('App paused');
        break;
      default:
        break;
    }
  }

  // 自動掃描方法
  void _startAutoScan() {
    if (widget.shouldAutoSearch && !_autoSearchCompleted) {  // 只有在自動搜尋模式且未完成時才跳過
      return;
    }

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
    if (!mounted) return;

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

    // 🔥 自動搜尋模式的特殊處理
    if (_isAutoSearching && widget.shouldAutoSearch) {
      final configuredSSID = WifiScannerComponent.configuredSSID;

      if (configuredSSID != null && configuredSSID.isNotEmpty) {
        bool foundConfiguredSSID = devices.any((device) => device.ssid == configuredSSID);

        print('🔍 自動搜尋結果：配置的 SSID "$configuredSSID" ${foundConfiguredSSID ? "已找到" : "未找到"}');

        if (!foundConfiguredSSID && _autoSearchAttempts < _maxAutoSearchAttempts) {
          // 🔥 如果沒找到配置的 SSID 且還有重試次數，等待後重試
          print('🔍 未找到配置的 SSID，${2 * _autoSearchAttempts} 秒後進行第 ${_autoSearchAttempts + 1} 次嘗試');

          Future.delayed(Duration(seconds: 2 * _autoSearchAttempts), () {
            if (mounted && _isAutoSearching) {
              _triggerAutoSearchWithRetry();
            }
          });
          return; // 不重置 _isAutoSearching，繼續重試流程
        } else {
          // 🔥 修正：立即設置狀態，不要等待其他操作
          print('🔥 立即設置自動搜尋完成狀態');
          setState(() {
            _isAutoSearching = false;
            _autoSearchAttempts = 0;
            _autoSearchCompleted = true; // 🔥 標記自動搜尋已完成
          });
          print('🔥 自動搜尋狀態已重置：_autoSearchCompleted = $_autoSearchCompleted');

          // 🔥 然後才顯示提示訊息
          if (foundConfiguredSSID) {
            print('✅ 成功找到配置的 SSID "$configuredSSID"');

            // 顯示成功提示
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text('Found network: "$configuredSSID"'),
                  ],
                ),
                backgroundColor: Colors.green.withOpacity(0.8),
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            print('❌ 達到最大重試次數，仍未找到配置的 SSID "$configuredSSID"');

            // 顯示未找到提示
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Configured network "$configuredSSID" not found.\nIt may still be starting up.'),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange.withOpacity(0.8),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        // 沒有配置的 SSID 記錄
        print('⚠️ 沒有配置的 SSID 記錄');
        print('🔥 設置自動搜尋完成狀態（無配置SSID）');
        setState(() {
          _isAutoSearching = false;
          _autoSearchAttempts = 0;
          _autoSearchCompleted = true; // 🔥 標記自動搜尋已完成
        });
        print('🔥 自動搜尋狀態已重置：_autoSearchCompleted = $_autoSearchCompleted');
      }
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
        // 使用滑入動畫跳轉到 LoginPage
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => LoginPage(
              onBackPressed: () => Navigator.of(context).pop(),
            ),
            transitionDuration: const Duration(milliseconds: 250),
            reverseTransitionDuration: const Duration(milliseconds: 250),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0); // 從右側滑入
              const end = Offset.zero;
              const curve = Curves.easeInOut;

              var tween = Tween(begin: begin, end: end).chain(
                CurveTween(curve: curve),
              );

              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          ),
        );
      } else {
        // 使用滑入動畫跳轉到 WifiSettingFlowPage
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const WifiSettingFlowPage(
              preserveDataOnBack: true,  // 返回時保留資料
              preserveDataOnNext: true,  // 前進時保留下一步資料
            ),
            transitionDuration: const Duration(milliseconds: 250),
            reverseTransitionDuration: const Duration(milliseconds: 250),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0); // 從右側滑入
              const end = Offset.zero;
              const curve = Curves.easeInOut;

              var tween = Tween(begin: begin, end: end).chain(
                CurveTween(curve: curve),
              );

              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
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
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const QrCodeScannerPage(),
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0); // 從右側滑入
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
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
        // 使用滑入動畫跳轉到 LoginPage
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => LoginPage(
              onBackPressed: () {
                Navigator.of(context).pop(); // 返回到 InitializationPage
              },
            ),
            transitionDuration: const Duration(milliseconds: 250),
            reverseTransitionDuration: const Duration(milliseconds: 250),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0); // 從右側滑入
              const end = Offset.zero;
              const curve = Curves.easeInOut;

              var tween = Tween(begin: begin, end: end).chain(
                CurveTween(curve: curve),
              );

              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          ),
        );
      } else {
        // 使用滑入動畫跳轉到 WifiSettingFlowPage
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const WifiSettingFlowPage(
              preserveDataOnBack: true,  // 返回時保留資料
              preserveDataOnNext: true,  // 前進時保留下一步資料
            ),
            transitionDuration: const Duration(milliseconds: 250),
            reverseTransitionDuration: const Duration(milliseconds: 250),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0); // 從右側滑入
              const end = Offset.zero;
              const curve = Curves.easeInOut;

              var tween = Tween(begin: begin, end: end).chain(
                CurveTween(curve: curve),
              );

              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
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
                    maxDevicesToShow: 100,   //控制Wifi Scan的SSID數量
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
                      label: 'QR Code',
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
        // 手動搜尋時，重置所有自動搜尋相關狀態
        setState(() {
          _isAutoSearching = false;
          _autoSearchAttempts = 0;
          _autoSearchCompleted = false; // 重置自動搜尋完成狀態
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
              if (_isAutoSearching) ...[
                SizedBox(
                  width: height * 0.3,
                  height: height * 0.3,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Auto Searching... (${_autoSearchAttempts}/${_maxAutoSearchAttempts})',
                  style: TextStyle(
                    fontSize: height * 0.3,
                    color: Colors.white,
                  ),
                ),
              ] else ...[
                Text(
                  isScanning ? 'Scanning...' : 'Search',
                  style: TextStyle(
                    fontSize: height * 0.4,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}