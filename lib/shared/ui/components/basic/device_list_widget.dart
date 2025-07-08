// lib/shared/ui/components/basic/device_list_widget.dart - 修正有線連接顯示

import 'package:flutter/material.dart';
import 'package:whitebox/shared/ui/components/basic/NetworkTopologyComponent.dart';
import 'package:whitebox/shared/ui/pages/home/Topo/network_topo_config.dart';
import 'package:whitebox/shared/ui/pages/home/DeviceDetailPage.dart';
import 'package:whitebox/shared/theme/app_theme.dart';

/// 設備列表組件 - 修正有線連接顯示版本
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

  /// 🔧 新增：判斷設備是否為有線連接
  bool _isWiredConnection(NetworkDevice device) {
    final connectionType = device.additionalInfo['connectionDescription']?.toString() ?? '';
    final type = device.additionalInfo['type']?.toString() ?? '';

    // 檢查連接描述是否包含 Ethernet 關鍵字
    if (connectionType.toLowerCase().contains('ethernet') ||
        connectionType.toLowerCase().contains('有線')) {
      return true;
    }

    // 檢查 connectionType 原始資料
    final rawConnectionType = device.additionalInfo['connectionType']?.toString() ?? '';
    if (rawConnectionType.toLowerCase() == 'ethernet') {
      return true;
    }

    // Gateway 通常是有線連接
    if (type == 'gateway') {
      return true;
    }

    return false;
  }

  /// 🔧 新增：格式化 RSSI 顯示
  String _formatRSSIDisplay(NetworkDevice device) {
    if (_isWiredConnection(device)) {
      return 'Ethernet'; // 🔥 有線連接顯示 "Ethernet"
    }

    final rssiStr = device.additionalInfo['rssi']?.toString() ?? '';
    if (rssiStr.isEmpty || rssiStr == '0' || rssiStr == '0,0,0') {
      return ''; // 🔥 RSSI 為 0 或空時不顯示（過渡狀態）
    }

    return 'RSSI: $rssiStr';
  }

  /// 🔧 新增：檢查是否應該顯示 RSSI 行
  bool _shouldShowRSSI(NetworkDevice device) {
    if (_isWiredConnection(device)) {
      return true; // 有線連接顯示 "Ethernet"
    }

    final rssiStr = device.additionalInfo['rssi']?.toString() ?? '';
    return rssiStr.isNotEmpty && rssiStr != '0' && rssiStr != '0,0,0';
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme appTheme = AppTheme();

    print('=== DeviceListWidget Debug ===');
    print('傳入設備數量: ${devices.length}');
    for (var device in devices) {
      print('設備: ${device.name} (${device.id})');
      print('  MAC: ${device.mac}');
      print('  類型: ${device.additionalInfo['type']}');
      print('  客戶端數: ${device.additionalInfo['clients']}');
      print('  連接類型: ${device.additionalInfo['connectionDescription']}');
      print('  是否有線: ${_isWiredConnection(device)}');
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
                itemCount: devices.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final device = devices[index];
                  final isGateway = device.additionalInfo['type'] == 'gateway';

                  return appTheme.whiteBoxTheme.buildStandardCard(
                    width: double.infinity,
                    height: isGateway ? 100 : 95,
                    child: InkWell(
                      onTap: enableInteractions ? () {
                        print('點擊設備: ${device.name} (${device.additionalInfo['type']})');
                        onDeviceSelected?.call(device);
                      } : null,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                      child: Padding(
                        padding: isGateway
                            ? const EdgeInsets.all(16)
                            : const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
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

  /// 設備圖標
  Widget _buildDeviceIcon(NetworkDevice device, bool isGateway) {
    if (isGateway) {
      // Gateway 圖標 - 保持置中
      return SizedBox(
        width: 60,
        height: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              child: Image.asset(
                'assets/images/icon/router.png',
                width: 60,
                height: 60,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.router,
                    color: Colors.white,
                    size: 40,
                  );
                },
              ),
            ),
          ],
        ),
      );
    } else {
      // Extender 圖標
      return SizedBox(
        width: 60,
        height: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 4),
            Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.white.withOpacity(1.0),
                  BlendMode.srcIn,
                ),
                child: Image.asset(
                  'assets/images/icon/mesh.png',
                  width: 60,
                  height: 60,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.lan,
                      color: Colors.white.withOpacity(1.0),
                      size: 30,
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

  /// 🔧 修正：建構設備資訊 - 智能 RSSI 顯示
  Widget _buildDeviceInfo(NetworkDevice device, bool isGateway) {
    final String clientsStr = device.additionalInfo['clients']?.toString() ?? '0';
    final int clientCount = int.tryParse(clientsStr) ?? 0;

    if (isGateway) {
      // Gateway 資訊顯示（保持原有邏輯）
      return SizedBox(
         height: 80,
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
              'Clients: $clientCount',
              style: TextStyle(
                color: Colors.white.withOpacity(1.0),
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        ),
      );
    } else {
      // 🔧 Extender 資訊顯示 - 智能 RSSI 處理
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            'Agent ${device.mac}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
            maxLines: 2,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),

          // 🔥 關鍵修正：智能 RSSI 顯示
          if (_shouldShowRSSI(device)) ...[
            Text(
              _formatRSSIDisplay(device),
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
          ],

          Text(
            'Clients: $clientCount',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 11,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }
  }
}