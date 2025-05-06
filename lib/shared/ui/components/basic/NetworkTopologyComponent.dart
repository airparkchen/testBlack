import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 網絡拓撲圖元件
///
/// 顯示網絡設備之間的連接關係，包括有線和無線連接
/// 根據設備數量自動調整佈局
class NetworkTopologyComponent extends StatefulWidget {
  /// 中央路由器/網關名稱
  final String gatewayName;

  /// 連接到網關的裝置列表
  final List<NetworkDevice> devices;

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
    this.showInternet = true,
    this.width = double.infinity,
    this.height = 400,
    this.onDeviceSelected,
  }) : super(key: key);

  @override
  State<NetworkTopologyComponent> createState() => _NetworkTopologyComponentState();
}

class _NetworkTopologyComponentState extends State<NetworkTopologyComponent> {
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
          showInternet: widget.showInternet,
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
      if (distance <= 25) {
        widget.onDeviceSelected!(device);
        return;
      }
    }

    // 檢查是否點擊了中央網關
    final gatewayPosition = _calculateGatewayPosition();
    final gatewayDistance = (position - gatewayPosition).distance;

    if (gatewayDistance <= 35) {
      // 如果點擊了網關，可以在這裡添加處理邏輯
      print('點擊了網關: ${widget.gatewayName}');
    }
  }

  // 計算網關位置 - 固定在畫面中央 (50% 水平, 50% 垂直)
  Offset _calculateGatewayPosition() {
    return Offset(widget.width / 2, widget.height / 2);
  }

  // 計算設備位置
  Offset _calculateDevicePosition(NetworkDevice device) {
    final deviceCount = widget.devices.length;
    final index = widget.devices.indexOf(device);
    final gatewayPosition = _calculateGatewayPosition();

    // 根據設備數量決定佈局
    if (deviceCount == 1) {
      // 只有一個設備：放在下方 (50% 水平, 85% 垂直)
      return Offset(widget.width / 2, widget.height * 0.85);
    }
    else if (deviceCount == 2) {
      // 兩個設備：水平排列在下方
      double horizontalOffset;

      if (index == 0) {
        horizontalOffset = widget.width * 0.3; // 左側設備 (30% 水平)
      } else {
        horizontalOffset = widget.width * 0.7; // 右側設備 (70% 水平)
      }

      return Offset(horizontalOffset, widget.height * 0.85);
    }
    else if (deviceCount <= 4) {
      // 三個或四個設備：垂直排列在右側
      double verticalPosition;

      if (deviceCount == 3) {
        // 三個設備的垂直分布
        if (index == 0) {
          verticalPosition = widget.height * 0.2; // 頂部設備
        } else if (index == 1) {
          verticalPosition = widget.height * 0.5; // 中間設備
        } else {
          verticalPosition = widget.height * 0.8; // 底部設備
        }
      } else {
        // 四個設備的垂直分布
        verticalPosition = widget.height * (0.2 + index * 0.2); // 均勻分布
      }

      return Offset(widget.width * 0.85, verticalPosition); // 右側 85% 水平
    }
    else {
      // 超過四個設備時的處理 (這裡簡化為圓形分布)
      final angle = 2 * math.pi * index / deviceCount;
      return Offset(
        gatewayPosition.dx + 150 * math.cos(angle),
        gatewayPosition.dy + 150 * math.sin(angle),
      );
    }
  }
}

/// 拓撲圖繪製器
class TopologyPainter extends CustomPainter {
  final String gatewayName;
  final List<NetworkDevice> devices;
  final bool showInternet;

  TopologyPainter({
    required this.gatewayName,
    required this.devices,
    required this.showInternet,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 繪製互聯網圖標（如果啟用）
    if (showInternet) {
      // 互聯網圖標位置固定在頂部中央 (50% 水平, 15% 垂直)
      final internetPosition = Offset(size.width / 2, size.height * 0.15);
      _drawInternetIcon(canvas, internetPosition);

      // 繪製互聯網到網關的連線
      _drawConnection(canvas, internetPosition, center, ConnectionType.wired);
    }

    // 繪製中央網關
    _drawGateway(canvas, center, gatewayName);

    // 繪製設備和連接線
    for (var device in devices) {
      // 計算設備位置
      final devicePosition = _calculateDevicePosition(device, size);

      // 繪製設備與網關之間的連接線
      _drawConnection(canvas, center, devicePosition, device.connectionType);

      // 繪製設備圖標
      _drawDevice(canvas, devicePosition, device);
    }
  }

  // 繪製互聯網圖標
  void _drawInternetIcon(Canvas canvas, Offset position) {
    final paint = Paint()
      ..color = Colors.grey[300]! // 使用淺灰色
      ..style = PaintingStyle.fill;

    // 繪製一個白色的圓形代表互聯網
    canvas.drawCircle(position, 25, paint);

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
  void _drawGateway(Canvas canvas, Offset position, String name) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // 繪製網關圓形 - 調整大小為35
    canvas.drawCircle(position, 35, paint);

    // 添加數字標籤
    _drawLabel(canvas, position, "4", Colors.white);

    // 添加網關名稱標籤
    final textPainter = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          color: Colors.black,
          fontSize: 12,
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
        position.dy + 45, // 在圓形下方顯示
      ),
    );
  }

  // 繪製設備圖標
  void _drawDevice(Canvas canvas, Offset position, NetworkDevice device) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // 繪製設備圓形 - 調整大小為25
    canvas.drawCircle(position, 25, paint);

    // 添加數字標籤 - 根據設備類型選擇標籤
    String label = "2"; // 默認值
    if (device.connectionType == ConnectionType.wired) {
      label = "4"; // 有線設備用數字4標記
    }

    _drawLabel(canvas, position, label, Colors.white);
  }

  // 繪製連接線
  void _drawConnection(Canvas canvas, Offset start, Offset end, ConnectionType type) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2;

    if (type == ConnectionType.wired) {
      // 有線連接使用實線
      canvas.drawLine(start, end, paint);
    } else {
      // 無線連接使用虛線
      _drawDashedLine(canvas, start, end, paint);
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
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // 調整標籤位置到圓形的右下方
    final labelPosition = Offset(position.dx + 15, position.dy + 15);

    // 添加一個小圓形作為標籤背景
    final labelPaint = Paint()
      ..color = Colors.grey[400]!
      ..style = PaintingStyle.fill;

    // 繪製標籤背景圓形
    canvas.drawCircle(labelPosition, 12, labelPaint);

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
    final center = Offset(size.width / 2, size.height / 2);

    // 根據設備數量決定佈局
    if (deviceCount == 1) {
      // 只有一個設備：放在下方 (50% 水平, 85% 垂直)
      return Offset(size.width / 2, size.height * 0.85);
    }
    else if (deviceCount == 2) {
      // 兩個設備：水平排列在下方
      double horizontalOffset;

      if (index == 0) {
        horizontalOffset = size.width * 0.3; // 左側設備 (30% 水平)
      } else {
        horizontalOffset = size.width * 0.7; // 右側設備 (70% 水平)
      }

      return Offset(horizontalOffset, size.height * 0.85);
    }
    else if (deviceCount <= 4) {
      // 三個或四個設備：垂直排列在右側
      double verticalPosition;

      if (deviceCount == 3) {
        // 三個設備的垂直分布
        if (index == 0) {
          verticalPosition = size.height * 0.2; // 頂部設備
        } else if (index == 1) {
          verticalPosition = size.height * 0.5; // 中間設備
        } else {
          verticalPosition = size.height * 0.8; // 底部設備
        }
      } else {
        // 四個設備的垂直分布
        verticalPosition = size.height * (0.2 + index * 0.2); // 均勻分布
      }

      return Offset(size.width * 0.85, verticalPosition); // 右側 85% 水平
    }
    else {
      // 超過四個設備時的處理 (這裡簡化為圓形分布)
      final angle = 2 * math.pi * index / deviceCount;
      return Offset(
        center.dx + 150 * math.cos(angle),
        center.dy + 150 * math.sin(angle),
      );
    }
  }

  @override
  bool shouldRepaint(TopologyPainter oldDelegate) {
    return oldDelegate.gatewayName != gatewayName ||
        oldDelegate.devices != devices ||
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