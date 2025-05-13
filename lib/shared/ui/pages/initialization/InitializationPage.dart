import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:whitebox/shared/ui/pages/initialization/QrCodeScannerPage.dart';
import 'package:whitebox/shared/ui/components/basic/WifiScannerComponent.dart';
import 'package:whitebox/shared/ui/pages/initialization/WifiSettingFlowPage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
// 等I10n生成完成後再啟用
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:whitebox/shared/ui/components/basic/LanguageSwitcherComponent.dart';

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
    final screenSize = MediaQuery.of(context).size;

    // 當I10n生成好後可以啟用這行
    final appLocalizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // 當I10n生成好後可以啟用這行
        title: Text(appLocalizations.appTitle),
        // title: const Text('Wi-Fi 5G IOT APP'),
        actions: [
          // 添加語言切換元件
          const Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: LanguageSwitcherComponent(),
          ),
        ],
      ),
      body: SafeArea(
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
                maxDevicesToShow: 3,
                deviceBoxSize: 80,
                spacing: 20,
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
                // 當I10n生成好後可以啟用這行
                // label: appLocalizations.qrcode,
                label: appLocalizations.qrcode,
                onPressed: _openQrCodeScanner,
              ),
            ),

            // 手動新增按鈕
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 10, bottom: 10),
              child: _buildActionButton(
                // 當I10n生成好後可以啟用這行
                // label: appLocalizations.manual,
                label: appLocalizations.manual,
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
                child: ElevatedButton(
                  onPressed: isScanning ? null : () {
                    setState(() {
                      isScanning = true;
                    });
                    // 使用控制器來調用掃描方法
                    _scannerController.startScan();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDDDDDD),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(0),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                  ),
                  child: Text(
                    // 當I10n生成好後可以啟用這行
                    appLocalizations.searchDevices,
                    // 'Search Devices',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.normal),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 建立功能按鈕
  Widget _buildActionButton({required String label, required VoidCallback onPressed}) {
    return SizedBox(
      width: 80,
      height: 80,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFDDDDDD),
          foregroundColor: Colors.black,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0),
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}