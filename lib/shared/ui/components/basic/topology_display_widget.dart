// lib/shared/ui/pages/test/components/topology_display_widget.dart

import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:whitebox/shared/ui/components/basic/NetworkTopologyComponent.dart';
import 'package:whitebox/shared/theme/app_theme.dart';
import 'package:whitebox/shared/ui/pages/home/Topo/network_topo_config.dart';
import 'package:whitebox/shared/ui/pages/home/Topo/fake_data_generator.dart';

/// 拓樸圖和速度圖組合組件
class TopologyDisplayWidget extends StatefulWidget {
  final List<NetworkDevice> devices;
  final List<DeviceConnection> connections;
  final String gatewayName; // 👈 直接接收 gatewayName 參數
  final bool enableInteractions;
  final Function(NetworkDevice)? onDeviceSelected;
  final AnimationController animationController;

  const TopologyDisplayWidget({
    Key? key,
    required this.devices,
    required this.connections,
    required this.gatewayName,
    required this.enableInteractions,
    required this.animationController,
    this.onDeviceSelected,
  }) : super(key: key);

  @override
  State<TopologyDisplayWidget> createState() => TopologyDisplayWidgetState();
}

class TopologyDisplayWidgetState extends State<TopologyDisplayWidget> {
  final AppTheme _appTheme = AppTheme();
  late SpeedDataGenerator _speedDataGenerator;

  @override
  void initState() {
    super.initState();
    // 初始化速度生成器（如果使用假資料）
    if (!NetworkTopoConfig.useRealData) {
      _speedDataGenerator = FakeDataGenerator.createSpeedGenerator();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Column(
      children: [
        // 拓樸圖區域
        Expanded(
          flex: 3,
          child: _buildTopologyArea(screenSize),
        ),

        // 速度圖區域
        Container(
          height: NetworkTopoConfig.speedAreaHeight,
          padding: const EdgeInsets.only(top: 10, bottom: 10),
          child: _buildSpeedArea(screenSize),
        ),
      ],
    );
  }

  /// 建構拓樸區域
  Widget _buildTopologyArea(Size screenSize) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 0),
      color: Colors.transparent,
      child: Column(
        children: [
          // 資料來源指示器（開發用）
          if (NetworkTopoConfig.useRealData)
            _buildDataSourceIndicator(),

          // 主要拓樸圖
          Expanded(
            child: Center(
              child: NetworkTopologyComponent(
                gatewayName: widget.gatewayName,
                devices: widget.devices,
                deviceConnections: widget.connections,
                totalConnectedDevices: widget.devices.length,
                height: screenSize.height * NetworkTopoConfig.topologyHeightRatio,
                onDeviceSelected: widget.enableInteractions ? widget.onDeviceSelected : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 建構資料來源指示器
  Widget _buildDataSourceIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            NetworkTopoConfig.useRealData ? '🌐 Real Data' : '🎭 Mock Data',
            style: TextStyle(color: Colors.white70, fontSize: 10),
          ),
          SizedBox(width: 8),
          if (widget.enableInteractions)
            GestureDetector(
              onTap: () {
                // 這裡可以加入資料來源切換邏輯
                print('切換資料來源');
              },
              child: Icon(Icons.refresh, color: Colors.white70, size: 16),
            ),
        ],
      ),
    );
  }

  /// 建構速度區域
  Widget _buildSpeedArea(Size screenSize) {
    final screenWidth = screenSize.width;

    return Container(
      margin: const EdgeInsets.only(left: 3, right: 3),
      child: _appTheme.whiteBoxTheme.buildStandardCard(
        width: screenWidth - 36,
        height: 150,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 根據資料來源選擇顯示方式
            if (NetworkTopoConfig.useRealData)
              _buildRealSpeedChart()
            else
              _buildFakeSpeedChart(),
          ],
        ),
      ),
    );
  }

  /// 建構假資料速度圖表
  Widget _buildFakeSpeedChart() {
    return SpeedChartWidget(
      dataGenerator: _speedDataGenerator,
      animationController: widget.animationController,
      endAtPercent: 0.7,
    );
  }

  /// 建構真實資料速度圖表（暫時簡化）
  Widget _buildRealSpeedChart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Real Speed Data',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Coming Soon...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// 更新速度數據（供外部調用）
  void updateSpeedData() {
    if (!NetworkTopoConfig.useRealData && mounted) {
      setState(() {
        _speedDataGenerator.update();
      });
    }
  }
}

/// 速度圖表小部件（保持原有邏輯）
class SpeedChartWidget extends StatelessWidget {
  final SpeedDataGenerator dataGenerator;
  final AnimationController animationController;
  final double endAtPercent;

  const SpeedChartWidget({
    Key? key,
    required this.dataGenerator,
    required this.animationController,
    this.endAtPercent = 0.7,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double currentSpeed = dataGenerator.currentSpeed.round().toDouble();
    final int speedValue = currentSpeed.toInt();
    final double currentWidthPercentage = dataGenerator.getWidthPercentage();
    final bool isFullWidth = currentWidthPercentage >= endAtPercent;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double actualWidth = constraints.maxWidth;
        final double actualHeight = constraints.maxHeight;

        if (actualWidth <= 0 || actualHeight <= 0) {
          return const SizedBox();
        }

        final double chartEndX = actualWidth * currentWidthPercentage;
        final double range = dataGenerator.maxSpeed - dataGenerator.minSpeed;
        final double normalizedValue = (currentSpeed - dataGenerator.minSpeed) / range;
        final double dotY = (1.0 - normalizedValue) * actualHeight;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // 速度曲線
            Positioned.fill(
              child: AnimatedBuilder(
                animation: animationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: SpeedCurvePainter(
                      speedData: dataGenerator.data,
                      minSpeed: dataGenerator.minSpeed,
                      maxSpeed: dataGenerator.maxSpeed,
                      animationValue: animationController.value,
                      endAtPercent: endAtPercent,
                      currentSpeed: currentSpeed,
                      currentWidthPercentage: currentWidthPercentage,
                      isFullWidth: isFullWidth,
                    ),
                    size: Size(actualWidth, actualHeight),
                  );
                },
              ),
            ),

            // 白點和垂直線
            if (dataGenerator.data.isNotEmpty) ...[
              // 垂直線
              Positioned(
                top: dotY + 8,
                bottom: 0,
                left: chartEndX - 1,
                child: Container(
                  width: 2,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white,
                        Color.fromRGBO(255, 255, 255, 0),
                      ],
                    ),
                  ),
                ),
              ),

              // 白色圓點
              Positioned(
                top: dotY - 8,
                left: chartEndX - 8,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // 速度標籤
              Positioned(
                top: dotY - 50,
                left: chartEndX - 44,
                child: _buildSpeedLabel(speedValue),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSpeedLabel(int speed) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(
              width: 88,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  '$speed Mb/s',
                  style: const TextStyle(
                    color: Color.fromRGBO(255, 255, 255, 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -6,
          left: 0,
          right: 0,
          child: Center(
            child: ClipPath(
              clipper: TriangleClipper(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(
                  width: 16,
                  height: 6,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 三角形裁剪器
class TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// 速度曲線繪製器（保持原有邏輯）
class SpeedCurvePainter extends CustomPainter {
  final List<double> speedData;
  final bool isFullWidth;
  final double currentWidthPercentage;
  final double minSpeed;
  final double maxSpeed;
  final double animationValue;
  final double endAtPercent;
  final double currentSpeed;

  SpeedCurvePainter({
    required this.speedData,
    required this.minSpeed,
    required this.maxSpeed,
    required this.animationValue,
    this.endAtPercent = 0.7,
    required this.currentSpeed,
    required this.isFullWidth,
    required this.currentWidthPercentage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (speedData.isEmpty || size.width <= 0 || size.height <= 0) return;

    final double range = maxSpeed - minSpeed;
    if (range <= 0) return;

    final path = Path();
    final double currentEndX = size.width * currentWidthPercentage;
    final double stepX = currentEndX / (speedData.length - 1);

    double x = 0;
    final List<Offset> points = [];

    for (int i = 0; i < speedData.length; i++) {
      final double normalizedValue = (speedData[i] - minSpeed) / range;
      final double y = size.height - (normalizedValue * size.height);
      points.add(Offset(x, y));
      x += stepX;
    }

    if (points.length < 2) return;

    path.moveTo(points[0].dx, points[0].dy);

    if (points.length > 2) {
      for (int i = 0; i < points.length - 2; i++) {
        final Offset current = points[i];
        final Offset next = points[i + 1];

        final double controlX1 = current.dx + (next.dx - current.dx) * 0.5;
        final double controlY1 = current.dy;
        final double controlX2 = next.dx - (next.dx - current.dx) * 0.5;
        final double controlY2 = next.dy;

        path.cubicTo(controlX1, controlY1, controlX2, controlY2, next.dx, next.dy);
      }
      path.lineTo(points[points.length - 1].dx, points[points.length - 1].dy);
    } else {
      path.lineTo(points[1].dx, points[1].dy);
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF00EEFF),
          Color.fromRGBO(255, 255, 255, 0.5),
        ],
      ).createShader(Rect.fromLTWH(0, 0, currentEndX, size.height));

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF00EEFF),
          Color.fromRGBO(255, 255, 255, 0.5),
        ],
      ).createShader(Rect.fromLTWH(0, 0, currentEndX, size.height))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SpeedCurvePainter oldDelegate) {
    return oldDelegate.speedData != speedData ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.currentSpeed != currentSpeed;
  }
}