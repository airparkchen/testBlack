// lib/shared/ui/components/basic/device_list_widget.dart

import 'package:flutter/material.dart';
import 'package:whitebox/shared/ui/components/basic/NetworkTopologyComponent.dart';
import 'package:whitebox/shared/ui/pages/home/Topo/network_topo_config.dart';
import 'package:whitebox/shared/ui/pages/home/DeviceDetailPage.dart';
import 'package:whitebox/shared/theme/app_theme.dart';


/// 設備列表組件 - 修改為卡片樣式
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
    final AppTheme appTheme = AppTheme();

    // 準備完整的設備列表（包括網關）
    List<DeviceListItem> allDevices = _prepareDeviceList();

    return LayoutBuilder(
      builder: (context, constraints) {
        // 使用父容器提供的實際可用空間
        final double availableHeight = constraints.maxHeight;

        return Container(
          width: constraints.maxWidth,
          height: availableHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRect(   //定義裁剪邊界
            child: Padding(  //縮小可視區域
              padding: const EdgeInsets.only(
                top: 50,    // 👈 控制上限（消失線距離頂部多遠）
                bottom: 0, // 👈 控制下限（消失線距離底部多遠）
              ), // 控制裁剪區域的邊界 (消失線)
              child: ListView.separated(   //列表
                padding: const EdgeInsets.symmetric(vertical: 20),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: allDevices.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final deviceItem = allDevices[index];

                  return appTheme.whiteBoxTheme.buildStandardCard(
                    width: double.infinity,
                    height: deviceItem.isGateway ? 100 : 95,
                    child: InkWell(
                      // onTap: enableInteractions ? () {
                      //   // 導航到設備詳情頁面
                      //   Navigator.of(context).push(
                      //     MaterialPageRoute(
                      //       builder: (context) => DeviceDetailPage(
                      //         selectedDevice: deviceItem.device,
                      //         isGateway: deviceItem.isGateway,
                      //         // connectedClients: [], // 可選：如果有預先載入的客戶端資料
                      //       ),
                      //     ),
                      //   );
                      // } : null,
                      onTap: enableInteractions ? () {
                        // 👈 修改：直接使用回調，不再使用 Navigator
                        onDeviceSelected?.call(deviceItem.device);
                      } : null,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // 左側圖標區域
                            _buildDeviceIcon(deviceItem),

                            const SizedBox(width: 16),

                            // 右側資訊區域
                            Expanded(
                              child: _buildDeviceInfo(deviceItem),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// 準備設備列表（網關 + 客戶端設備）
  List<DeviceListItem> _prepareDeviceList() {
    List<DeviceListItem> allDevices = [];

    // 添加網關設備到列表最前方
    allDevices.add(DeviceListItem(
      device: NetworkDevice(
        name: 'Controller',
        id: 'router-001',
        mac: '48:21:0B:4A:46:CF',
        ip: '192.168.1.1',
        connectionType: ConnectionType.wired,
        additionalInfo: {
          'type': 'router',
          'status': 'online',
          'clients': devices.length,
          'rssi': '',
        },
      ),
      isGateway: true,
    ));

    // 添加客戶端設備
    for (var device in devices) {
      allDevices.add(DeviceListItem(
        device: NetworkDevice(
          name: _getAgentName(device),
          id: device.id,
          mac: device.mac,
          ip: device.ip,
          connectionType: device.connectionType,
          additionalInfo: {
            'type': 'mesh_agent',
            'status': device.additionalInfo['status'] ?? 'online',
            'clients': 2,
            'rssi': '-25, -39',
          },
        ),
        isGateway: false,
      ));
    }

    return allDevices;
  }

  /// 根據設備生成 Agent 名稱
  String _getAgentName(NetworkDevice device) {
    // 第一個設備顯示 MAC，其他只顯示 Agent
    if (devices.indexOf(device) == 0) {
      return 'Agent(MAC) ${device.mac}';
    } else {
      return 'Agent ${device.mac}';
    }
  }

  /// 建構設備圖標
  Widget _buildDeviceIcon(DeviceListItem deviceItem) {
    if (deviceItem.isGateway) {
      // Gateway 圖標 - 較大，參考 NetworkTopologyComponent
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        ),
        child: Center(
          child: Image.asset(
            'assets/images/icon/router.png',
            width: 40,
            height: 40,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.router,
                color: Colors.white,
                size: 25,
              );
            },
          ),
        ),
      );
    } else {
      // Agent/Mesh 圖標 - 較小，使用 mesh.png
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        ),
        child: Center(
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.white.withOpacity(1.0),  // 調整圖標顏色飽和度
              BlendMode.srcIn,
            ),
            child: Image.asset(
              'assets/images/icon/mesh.png',
              width: 30,
              height: 30,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.lan,
                  color: Colors.white.withOpacity(0.8),
                  size: 20,
                );
              },
            ),
          ),
        ),
      );
    }
  }

  /// 建構設備資訊
  Widget _buildDeviceInfo(DeviceListItem deviceItem) {
    final device = deviceItem.device;
    final isGateway = deviceItem.isGateway;

    if (isGateway) {
      // Gateway 資訊顯示 - 保持原樣
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center, // 👈 Gateway 保持 center
        children: [
          Text(
            '${device.name} ${device.mac}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Clients: ${device.additionalInfo['clients']}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      );
    } else {
      // Agent 資訊顯示 - 使用 Transform 讓文字群組向上移動
      return Transform.translate(
        offset: const Offset(0, -8), // 👈 讓整個文字群組向上移動 8 pixels
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              device.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              'IP Address: ${device.ip}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              'RSSI: ${device.additionalInfo['rssi']}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              'Clients: ${device.additionalInfo['clients']}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }
  }
}

/// 設備列表項目類
class DeviceListItem {
  final NetworkDevice device;
  final bool isGateway;

  DeviceListItem({
    required this.device,
    required this.isGateway,
  });
}