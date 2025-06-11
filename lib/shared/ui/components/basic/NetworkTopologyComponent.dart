import 'package:flutter/material.dart';
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

/// 網絡拓撲圖元件 - 使用 Stack + Image.asset() 方式
///
/// 顯示網絡設備之間的連接關係，包括有線和無線連接
/// 根據設備數量自動調整佈局
/// 這種實現方式與專案中其他圖片使用方式保持一致
class NetworkTopologyComponent extends StatefulWidget {
  /// 中央路由器/網關名稱
  final String gatewayName;

  /// 連接到網關的裝置列表
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
  static const double kInternetHorizontalPosition = 0.45;  // 水平位置 (比例，0.5 = 50%)
  static const double kInternetVerticalPosition = 0.25;   // 垂直位置 (比例，0.25 = 25%)
  static const double kInternetHorizontalPosition34 = 0.3;  // 3-4設備時的水平位置

  // 佈局常量 - 主路由器/網關位置
  static const double kGatewayHorizontalPosition = 0.45;   // 水平位置 (比例，0.5 = 50%)
  static const double kGatewayVerticalPosition = 0.5;     // 垂直位置 (比例，0.5 = 50%)
  static const double kGatewayHorizontalPosition34 = 0.3; // 3-4設備時的網關水平位置

  // 佈局常量 - 單一設備位置 (一個設備時)
  static const double kSingleDeviceHorizontalPosition = 0.45;  // 水平位置 (比例，0.5 = 50%)
  static const double kSingleDeviceVerticalPosition = 0.85;   // 垂直位置 (比例，0.85 = 85%)

  // 佈局常量 - 兩個設備位置 (兩個設備時的水平分布)
  static const double kTwoDevicesLeftPosition = 0.3;     // 左側設備水平位置 (比例，0.3 = 30%)
  static const double kTwoDevicesRightPosition = 0.6;    // 右側設備水平位置 (比例，0.7 = 70%)
  static const double kTwoDevicesVerticalPosition = 0.80; // 兩個設備共用的垂直位置 (比例，0.85 = 85%)

  // 佈局常量 - 設備右側列位置 (3-4個設備時)
  static const double kRightColumnHorizontalPosition = 0.65;  // 右側列水平位置 (比例，0.65 = 65%)

  // 佈局常量 - 垂直排列設備位置 (3個設備時的垂直分布)
  static const List<double> kThreeDevicesVerticalPositions = [0.2, 0.5, 0.8];  // 垂直位置列表

  // 佈局常量 - 設備間距 (4個以上設備時使用)
  static const double kVerticalSpacing = 0.2;  // 垂直間距 (比例，0.2 = 20%)

  // 佈局常量 - 圓形大小
  static const double kInternetRadius = 30.0;  // 互聯網圖標半徑
  static const double kGatewayRadius = 42.0;   // 網關圖標半徑  gateway
  static const double kDeviceRadius = 35.0;    // 設備圖標半徑
  static const double kLabelRadius = 12.0;     // 標籤圓形半徑

  @override
  Widget build(BuildContext context) {
    // 獲取螢幕尺寸並計算實際容器尺寸
    final screenSize = MediaQuery.of(context).size;
    final actualWidth = widget.width == double.infinity ? screenSize.width : widget.width;
    final actualHeight = widget.height;

    return Container(
      width: actualWidth,
      height: actualHeight,
      color: Colors.transparent,
      child: Stack(
        children: [
          // 背景和連接線 - 使用 CustomPainter 只繪製線條
          Positioned.fill(
            child: CustomPaint(
              painter: ConnectionLinesPainter(
                calculateDevicePosition: _calculateDevicePosition,
                devices: widget.devices,
                showInternet: widget.showInternet,
                gatewayPosition: _calculateGatewayPosition(actualWidth, actualHeight),
                internetPosition: widget.showInternet ? _calculateInternetPosition(actualWidth, actualHeight) : null,
                containerWidth: actualWidth,
                containerHeight: actualHeight,
              ),
            ),
          ),

          // 互聯網圖標
          if (widget.showInternet) _buildInternetIcon(actualWidth, actualHeight),

          // 網關圖標（無數字標籤）
          _buildGatewayIcon(actualWidth, actualHeight),

          // 設備圖標們（無數字標籤）
          ...widget.devices.map((device) => _buildDeviceIcon(device, actualWidth, actualHeight)),

          // 獨立的數字標籤們 - 放在最後確保在最上層
          _buildGatewayLabel(actualWidth, actualHeight),
          ...widget.devices.map((device) => _buildDeviceLabel(device, actualWidth, actualHeight)),
        ],
      ),
    );
  }

// 修正 _buildGatewayLabel 方法，確保能正確獲取 Gateway 的連接數
  Widget _buildGatewayLabel(double containerWidth, double containerHeight) {
    final centerPosition = _calculateGatewayPosition(containerWidth, containerHeight);

    // 🎯 修正：改為從 deviceConnections 中查找 Gateway 的連接數
    int gatewayConnectionCount = 0;

    if (widget.deviceConnections != null) {
      // 嘗試從連接資料中找到 Gateway 的連接數
      try {
        // Gateway 的設備 ID 通常是 'gateway' 或以 gateway MAC 生成
        final gatewayConnection = widget.deviceConnections!.firstWhere(
              (conn) => conn.deviceId.contains('gateway') ||
              conn.deviceId.contains('00037fbadbad') || // 根據 log 中的 MAC
              conn.deviceId.toLowerCase().contains('controller'),
          orElse: () => DeviceConnection(deviceId: '', connectedDevicesCount: 0),
        );

        gatewayConnectionCount = gatewayConnection.connectedDevicesCount;
        print('🔍 Gateway 連接數從 DeviceConnections 獲取: $gatewayConnectionCount');
      } catch (e) {
        print('⚠️ 無法從 DeviceConnections 獲取 Gateway 連接數，使用預設值');
        gatewayConnectionCount = widget.totalConnectedDevices ?? widget.devices.length;
      }
    } else {
      // 如果沒有 deviceConnections，使用 totalConnectedDevices
      gatewayConnectionCount = widget.totalConnectedDevices ?? widget.devices.length;
    }

    print('🎯 Gateway 最終顯示連接數: $gatewayConnectionCount');

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
            offset: const Offset(0, -1.2),  //clients數字位置
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

  // 建構網關的獨立數字標籤
// 建構獨立的數字標籤
  Widget _buildDeviceLabel(NetworkDevice device, double containerWidth, double containerHeight) {
    final centerPosition = _calculateDevicePosition(device, containerWidth, containerHeight);
    final connectionCount = _getDeviceConnectionCount(device.id);

    //如果數量為 0 就不顯示
    if (connectionCount <= 0) {
      return const SizedBox.shrink(); // 返回空 Widget
    }

    return Positioned(
      // 計算標籤位置：設備圓心 + 設備半徑 + 標籤偏移
      left: centerPosition.dx + (kDeviceRadius * 0.8) - kLabelRadius*1.3,  // 往左移一點
      top: centerPosition.dy + (kDeviceRadius * 0.8) - kLabelRadius*1.1,   // 往上移一點
      child: Container(
        width: kLabelRadius * 2,
        height: kLabelRadius * 2,
        decoration: BoxDecoration(
          color: Color(0xFF9747FF),  // 完全不透明
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1), // 可選：加個白邊
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

  // 建構互聯網圖標 - 傳入實際尺寸
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
          clipBehavior: Clip.none, // 允許文字溢出到圓圈範圍外
          children: [
            // 原本的白色圓點
            Container(
              width: kInternetRadius * 2,
              height: kInternetRadius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // border: Border.all(color: Colors.white, width: 2),
              ),
              child: Container(
                width: kInternetRadius * 2,
                height: kInternetRadius * 2,
                child: Center(
                  child: Container(
                    width: 20,  // 白點大小
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),

            // 新增的"internet"文字標籤
            Positioned(
              // 將文字置中對齊白點，並向上偏移5px
              left: (kInternetRadius * 2 - 60) / 2, // 50是預估文字寬度，讓文字水平置中
              top: -5 , // 向上偏移5px，再減去文字高度(約16px)讓文字完全在白點上方
              child: Container(
                width: 60, // 文字容器寬度
                child: Text(
                  'Internet',
                  textAlign: TextAlign.center, // 文字置中
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    // fontWeight: FontWeight.w400, // 普通字重
                    fontWeight: FontWeight.bold, // 粗體字重
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// 修正 _buildGatewayIcon 方法中的點擊事件，使用正確的 Gateway 資訊
  Widget _buildGatewayIcon(double containerWidth, double containerHeight) {
    final centerPosition = _calculateGatewayPosition(containerWidth, containerHeight);

    return Positioned(
      left: centerPosition.dx - kGatewayRadius,
      top: centerPosition.dy - kGatewayRadius,
      child: GestureDetector(
        onTap: () {
          if (widget.onDeviceSelected != null) {
            // 🎯 修正：創建正確的 Gateway 設備物件
            final gatewayDevice = NetworkDevice(
              name: widget.gatewayName, // 使用傳入的 Gateway 名稱
              id: _getGatewayDeviceId(), // 🎯 使用正確的 Gateway ID
              mac: _extractGatewayMacFromConnections(), // 🎯 從連接資料中提取真實 MAC
              ip: '192.168.1.1',
              connectionType: ConnectionType.wired,
              additionalInfo: {
                'type': 'gateway',
                'status': 'online',
                'clients': _getGatewayConnectionCount().toString(), // 🎯 正確的客戶端數量
              },
            );
            widget.onDeviceSelected!(gatewayDevice);
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

  // 🎯 新增：輔助方法來獲取 Gateway 的正確資訊

  /// 從 DeviceConnections 中提取 Gateway 的 MAC 地址
  String _extractGatewayMacFromConnections() {
    if (widget.deviceConnections == null) return '00:03:7f:ba:db:ad'; // 預設值

    try {
      // 查找 Gateway 的連接資料
      final gatewayConnection = widget.deviceConnections!.firstWhere(
            (conn) => conn.deviceId.contains('00037fbadbad'), // 根據 log 中的真實 MAC
        orElse: () => DeviceConnection(deviceId: 'device-00037fbadbad', connectedDevicesCount: 0),
      );

      // 從 deviceId 提取 MAC 地址
      String deviceId = gatewayConnection.deviceId;
      if (deviceId.startsWith('device-')) {
        String macWithoutColons = deviceId.substring(7); // 移除 'device-' 前綴
        // 將 MAC 地址格式化為標準格式
        if (macWithoutColons.length == 12) {
          return macWithoutColons.replaceAllMapped(
              RegExp(r'(.{2})'),
                  (match) => '${match.group(1)}:'
          ).substring(0, 17); // 移除最後一個冒號
        }
      }

      return '00:03:7f:ba:db:ad'; // 預設值
    } catch (e) {
      print('⚠️ 無法提取 Gateway MAC，使用預設值: $e');
      return '00:03:7f:ba:db:ad';
    }
  }

  /// 獲取 Gateway 的設備 ID
  String _getGatewayDeviceId() {
    if (widget.deviceConnections == null) return 'device-00037fbadbad';

    try {
      final gatewayConnection = widget.deviceConnections!.firstWhere(
            (conn) => conn.deviceId.contains('00037fbadbad'),
        orElse: () => DeviceConnection(deviceId: 'device-00037fbadbad', connectedDevicesCount: 0),
      );
      return gatewayConnection.deviceId;
    } catch (e) {
      return 'device-00037fbadbad';
    }
  }

  int _getGatewayConnectionCount() {
    if (widget.deviceConnections == null) {
      return widget.totalConnectedDevices ?? widget.devices.length;
    }

    try {
      final gatewayConnection = widget.deviceConnections!.firstWhere(
            (conn) => conn.deviceId.contains('00037fbadbad'),
        orElse: () => DeviceConnection(deviceId: '', connectedDevicesCount: 0),
      );
      return gatewayConnection.connectedDevicesCount;
    } catch (e) {
      return widget.totalConnectedDevices ?? widget.devices.length;
    }
  }

    // 建構設備圖標 - 傳入實際尺寸
  Widget _buildDeviceIcon(NetworkDevice device, double containerWidth, double containerHeight) {
    final centerPosition = _calculateDevicePosition(device, containerWidth, containerHeight);
    final connectionCount = _getDeviceConnectionCount(device.id);

    // String iconPath = device.connectionType == ConnectionType.wired
    //     ? 'assets/images/icon/mesh.png'
    //     : 'assets/images/icon/router.png';
    String iconPath = 'assets/images/icon/mesh.png';

    //調整有線與無線 (連線)
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
                        Colors.white.withOpacity(1.0),  //調整裝置圖標顏色飽和度
                        BlendMode.srcIn,
                      ),
                      child: Image.asset(   //裝置圖標大小
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
                  // Positioned(
                  //   right: -5,
                  //   bottom: -5,
                  //   child: Container(
                  //     width: kLabelRadius * 2,
                  //     height: kLabelRadius * 2,
                  //     decoration: BoxDecoration(
                  //       color: Colors.purple.withOpacity(0.7),
                  //       shape: BoxShape.circle,
                  //     ),
                  //     child: Center(
                  //       child: Text(
                  //         connectionCount.toString(),
                  //         style: const TextStyle(
                  //           color: Colors.white,
                  //           fontSize: 12,
                  //           fontWeight: FontWeight.bold,
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 計算互聯網圖標位置 - 使用實際尺寸
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

  // 計算網關位置 - 使用實際尺寸
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

  // 計算設備位置 - 使用實際尺寸，保持原始邏輯
  Offset _calculateDevicePosition(NetworkDevice device, double containerWidth, double containerHeight) {
    final deviceCount = widget.devices.length;
    final index = widget.devices.indexOf(device);

    // 根據設備數量決定佈局 - 保持原始邏輯
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
          containerWidth * kRightColumnHorizontalPosition, // 調整右側列位置
          containerHeight * verticalPosition
      );
    }
    else if (deviceCount <= 4) {
      double verticalPosition = 0.2 + index * kVerticalSpacing;

      return Offset(
          containerWidth * kRightColumnHorizontalPosition, // 調整右側列位置
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
    if (widget.deviceConnections == null) return 2;

    try {
      final connection = widget.deviceConnections!.firstWhere(
              (conn) => conn.deviceId == deviceId
      );
      return connection.connectedDevicesCount;
    } catch (e) {
      return 2;
    }
  }
}

/// 只負責繪製連接線的 CustomPainter
class ConnectionLinesPainter extends CustomPainter {
  final List<NetworkDevice> devices;
  final bool showInternet;
  final Offset gatewayPosition;
  final Offset? internetPosition;
  final double containerWidth;
  final double containerHeight;
  final Offset Function(NetworkDevice, double, double) calculateDevicePosition;

  ConnectionLinesPainter({
    required this.devices,
    required this.showInternet,
    required this.gatewayPosition,
    this.internetPosition,
    required this.containerWidth,
    required this.containerHeight,
    required this.calculateDevicePosition,  // 新增
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 繪製互聯網到網關的連線
    if (showInternet && internetPosition != null) {
      _drawConnection(canvas, internetPosition!, gatewayPosition  , ConnectionType.wired);
    }

    // 繪製設備到網關的連線
    for (var device in devices) {
      final devicePosition = _calculateDevicePosition(device);
      _drawConnection(canvas, gatewayPosition, devicePosition, device.connectionType);
    }
  }

  // 繪製連接線 連接裝置的線
  void _drawConnection(Canvas canvas, Offset start, Offset end, ConnectionType type) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    if (distance < 0.001) return;

    final unitX = dx / distance;
    final unitY = dy / distance;

    double startRadius = 30.0; // 設備圓的半徑
    double endRadius = 30.0;

    if (start == gatewayPosition) {
      startRadius = 42.0; // 網關圓的半徑
    }
    if (end == gatewayPosition) {
      endRadius = 42.0;  //gateway半徑
    }
    if (start == internetPosition) {
      startRadius = 8.0;  // 白點半徑
    }
    if (end == internetPosition) {
      endRadius = 8.0;   // 白點半徑
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
      ..color = Colors.white  //線的顏色
      ..strokeWidth = 2.0;  // 改變粗細

    if (type == ConnectionType.wired) {
      canvas.drawLine(adjustedStart, adjustedEnd, paint); // 實線
    } else {
      _drawDashedLine(canvas, adjustedStart, adjustedEnd, paint); // 虛線
    }
  }

  // 繪製虛線
  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLength = 5.0; // 虛線段長度
    const gapLength = 5.0; // 虛線間隔長度

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

  // 計算設備位置（與主組件邏輯一致）
  Offset _calculateDevicePosition(NetworkDevice device) {
    return calculateDevicePosition(device, containerWidth, containerHeight);
  }
  //   final deviceCount = devices.length;
  //   final index = devices.indexOf(device);
  //
  //   if (deviceCount == 1) {
  //     return Offset(containerWidth * 0.5, containerHeight * 0.85);
  //   } else if (deviceCount == 2) {
  //     double horizontalOffset = index == 0 ? 0.3 : 0.7;
  //     return Offset(containerWidth * horizontalOffset, containerHeight * 0.85);
  //   } else if (deviceCount == 3) {
  //     final positions = [0.2, 0.5, 0.8];
  //     return Offset(containerWidth * 0.65, containerHeight * positions[index]);
  //   } else if (deviceCount <= 4) {
  //     double verticalPosition = 0.2 + index * 0.2;
  //     return Offset(containerWidth * 0.65, containerHeight * verticalPosition);
  //   } else {
  //     final angle = 2 * math.pi * index / deviceCount;
  //     return Offset(
  //       gatewayPosition.dx + 150 * math.cos(angle),
  //       gatewayPosition.dy + 150 * math.sin(angle),
  //     );
  //   }
  // }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 網絡設備類
class NetworkDevice {
  /// 設備名稱
  final String name;

  /// 設備ID
  final String id;

  /// 設備MAC地址
  final String mac;

  /// 設備IP地址
  final String ip;

  /// 連接類型 (有線或無線)
  final ConnectionType connectionType;

  /// 額外的設備資訊
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
  wired,   // 有線連接
  wireless // 無線連接
}