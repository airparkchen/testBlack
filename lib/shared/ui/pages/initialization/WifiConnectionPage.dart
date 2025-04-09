import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';

class WifiConnectionPage extends StatefulWidget {
  const WifiConnectionPage({super.key});

  @override
  State<WifiConnectionPage> createState() => _WifiConnectionPageState();
}

class _WifiConnectionPageState extends State<WifiConnectionPage> {
  List<WiFiAccessPoint> wifiNetworks = [];
  int? selectedNetworkIndex;
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    _startWifiScan();
  }

  Future<void> _startWifiScan() async {
    setState(() {
      isScanning = true;
    });

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
      wifiNetworks = results;
      isScanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final safeAreaPadding = MediaQuery.of(context).padding;

    // 計算安全區域內的可用高度
    final availableHeight =
        size.height - safeAreaPadding.top - safeAreaPadding.bottom;

    // 文字高度比例：201-60-695 (總計956)
    const textHeightTotal = 201 + 60 + 695; // 956
    final topTextMargin = availableHeight * (201 / textHeightTotal);
    final textHeight = availableHeight * (60 / textHeightTotal);

    // Wi-Fi 列表高度比例：281-394-281 (總計956)
    const listHeightTotal = 281 + 394 + 281; // 956
    final listAreaTop = availableHeight * (281 / listHeightTotal);
    final listHeight = availableHeight * (394 / listHeightTotal);

    // Wi-Fi 列表寬度比例：20-400-20 (總計440)
    const listWidthProportion = 20 + 400 + 20; // 440
    final leftListMargin = size.width * (20 / listWidthProportion);
    final listWidth = size.width * (400 / listWidthProportion);

    // 按鈕寬度比例：20-150-100-150-20 (總計440)
    const buttonWidthProportion = 20 + 150 + 100 + 150 + 20; // 440
    final leftButtonMargin = size.width * (20 / buttonWidthProportion);
    final backButtonWidth = size.width * (150 / buttonWidthProportion);
    final middleButtonSpace = size.width * (100 / buttonWidthProportion);
    final nextButtonWidth = size.width * (150 / buttonWidthProportion);

    return Scaffold(
      backgroundColor: Colors.white,
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
                  child: const Center(
                    child: Text(
                      'Wi-Fi on/off Check',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ),

                // 標題與列表之間的空間
                SizedBox(height: listAreaTop - topTextMargin - textHeight),

                // Wi-Fi 列表容器
                SizedBox(
                  height: listHeight,
                  child: Row(
                    children: [
                      // 左邊距
                      SizedBox(width: leftListMargin),

                      // Wi-Fi 列表
                      SizedBox(
                        width: listWidth,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey[400]!),
                          ),
                          child: isScanning
                              ? const Center(
                            child: CircularProgressIndicator(),
                          )
                              : wifiNetworks.isEmpty
                              ? const Center(
                            child: Text(
                              '未找到 Wi-Fi 網絡',
                              style: TextStyle(fontSize: 16),
                            ),
                          )
                              : ListView.builder(
                            itemCount: wifiNetworks.length,
                            itemBuilder: (context, index) {
                              final network = wifiNetworks[index];
                              final isSelected =
                                  selectedNetworkIndex == index;

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedNetworkIndex = index;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.grey[300]
                                        : Colors.transparent,
                                    borderRadius:
                                    BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      // WiFi 強度圖標
                                      Icon(
                                        Icons.wifi,
                                        size: 22,
                                        color: network.level > -70
                                            ? Colors.black
                                            : Colors.grey,
                                      ),
                                      const SizedBox(width: 12),
                                      // 網絡名稱
                                      Expanded(
                                        child: Text(
                                          network.ssid.isNotEmpty
                                              ? network.ssid
                                              : '未知網絡',
                                          style: const TextStyle(
                                              fontSize: 16),
                                        ),
                                      ),
                                      // 安全鎖圖標
                                      if (network.capabilities
                                          .contains('WPA') ||
                                          network.capabilities
                                              .contains('WEP'))
                                        const Icon(
                                          Icons.lock_outline,
                                          size: 18,
                                          color: Colors.grey,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // 右邊距
                      SizedBox(width: leftListMargin),
                    ],
                  ),
                ),

                // 底部空間 - 用於放置按鈕
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          // 左側留白
                          SizedBox(width: leftButtonMargin),

                          // 返回按鈕
                          SizedBox(
                            width: backButtonWidth,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[300],
                                foregroundColor: Colors.black,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(0),
                                  side: BorderSide(color: Colors.grey[400]!),
                                ),
                              ),
                              child: const Text(
                                'Back',
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                          ),

                          // 中間間隔
                          SizedBox(width: middleButtonSpace),

                          // 下一步按鈕
                          SizedBox(
                            width: nextButtonWidth,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: selectedNetworkIndex != null
                                  ? () {
                                // 傳回選中的 Wi-Fi 網絡名稱
                                Navigator.pop(
                                    context,
                                    wifiNetworks[selectedNetworkIndex!]
                                        .ssid);
                              }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[300],
                                foregroundColor: Colors.black,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(0),
                                  side: BorderSide(color: Colors.grey[400]!),
                                ),
                                disabledBackgroundColor: Colors.grey[200],
                                disabledForegroundColor: Colors.grey,
                              ),
                              child: const Text(
                                'Next',
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                          ),

                          // 右側留白
                          SizedBox(width: leftButtonMargin),
                        ],
                      ),
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
}