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

/// 網絡拓撲圖元件
///
/// 顯示網絡設備之間的連接關係，包括有線和無線連接
/// 根據設備數量自動調整佈局
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
  static const double kInternetHorizontalPosition = 0.5;  // 水平位置 (比例，0.5 = 50%)
  static const double kInternetVerticalPosition = 0.15;   // 垂直位置 (比例，0.15 = 15%)

  // 佈局常量 - 主路由器/網關位置
  static const double kGatewayHorizontalPosition = 0.5;   // 水平位置 (比例，0.5 = 50%)
  static const double kGatewayVerticalPosition = 0.5;     // 垂直位置 (比例，0.5 = 50%)

  // 佈局常量 - 單一設備位置 (一個設備時)
  static const double kSingleDeviceHorizontalPosition = 0.5;  // 水平位置 (比例，0.5 = 50%)
  static const double kSingleDeviceVerticalPosition = 0.85;   // 垂直位置 (比例，0.85 = 85%)

  // 佈局常量 - 兩個設備位置 (兩個設備時的水平分布)
  static const double kTwoDevicesLeftPosition = 0.3;     // 左側設備水平位置 (比例，0.3 = 30%)
  static const double kTwoDevicesRightPosition = 0.7;    // 右側設備水平位置 (比例，0.7 = 70%)
  static const double kTwoDevicesVerticalPosition = 0.85; // 兩個設備共用的垂直位置 (比例，0.85 = 85%)

  // 佈局常量 - 設備右側列位置 (3-4個設備時)
  static const double kRightColumnHorizontalPosition = 0.85;  // 右側列水平位置 (比例，0.85 = 85%)

  // 佈局常量 - 垂直排列設備位置 (3個設備時的垂直分布)
  static const List<double> kThreeDevicesVerticalPositions = [0.2, 0.5, 0.8];  // 垂直位置列表

  // 佈局常量 - 設備間距 (4個以上設備時使用)
  static const double kVerticalSpacing = 0.2;  // 垂直間距 (比例，0.2 = 20%)

  // 佈局常量 - 圓形大小
  static const double kInternetRadius = 25.0;  // 互聯網圖標半徑
  static const double kGatewayRadius = 35.0;   // 網關圖標半徑
  static const double kDeviceRadius = 25.0;    // 設備圖標半徑
  static const double kLabelRadius = 12.0;     // 標籤圓形半徑

  // 佈局常量 - 連接線
  static const double kWiredLineWidth = 2.0;    // 有線連接線寬度
  static const double kWirelessLineWidth = 2.0; // 無線連接線寬度
  static const double kDashLength = 5.0;        // 虛線長度
  static const double kGapLength = 4.0;         // 虛線間隔長度

  // 佈局常量 - 標籤偏移
  static const double kLabelOffsetX = 15.0;     // 標籤水平偏移
  static const double kLabelOffsetY = 15.0;     // 標籤垂直偏移

  // 佈局常量 - 文字大小
  static const double kLabelFontSize = 14.0;    // 標籤文字大小
  static const double kNameFontSize = 12.0;     // 名稱文字大小

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.white,
      child: CustomPaint(
        painter: TopologyPainter(
          gatewayName: widget.gatewayName,
          devices: widget.devices,
          deviceConnections: widget.deviceConnections,
          totalConnectedDevices: widget.totalConnectedDevices ?? widget.devices.length,
          showInternet: widget.showInternet,
          layoutConstants: LayoutConstants(
            internetHorizontalPosition: kInternetHorizontalPosition,
            internetVerticalPosition: kInternetVerticalPosition,
            gatewayHorizontalPosition: kGatewayHorizontalPosition,
            gatewayVerticalPosition: kGatewayVerticalPosition,
            singleDeviceHorizontalPosition: kSingleDeviceHorizontalPosition,
            singleDeviceVerticalPosition: kSingleDeviceVerticalPosition,
            twoDevicesLeftPosition: kTwoDevicesLeftPosition,
            twoDevicesRightPosition: kTwoDevicesRightPosition,
            twoDevicesVerticalPosition: kTwoDevicesVerticalPosition,
            rightColumnHorizontalPosition: kRightColumnHorizontalPosition,
            threeDevicesVerticalPositions: kThreeDevicesVerticalPositions,
            verticalSpacing: kVerticalSpacing,
            internetRadius: kInternetRadius,
            gatewayRadius: kGatewayRadius,
            deviceRadius: kDeviceRadius,
            labelRadius: kLabelRadius,
            wiredLineWidth: kWiredLineWidth,
            wirelessLineWidth: kWirelessLineWidth,
            dashLength: kDashLength,
            gapLength: kGapLength,
            labelOffsetX: kLabelOffsetX,
            labelOffsetY: kLabelOffsetY,
            labelFontSize: kLabelFontSize,
            nameFontSize: kNameFontSize,
          ),
        ),
        child: GestureDetector(
          onTapDown: (details) {
            // 處理點擊事件，檢查是否點擊了設備
            _handleTap(details.localPosition);
          },
          // 使元件能夠接收手勢
          behavior: HitTestBehavior.opaque,
          child: Container(),
        ),
      ),
    );
  }

  // 處理點擊事件
  void _handleTap(Offset position) {
    if (widget.onDeviceSelected == null) return;

    // 檢查是否點擊了設備
    for (var device in widget.devices) {
      // 計算設備圓心位置
      final centerPosition = _calculateDevicePosition(device);

      // 計算點擊位置與設備圓心的距離
      final distance = (position - centerPosition).distance;

      // 如果距離小於設備圖標半徑，則認為點擊了該設備
      if (distance <= kDeviceRadius) {
        widget.onDeviceSelected!(device);
        return;
      }
    }

    // 檢查是否點擊了中央網關
    final gatewayPosition = _calculateGatewayPosition();
    final gatewayDistance = (position - gatewayPosition).distance;

    if (gatewayDistance <= kGatewayRadius) {
      // 如果點擊了網關，可以在這裡添加處理邏輯
      print('點擊了網關: ${widget.gatewayName}');
    }
  }

  // 計算網關位置 - 固定在畫面中央 (50% 水平, 50% 垂直)
  Offset _calculateGatewayPosition() {
    return Offset(
        widget.width * kGatewayHorizontalPosition,
        widget.height * kGatewayVerticalPosition
    );
  }

  // 計算設備位置
  Offset _calculateDevicePosition(NetworkDevice device) {
    final deviceCount = widget.devices.length;
    final index = widget.devices.indexOf(device);

    // 根據設備數量決定佈局
    if (deviceCount == 1) {
      // 只有一個設備：放在下方 (50% 水平, 85% 垂直)
      return Offset(
          widget.width * kSingleDeviceHorizontalPosition,
          widget.height * kSingleDeviceVerticalPosition
      );
    }
    else if (deviceCount == 2) {
      // 兩個設備：水平排列在下方
      double horizontalOffset;

      if (index == 0) {
        horizontalOffset = kTwoDevicesLeftPosition; // 左側設備 (30% 水平)
      } else {
        horizontalOffset = kTwoDevicesRightPosition; // 右側設備 (70% 水平)
      }

      return Offset(
          widget.width * horizontalOffset,
          widget.height * kTwoDevicesVerticalPosition
      );
    }
    else if (deviceCount == 3) {
      // 三個設備：垂直排列在右側，使用預設的三個位置
      double verticalPosition = kThreeDevicesVerticalPositions[index];

      return Offset(
          widget.width * kRightColumnHorizontalPosition,
          widget.height * verticalPosition
      );
    }
    else if (deviceCount <= 4) {
      // 四個設備：垂直排列在右側，均勻分布
      double verticalPosition = 0.2 + index * kVerticalSpacing; // 0.2, 0.4, 0.6, 0.8

      return Offset(
          widget.width * kRightColumnHorizontalPosition,
          widget.height * verticalPosition
      );
    }
    else {
      // 超過四個設備時的處理 (這裡簡化為圓形分布)
      final gatewayPosition = _calculateGatewayPosition();
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
      return 0; // 如果找不到連接信息，返回0
    }
  }
}

/// 拓撲圖布局常量集合
class LayoutConstants {
  final double internetHorizontalPosition;
  final double internetVerticalPosition;
  final double gatewayHorizontalPosition;
  final double gatewayVerticalPosition;
  final double singleDeviceHorizontalPosition;
  final double singleDeviceVerticalPosition;
  final double twoDevicesLeftPosition;
  final double twoDevicesRightPosition;
  final double twoDevicesVerticalPosition;
  final double rightColumnHorizontalPosition;
  final List<double> threeDevicesVerticalPositions;
  final double verticalSpacing;
  final double internetRadius;
  final double gatewayRadius;
  final double deviceRadius;
  final double labelRadius;
  final double wiredLineWidth;
  final double wirelessLineWidth;
  final double dashLength;
  final double gapLength;
  final double labelOffsetX;
  final double labelOffsetY;
  final double labelFontSize;
  final double nameFontSize;

  const LayoutConstants({
    required this.internetHorizontalPosition,
    required this.internetVerticalPosition,
    required this.gatewayHorizontalPosition,
    required this.gatewayVerticalPosition,
    required this.singleDeviceHorizontalPosition,
    required this.singleDeviceVerticalPosition,
    required this.twoDevicesLeftPosition,
    required this.twoDevicesRightPosition,
    required this.twoDevicesVerticalPosition,
    required this.rightColumnHorizontalPosition,
    required this.threeDevicesVerticalPositions,
    required this.verticalSpacing,
    required this.internetRadius,
    required this.gatewayRadius,
    required this.deviceRadius,
    required this.labelRadius,
    required this.wiredLineWidth,
    required this.wirelessLineWidth,
    required this.dashLength,
    required this.gapLength,
    required this.labelOffsetX,
    required this.labelOffsetY,
    required this.labelFontSize,
    required this.nameFontSize,
  });
}

/// 拓撲圖繪製器
class TopologyPainter extends CustomPainter {
  final String gatewayName;
  final List<NetworkDevice> devices;
  final List<DeviceConnection>? deviceConnections;
  final int totalConnectedDevices;
  final bool showInternet;
  final LayoutConstants layoutConstants;

  TopologyPainter({
    required this.gatewayName,
    required this.devices,
    this.deviceConnections,
    required this.totalConnectedDevices,
    required this.showInternet,
    required this.layoutConstants,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
        size.width * layoutConstants.gatewayHorizontalPosition,
        size.height * layoutConstants.gatewayVerticalPosition
    );

    // 繪製互聯網圖標（如果啟用）
    if (showInternet) {
      // 互聯網圖標位置固定在頂部中央
      final internetPosition = Offset(
          size.width * layoutConstants.internetHorizontalPosition,
          size.height * layoutConstants.internetVerticalPosition
      );
      _drawInternetIcon(canvas, internetPosition);

      // 繪製互聯網到網關的連線 (從圓周到圓周)
      _drawConnectionBetweenCircles(
          canvas,
          internetPosition,
          layoutConstants.internetRadius,
          center,
          layoutConstants.gatewayRadius,
          ConnectionType.wired
      );
    }

    // 繪製中央網關
    _drawGateway(canvas, center, gatewayName, totalConnectedDevices);

    // 繪製設備和連接線
    for (var device in devices) {
      // 計算設備位置
      final devicePosition = _calculateDevicePosition(device, size);

      // 獲取設備連接數量
      final connectionCount = _getDeviceConnectionCount(device.id);

      // 繪製設備與網關之間的連接線 (從圓周到圓周)
      _drawConnectionBetweenCircles(
          canvas,
          center,
          layoutConstants.gatewayRadius,
          devicePosition,
          layoutConstants.deviceRadius,
          device.connectionType
      );

      // 繪製設備圖標
      _drawDevice(canvas, devicePosition, device, connectionCount);
    }
  }

  // 繪製互聯網圖標
  void _drawInternetIcon(Canvas canvas, Offset position) {
    final paint = Paint()
      ..color = Colors.grey[300]! // 使用淺灰色
      ..style = PaintingStyle.fill;

    // 繪製一個白色的圓形代表互聯網
    canvas.drawCircle(position, layoutConstants.internetRadius, paint);

    // 添加簡單的"地球"圖案
    final borderPaint = Paint()
      ..color = Colors.grey[600]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // 繪製水平線
    canvas.drawLine(
        Offset(position.dx - 15, position.dy),
        Offset(position.dx + 15, position.dy),
        borderPaint
    );

    // 繪製垂直線
    canvas.drawLine(
        Offset(position.dx, position.dy - 15),
        Offset(position.dx, position.dy + 15),
        borderPaint
    );

    // 繪製橢圓
    final rect = Rect.fromCenter(
      center: position,
      width: 30,
      height: 20,
    );
    canvas.drawOval(rect, borderPaint);
  }

  // 繪製網關圖標
  void _drawGateway(Canvas canvas, Offset position, String name, int connectionCount) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // 繪製網關圓形
    canvas.drawCircle(position, layoutConstants.gatewayRadius, paint);

    // 添加數字標籤，顯示連接的設備數量
    _drawLabel(canvas, position, connectionCount.toString(), Colors.white);

    // 添加網關名稱標籤
    final textPainter = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          color: Colors.black,
          fontSize: layoutConstants.nameFontSize,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.white.withOpacity(0.7),
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // 在網關下方顯示名稱
    textPainter.paint(
      canvas,
      Offset(
        position.dx - textPainter.width / 2,
        position.dy + layoutConstants.gatewayRadius + 10, // 在圓形下方顯示
      ),
    );
  }

  // 繪製設備圖標
  void _drawDevice(Canvas canvas, Offset position, NetworkDevice device, int connectionCount) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // 繪製設備圓形
    canvas.drawCircle(position, layoutConstants.deviceRadius, paint);

    // 添加數字標籤 - 顯示連接的子設備數量
    _drawLabel(canvas, position, connectionCount.toString(), Colors.white);

    // 添加設備名稱標籤
    final textPainter = TextPainter(
      text: TextSpan(
        text: device.name,
        style: TextStyle(
          color: Colors.black,
          fontSize: layoutConstants.nameFontSize,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.white.withOpacity(0.7),
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // 在設備下方顯示名稱
    textPainter.paint(
      canvas,
      Offset(
        position.dx - textPainter.width / 2,
        position.dy + layoutConstants.deviceRadius + 10, // 在圓形下方顯示
      ),
    );
  }

  // 繪製兩個圓形之間的連接線 (從圓周到圓周，而非圓心到圓心)
  void _drawConnectionBetweenCircles(
      Canvas canvas,
      Offset start,
      double startRadius,
      Offset end,
      double endRadius,
      ConnectionType type
      ) {
    // 計算兩點之間的方向向量
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    // 確保距離不為零
    if (distance < 0.001) return;

    // 計算單位向量
    final unitX = dx / distance;
    final unitY = dy / distance;

    // 計算起點圓周上的點
    final startX = start.dx + unitX * startRadius;
    final startY = start.dy + unitY * startRadius;

    // 計算終點圓周上的點
    final endX = end.dx - unitX * endRadius;
    final endY = end.dy - unitY * endRadius;

    final adjustedStart = Offset(startX, startY);
    final adjustedEnd = Offset(endX, endY);

    final lineWidth = type == ConnectionType.wired
        ? layoutConstants.wiredLineWidth
        : layoutConstants.wirelessLineWidth;

    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = lineWidth;

    if (type == ConnectionType.wired) {
      // 有線連接使用實線
      canvas.drawLine(adjustedStart, adjustedEnd, paint);
    } else {
      // 無線連接使用虛線
      _drawDashedLine(canvas, adjustedStart, adjustedEnd, paint);
    }
  }

  // 繪製虛線
  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final dashLength = layoutConstants.dashLength;
    final gapLength = layoutConstants.gapLength;

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
          paint
      );
    }
  }

  // 繪製標籤
  void _drawLabel(Canvas canvas, Offset position, String label, Color textColor) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: textColor,
          fontSize: layoutConstants.labelFontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // 調整標籤位置到圓形的右下方
    final labelPosition = Offset(
        position.dx + layoutConstants.labelOffsetX,
        position.dy + layoutConstants.labelOffsetY
    );

    // 添加一個小圓形作為標籤背景
    final labelPaint = Paint()
      ..color = Colors.grey[400]!
      ..style = PaintingStyle.fill;

    // 繪製標籤背景圓形
    canvas.drawCircle(labelPosition, layoutConstants.labelRadius, labelPaint);

    // 繪製標籤文字
    textPainter.paint(
      canvas,
      Offset(
        labelPosition.dx - textPainter.width / 2,
        labelPosition.dy - textPainter.height / 2,
      ),
    );
  }

  // 計算設備位置
  Offset _calculateDevicePosition(NetworkDevice device, Size size) {
    final deviceCount = devices.length;
    final index = devices.indexOf(device);

    // 根據設備數量決定佈局
    if (deviceCount == 1) {
      // 只有一個設備：放在下方 (50% 水平, 85% 垂直)
      return Offset(
          size.width * layoutConstants.singleDeviceHorizontalPosition,
          size.height * layoutConstants.singleDeviceVerticalPosition
      );
    }
    else if (deviceCount == 2) {
      // 兩個設備：水平排列在下方
      double horizontalOffset;

      if (index == 0) {
        horizontalOffset = layoutConstants.twoDevicesLeftPosition; // 左側設備 (30% 水平)
      } else {
        horizontalOffset = layoutConstants.twoDevicesRightPosition; // 右側設備 (70% 水平)
      }

      return Offset(
          size.width * horizontalOffset,
          size.height * layoutConstants.twoDevicesVerticalPosition
      );
    }
    else if (deviceCount == 3) {
      // 三個設備：垂直排列在右側，使用預設的三個位置
      double verticalPosition = layoutConstants.threeDevicesVerticalPositions[index];

      return Offset(
          size.width * layoutConstants.rightColumnHorizontalPosition,
          size.height * verticalPosition
      );
    }
    else if (deviceCount <= 4) {
      // 四個設備：垂直排列在右側，均勻分布
      double verticalPosition = 0.2 + index * layoutConstants.verticalSpacing; // 0.2, 0.4, 0.6, 0.8

      return Offset(
          size.width * layoutConstants.rightColumnHorizontalPosition,
          size.height * verticalPosition
      );
    }
    else {
      // 超過四個設備時的處理 (這裡簡化為圓形分布)
      final center = Offset(
          size.width * layoutConstants.gatewayHorizontalPosition,
          size.height * layoutConstants.gatewayVerticalPosition
      );
      final angle = 2 * math.pi * index / deviceCount;
      return Offset(
        center.dx + 150 * math.cos(angle),
        center.dy + 150 * math.sin(angle),
      );
    }
  }

  // 獲取裝置的連接數量
  int _getDeviceConnectionCount(String deviceId) {
    if (deviceConnections == null) return 0;

    try {
      final connection = deviceConnections!.firstWhere(
              (conn) => conn.deviceId == deviceId
      );
      return connection.connectedDevicesCount;
    } catch (e) {
      return 0; // 如果找不到連接信息，返回0
    }
  }

  @override
  bool shouldRepaint(TopologyPainter oldDelegate) {
    return oldDelegate.gatewayName != gatewayName ||
        oldDelegate.devices != devices ||
        oldDelegate.totalConnectedDevices != totalConnectedDevices ||
        oldDelegate.showInternet != showInternet;
  }
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