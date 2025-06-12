// lib/shared/ui/components/basic/topology_display_widget.dart - 修改版本

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
  final String gatewayName;
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

  // 🎯 修改：支援兩種數據生成器
  late SpeedDataGenerator? _fakeSpeedDataGenerator;
  late RealSpeedDataGenerator? _realSpeedDataGenerator;

  @override
  void initState() {
    super.initState();

    // 🎯 根據配置初始化對應的數據生成器
    if (NetworkTopoConfig.useRealData) {
      _realSpeedDataGenerator = RealSpeedDataGenerator(
        dataPointCount: 100,
        minSpeed: 20,
        maxSpeed: 150,
        updateInterval: Duration(seconds: 5),
      );
      _fakeSpeedDataGenerator = null;
      print('🌐 初始化真實速度數據生成器');
      // 🎯 關鍵修正：確保初始化完成後觸發 Widget 重建
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            // 強制重建，確保白點顯示
          });
        }
      });

    } else {
      _fakeSpeedDataGenerator = FakeDataGenerator.createSpeedGenerator();
      _realSpeedDataGenerator = null;
      print('🎭 初始化假數據速度生成器（固定長度滑動窗口模式）');
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
          // 🎯 可選：資料來源指示器（開發用，可以開啟來調試）
          // if (true) // 改為 true 來顯示
          //   _buildDataSourceIndicator(),

          // 主要拓樸圖
          Expanded(
            child: Center(
              child: NetworkTopologyComponent(
                gatewayName: widget.gatewayName,
                devices: widget.devices,
                deviceConnections: widget.connections,
                totalConnectedDevices: _calculateTotalConnectedDevices(),
                height: screenSize.height * NetworkTopoConfig.topologyHeightRatio,
                onDeviceSelected: widget.enableInteractions ? widget.onDeviceSelected : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 動態計算總連接設備數（只計算 Host）
  int _calculateTotalConnectedDevices() {
    if (widget.connections.isEmpty) {
      print('⚠️ connections 為空，返回設備數量');
      return widget.devices.length;
    }

    try {
      final gatewayConnection = widget.connections.firstWhere(
            (conn) => conn.deviceId.contains('00037fbadbad') ||
            conn.deviceId.toLowerCase().contains('gateway'),
        orElse: () => DeviceConnection(deviceId: '', connectedDevicesCount: 0),
      );

      final totalConnected = gatewayConnection.connectedDevicesCount;
      // print('🎯 Gateway 總連接 Host 數: $totalConnected');
      return totalConnected;
    } catch (e) {
      // print('⚠️ 無法計算總連接數，使用預設值: $e');
      return widget.devices.length;
    }
  }

  /// 🎯 可選：建構資料來源指示器（調試用）
  Widget _buildDataSourceIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            NetworkTopoConfig.useRealData ? '🌐 Real Speed Data' : '🎭 Fake Speed Data (Fixed Length)',
            style: TextStyle(color: Colors.white70, fontSize: 10),
          ),
          SizedBox(width: 8),
          if (widget.enableInteractions)
            GestureDetector(
              onTap: () {
                print('📊 當前數據模式: ${NetworkTopoConfig.useRealData ? "真實" : "假數據"}');
                updateSpeedData(); // 手動觸發更新
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
            // 🎯 根據資料來源選擇顯示方式
            if (NetworkTopoConfig.useRealData)
              _buildRealSpeedChart()
            else
              _buildFakeSpeedChart(),
          ],
        ),
      ),
    );
  }

  /// 🎯 修改：建構假資料速度圖表 - 固定長度滑動窗口
  Widget _buildFakeSpeedChart() {
    if (_fakeSpeedDataGenerator == null) {
      return _buildErrorChart('假數據生成器未初始化');
    }

    return SpeedChartWidget(
      dataGenerator: _fakeSpeedDataGenerator!,
      animationController: widget.animationController,
      endAtPercent: 0.7, // 🎯 固定在70%位置
      isRealData: false,
    );
  }

  /// 🎯 修改：建構真實資料速度圖表
  Widget _buildRealSpeedChart() {
    if (_realSpeedDataGenerator == null) {
      return _buildErrorChart('真實數據生成器未初始化');
    }

    // 🎯 使用真實數據生成器繪製圖表（目前是預設直線）
    return RealSpeedChartWidget(
      dataGenerator: _realSpeedDataGenerator!,
      animationController: widget.animationController,
      endAtPercent: 0.7,
    );
  }

  /// 🎯 新增：錯誤狀態顯示
  Widget _buildErrorChart(String errorMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.white.withOpacity(0.7),
            size: 32,
          ),
          SizedBox(height: 8),
          Text(
            errorMessage,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 🎯 修改：更新速度數據（供外部調用）
  void updateSpeedData() {
    if (!mounted) return;

    if (NetworkTopoConfig.useRealData) {
      // 🎯 更新真實數據
      _realSpeedDataGenerator?.update();
      // print('📈 更新真實速度數據');
    } else {
      // 🎯 更新假數據（固定長度滑動窗口）
      if (_fakeSpeedDataGenerator != null) {
        setState(() {
          _fakeSpeedDataGenerator!.update();
        });
        // print('📊 更新假速度數據（滑動窗口）');
      }
    }
  }
}

/// 🎯 修改：假數據速度圖表小部件
class SpeedChartWidget extends StatelessWidget {
  final SpeedDataGenerator dataGenerator;
  final AnimationController animationController;
  final double endAtPercent;
  final bool isRealData;

  const SpeedChartWidget({
    Key? key,
    required this.dataGenerator,
    required this.animationController,
    this.endAtPercent = 0.7,
    this.isRealData = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double currentSpeed = dataGenerator.currentSpeed.round().toDouble();
    final int speedValue = currentSpeed.toInt();
    final double currentWidthPercentage = dataGenerator.getWidthPercentage();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double actualWidth = constraints.maxWidth;
        final double actualHeight = constraints.maxHeight;

        if (actualWidth <= 0 || actualHeight <= 0) {
          return const SizedBox();
        }

        // 🎯 固定在70%位置
        final double chartEndX = actualWidth * endAtPercent;
        final double range = dataGenerator.maxSpeed - dataGenerator.minSpeed;
        final double normalizedValue = (currentSpeed - dataGenerator.minSpeed) / range;
        final double dotY = (1.0 - normalizedValue) * actualHeight;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // 🎯 修改：速度曲線 - 固定長度滑動窗口模式
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
                      isFixedLength: true, // 🎯 啟用固定長度模式
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

/// 🎯 新增：真實數據速度圖表小部件
class RealSpeedChartWidget extends StatelessWidget {
  final RealSpeedDataGenerator dataGenerator;
  final AnimationController animationController;
  final double endAtPercent;

  const RealSpeedChartWidget({
    Key? key,
    required this.dataGenerator,
    required this.animationController,
    this.endAtPercent = 0.7,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 🎯 修改：繪製真實數據圖表（目前是預設直線）
    final double currentSpeed = dataGenerator.currentSpeed.round().toDouble();
    final int speedValue = currentSpeed.toInt();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double actualWidth = constraints.maxWidth;
        final double actualHeight = constraints.maxHeight;

        if (actualWidth <= 0 || actualHeight <= 0) {
          return const SizedBox();
        }

        final double chartEndX = actualWidth * endAtPercent;
        final double range = 150.0 - 20.0; // 使用固定範圍
        final double normalizedValue = (currentSpeed - 20.0) / range;
        final double dotY = (1.0 - normalizedValue) * actualHeight;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // 🎯 真實數據曲線（目前是預設直線）
            Positioned.fill(
              child: AnimatedBuilder(
                animation: animationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: RealSpeedCurvePainter(
                      speedData: dataGenerator.data,
                      minSpeed: 20.0,
                      maxSpeed: 150.0,
                      animationValue: animationController.value,
                      endAtPercent: endAtPercent,
                      currentSpeed: currentSpeed,
                    ),
                    size: Size(actualWidth, actualHeight),
                  );
                },
              ),
            ),

            // 白點和垂直線（與假數據相同的樣式）
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

/// 🎯 新增：真實數據曲線繪製器
class RealSpeedCurvePainter extends CustomPainter {
  final List<double> speedData;
  final double minSpeed;
  final double maxSpeed;
  final double animationValue;
  final double endAtPercent;
  final double currentSpeed;

  RealSpeedCurvePainter({
    required this.speedData,
    required this.minSpeed,
    required this.maxSpeed,
    required this.animationValue,
    this.endAtPercent = 0.7,
    required this.currentSpeed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (speedData.isEmpty || size.width <= 0 || size.height <= 0) return;

    final double range = maxSpeed - minSpeed;
    if (range <= 0) return;

    final path = Path();
    final double chartWidth = size.width * endAtPercent;

    // 🎯 對於真實數據（目前是預設直線），繪製簡單的水平線
    final double normalizedValue = (currentSpeed - minSpeed) / range;
    final double y = size.height - (normalizedValue * size.height);

    // 繪製水平直線
    path.moveTo(0, y);
    path.lineTo(chartWidth, y);

    // 🎯 未來可以改為繪製真實的曲線數據
    /*
    final double stepX = chartWidth / (speedData.length - 1);
    final List<Offset> points = [];

    for (int i = 0; i < speedData.length; i++) {
      final double x = i * stepX;
      final double normalizedValue = (speedData[i] - minSpeed) / range;
      final double y = size.height - (normalizedValue * size.height);
      points.add(Offset(x, y));
    }

    // 繪製平滑曲線邏輯...
    */

    // 創建畫筆
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF00EEFF),
          Color.fromRGBO(255, 255, 255, 0.5),
        ],
      ).createShader(Rect.fromLTWH(0, 0, chartWidth, size.height));

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF00EEFF),
          Color.fromRGBO(255, 255, 255, 0.5),
        ],
      ).createShader(Rect.fromLTWH(0, 0, chartWidth, size.height))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant RealSpeedCurvePainter oldDelegate) {
    return oldDelegate.speedData != speedData ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.currentSpeed != currentSpeed;
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

/// 🎯 修改：速度曲線繪製器 - 支援固定長度滑動窗口
class SpeedCurvePainter extends CustomPainter {
  final List<double> speedData;
  final bool isFixedLength;
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
    this.isFixedLength = true, // 🎯 預設使用固定長度模式
    required this.currentWidthPercentage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (speedData.isEmpty || size.width <= 0 || size.height <= 0) return;

    final double range = maxSpeed - minSpeed;
    if (range <= 0) return;

    final path = Path();

    // 🎯 固定長度模式：線條始終占用 endAtPercent 的寬度
    final double chartWidth = size.width * endAtPercent;

    // 🎯 計算每個數據點之間的間距
    final double stepX = chartWidth / (speedData.length - 1);

    // 🎯 收集所有點的座標
    final List<Offset> points = [];

    for (int i = 0; i < speedData.length; i++) {
      // 🎯 X座標：從左到右均勻分布在 chartWidth 範圍內
      final double x = i * stepX;

      // Y座標：根據速度值計算
      final double normalizedValue = (speedData[i] - minSpeed) / range;
      final double y = size.height - (normalizedValue * size.height);

      points.add(Offset(x, y));
    }

    if (points.isEmpty) return;

    // 🎯 繪製平滑曲線
    path.moveTo(points[0].dx, points[0].dy);

    if (points.length > 2) {
      // 使用貝茲曲線創建平滑效果
      for (int i = 0; i < points.length - 2; i++) {
        final Offset current = points[i];
        final Offset next = points[i + 1];

        // 計算控制點以創建平滑曲線
        final double controlX1 = current.dx + (next.dx - current.dx) * 0.5;
        final double controlY1 = current.dy;
        final double controlX2 = next.dx - (next.dx - current.dx) * 0.5;
        final double controlY2 = next.dy;

        path.cubicTo(controlX1, controlY1, controlX2, controlY2, next.dx, next.dy);
      }

      // 連接到最後一個點
      path.lineTo(points[points.length - 1].dx, points[points.length - 1].dy);
    } else if (points.length == 2) {
      // 只有兩個點時直接連線
      path.lineTo(points[1].dx, points[1].dy);
    }

    // 🎯 創建漸變色畫筆
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF00EEFF),
          Color.fromRGBO(255, 255, 255, 0.5),
        ],
      ).createShader(Rect.fromLTWH(0, 0, chartWidth, size.height));

    // 🎯 創建發光效果畫筆
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF00EEFF),
          Color.fromRGBO(255, 255, 255, 0.5),
        ],
      ).createShader(Rect.fromLTWH(0, 0, chartWidth, size.height))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    // 先繪製發光效果，再繪製主線條
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);

    // 🎯 調試用：可以取消註解來查看數據點位置
    // _drawDebugPoints(canvas, points);
  }

  /// 🎯 調試用：繪製數據點（可選）
  void _drawDebugPoints(Canvas canvas, List<Offset> points) {
    final pointPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 2, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SpeedCurvePainter oldDelegate) {
    return oldDelegate.speedData != speedData ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.currentSpeed != currentSpeed ||
        oldDelegate.isFixedLength != isFixedLength;
  }
}