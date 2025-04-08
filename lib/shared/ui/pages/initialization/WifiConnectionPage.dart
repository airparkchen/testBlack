import 'package:flutter/material.dart';

class WifiConnectionPage extends StatefulWidget {
  const WifiConnectionPage({super.key});

  @override
  State<WifiConnectionPage> createState() => _WifiConnectionPageState();
}

class _WifiConnectionPageState extends State<WifiConnectionPage> {
  // 模擬的WiFi連接列表
  final List<Map<String, dynamic>> wifiNetworks = [
    {'name': 'Home Network', 'strength': 3, 'secured': true},
    {'name': 'Office WiFi', 'strength': 4, 'secured': true},
    {'name': 'Guest Network', 'strength': 2, 'secured': false},
    {'name': 'TP-Link_5G', 'strength': 2, 'secured': true},
    {'name': 'AndroidAP', 'strength': 1, 'secured': true},
  ];

  // 選中的網絡索引
  int? selectedNetworkIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            // 頁面標題
            const Center(
              child: Text(
                'Wi-Fi 連接設定',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 40),
            // WiFi列表容器
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ListView.builder(
                  itemCount: wifiNetworks.length,
                  itemBuilder: (context, index) {
                    final network = wifiNetworks[index];
                    final isSelected = selectedNetworkIndex == index;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedNetworkIndex = index;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.grey[300] : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            // WiFi強度圖標
                            Icon(
                              Icons.wifi,
                              size: 22,
                              color: network['strength'] > 2 ? Colors.black : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            // 網絡名稱
                            Expanded(
                              child: Text(
                                network['name'],
                                style: const TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            // 安全鎖圖標
                            if (network['secured'])
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
            const SizedBox(height: 20),
            // 底部按鈕區域
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 返回按鈕
                  SizedBox(
                    width: 150,
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
                  // 下一步按鈕
                  SizedBox(
                    width: 150,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: selectedNetworkIndex != null
                          ? () {
                        // 處理下一步邏輯
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}