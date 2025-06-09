// lib/shared/ui/pages/home/DeviceDetailPage.dart

import 'package:flutter/material.dart';
import 'package:whitebox/shared/ui/components/basic/NetworkTopologyComponent.dart';
import 'package:whitebox/shared/theme/app_theme.dart';

/// 設備詳情頁面
class DeviceDetailPage extends StatefulWidget {
  /// 選中的設備（Gateway 或 Agent）
  final NetworkDevice selectedDevice;

  /// 是否為網關設備
  final bool isGateway;

  /// 連接的客戶端列表（將來從 Mesh API 取得）
  final List<ClientDevice>? connectedClients;
  final bool showBottomNavigation;  // 👈 添加這個參數
  final VoidCallback? onBack;

  const DeviceDetailPage({
    Key? key,
    required this.selectedDevice,
    this.isGateway = false,
    this.connectedClients,
    this.showBottomNavigation = true,  // 👈 添加預設值
    this.onBack,
  }) : super(key: key);

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  final AppTheme _appTheme = AppTheme();

  // 假資料 - 將來會被 Mesh API 資料替代
  late List<ClientDevice> _clientDevices;

  @override
  void initState() {
    super.initState();
    _loadClientDevices();
  }

  /// 載入客戶端設備資料（預留 API 接口）
  void _loadClientDevices() {
    // TODO: 將來替換為 Mesh API 呼叫
    // final apiData = await MeshApiService.getConnectedClients(widget.selectedDevice.id);

    _clientDevices = widget.connectedClients ?? _generateFakeClientData();
  }

  /// 生成假資料（開發用）
  List<ClientDevice> _generateFakeClientData() {
    return [
      ClientDevice(
        name: 'TV',
        deviceType: 'OWA813V_6G',
        mac: '48:21:0B:4A:47:9B',
        ip: '192.168.1.164',
        connectionTime: '1d/22h/22m/12s',
        clientType: ClientType.tv,
      ),
      ClientDevice(
        name: 'Xbox',
        deviceType: 'Connected via Ethernet',
        mac: '48:21:0B:4A:47:9B',
        ip: '192.168.1.164',
        connectionTime: '1d/22h/22m/12s',
        clientType: ClientType.xbox,
      ),
      ClientDevice(
        name: 'Iphone',
        deviceType: 'OWA813V_6G',
        mac: '48:21:0B:4A:47:9B',
        ip: '192.168.1.164',
        connectionTime: '1d/22h/22m/12s',
        clientType: ClientType.iphone,
      ),
      ClientDevice(
        name: 'Laptop',
        deviceType: 'OWA813V_5G',
        mac: '48:21:0B:4A:47:9B',
        ip: '192.168.1.164',
        connectionTime: '1d/22h/22m/12s',
        clientType: ClientType.laptop,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BackgroundDecorator.imageBackground(
          imagePath: AppBackgrounds.mainBackground,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 頂部區域：RSSI + 返回按鈕
              _buildTopArea(),

              // 設備主要資訊區域
              _buildDeviceInfoArea(),

              // 客戶端列表區域
              Expanded(
                child: _buildClientListArea(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 建構頂部區域（RSSI + 返回按鈕）
  Widget _buildTopArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Stack(
        children: [
          // 返回按鈕（固定在左側）
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else {
                  Navigator.of(context).pop();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),

          // RSSI 顯示（水平居中）
          Center(
            child: Container(
              width: 200, // 👈 固定寬度，與 NetworkTopo 頁面的膠囊 bar 相同
              height: 22, // 👈 固定高度，與 NetworkTopo 頁面相同
              decoration: BoxDecoration(
                color: const Color(0xFF64FF00), // 亮綠色
                borderRadius: BorderRadius.circular(15), // 👈 高度的一半，確保圓角
              ),
              child: Center( // 👈 確保文字完全居中
                child: Text(
                  'RSSI : ${widget.selectedDevice.additionalInfo['rssi'] ?? '-48,-32'}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12, // 👈 調整字體大小以配合固定寬度
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center, // 👈 文字置中對齊
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 建構設備主要資訊區域
  Widget _buildDeviceInfoArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),   //整體文字卡片 位置調整
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 設備圖標（參考 NetworkTopologyComponent 的樣式）
          _buildDeviceIcon(),

          const SizedBox(width: 24),

          // 設備資訊
          Expanded(
            child: _buildDeviceInfo(),
          ),
        ],
      ),
    );
  }

  /// 建構設備圖標（白色圓圈 + 透明背景 + 圖標）
  /// 建構設備圖標（白色圓圈 + 透明背景 + 圖標 + 右下角數字標籤）
  /// 建構設備圖標（白色圓圈 + 透明背景 + 圖標 + 右下角數字標籤）
  Widget _buildDeviceIcon() {
    final iconSize = widget.isGateway ? 80.0 : 70.0; // icon 本身的大小
    final containerSize = widget.isGateway ? 120.0 : 100.0;  //外圈半徑
    final clientCount = _clientDevices.length;

    return Container(
      width: containerSize,
      height: containerSize,
      child: Stack(
        children: [
          // 主要圓形圖標
          Container(
            width: containerSize,
            height: containerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),  //外圈邊框粗細
              color: Colors.transparent,
            ),
            child: Center(
              child: widget.isGateway
                  ? Image.asset(
                'assets/images/icon/router.png',
                width: iconSize,
                height: iconSize,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.router,
                    color: Colors.white,
                    size: iconSize * 0.6,
                  );
                },
              )
                  : ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.white.withOpacity(1.0),
                  BlendMode.srcIn,
                ),
                child: Image.asset(
                  'assets/images/icon/mesh.png',
                  width: iconSize,
                  height: iconSize,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.lan,
                      color: Colors.white.withOpacity(0.8),
                      size: iconSize * 0.6,
                    );
                  },
                ),
              ),
            ),
          ),

          // 右下角紫色數字標籤（參考 NetworkTopologyComponent） 小圓圈位置
          if (clientCount > 0)
            Positioned(
              right: containerSize * 0.01,  // 距離右邊 10%
              bottom: containerSize * 0.05, // 距離底部 10%
              child: Container(
                width: 30,    //小圓圈大小
                height: 30,
                decoration: BoxDecoration(
                  color: Color(0xFF9747FF), // 紫色背景
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),  //小圓圈邊框粗細
                ),
                child: Center(
                  child: Text(
                    clientCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,  //小圓圈數字大小
                      fontWeight: FontWeight.bold,  //小圓圈數字粗細
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 建構設備資訊文字
  Widget _buildDeviceInfo() {
    final deviceName = widget.isGateway ? 'Controller' : widget.selectedDevice.name;
    final clientCount = _clientDevices.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // NAME 標籤
        Text(
          'NAME',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
        ),
        const SizedBox(height: 4),

        // 設備名稱 + MAC
        Text(
          '$deviceName ${widget.selectedDevice.mac}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // Clients 數量
        Text(
          'Clients: $clientCount',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  /// 建構客戶端列表區域
  Widget _buildClientListArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRect(
            child: Padding(
              padding: const EdgeInsets.only(
                top: 20,    // 上限調整
                bottom: 100, // 下限調整（避免被底部導航遮擋）
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 16),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _clientDevices.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final client = _clientDevices[index];
                  return _buildClientCard(client);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// 建構單個客戶端卡片
  Widget _buildClientCard(ClientDevice client) {
    return _appTheme.whiteBoxTheme.buildStandardCard(
      width: double.infinity,
      height: 100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 左側：圖標 + 連線時間
            _buildClientIcon(client),

            const SizedBox(width: 16),

            // 右側：客戶端資訊
            Expanded(
              child: _buildClientInfo(client),
            ),
          ],
        ),
      ),
    );
  }

  /// 建構客戶端圖標 + 連線時間
  Widget _buildClientIcon(ClientDevice client) {
    return Container(
      width: 60,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 圖標
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
            ),
            child: Center(
              child: Image.asset(
                _getClientIconPath(client.clientType),
                width: 24,
                height: 24,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    _getClientFallbackIcon(client.clientType),
                    color: Colors.white.withOpacity(0.8),
                    size: 20,
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 連線時間
          Text(
            client.connectionTime,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 建構客戶端資訊
  Widget _buildClientInfo(ClientDevice client) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 設備名稱
        Text(
          client.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),

        // 網路類型
        Text(
          client.deviceType,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),

        // MAC 地址
        Text(
          'MAC : ${client.mac}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),

        // IP 地址
        Text(
          'IP : ${client.ip}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  /// 根據客戶端類型取得圖標路徑
  String _getClientIconPath(ClientType type) {
    switch (type) {
      case ClientType.tv:
        return 'assets/images/icon/tv.png';
      case ClientType.xbox:
        return 'assets/images/icon/xbox.png';
      case ClientType.iphone:
        return 'assets/images/icon/iphone.png';
      case ClientType.laptop:
        return 'assets/images/icon/laptop.png';
      default:
        return 'assets/images/icon/device.png'; // 預設圖標
    }
  }

  /// 根據客戶端類型取得後備圖標
  IconData _getClientFallbackIcon(ClientType type) {
    switch (type) {
      case ClientType.tv:
        return Icons.tv;
      case ClientType.xbox:
        return Icons.games;
      case ClientType.iphone:
        return Icons.phone_iphone;
      case ClientType.laptop:
        return Icons.laptop;
      default:
        return Icons.device_unknown;
    }
  }
}

/// 客戶端設備類型枚舉
enum ClientType {
  tv,
  xbox,
  iphone,
  laptop,
}

/// 客戶端設備資料類（預留 API 結構）
class ClientDevice {
  final String name;
  final String deviceType;
  final String mac;
  final String ip;
  final String connectionTime;
  final ClientType clientType;

  // 預留 API 欄位
  final String? rssi;
  final String? status;
  final DateTime? lastSeen;
  final Map<String, dynamic>? additionalInfo;

  ClientDevice({
    required this.name,
    required this.deviceType,
    required this.mac,
    required this.ip,
    required this.connectionTime,
    required this.clientType,
    this.rssi,
    this.status,
    this.lastSeen,
    this.additionalInfo,
  });

  /// 從 API JSON 創建實例（預留方法）
  factory ClientDevice.fromJson(Map<String, dynamic> json) {
    return ClientDevice(
      name: json['name'] ?? '',
      deviceType: json['deviceType'] ?? '',
      mac: json['mac'] ?? '',
      ip: json['ip'] ?? '',
      connectionTime: json['connectionTime'] ?? '',
      clientType: _parseClientType(json['type']),
      rssi: json['rssi'],
      status: json['status'],
      lastSeen: json['lastSeen'] != null ? DateTime.parse(json['lastSeen']) : null,
      additionalInfo: json['additionalInfo'],
    );
  }

  /// 解析客戶端類型（預留方法）
  static ClientType _parseClientType(String? type) {
    switch (type?.toLowerCase()) {
      case 'tv':
        return ClientType.tv;
      case 'xbox':
        return ClientType.xbox;
      case 'iphone':
      case 'phone':
        return ClientType.iphone;
      case 'laptop':
      case 'computer':
        return ClientType.laptop;
      default:
        return ClientType.laptop; // 預設類型
    }
  }
}