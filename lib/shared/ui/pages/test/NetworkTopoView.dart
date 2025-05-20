import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whitebox/shared/theme/app_theme.dart';
import 'package:whitebox/shared/ui/components/basic/NetworkTopologyComponent.dart';
import 'package:whitebox/shared/ui/pages/test/DeviceDetailPage.dart'; // 引入設備詳情頁

/// 網絡拓撲視圖頁面
///
/// 這個頁面用於顯示網絡裝置之間的拓撲關係，包括有線和無線連接
class NetworkTopoView extends StatefulWidget {
  // 是否顯示測試控制器
  final bool showDeviceCountController;

  // 預設設備數量
  final int defaultDeviceCount;

  // 設備數據源 - 提供外部傳入設備列表的可能性
  final List<NetworkDevice>? externalDevices;

  // 設備連接數據源
  final List<DeviceConnection>? externalDeviceConnections;

  const NetworkTopoView({
    Key? key,
    this.showDeviceCountController = true, // 預設不顯示測試控制器
    this.defaultDeviceCount = 4, // 預設顯示4個設備
    this.externalDevices, // 允許外部傳入設備列表
    this.externalDeviceConnections, // 允許外部傳入連接數據
  }) : super(key: key);

  @override
  State<NetworkTopoView> createState() => _NetworkTopoViewState();
}

class _NetworkTopoViewState extends State<NetworkTopoView> {
  // 視圖模式: 'topology' 或 'list'
  String _viewMode = 'topology';

  // 底部選項卡
  int _selectedBottomTab = 1; // 預設為中間的連線選項

  // 控制裝置數量的控制器 測試用
  late final TextEditingController _deviceCountController;

  // 當前裝置數量
  late int _deviceCount;

  @override
  void initState() {
    super.initState();

    // 初始化設備數量
    _deviceCount = widget.defaultDeviceCount;

    // 初始化控制器
    _deviceCountController = TextEditingController(text: _deviceCount.toString());

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
      appBar: null,
      body: Column(
        children: [
          // 裝置數量控制器 - 根據標誌決定是否顯示
          if (widget.showDeviceCountController)
            buildDeviceCountController(),

          // 視圖切換選項卡 (與AppBar分開)
          SizedBox(height: 80),
          buildTabBar(),

          // 主要內容區域
          Expanded(
            child: _viewMode == 'topology'
                ? buildTopologyView()
                : buildListView(),
          ),

          // 速度區域 (Speed Area)
          buildSpeedArea(),

          // 底部導航欄
          buildBottomNavBar(),
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

  // 構建選項卡 (與AppBar分開)
  Widget buildTabBar() {
    return Container(
      margin: EdgeInsetsDirectional.only(start: 60, end: 60, top: 10, bottom: 5), // 設置合適的左右邊距使其不是全寬
      height: 30, // 精確高度，根據SVG設定
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
                decoration: BoxDecoration(
                  color: _viewMode == 'topology' ? Colors.grey[600] : Colors.grey[300],
                  borderRadius: BorderRadiusDirectional.only(
                    topStart: Radius.circular(4),
                    topEnd: Radius.circular(4),
                  ),
                ),
                child: Text(
                  'Topology',
                  style: TextStyle(
                    color: _viewMode == 'topology' ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12, // 調整字體大小
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
                decoration: BoxDecoration(
                  color: _viewMode == 'list' ? Colors.grey[600] : Colors.grey[300],
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Text(
                  'List',
                  style: TextStyle(
                    color: _viewMode == 'list' ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12, // 調整字體大小
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 獲取設備數據 - 從外部數據源或生成測試數據
  List<NetworkDevice> getDevices() {
    // 如果提供了外部設備數據，優先使用
    if (widget.externalDevices != null && widget.externalDevices!.isNotEmpty) {
      return widget.externalDevices!;
    }

    // 否則生成測試數據
    List<NetworkDevice> dummyDevices = [];

    // 根據裝置數量生成設備
    for (int i = 0; i < _deviceCount; i++) {
      String name = '';
      String deviceType = '';

      // 創建與圖片相符的設備
      switch (i) {
        case 0:
          name = 'TV';
          deviceType = 'OWA813V_6G';
          break;
        case 1:
          name = 'Xbox';
          deviceType = 'Connected via Ethernet';
          break;
        case 2:
          name = 'Iphone';
          deviceType = 'OWA813V_6G';
          break;
        case 3:
          name = 'Laptop';
          deviceType = 'OWA813V_5G';
          break;
        default:
          name = '設備 ${i + 1}';
          deviceType = 'OWA813V_6G';
      }

      // 決定連接類型
      final isWired = (name == 'Xbox');

      final device = NetworkDevice(
        name: name,
        id: 'device-${i + 1}',
        mac: '48:21:0B:4A:47:9B', // 使用與圖片匹配的MAC地址
        ip: '192.168.1.164',      // 使用與圖片匹配的IP地址
        connectionType: isWired ? ConnectionType.wired : ConnectionType.wireless,
        additionalInfo: {
          'type': deviceType,
          'status': 'online',
        },
      );

      dummyDevices.add(device);
    }

    return dummyDevices;
  }

  // 獲取設備連接數據 - 從外部數據源或生成測試數據
  List<DeviceConnection> getDeviceConnections(List<NetworkDevice> devices) {
    // 如果提供了外部連接數據，優先使用
    if (widget.externalDeviceConnections != null && widget.externalDeviceConnections!.isNotEmpty) {
      return widget.externalDeviceConnections!;
    }

    // 否則生成測試數據
    List<DeviceConnection> connections = [];

    // 為每個設備創建連接數據
    for (var device in devices) {
      connections.add(
        DeviceConnection(
          deviceId: device.id,
          connectedDevicesCount: 2, // 固定為2個連接設備
        ),
      );
    }

    return connections;
  }

  // 構建拓撲視圖
  Widget buildTopologyView() {
    // 獲取設備數據
    final devices = getDevices();

    // 獲取設備連接數據
    final deviceConnections = getDeviceConnections(devices);

    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.white,
      child: Center(
        child: NetworkTopologyComponent(
          gatewayName: 'Controller',
          devices: devices,
          deviceConnections: deviceConnections,
          totalConnectedDevices: 4, // 主機上的數字顯示
          height: MediaQuery.of(context).size.height * 0.5,  // 調整高度為屏幕高度的50%
          onDeviceSelected: (device) {
            // 獲取設備連接的子設備數量
            int connectionCount = 2; // 預設值
            bool isGateway = false;

            // 判斷是否為網關設備
            if (device.id == 'gateway') {
              isGateway = true;
              connectionCount = 4;
            } else {
              // 尋找該設備的連接數量
              try {
                final connection = deviceConnections.firstWhere(
                        (conn) => conn.deviceId == device.id
                );
                connectionCount = connection.connectedDevicesCount;
              } catch (e) {
                // 如果找不到連接信息，使用預設值
                connectionCount = 2;
              }
            }

            // 使用新的設備詳情頁面
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DeviceDetailPage(
                  device: device,
                  connectedDevicesCount: connectionCount,
                  isGateway: isGateway,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // 構建列表視圖
  Widget buildListView() {
    // 獲取設備數據
    List<NetworkDevice> devices = getDevices();

    // 添加網關設備到列表最前方
    devices.insert(0, NetworkDevice(
      name: 'Controller',
      id: 'router-001',
      mac: '48:21:0B:4A:46:CF',
      ip: '192.168.1.1',
      connectionType: ConnectionType.wired,
      additionalInfo: {
        'type': 'router',
        'status': 'online',
        'uptime': '10天3小時',
      },
    ));

    return ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: devices.length,
      separatorBuilder: (context, index) => Divider(),
      itemBuilder: (context, index) {
        final device = devices[index];

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.black,
            child: Text(
              index == 0 ? '4' : '2',
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
          onTap: () {
            // 點擊列表項時導航到設備詳情頁
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DeviceDetailPage(
                  device: device,
                  connectedDevicesCount: index == 0 ? 4 : 2,
                  isGateway: index == 0,
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 構建速度區域 (Speed Area)
  Widget buildSpeedArea() {
    return Container(
      height: 154,
      color: Color(0xFFEFEFEF),
      padding: EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Speed area',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // 構建底部導航欄
  Widget buildBottomNavBar() {
    return Container(
      color: Colors.white,
      height: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Dashboard
          buildBottomNavItem(0, 'Dashboard'),

          // 連線 (當前頁面)
          buildBottomNavItem(1, '連線'),

          // Setting
          buildBottomNavItem(2, 'Setting'),
        ],
      ),
    );
  }

  // 構建底部導航項
  Widget buildBottomNavItem(int index, String label) {
    final isSelected = index == _selectedBottomTab;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedBottomTab = index;
        });
      },
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey[300] : Colors.transparent,
          border: isSelected ? Border.all(color: Colors.grey) : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}