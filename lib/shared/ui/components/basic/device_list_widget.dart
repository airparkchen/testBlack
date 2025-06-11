// lib/shared/ui/components/basic/device_list_widget.dart - 修正版本

import 'package:flutter/material.dart';
import 'package:whitebox/shared/ui/components/basic/NetworkTopologyComponent.dart';
import 'package:whitebox/shared/ui/pages/home/Topo/network_topo_config.dart';
import 'package:whitebox/shared/ui/pages/home/DeviceDetailPage.dart';
import 'package:whitebox/shared/theme/app_theme.dart';

/// 設備列表組件 - 修正版本
/// 🎯 關鍵修正：直接使用傳入的設備列表，不再自行添加 Gateway
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

    // 🎯 修正：直接使用傳入的設備列表，不再重複處理
    print('=== DeviceListWidget Debug ===');
    print('傳入設備數量: ${devices.length}');
    for (var device in devices) {
      print('設備: ${device.name} (${device.id})');
      print('  MAC: ${device.mac}');
      print('  類型: ${device.additionalInfo['type']}');
      print('  客戶端數: ${device.additionalInfo['clients']}');
    }
    print('============================');

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableHeight = constraints.maxHeight;

        return Container(
          width: constraints.maxWidth,
          height: availableHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRect(
            child: Padding(
              padding: const EdgeInsets.only(
                top: 50,
                bottom: 0,
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 20),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: devices.length, // 🎯 直接使用傳入的設備數量
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final device = devices[index];
                  final isGateway = device.additionalInfo['type'] == 'gateway';

                  return appTheme.whiteBoxTheme.buildStandardCard(
                    width: double.infinity,
                    height: isGateway ? 100 : 95,
                    child: InkWell(
                      onTap: enableInteractions ? () {
                        // 🎯 修正：傳遞正確的設備資訊到詳情頁面
                        print('點擊設備: ${device.name} (${device.additionalInfo['type']})');
                        onDeviceSelected?.call(device);
                      } : null,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // 左側圖標區域
                            _buildDeviceIcon(device, isGateway),

                            const SizedBox(width: 16),

                            // 右側資訊區域
                            Expanded(
                              child: _buildDeviceInfo(device, isGateway),
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

  /// 🎯 修正：建構設備圖標
  Widget _buildDeviceIcon(NetworkDevice device, bool isGateway) {
    if (isGateway) {
      // Gateway 圖標 - 約束置中
      return SizedBox(
        width: 60,
        height: 80, // 🎯 配合卡片高度調整
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // 🎯 垂直置中
          crossAxisAlignment: CrossAxisAlignment.center, // 🎯 水平置中
          children: [
            Container(
              width: 60, // 🎯 固定圖標容器大小
              height: 60,
              alignment: Alignment.center, // 🎯 容器內容置中
              child: Image.asset(
                'assets/images/icon/router.png',
                width: 60,
                height: 60,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.router,
                    color: Colors.white,
                    size: 40, // 🎯 調整後備圖標大小
                  );
                },
              ),
            ),
          ],
        ),
      );
    } else {
      // Extender 圖標 - 約束置中
      return SizedBox(
        width: 60,
        height: 80, // 🎯 配合卡片高度調整
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // 🎯 垂直置中
          crossAxisAlignment: CrossAxisAlignment.center, // 🎯 水平置中
          children: [
            Container(
              width: 50, // 🎯 固定圖標容器大小
              height: 50,
              alignment: Alignment.center, // 🎯 容器內容置中
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.white.withOpacity(1.0),
                  BlendMode.srcIn,
                ),
                child: Image.asset(
                  'assets/images/icon/mesh.png',
                  width: 60, // 🎯 調整圖標大小
                  height: 60,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.lan,
                      color: Colors.white.withOpacity(1.0),
                      size: 30, // 🎯 調整後備圖標大小
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }
  }


  /// 🎯 修正：建構設備資訊
  Widget _buildDeviceInfo(NetworkDevice device, bool isGateway) {
    // 🎯 從 additionalInfo 中正確獲取客戶端數量
    final String clientsStr = device.additionalInfo['clients']?.toString() ?? '0';
    final int clientCount = int.tryParse(clientsStr) ?? 0;

    if (isGateway) {
      // Gateway 資訊顯示
      return SizedBox(
          height: 80, // 🎯 配合圖標高度
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${device.name} ${device.mac}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.normal,
              height: 1.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            'Clients: $clientCount', // 🎯 使用正確的客戶端數量
            style: TextStyle(
              color: Colors.white.withOpacity(1.0),
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      )
    );
    } else {
      // Extender 資訊顯示
      return SizedBox(
        height: 80, // 🎯 配合圖標高度
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              device.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              'IP Address: ${device.ip}',
              style: TextStyle(
                color: Colors.white.withOpacity(1.0),
                fontSize: 12,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              'RSSI: ${device.additionalInfo['rssi']}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Clients: $clientCount', // 🎯 使用正確的客戶端數量
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11,
                height: 1.2,
              ),
            ),
          ],
        ),
      );
    }
  }
}