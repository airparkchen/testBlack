import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';

// WiFi掃描元件回調函數類型
typedef OnWifiScanComplete = void Function(List<WiFiAccessPoint> devices, String? error);
typedef OnDeviceSelected = void Function(WiFiAccessPoint device);

// WiFi掃描控制器
class WifiScannerController {
  _WifiScannerComponentState? _state;

  // 註冊狀態
  void _registerState(_WifiScannerComponentState state) {
    _state = state;
  }

  // 取消註冊狀態
  void _unregisterState() {
    _state = null;
  }

  // 開始掃描
  void startScan() {
    _state?.startScan();
  }

  // 獲取當前掃描到的設備
  List<WiFiAccessPoint> getDiscoveredDevices() {
    return _state?.discoveredDevices ?? [];
  }

  // 檢查是否正在掃描
  bool isScanning() {
    return _state?.isScanning ?? false;
  }
}

class WifiScannerComponent extends StatefulWidget {
  final int maxDevicesToShow; // 最多顯示的裝置數量
  final OnWifiScanComplete? onScanComplete; // 掃描完成回調
  final OnDeviceSelected? onDeviceSelected; // 裝置選擇回調
  final bool autoScan; // 是否自動開始掃描
  final double deviceBoxSize; // 裝置方框大小
  final double spacing; // 間距
  final WifiScannerController? controller; // 控制器

  const WifiScannerComponent({
    Key? key,
    this.maxDevicesToShow = 3,
    this.onScanComplete,
    this.onDeviceSelected,
    this.autoScan = true,
    this.deviceBoxSize = 80,
    this.spacing = 20,
    this.controller,
  }) : super(key: key);

  @override
  State<WifiScannerComponent> createState() => _WifiScannerComponentState();
}

class _WifiScannerComponentState extends State<WifiScannerComponent> {
  List<WiFiAccessPoint> discoveredDevices = [];
  bool isScanning = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    // 註冊控制器
    if (widget.controller != null) {
      widget.controller!._registerState(this);
    }

    if (widget.autoScan) {
      // 組件初始化後自動開始掃描
      WidgetsBinding.instance.addPostFrameCallback((_) {
        startScan();
      });
    }
  }

  @override
  void dispose() {
    // 取消註冊控制器
    if (widget.controller != null) {
      widget.controller!._unregisterState();
    }
    super.dispose();
  }

  // 開始掃描 WiFi 裝置
  Future<void> startScan() async {
    // 避免重複掃描
    if (isScanning) return;

    setState(() {
      isScanning = true;
      errorMessage = null;
    });

    try {
      // 檢查是否可以掃描 Wi-Fi
      final canScan = await WiFiScan.instance.canGetScannedResults();
      if (canScan != CanGetScannedResults.yes) {
        final error = '無法掃描 Wi-Fi，請檢查權限狀態: $canScan';
        setState(() {
          errorMessage = error;
          isScanning = false;
        });

        // 呼叫回調
        if (widget.onScanComplete != null) {
          widget.onScanComplete!([], error);
        }
        return;
      }

      // 開始掃描
      await WiFiScan.instance.startScan();

      // 短暫延遲，確保掃描有足夠時間完成
      await Future.delayed(const Duration(milliseconds: 500));

      // 獲取掃描結果
      final results = await WiFiScan.instance.getScannedResults();

      // 按信號強度排序結果
      results.sort((a, b) => b.level.compareTo(a.level));

      // 僅保留前 N 個結果
      final limitedResults = results.take(widget.maxDevicesToShow).toList();

      setState(() {
        discoveredDevices = limitedResults;
        isScanning = false;
      });

      // 呼叫回調
      if (widget.onScanComplete != null) {
        widget.onScanComplete!(limitedResults, null);
      }
    } catch (e) {
      final error = '掃描裝置時出錯: $e';
      setState(() {
        errorMessage = error;
        isScanning = false;
      });

      // 呼叫回調
      if (widget.onScanComplete != null) {
        widget.onScanComplete!([], error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isScanning) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: startScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDDDDDD),
                foregroundColor: Colors.black,
              ),
              child: const Text('重試'),
            ),
          ],
        ),
      );
    }

    if (discoveredDevices.isEmpty) {
      return const Center(
        child: Text(
          'No device found\nPlease scan again',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    // 建立水平裝置列表，從左開始排列
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.only(left: widget.spacing),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: discoveredDevices.map((device) {
          return Padding(
            padding: EdgeInsets.only(right: widget.spacing),
            child: _buildDeviceBox(device),
          );
        }).toList(),
      ),
    );
  }

  // 建立裝置方塊
  Widget _buildDeviceBox(WiFiAccessPoint device) {
    // 格式化 MAC 地址顯示 (BSSID)
    String formattedBSSID = device.bssid;
    // 如果 BSSID 格式是 "AA:BB:CC:DD:EE:FF"，只顯示後四個部分
    if (formattedBSSID.contains(':') && formattedBSSID.split(':').length >= 4) {
      List<String> parts = formattedBSSID.split(':');
      formattedBSSID = '${parts[parts.length - 4]}:${parts[parts.length - 3]}:${parts[parts.length - 2]}:${parts[parts.length - 1]}';
    }

    return GestureDetector(
      onTap: () {
        // 觸發裝置選擇回調
        if (widget.onDeviceSelected != null) {
          widget.onDeviceSelected!(device);
        }
      },
      child: Container(
        width: widget.deviceBoxSize,
        height: widget.deviceBoxSize,
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
            const SizedBox(height: 6),
            // 顯示 SSID（如果有的話）
            Text(
              device.ssid.isNotEmpty ? device.ssid : '未知裝置',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // 顯示 MAC 地址
            Text(
              formattedBSSID,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}