import 'package:flutter/material.dart';
import 'package:whitebox/shared/ui/components/basic/NetworkTopologyComponent.dart';

/// 設備詳情頁
class DeviceDetailPage extends StatefulWidget {
  /// 設備數據
  final NetworkDevice device;

  /// 連接的設備數量
  final int connectedDevicesCount;

  /// 是否為主路由器/網關
  final bool isGateway;

  const DeviceDetailPage({
    Key? key,
    required this.device,
    this.connectedDevicesCount = 0,
    this.isGateway = false,
  }) : super(key: key);

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  // 模擬連接的客戶端列表
  final List<ClientDevice> _connectedClients = [
    ClientDevice(
      name: 'TV',
      deviceType: 'OWA813V_6G',
      mac: '48:21:0B:4A:47:9B',
      ip: '192.168.1.164',
      connectionTime: '1d/22h/22m/12s',
    ),
    ClientDevice(
      name: 'Xbox',
      deviceType: 'Connected via Ethernet',
      mac: '48:21:0B:4A:47:9B',
      ip: '192.168.1.164',
      connectionTime: '1d/22h/22m/12s',
    ),
    ClientDevice(
      name: 'Iphone',
      deviceType: 'OWA813V_6G',
      mac: '48:21:0B:4A:47:9B',
      ip: '192.168.1.164',
      connectionTime: '1d/22h/22m/12s',
    ),
    ClientDevice(
      name: 'Laptop',
      deviceType: 'OWA813V_5G',
      mac: '48:21:0B:4A:47:9B',
      ip: '192.168.1.164',
      connectionTime: '1d/22h/22m/12s',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 頂部返回按鈕
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                child: Icon(
                  Icons.arrow_back,
                  color: Colors.black,
                  size: 32,
                ),
              ),
            ),

            // 信號強度顯示
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                width: 360,
                height: 40,
                color: Color(0xFF64FF00), // 亮綠色
                alignment: Alignment.center,
                child: Text(
                  'RSSI : -48,-32',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // 主設備信息區域
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 設備圖標 (黑色圓圈)
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      children: [
                        // 數字標籤
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                '${widget.connectedDevicesCount}',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(width: 24),

                  // 設備信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NAME',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          widget.isGateway
                              ? 'Controller ${widget.device.mac}'
                              : widget.device.name,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Clients: ${widget.connectedDevicesCount}',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 客戶端列表
            Expanded(
              child: ListView.builder(
                itemCount: _connectedClients.length,
                itemBuilder: (context, index) {
                  final client = _connectedClients[index];
                  return _buildClientListItem(client);
                },
              ),
            ),

            // 底部導航欄 (灰色框框)
            Container(
              height: 80,
              color: Colors.grey[300],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    width: 80,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      border: Border.all(color: Colors.grey[600]!, width: 3),
                    ),
                  ),
                  Container(
                    width: 80,
                    height: 60,
                    color: Colors.grey[400],
                  ),
                  Container(
                    width: 80,
                    height: 60,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 構建客戶端列表項
  Widget _buildClientListItem(ClientDevice client) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      color: Colors.grey[200],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左側連接時間
          Container(
            width: 120,
            height: 120,
            padding: EdgeInsets.all(8),
            alignment: Alignment.bottomCenter,
            child: Text(
              client.connectionTime,
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
          ),

          // 右側設備詳細信息
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 設備名稱
                  Text(
                    client.name,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 4),

                  // 設備類型
                  Text(
                    client.deviceType,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                    ),
                  ),

                  SizedBox(height: 4),

                  // MAC地址
                  Text(
                    'MAC : ${client.mac}',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                    ),
                  ),

                  SizedBox(height: 4),

                  // IP地址
                  Text(
                    'IP : ${client.ip}',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 客戶端設備類
class ClientDevice {
  final String name;
  final String deviceType;
  final String mac;
  final String ip;
  final String connectionTime;

  ClientDevice({
    required this.name,
    required this.deviceType,
    required this.mac,
    required this.ip,
    required this.connectionTime,
  });
}