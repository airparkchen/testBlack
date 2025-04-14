import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:whitebox/shared/ui/pages/initialization/QrCodeScannerPage.dart';
import 'package:whitebox/shared/ui/components/basic/WifiScannerComponent.dart';

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
    // 在這裡處理裝置選擇邏輯
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已選擇裝置: ${device.ssid.isNotEmpty ? device.ssid : "未知裝置"}')),
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

  // 手動新增頁面（先只顯示一個提示）
  void _openManualAdd() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('手動新增功能即將推出')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
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
                label: 'QRcode',
                onPressed: _openQrCodeScanner,
              ),
            ),

            // 手動新增按鈕
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 10, bottom: 10),
              child: _buildActionButton(
                label: '手動',
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
                  child: const Text(
                    'Search Devices',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.normal),
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