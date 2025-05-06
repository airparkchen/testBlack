import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whitebox/shared/theme/app_theme.dart';
import 'package:whitebox/shared/ui/components/basic/NetworkTopologyComponent.dart';

/// 網絡拓撲視圖頁面
///
/// 這個頁面用於顯示網絡裝置之間的拓撲關係，包括有線和無線連接
class NetworkTopoView extends StatefulWidget {
  const NetworkTopoView({Key? key}) : super(key: key);

  @override
  State<NetworkTopoView> createState() => _NetworkTopoViewState();
}

class _NetworkTopoViewState extends State<NetworkTopoView> {
  // 視圖模式: 'topology' 或 'list'
  String _viewMode = 'topology';

  // 控制裝置數量的控制器
  final TextEditingController _deviceCountController = TextEditingController(text: '3');

  // 當前裝置數量
  int _deviceCount = 3;

  @override
  void initState() {
    super.initState();

    // 添加監聽器，當數量改變時更新視圖
    _deviceCountController.addListener(() {
      final newCount = int.tryParse(_deviceCountController.text) ?? 0;
      if (newCount != _deviceCount && newCount >= 0 && newCount <= 10) {
        setState(() {
          _deviceCount = newCount;
        });
      }
    });
  }

  @override
  void dispose() {
    _deviceCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('網絡拓撲'),
        backgroundColor: AppColors.buttonBackgroundColor,
      ),
      body: Column(
        children: [
          // 視圖切換選項卡
          buildTabBar(),

          // 裝置數量控制器
          buildDeviceCountController(),

          // 主要內容區域
          Expanded(
            child: _viewMode == 'topology'
                ? buildTopologyView()
                : buildListView(),
          ),

          // 底部區域 (速度測試等)
          buildBottomSection(),
        ],
      ),
    );
  }

  // 構建選項卡
  Widget buildTabBar() {
    return Container(
      height: 50,
      child: Row(
        children: [
          // 拓撲視圖選項卡
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _viewMode = 'topology';
                });
              },
              child: Container(
                alignment: Alignment.center,
                color: _viewMode == 'topology'
                    ? Colors.grey[600]
                    : Colors.grey[300],
                child: Text(
                  'Topology',
                  style: TextStyle(
                    color: _viewMode == 'topology'
                        ? Colors.white
                        : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // 列表視圖選項卡
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _viewMode = 'list';
                });
              },
              child: Container(
                alignment: Alignment.center,
                color: _viewMode == 'list'
                    ? Colors.grey[600]
                    : Colors.grey[300],
                child: Text(
                  'List',
                  style: TextStyle(
                    color: _viewMode == 'list'
                        ? Colors.white
                        : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 構建裝置數量控制器
  Widget buildDeviceCountController() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[100],
      child: Row(
        children: [
          Text(
            '裝置數量:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(width: 16),

          // 減少按鈕
          InkWell(
            onTap: () {
              if (_deviceCount > 0) {
                setState(() {
                  _deviceCount--;
                  _deviceCountController.text = _deviceCount.toString();
                });
              }
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(Icons.remove),
            ),
          ),

          // 數量輸入框
          Container(
            width: 60,
            margin: EdgeInsets.symmetric(horizontal: 8),
            child: TextField(
              controller: _deviceCountController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
            ),
          ),

          // 增加按鈕
          InkWell(
            onTap: () {
              if (_deviceCount < 10) {
                setState(() {
                  _deviceCount++;
                  _deviceCountController.text = _deviceCount.toString();
                });
              }
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  // 構建拓撲視圖
  Widget buildTopologyView() {
    // 創建測試數據
    List<NetworkDevice> dummyDevices = [];

    // 根據裝置數量生成設備
    for (int i = 0; i < _deviceCount; i++) {
      // 隨機決定連接類型
      final isWired = i % 3 == 0; // 每3個設備中的第1個設為有線連接

      dummyDevices.add(
        NetworkDevice(
          name: '設備 ${i + 1}',
          id: 'device-${i + 1}',
          mac: '00:11:22:33:44:${55 + i}',
          ip: '192.168.1.${100 + i}',
          connectionType: isWired ? ConnectionType.wired : ConnectionType.wireless,
          additionalInfo: {
            'type': isWired ? 'computer' : 'mobile',
            'status': 'online',
          },
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.white,
      child: Center(
        child: NetworkTopologyComponent(
          gatewayName: '主路由器',
          devices: dummyDevices,
          height: 400,
          onDeviceSelected: (device) {
            // 處理設備選擇
            _showDeviceInfo(device);
          },
        ),
      ),
    );
  }

  // 構建列表視圖
  Widget buildListView() {
    // 使用與拓撲視圖相同的邏輯創建測試數據
    List<NetworkDevice> dummyDevices = [
      NetworkDevice(
        name: '主路由器',
        id: 'router-001',
        mac: 'AA:BB:CC:DD:EE:FF',
        ip: '192.168.1.1',
        connectionType: ConnectionType.wired,
        additionalInfo: {
          'type': 'router',
          'status': 'online',
          'uptime': '10天3小時',
        },
      ),
    ];

    // 添加設備
    for (int i = 0; i < _deviceCount; i++) {
      final isWired = i % 3 == 0;

      dummyDevices.add(
        NetworkDevice(
          name: '設備 ${i + 1}',
          id: 'device-${i + 1}',
          mac: '00:11:22:33:44:${55 + i}',
          ip: '192.168.1.${100 + i}',
          connectionType: isWired ? ConnectionType.wired : ConnectionType.wireless,
          additionalInfo: {
            'type': isWired ? 'computer' : 'mobile',
            'status': 'online',
          },
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: dummyDevices.length,
      separatorBuilder: (context, index) => Divider(),
      itemBuilder: (context, index) {
        final device = dummyDevices[index];

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.black,
            child: Text(
              device.additionalInfo['type']?.substring(0, 1).toUpperCase() ?? 'D',
              style: TextStyle(color: Colors.white),
            ),
          ),
          title: Text(
            device.name,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('${device.ip} | ${device.mac}'),
          trailing: Icon(
            device.connectionType == ConnectionType.wired
                ? Icons.lan
                : Icons.wifi,
            color: device.connectionType == ConnectionType.wired
                ? Colors.green
                : Colors.blue,
          ),
          onTap: () => _showDeviceInfo(device),
        );
      },
    );
  }

  // 顯示設備信息
  void _showDeviceInfo(NetworkDevice device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(device.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${device.id}'),
            Text('MAC: ${device.mac}'),
            Text('IP: ${device.ip}'),
            Text('連接類型: ${device.connectionType == ConnectionType.wired ? '有線' : '無線'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('關閉'),
          ),
        ],
      ),
    );
  }

  // 構建底部區域
  Widget buildBottomSection() {
    return Container(
      height: 150,
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Speed area',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                buildSpeedButton('測速1'),
                buildSpeedButton('測速2'),
                buildSpeedButton('測速3'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 構建速度測試按鈕
  Widget buildSpeedButton(String label) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        border: Border.all(color: Colors.grey),
      ),
      child: Center(
        child: Text(label),
      ),
    );
  }
}