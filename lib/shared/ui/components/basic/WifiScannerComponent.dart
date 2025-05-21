import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:whitebox/shared/theme/app_theme.dart';

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
  final WifiScannerController? controller; // 控制器
  final double height; // 控制卡片高度

  const WifiScannerComponent({
    Key? key,
    this.maxDevicesToShow = 10,
    this.onScanComplete,
    this.onDeviceSelected,
    this.autoScan = true,
    this.controller,
    this.height = 400, // 預設高度較小
  }) : super(key: key);

  @override
  State<WifiScannerComponent> createState() => _WifiScannerComponentState();
}

class _WifiScannerComponentState extends State<WifiScannerComponent> {
  List<WiFiAccessPoint> discoveredDevices = [];
  bool isScanning = false;
  String? errorMessage;

  // 添加 AppTheme 實例
  final AppTheme _appTheme = AppTheme();

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

      // 使用 Set 來過濾重複的 SSID
      final seenSsids = <String>{};
      final uniqueResults = <WiFiAccessPoint>[];

      for (var result in results) {
        if (result.ssid.isNotEmpty && seenSsids.add(result.ssid)) {
          uniqueResults.add(result);
        }
      }

      // 按信號強度排序結果
      uniqueResults.sort((a, b) => b.level.compareTo(a.level));

      // 僅保留前 N 個結果
      final limitedResults = uniqueResults.take(widget.maxDevicesToShow).toList();

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
    final screenSize = MediaQuery.of(context).size;

    // 使用傳入的高度參數
    double cardHeight = widget.height;

    // 使用主題的 buildStandardCard 方法
    return _appTheme.whiteBoxTheme.buildStandardCard(
      width: screenSize.width * 0.9,
      height: cardHeight,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (isScanning) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white, // 使用白色以配合主題
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFFFF00E5)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: startScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9747FF).withOpacity(0.7),
                foregroundColor: Colors.white,
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
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
      );
    }

    // 使用 ListView 建立垂直列表
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0), // 僅水平方向添加填充
      child: ListView.separated(
        padding: EdgeInsets.zero, // 移除默認填充
        itemCount: discoveredDevices.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.white.withOpacity(0.1), // 淡白色分隔線，與設計稿一致
        ),
        itemBuilder: (context, index) {
          return _buildDeviceListItem(discoveredDevices[index]);
        },
      ),
    );
  }

  // 建立裝置列表項
  Widget _buildDeviceListItem(WiFiAccessPoint device) {
    // 判斷是否有密碼（根據安全類型）
    bool hasPassword = device.capabilities != null && device.capabilities.isNotEmpty;

    // 計算 WiFi 信號強度圖示
    int signalStrength = device.level;
    IconData wifiIcon;

    if (signalStrength >= -65) {
      wifiIcon = Icons.wifi; // 強信號
    } else if (signalStrength >= -75) {
      wifiIcon = Icons.wifi_2_bar; // 中等信號
    } else {
      wifiIcon = Icons.wifi_1_bar; // 弱信號
    }

    return InkWell(
      onTap: () {
        // 觸發裝置選擇回調
        if (widget.onDeviceSelected != null) {
          widget.onDeviceSelected!(device);
        }
      },
      child: Container(
        height: 52, // 根據設計稿指定高度
        child: Row(
          children: [
            // 裝置信息
            Expanded(
              child: Text(
                device.ssid.isNotEmpty ? device.ssid : '未知裝置',
                style: const TextStyle(
                  fontSize: 16, // 將字體調小
                  color: Color.fromRGBO(255, 255, 255, 0.8), // 根據設計稿顏色
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

// 顯示鎖頭圖標（如果有密碼）
            if (hasPassword)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Colors.white.withOpacity(0.8),
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    'assets/images/icon/lock_icon.png',
                    width: 16,
                    height: 16,
                  ),
                ),
              ),

            // WiFi 信號強度圖標 - 放在右側
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
}