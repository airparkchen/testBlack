import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:whitebox/shared/ui/pages/initialization/QrCodeScannerPage.dart';
import 'package:whitebox/shared/ui/components/basic/WifiScannerComponent.dart';
import 'package:whitebox/shared/ui/pages/initialization/WifiSettingFlowPage.dart';
import 'package:whitebox/shared/theme/app_theme.dart'; // 引入 AppTheme

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

  // 處理裝置選擇
  void _handleDeviceSelected(WiFiAccessPoint device) {
    // 現在當選擇裝置時，直接導航到 WifiSettingFlowPage
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WifiSettingFlowPage()),
    );
  }

  // 開啟掃描 QR 碼頁面
  void _openQrCodeScanner() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QrCodeScannerPage()),
    );

    if (result != null) {
      // 處理 QR 碼掃描結果
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QR 碼掃描結果: $result')),
      );
    }
  }

  // 手動新增頁面 - 現在打開 WifiSettingFlowPage
  void _openManualAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WifiSettingFlowPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery
        .of(context)
        .size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final wifiListHeight = screenHeight * 0.45; // 高度為螢幕高度的50%

    return Scaffold(
      backgroundColor: Colors.transparent, // 確保 Scaffold 是透明的
      body: Container(
        // 設置背景圖片
        decoration: BackgroundDecorator.imageBackground(
          imagePath: AppBackgrounds.mainBackground, // 使用您的背景圖片
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 頂部留白
              SizedBox(height: screenSize.height * 0.05),

              // 裝置列表區域（顯示前三個裝置）
              SizedBox(
                height: screenSize.height * 0.3,
                child: WifiScannerComponent(
                  controller: _scannerController,
                  maxDevicesToShow: 8,
                  height: wifiListHeight,
                  onScanComplete: _handleScanComplete,
                  onDeviceSelected: _handleDeviceSelected,
                ),
              ),

              // 中間留白
              const Spacer(),

              // QR 碼掃描按鈕
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 10, bottom: 10),
                child: _buildActionButton(
                  label: 'QRcode',
                  onPressed: _openQrCodeScanner,
                ),
              ),

              // 手動新增按鈕
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 10, bottom: 10),
                child: _buildActionButton(
                  label: 'Manual',
                  onPressed: _openManualAdd,
                ),
              ),

              // 底部留白
              const Spacer(),

              // 搜尋裝置按鈕
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: _buildSearchButton(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// 建立功能按鈕 - 使用標準漸層卡片
  Widget _buildActionButton(
      {required String label, required VoidCallback onPressed}) {
    return SizedBox(
      width: 80,
      height: 80,
      child: GestureDetector(
        onTap: onPressed,
        child: _appTheme.whiteBoxTheme.buildStandardCard(
          width: 80,
          height: 80,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchButton() {
    return GestureDetector(
      onTap: isScanning ? null : () {
        setState(() {
          isScanning = true;
        });
        _scannerController.startScan();
      },
      child: _appTheme.whiteBoxTheme.buildSimpleColorButton(
        width: double.infinity,
        height: 50,
        borderRadius: BorderRadius.circular(4),
        child: Center(
          child: Text(
            'Search Devices',
            style: AppTextStyles.buttonText,
          ),
        ),
      ),
    );
  }
}