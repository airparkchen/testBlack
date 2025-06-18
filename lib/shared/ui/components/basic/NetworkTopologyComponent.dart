// lib/shared/ui/components/basic/NetworkTopologyComponent.dart - 修正版本
// 🎯 修正：只顯示到父節點的連線，保持原有佈局邏輯

import 'package:flutter/material.dart';
import 'package:whitebox/shared/ui/pages/home/Topo/network_topo_config.dart';
import 'package:whitebox/shared/services/real_data_integration_service.dart';
import 'dart:math' as math;

/// 裝置連接資訊類別
class DeviceConnection {
  /// 裝置ID
  final String deviceId;

  /// 連接的子裝置數量
  final int connectedDevicesCount;

  DeviceConnection({
    required this.deviceId,
    required this.connectedDevicesCount,
  });
}

/// 🎯 修正：網絡拓撲圖元件 - 只連接到父節點
class NetworkTopologyComponent extends StatefulWidget {
  /// 🎯 真實的 Gateway 設備資料
  final NetworkDevice? gatewayDevice;

  /// 中央路由器/網關名稱（保留向後兼容）
  final String gatewayName;

  /// 連接到網關的裝置列表（只包含 Extender）
  final List<NetworkDevice> devices;

  /// 裝置連接資訊列表 (記錄每個裝置連接的子設備數量)
  final List<DeviceConnection>? deviceConnections;

  /// 連接到網關的總設備數量 (用於主機數字顯示，如果不提供則使用devices列表長度)
  final int? totalConnectedDevices;

  /// 是否顯示互聯網圖標
  final bool showInternet;

  /// 元件寬度
  final double width;

  /// 元件高度
  final double height;

  /// 當設備被點擊時的回調
  final Function(NetworkDevice)? onDeviceSelected;

  const NetworkTopologyComponent({
    Key? key,
    this.gatewayDevice,
    required this.gatewayName,
    required this.devices,
    this.deviceConnections,
    this.totalConnectedDevices,
    this.showInternet = true,
    this.width = double.infinity,
    this.height = 400,
    this.onDeviceSelected,
  }) : super(key: key);

  @override
  State<NetworkTopologyComponent> createState() => _NetworkTopologyComponentState();
}

class _NetworkTopologyComponentState extends State<NetworkTopologyComponent> {
  // 佈局常量 - 互聯網圖標位置
  static const double kInternetHorizontalPosition = 0.45;
  static const double kInternetVerticalPosition = 0.25;
  static const double kInternetHorizontalPosition34 = 0.3;

  // 佈局常量 - 主路由器/網關位置
  static const double kGatewayHorizontalPosition = 0.45;
  static const double kGatewayVerticalPosition = 0.5;
  static const double kGatewayHorizontalPosition34 = 0.3;

  // 佈局常量 - 單一設備位置
  static const double kSingleDeviceHorizontalPosition = 0.45;
  static const double kSingleDeviceVerticalPosition = 0.85;

  // 佈局常量 - 兩個設備位置
  static const double kTwoDevicesLeftPosition = 0.3;
  static const double kTwoDevicesRightPosition = 0.6;
  static const double kTwoDevicesVerticalPosition = 0.80;

  // 佈局常量 - 設備右側列位置
  static const double kRightColumnHorizontalPosition = 0.65;

  // 佈局常量 - 垂直排列設備位置
  static const List<double> kThreeDevicesVerticalPositions = [0.2, 0.5, 0.8];

  // 佈局常量 - 設備間距
  static const double kVerticalSpacing = 0.2;

  // 佈局常量 - 圓形大小
  static const double kInternetRadius = 30.0;
  static const double kGatewayRadius = 42.0;
  static const double kDeviceRadius = 35.0;
  static const double kLabelRadius = 12.0;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final actualWidth = widget.width == double.infinity ? screenSize.width : widget.width;
    final actualHeight = widget.height;

    return Container(
      width: actualWidth,
      height: actualHeight,
      color: Colors.transparent,
      child: Stack(
        children: [
          // 🎯 修正：背景和連接線 - 只連接到父節點
          Positioned.fill(
            child: CustomPaint(
              painter: CorrectedConnectionLinesPainter(
                calculateDevicePosition: _calculateDevicePosition,
                devices: widget.devices,
                showInternet: widget.showInternet,
                gatewayPosition: _calculateGatewayPosition(actualWidth, actualHeight),
                internetPosition: widget.showInternet ? _calculateInternetPosition(actualWidth, actualHeight) : null,
                containerWidth: actualWidth,
                containerHeight: actualHeight,
                gatewayDevice: widget.gatewayDevice, // 🎯 新增：傳入 Gateway 資料
              ),
            ),
          ),

          // 互聯網圖標
          if (widget.showInternet) _buildInternetIcon(actualWidth, actualHeight),

          // Gateway 圖標
          _buildGatewayIcon(actualWidth, actualHeight),

          // Extender 設備圖標們
          ...widget.devices.map((device) => _buildDeviceIcon(device, actualWidth, actualHeight)),

          // 獨立的數字標籤們
          _buildGatewayLabel(actualWidth, actualHeight),
          ...widget.devices.map((device) => _buildDeviceLabel(device, actualWidth, actualHeight)),
        ],
      ),
    );
  }

  /// 建構 Gateway 標籤
  Widget _buildGatewayLabel(double containerWidth, double containerHeight) {
    final centerPosition = _calculateGatewayPosition(containerWidth, containerHeight);

    // 優先從真實 Gateway 設備獲取連接數
    int gatewayConnectionCount = 0;

    if (widget.gatewayDevice != null) {
      // 使用真實 Gateway 設備的客戶端數量
      final clientsStr = widget.gatewayDevice!.additionalInfo['clients']?.toString() ?? '0';
      gatewayConnectionCount = int.tryParse(clientsStr) ?? 0;
      print('🎯 Gateway 連接數從真實設備獲取: $gatewayConnectionCount');
    } else if (widget.deviceConnections != null) {
      // 備用方案：嘗試從 deviceConnections 查找
      try {
        final gatewayConnection = widget.deviceConnections!.firstWhere(
              (conn) => conn.deviceId.toLowerCase().contains('gateway') ||
              conn.deviceId.toLowerCase().contains('controller'),
          orElse: () {
            if (widget.deviceConnections!.isNotEmpty) {
              var maxConnection = widget.deviceConnections!.first;
              for (var conn in widget.deviceConnections!) {
                if (conn.connectedDevicesCount > maxConnection.connectedDevicesCount) {
                  maxConnection = conn;
                }
              }
              return maxConnection;
            }
            return DeviceConnection(deviceId: '', connectedDevicesCount: 0);
          },
        );
        gatewayConnectionCount = gatewayConnection.connectedDevicesCount;
        print('🎯 Gateway 連接數從 DeviceConnections 獲取: $gatewayConnectionCount');
      } catch (e) {
        gatewayConnectionCount = widget.totalConnectedDevices ?? 0;
        print('⚠️ 使用預設 Gateway 連接數: $gatewayConnectionCount');
      }
    } else {
      gatewayConnectionCount = widget.totalConnectedDevices ?? 0;
    }

    if (gatewayConnectionCount <= 0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: centerPosition.dx + (kDeviceRadius * 1) - kLabelRadius*1.3,
      top: centerPosition.dy + (kDeviceRadius * 0.9) - kLabelRadius*1.1,
      child: Container(
        width: kLabelRadius * 2,
        height: kLabelRadius * 2,
        decoration: BoxDecoration(
          color: Color(0xFF9747FF),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Center(
          child: Transform.translate(
            offset: const Offset(0, -1.2),
            child: Text(
              gatewayConnectionCount.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 建構設備的獨立數字標籤
  Widget _buildDeviceLabel(NetworkDevice device, double containerWidth, double containerHeight) {
    final centerPosition = _calculateDevicePosition(device, containerWidth, containerHeight);
    final connectionCount = _getDeviceConnectionCount(device.id);

    if (connectionCount <= 0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: centerPosition.dx + (kDeviceRadius * 0.8) - kLabelRadius * 1.3,
      top: centerPosition.dy + (kDeviceRadius * 0.8) - kLabelRadius * 1.1,
      child: Container(
        width: kLabelRadius * 2,
        height: kLabelRadius * 2,
        decoration: BoxDecoration(
          color: Color(0xFF9747FF),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Center(
          child: Transform.translate(
            offset: const Offset(0, -1.2),
            child: Text(
              connectionCount.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 建構互聯網圖標
  Widget _buildInternetIcon(double containerWidth, double containerHeight) {
    final centerPosition = _calculateInternetPosition(containerWidth, containerHeight);

    return Positioned(
      left: centerPosition.dx - kInternetRadius,
      top: centerPosition.dy - kInternetRadius,
      child: GestureDetector(
        onTap: () {
          print('互聯網圖標被點擊');
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: kInternetRadius * 2,
              height: kInternetRadius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: Container(
                width: kInternetRadius * 2,
                height: kInternetRadius * 2,
                child: Center(
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: (kInternetRadius * 2 - 60) / 2,
              top: -5,
              child: Container(
                width: 60,
                child: Text(
                  'Internet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 建構 Gateway 圖標
  Widget _buildGatewayIcon(double containerWidth, double containerHeight) {
    final centerPosition = _calculateGatewayPosition(containerWidth, containerHeight);

    return Positioned(
      left: centerPosition.dx - kGatewayRadius,
      top: centerPosition.dy - kGatewayRadius,
      child: GestureDetector(
        onTap: () {
          if (widget.onDeviceSelected != null) {
            NetworkDevice gatewayDeviceToSelect;

            if (widget.gatewayDevice != null) {
              gatewayDeviceToSelect = widget.gatewayDevice!;
              print('🎯 使用真實 Gateway 設備: ${gatewayDeviceToSelect.name} (${gatewayDeviceToSelect.mac})');
            } else {
              gatewayDeviceToSelect = NetworkDevice(
                name: widget.gatewayName,
                id: 'device-gateway',
                mac: 'unknown',
                ip: '192.168.1.1',
                connectionType: ConnectionType.wired,
                additionalInfo: {
                  'type': 'gateway',
                  'status': 'online',
                  'clients': (widget.totalConnectedDevices ?? 0).toString(),
                },
              );
              print('⚠️ 使用備用 Gateway 設備資料（MAC 未知）');
            }

            widget.onDeviceSelected!(gatewayDeviceToSelect);
          }
        },
        child: Container(
          width: kGatewayRadius * 2,
          height: kGatewayRadius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: ClipOval(
            child: Container(
              color: Colors.black.withOpacity(0),
              child: Center(
                child: Image.asset(
                  'assets/images/icon/router.png',
                  width: 60,
                  height: 60,
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
            ),
          ),
        ),
      ),
    );
  }

  /// 建構設備圖標
  Widget _buildDeviceIcon(NetworkDevice device, double containerWidth, double containerHeight) {
    final centerPosition = _calculateDevicePosition(device, containerWidth, containerHeight);
    final connectionCount = _getDeviceConnectionCount(device.id);

    String iconPath = 'assets/images/icon/mesh.png';

    IconData fallbackIcon = device.connectionType == ConnectionType.wired
        ? Icons.lan
        : Icons.wifi;

    return Positioned(
      left: centerPosition.dx - kDeviceRadius,
      top: centerPosition.dy - kDeviceRadius,
      child: GestureDetector(
        onTap: () {
          if (widget.onDeviceSelected != null) {
            widget.onDeviceSelected!(device);
          }
        },
        child: Container(
          width: kDeviceRadius * 2,
          height: kDeviceRadius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: ClipOval(
            child: Container(
              color: Colors.purple.withOpacity(0.0),
              child: Stack(
                children: [
                  Center(
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        Colors.white.withOpacity(1.0),
                        BlendMode.srcIn,
                      ),
                      child: Image.asset(
                        iconPath,
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            fallbackIcon,
                            color: Colors.white.withOpacity(0.8),
                            size: 15,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 計算互聯網圖標位置
  Offset _calculateInternetPosition(double containerWidth, double containerHeight) {
    if (widget.devices.length >= 3 && widget.devices.length <= 4) {
      return Offset(
          containerWidth * kInternetHorizontalPosition34,
          containerHeight * kInternetVerticalPosition
      );
    } else {
      return Offset(
          containerWidth * kInternetHorizontalPosition,
          containerHeight * kInternetVerticalPosition
      );
    }
  }

  // 計算網關位置
  Offset _calculateGatewayPosition(double containerWidth, double containerHeight) {
    if (widget.devices.length >= 3 && widget.devices.length <= 4) {
      return Offset(
          containerWidth * kGatewayHorizontalPosition34,
          containerHeight * kGatewayVerticalPosition
      );
    } else {
      return Offset(
          containerWidth * kGatewayHorizontalPosition,
          containerHeight * kGatewayVerticalPosition
      );
    }
  }

  // 🎯 保持原有佈局邏輯：計算設備位置
  Offset _calculateDevicePosition(NetworkDevice device, double containerWidth, double containerHeight) {
    final deviceCount = widget.devices.length;
    final index = widget.devices.indexOf(device);

    if (deviceCount == 1) {
      return Offset(
          containerWidth * kSingleDeviceHorizontalPosition,
          containerHeight * kSingleDeviceVerticalPosition
      );
    }
    else if (deviceCount == 2) {
      double horizontalOffset;
      if (index == 0) {
        horizontalOffset = kTwoDevicesLeftPosition;
      } else {
        horizontalOffset = kTwoDevicesRightPosition;
      }

      return Offset(
          containerWidth * horizontalOffset,
          containerHeight * kTwoDevicesVerticalPosition
      );
    }
    else if (deviceCount == 3) {
      double verticalPosition = kThreeDevicesVerticalPositions[index];

      return Offset(
          containerWidth * kRightColumnHorizontalPosition,
          containerHeight * verticalPosition
      );
    }
    else if (deviceCount <= 4) {
      double verticalPosition = 0.2 + index * kVerticalSpacing;

      return Offset(
          containerWidth * kRightColumnHorizontalPosition,
          containerHeight * verticalPosition
      );
    }
    else {
      final gatewayPosition = _calculateGatewayPosition(containerWidth, containerHeight);
      final angle = 2 * math.pi * index / deviceCount;
      return Offset(
        gatewayPosition.dx + 150 * math.cos(angle),
        gatewayPosition.dy + 150 * math.sin(angle),
      );
    }
  }

  // 獲取裝置的連接數量
  int _getDeviceConnectionCount(String deviceId) {
    if (widget.deviceConnections == null) return 0;

    try {
      final connection = widget.deviceConnections!.firstWhere(
              (conn) => conn.deviceId == deviceId
      );
      return connection.connectedDevicesCount;
    } catch (e) {
      return 0;
    }
  }
}

/// 🎯 修正：只負責繪製正確連接線的 CustomPainter
class CorrectedConnectionLinesPainter extends CustomPainter {
  final List<NetworkDevice> devices;
  final bool showInternet;
  final Offset gatewayPosition;
  final Offset? internetPosition;
  final double containerWidth;
  final double containerHeight;
  final Offset Function(NetworkDevice, double, double) calculateDevicePosition;
  final NetworkDevice? gatewayDevice; // 🎯 新增：Gateway 設備資料

  CorrectedConnectionLinesPainter({
    required this.devices,
    required this.showInternet,
    required this.gatewayPosition,
    this.internetPosition,
    required this.containerWidth,
    required this.containerHeight,
    required this.calculateDevicePosition,
    this.gatewayDevice, // 🎯 新增參數
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 繪製互聯網到網關的連線
    if (showInternet && internetPosition != null) {
      _drawConnection(canvas, internetPosition!, gatewayPosition, ConnectionType.wired);
    }

    // 🎯 修正：根據真實的父節點關係繪製連線
    _drawParentBasedConnections(canvas, size);
  }

  /// 🎯 新增：根據父節點關係繪製連線
  void _drawParentBasedConnections(Canvas canvas, Size size) {
    if (!NetworkTopoConfig.showExtenderConnections) {
      // 🎯 如果關閉 Extender 連線顯示，則使用原始邏輯（全部連到 Gateway）
      for (var device in devices) {
        final devicePosition = calculateDevicePosition(device, containerWidth, containerHeight);
        _drawConnection(canvas, gatewayPosition, devicePosition, device.connectionType);
      }
      return;
    }

    try {
      // 🎯 修正：根據 parentAccessPoint 決定連線目標
      for (var device in devices) {
        final devicePosition = calculateDevicePosition(device, containerWidth, containerHeight);
        final parentMAC = device.additionalInfo['parentAccessPoint']?.toString() ?? '';

        print('🔍 [CONNECTION] 分析設備連線: ${device.name}');
        print('   └─ 父節點 MAC: $parentMAC');

        if (parentMAC.isEmpty) {
          // 沒有父節點資訊，連接到 Gateway
          print('   └─ 連接到: Gateway (無父節點資訊)');
          _drawConnection(canvas, gatewayPosition, devicePosition, device.connectionType);
          continue;
        }

        // 🎯 關鍵修正：檢查父節點是 Gateway 還是其他 Extender
        if (gatewayDevice != null && parentMAC == gatewayDevice!.mac) {
          // 父節點是 Gateway，連接到 Gateway
          print('   └─ 連接到: Gateway');
          _drawConnection(canvas, gatewayPosition, devicePosition, device.connectionType);
        } else {
          // 🎯 父節點是其他 Extender，尋找父 Extender 並連接
          NetworkDevice? parentDevice;
          try {
            parentDevice = devices.firstWhere((d) => d.mac == parentMAC);
            print('   └─ 連接到: Extender ${parentDevice.name}');
          } catch (e) {
            print('   └─ 找不到父設備，連接到 Gateway');
            _drawConnection(canvas, gatewayPosition, devicePosition, device.connectionType);
            continue;
          }

          if (parentDevice != null) {
            final parentPosition = calculateDevicePosition(parentDevice, containerWidth, containerHeight);
            _drawConnection(canvas, parentPosition, devicePosition, device.connectionType);
            print('   └─ ✅ 已繪製到父 Extender 的連線');
          }
        }
      }
    } catch (e) {
      print('❌ [CONNECTION] 繪製連線時發生錯誤: $e');
      // 發生錯誤時使用備用邏輯：全部連到 Gateway
      for (var device in devices) {
        final devicePosition = calculateDevicePosition(device, containerWidth, containerHeight);
        _drawConnection(canvas, gatewayPosition, devicePosition, device.connectionType);
      }
    }
  }

  // 繪製連接線
  void _drawConnection(Canvas canvas, Offset start, Offset end, ConnectionType type) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    if (distance < 0.001) return;

    final unitX = dx / distance;
    final unitY = dy / distance;

    double startRadius = 35.0;
    double endRadius = 35.0;

    if (type == ConnectionType.wireless) {
      startRadius = 32.0;
      endRadius = 28.0;
    }

    if (start == gatewayPosition) {
      startRadius = 42.0;
    }
    if (end == gatewayPosition) {
      endRadius = 42.0;
    }
    if (start == internetPosition) {
      startRadius = 8.0;
    }
    if (end == internetPosition) {
      endRadius = 8.0;
    }

    final adjustedStart = Offset(
      start.dx + unitX * startRadius,
      start.dy + unitY * startRadius,
    );
    final adjustedEnd = Offset(
      end.dx - unitX * endRadius,
      end.dy - unitY * endRadius,
    );

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0;

    if (type == ConnectionType.wired) {
      canvas.drawLine(adjustedStart, adjustedEnd, paint);
    } else {
      _drawDashedLine(canvas, adjustedStart, adjustedEnd, paint);
    }
  }

  // 繪製虛線
  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLength = 5.0;
    const gapLength = 5.0;

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    final iterations = (distance / (dashLength + gapLength)).floor();
    final normalizedDx = dx / distance;
    final normalizedDy = dy / distance;

    for (int i = 0; i < iterations; i++) {
      final startDashX = start.dx + normalizedDx * (dashLength + gapLength) * i;
      final startDashY = start.dy + normalizedDy * (dashLength + gapLength) * i;
      final endDashX = startDashX + normalizedDx * dashLength;
      final endDashY = startDashY + normalizedDy * dashLength;

      canvas.drawLine(
        Offset(startDashX, startDashY),
        Offset(endDashX, endDashY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CorrectedConnectionLinesPainter oldDelegate) => true;
}

/// 網絡設備類
class NetworkDevice {
  final String name;
  final String id;
  final String mac;
  final String ip;
  final ConnectionType connectionType;
  final Map<String, dynamic> additionalInfo;

  NetworkDevice({
    required this.name,
    required this.id,
    required this.mac,
    required this.ip,
    required this.connectionType,
    this.additionalInfo = const {},
  });
}

/// 連接類型枚舉
enum ConnectionType {
  wired,
  wireless
}