// lib/shared/ui/pages/home/DeviceDetailPage.dart - 修正版本

import 'package:flutter/material.dart';
import 'package:whitebox/shared/ui/components/basic/NetworkTopologyComponent.dart';
import 'package:whitebox/shared/theme/app_theme.dart';
import 'package:whitebox/shared/services/real_data_integration_service.dart';
import 'package:whitebox/shared/ui/pages/home/Topo/network_topo_config.dart';

/// 設備詳情頁面 - 修正版本
class DeviceDetailPage extends StatefulWidget {
  final NetworkDevice selectedDevice;
  final bool isGateway;
  final List<ClientDevice>? connectedClients;
  final bool showBottomNavigation;
  final VoidCallback? onBack;

  const DeviceDetailPage({
    Key? key,
    required this.selectedDevice,
    this.isGateway = false,
    this.connectedClients,
    this.showBottomNavigation = true,
    this.onBack,
  }) : super(key: key);

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  final AppTheme _appTheme = AppTheme();

  List<ClientDevice> _clientDevices = [];
  bool _isLoadingClients = true;

  @override
  void initState() {
    super.initState();

    // 🎯 調試：輸出傳入的設備資訊
    print('=== DeviceDetailPage Debug ===');
    print('選中設備: ${widget.selectedDevice.name}');
    print('設備 MAC: ${widget.selectedDevice.mac}');
    print('設備 ID: ${widget.selectedDevice.id}');
    print('是否為 Gateway: ${widget.isGateway}');
    print('設備類型: ${widget.selectedDevice.additionalInfo['type']}');
    print('客戶端數量 (additionalInfo): ${widget.selectedDevice.additionalInfo['clients']}');
    print('============================');

    _loadClientDevices();
  }

  /// 🎯 修正：異步載入客戶端設備資料
  Future<void> _loadClientDevices() async {
    if (!mounted) return;

    setState(() {
      _isLoadingClients = true;
    });

    try {
      List<ClientDevice> clientDevices;

      if (NetworkTopoConfig.useRealData) {
        // 🎯 修正：使用設備 ID 而不是重新生成
        final deviceId = widget.selectedDevice.id;
        print('🌐 載入真實客戶端數據，設備 ID: $deviceId');

        clientDevices = await RealDataIntegrationService.getClientDevicesForParent(deviceId);
        print('✅ 載入真實客戶端數據: ${clientDevices.length} 個設備');
      } else {
        clientDevices = widget.connectedClients ?? _generateFakeClientData();
        print('🎭 使用假客戶端數據: ${clientDevices.length} 個設備');
      }

      if (mounted) {
        setState(() {
          _clientDevices = clientDevices;
          _isLoadingClients = false;
        });

        // 🎯 調試：輸出載入的客戶端設備
        print('=== 載入的客戶端設備 ===');
        for (var client in clientDevices) {
          print('客戶端: ${client.name} (${client.mac})');
        }
        print('========================');
      }
    } catch (e) {
      print('❌ 載入客戶端設備時發生錯誤: $e');
      if (mounted) {
        setState(() {
          _clientDevices = _generateFakeClientData();
          _isLoadingClients = false;
        });
      }
    }
  }

  /// 生成設備 ID 的方法（備用）
  String _generateDeviceId(String macAddress) {
    return 'device-${macAddress.replaceAll(':', '').toLowerCase()}';
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
              _buildTopArea(),
              _buildDeviceInfoArea(),
              Expanded(
                child: _buildClientListArea(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
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
                color: Colors.transparent,
                child: Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 5,
            child: Center(
              child: Container(
                width: 175,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF64FF00),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'RSSI : ${widget.selectedDevice.additionalInfo['rssi'] ?? '-48,-32'}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildDeviceIcon(),
          const SizedBox(width: 24),
          Expanded(
            child: _buildDeviceInfo(),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceIcon() {
    // 🎯 修正：根據設備類型判斷是否為 Gateway
    final bool isGatewayDevice = widget.selectedDevice.additionalInfo['type'] == 'gateway';
    final iconSize = isGatewayDevice ? 60.0 : 50.0;
    final containerSize = isGatewayDevice ? 100.0 : 80.0;
    final clientCount = _clientDevices.length;

    return Container(
      width: containerSize,
      height: containerSize,
      child: Stack(
        children: [
          Container(
            width: containerSize,
            height: containerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              color: Colors.transparent,
            ),
            child: Center(
              child: isGatewayDevice
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
          if (clientCount > 0)
            Positioned(
              right: containerSize * 0.01,
              bottom: containerSize * 0.05,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Color(0xFF9747FF),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Center(
                  child: Text(
                    clientCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
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

  /// 🎯 修正：建構設備資訊文字
  Widget _buildDeviceInfo() {
    // 🎯 修正：根據設備類型動態生成名稱
    final bool isGatewayDevice = widget.selectedDevice.additionalInfo['type'] == 'gateway';

    String deviceName;
    if (isGatewayDevice) {
      deviceName = 'Controller';
    } else {
      // 對於 Extender，使用設備名稱
      deviceName = widget.selectedDevice.name;
    }

    final clientCount = _clientDevices.length;

    return Transform.translate(
      offset: const Offset(0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // NAME 標籤
          Text(
            'NAME',
            style: TextStyle(
              color: Colors.white.withOpacity(1.0),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),

          // 🎯 修正：顯示正確的設備名稱 + MAC
          Text(
            '$deviceName ${widget.selectedDevice.mac}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.normal,
            ),
          ),
          const SizedBox(height: 0),

          // 🎯 修正：顯示實際的客戶端數量
          Text(
            'Clients: $clientCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientListArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRect(
            child: Padding(
              padding: const EdgeInsets.only(top: 0, bottom: 0),
              child: _isLoadingClients
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      '載入客戶端設備中...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              )
                  : _clientDevices.isEmpty
                  ? const Center(
                child: Text(
                  '沒有連接的設備',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              )
                  : ListView.separated(
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

  Widget _buildClientCard(ClientDevice client) {
    return _appTheme.whiteBoxTheme.buildStandardCard(
      width: double.infinity,
      height: 100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildClientIcon(client),
            const SizedBox(width: 16),
            Expanded(
              child: _buildClientInfo(client),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientIcon(ClientDevice client) {
    return Container(
      width: 60,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            child: Center(
              child: Image.asset(
                _getClientIconPath(client.clientType),
                width: 40,
                height: 40,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    _getClientFallbackIcon(client.clientType),
                    color: Colors.white.withOpacity(0.8),
                    size: 40,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
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

  Widget _buildClientInfo(ClientDevice client) {
    return Transform.translate(
      offset: const Offset(0, -10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            client.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            client.deviceType,
            style: TextStyle(
              color: Colors.white.withOpacity(1.0),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'MAC : ${client.mac}',
            style: TextStyle(
              color: Colors.white.withOpacity(1.0),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'IP : ${client.ip}',
            style: TextStyle(
              color: Colors.white.withOpacity(1.0),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _getClientIconPath(ClientType type) {
    switch (type) {
      case ClientType.tv:
        return 'assets/images/icon/TV.png';
      case ClientType.xbox:
        return 'assets/images/icon/Xbox.png';
      case ClientType.iphone:
        return 'assets/images/icon/iPhone.png';
      case ClientType.laptop:
        return 'assets/images/icon/laptop.png';
      default:
        return 'assets/images/icon/device.png';
    }
  }

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

/// 客戶端設備資料類
class ClientDevice {
  final String name;
  final String deviceType;
  final String mac;
  final String ip;
  final String connectionTime;
  final ClientType clientType;
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
        return ClientType.laptop;
    }
  }
}