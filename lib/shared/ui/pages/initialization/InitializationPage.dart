import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:whitebox/shared/ui/pages/initialization/QrCodeScannerPage.dart';

class InitializationPage extends StatefulWidget {
  const InitializationPage({super.key});

  @override
  State<InitializationPage> createState() => _InitializationPageState();
}

class _InitializationPageState extends State<InitializationPage> {
  List<WiFiAccessPoint> discoveredDevices = [];
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    _startDeviceScan();
  }

  // 開始掃描裝置
  Future<void> _startDeviceScan() async {
    setState(() {
      isScanning = true;
    });

    try {
      // 檢查是否可以掃描 Wi-Fi
      final canScan = await WiFiScan.instance.canGetScannedResults();
      if (canScan != CanGetScannedResults.yes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無法掃描 Wi-Fi，請檢查權限')),
        );
        setState(() {
          isScanning = false;
        });
        return;
      }

      // 開始掃描
      await WiFiScan.instance.startScan();
      final results = await WiFiScan.instance.getScannedResults();

      setState(() {
        // 只取前三個結果
        discoveredDevices = results.take(3).toList();
        isScanning = false;
      });
    } catch (e) {
      print('掃描裝置時出錯: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('掃描裝置時出錯: $e')),
      );
      setState(() {
        isScanning = false;
      });
    }
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
          crossAxisAlignment: CrossAxisAlignment.start, // 改為左對齊
          children: [
            // 頂部留白
            SizedBox(height: screenSize.height * 0.05),

            // 裝置列表區域（顯示前三個裝置）
            SizedBox(
              height: screenSize.height * 0.3,
              child: isScanning
                  ? const Center(child: CircularProgressIndicator())
                  : _buildDeviceList(),
            ),

            // 中間留白
            const Spacer(),

            // QR 碼掃描按鈕和手動新增按鈕，左對齊
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
                  onPressed: isScanning ? null : _startDeviceScan,
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

  // 建立裝置列表
  Widget _buildDeviceList() {
    // 若沒有掃描到裝置，顯示提示文字
    if (discoveredDevices.isEmpty) {
      return const Center(
        child: Text(
          '未發現裝置\n請點擊下方按鈕重新掃描',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    // 建立水平裝置列表，從左開始排列
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: 20), // 左側內邊距
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start, // 左對齊
        children: discoveredDevices.map((device) {
          return Padding(
            padding: const EdgeInsets.only(right: 20), // 每個方框右側間距
            child: _buildDeviceBox(device),
          );
        }).toList(),
      ),
    );
  }

  // 建立裝置方塊
  Widget _buildDeviceBox(WiFiAccessPoint device) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFDDDDDD),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 先顯示 "OLD" 文字，之後會替換成圖標
          const Text(
            'OLD',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          // 顯示 SSID（如果有的話）
          Text(
            device.ssid.isNotEmpty ? device.ssid : '未知裝置',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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