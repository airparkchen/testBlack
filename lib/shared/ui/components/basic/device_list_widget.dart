// lib/shared/ui/pages/test/components/device_list_widget.dart

import 'package:flutter/material.dart';
import 'package:whitebox/shared/ui/components/basic/NetworkTopologyComponent.dart';
import 'package:whitebox/shared/ui/pages/home/Topo/network_topo_config.dart';

/// 設備列表組件
class DeviceListWidget extends StatelessWidget {
  final List<NetworkDevice> devices;
  final bool enableInteractions;
  final Function(NetworkDevice)? onDeviceSelected;

  const DeviceListWidget({
    Key? key,
    required this.devices,
    required this.enableInteractions,
    this.onDeviceSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 準備完整的設備列表（包括網關）
    List<NetworkDevice> allDevices = _prepareDeviceList();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: allDevices.length,
      separatorBuilder: (context, index) => const Divider(
        color: Colors.white30,
        height: 1,
      ),
      itemBuilder: (context, index) {
        final device = allDevices[index];
        final isGateway = index == 0; // 第一個是網關

        return _buildDeviceListTile(device, isGateway);
      },
    );
  }

  /// 準備設備列表（網關 + 客戶端設備）
  List<NetworkDevice> _prepareDeviceList() {
    List<NetworkDevice> allDevices = [];

    // 添加網關設備到列表最前方
    allDevices.add(NetworkDevice(
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

    // 添加客戶端設備
    allDevices.addAll(devices);

    return allDevices;
  }

  /// 建構設備列表項目
  Widget _buildDeviceListTile(NetworkDevice device, bool isGateway) {
    return ListTile(
      leading: _buildDeviceAvatar(device, isGateway),
      title: Text(
        device.name,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${device.ip} | ${device.mac}',
            style: const TextStyle(color: Colors.white70),
          ),
          if (device.additionalInfo.containsKey('uptime'))
            Text(
              'Uptime: ${device.additionalInfo['uptime']}',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildConnectionIcon(device),
          const SizedBox(height: 4),
          _buildStatusIndicator(device),
        ],
      ),
      onTap: enableInteractions ? () => onDeviceSelected?.call(device) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
    );
  }

  /// 建構設備頭像
  Widget _buildDeviceAvatar(NetworkDevice device, bool isGateway) {
    String connectionCount = isGateway ? devices.length.toString() : '2';
    Color backgroundColor = isGateway ? Colors.black : NetworkTopoConfig.primaryColor;

    return CircleAvatar(
      backgroundColor: backgroundColor,
      child: Text(
        connectionCount,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  /// 建構連接圖標
  Widget _buildConnectionIcon(NetworkDevice device) {
    IconData iconData;
    Color iconColor;

    switch (device.connectionType) {
      case ConnectionType.wired:
        iconData = Icons.lan;
        iconColor = Colors.green;
        break;
      case ConnectionType.wireless:
        iconData = Icons.wifi;
        iconColor = Colors.blue;
        break;
      default:
        iconData = Icons.device_unknown;
        iconColor = Colors.grey;
    }

    return Icon(
      iconData,
      color: iconColor,
      size: 20,
    );
  }

  /// 建構狀態指示器
  Widget _buildStatusIndicator(NetworkDevice device) {
    String status = device.additionalInfo['status'] ?? 'unknown';
    bool isOnline = status == 'online' || status == 'up';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isOnline
            ? Colors.green.withOpacity(0.2)
            : Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isOnline ? 'Online' : 'Offline',
        style: TextStyle(
          color: isOnline ? Colors.green : Colors.red,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}