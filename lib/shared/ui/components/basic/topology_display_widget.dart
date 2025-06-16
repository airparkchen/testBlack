// lib/shared/ui/components/basic/topology_display_widget.dart - 最小修正版本
// 🎯 只添加 Gateway 設備載入，保持原有結構不變

import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:whitebox/shared/ui/components/basic/NetworkTopologyComponent.dart';
import 'package:whitebox/shared/theme/app_theme.dart';
import 'package:whitebox/shared/ui/pages/home/Topo/network_topo_config.dart';
import 'package:whitebox/shared/ui/pages/home/Topo/fake_data_generator.dart';
import 'package:whitebox/shared/ui/pages/home/Topo/fake_data_generator.dart' as RealSpeedService;   //改用fake_data_generator中的服務
//TODO 未來要重構與分類  real_speed_data_service,real_data_integration_service,fake_data_generator...etc之中的套件
import 'package:whitebox/shared/services/real_data_integration_service.dart'; // 🎯 新增

/// 拓樸圖和速度圖組合組件
class TopologyDisplayWidget extends StatefulWidget {
  final List<NetworkDevice> devices;
  final List<DeviceConnection> deviceConnections;
  final String gatewayName;
  final bool enableInteractions;
  final Function(NetworkDevice)? onDeviceSelected;
  final AnimationController animationController;

  const TopologyDisplayWidget({
    Key? key,
    required this.devices,
    required this.deviceConnections,
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

  // 🎯 速度數據生成器 - 保持原有邏輯
  late SpeedDataGenerator? _fakeSpeedDataGenerator;
  late RealSpeedService.RealSpeedDataGenerator? _realSpeedDataGenerator;

  // 🎯 新增：Gateway 設備資料
  NetworkDevice? _gatewayDevice;
  bool _isLoadingGateway = false;

  @override
  void initState() {
    super.initState();

    // 🎯 原有的速度數據初始化邏輯
    if (NetworkTopoConfig.useRealData) {
      _realSpeedDataGenerator = RealSpeedService.RealSpeedDataGenerator(
        dataPointCount: 100,
        minSpeed: 0,
        maxSpeed: 1000,
        updateInterval: Duration(seconds: 10),
      );
      _fakeSpeedDataGenerator = null;
      print('🌐 初始化真實速度數據生成器');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });

    } else {
      _fakeSpeedDataGenerator = FakeDataGenerator.createSpeedGenerator();
      _realSpeedDataGenerator = null;
      print('🎭 初始化假數據速度生成器（固定長度滑動窗口模式）');
    }

    // 🎯 新增：載入 Gateway 設備資料
    _loadGatewayDevice();
  }

  /// 🎯 新增：載入真實 Gateway 設備資料
  Future<void> _loadGatewayDevice() async {
    if (!mounted) return;

    setState(() {
      _isLoadingGateway = true;
    });

    try {
      // 🎯 使用 RealDataIntegrationService 獲取 Gateway 設備
      final listDevices = await RealDataIntegrationService.getListViewDevices();

      // 找到 Gateway 設備
      final gateway = listDevices.firstWhere(
            (device) => device.additionalInfo['type'] == 'gateway',
        orElse: () => NetworkDevice(
          name: 'Controller',
          id: 'device-gateway',
          mac: '8c:0f:6f:61:0a:77',
          ip: '192.168.1.1',
          connectionType: ConnectionType.wired,
          additionalInfo: {
            'type': 'gateway',
            'status': 'online',
            'clients': '0',
          },
        ),
      );

      if (mounted) {
        setState(() {
          _gatewayDevice = gateway;
          _isLoadingGateway = false;
        });

        print('✅ 載入真實 Gateway 設備: ${gateway.name} (${gateway.mac})');
        print('   Gateway 客戶端數量: ${gateway.additionalInfo['clients']}');
      }
    } catch (e) {
      print('❌ 載入 Gateway 設備失敗: $e');
      if (mounted) {
        setState(() {
          _isLoadingGateway = false;
        });
      }
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
          // 主要拓樸圖
          Expanded(
            child: Center(
              child: NetworkTopologyComponent(
                gatewayDevice: _gatewayDevice, // 🎯 新增：傳遞真實 Gateway 設備
                gatewayName: widget.gatewayName,
                devices: widget.devices,
                deviceConnections: widget.deviceConnections,
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
    if (widget.deviceConnections.isEmpty) {
      print('⚠️ deviceConnections 為空，返回設備數量');
      return widget.devices.length;
    }

    try {
      final gatewayConnection = widget.deviceConnections.firstWhere(
            (conn) => conn.deviceId.contains('8c0f6f610a77') || // 🎯 修正：使用正確的 Gateway MAC
            conn.deviceId.toLowerCase().contains('gateway') ||
            conn.deviceId.toLowerCase().contains('controller'),
        orElse: () => DeviceConnection(deviceId: '', connectedDevicesCount: 0),
      );

      final totalConnected = gatewayConnection.connectedDevicesCount;
      return totalConnected;
    } catch (e) {
      return widget.devices.length;
    }
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
    if (_fakeSpeedDataGenerator == null) {
      return _buildErrorChart('假數據生成器未初始化');
    }

    return SpeedChartWidget(
      dataGenerator: _fakeSpeedDataGenerator!,
      animationController: widget.animationController,
      endAtPercent: 0.7,
      isRealData: false,
    );
  }

  /// 建構真實資料速度圖表
  Widget _buildRealSpeedChart() {
    if (_realSpeedDataGenerator == null) {
      return _buildErrorChart('真實數據生成器未初始化');
    }

    return RealSpeedChartWidget(
      dataGenerator: _realSpeedDataGenerator!,
      animationController: widget.animationController,
      endAtPercent: 0.7,
    );
  }

  /// 錯誤狀態顯示
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

  /// 更新速度數據（供外部調用）
  void updateSpeedData() {
    if (!mounted) return;

    if (NetworkTopoConfig.useRealData) {
      _realSpeedDataGenerator?.update();
    } else {
      if (_fakeSpeedDataGenerator != null) {
        setState(() {
          _fakeSpeedDataGenerator!.update();
        });
      }
    }
  }
}

// 🎯 保持原有的所有 Widget 類別不變
/// 假數據速度圖表小部件
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final double actualWidth = constraints.maxWidth;
        final double actualHeight = constraints.maxHeight;
        final double chartEndX = actualWidth * endAtPercent;

        final double normalizedValue = (currentSpeed - dataGenerator.minSpeed) /
            (dataGenerator.maxSpeed - dataGenerator.minSpeed);
        final double dotY = (1.0 - normalizedValue) * actualHeight;
        final double currentWidthPercentage = dataGenerator.getWidthPercentage();

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
                      isFixedLength: true,
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

/// 真實數據速度圖表小部件
class RealSpeedChartWidget extends StatelessWidget {
  final RealSpeedService.RealSpeedDataGenerator dataGenerator;
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
    final double currentSpeed = dataGenerator.currentSpeed.round().toDouble();
    final int speedValue = currentSpeed.toInt();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double actualWidth = constraints.maxWidth;
        final double actualHeight = constraints.maxHeight;
        final double chartEndX = actualWidth * endAtPercent;

        final double normalizedValue = (currentSpeed - dataGenerator.minSpeed) /
            (dataGenerator.maxSpeed - dataGenerator.minSpeed);
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
                    painter: RealSpeedCurvePainter(
                      speedData: dataGenerator.data,
                      minSpeed: dataGenerator.minSpeed,
                      maxSpeed: dataGenerator.maxSpeed,
                      animationValue: animationController.value,
                      endAtPercent: endAtPercent,
                      currentSpeed: currentSpeed,
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
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        currentSpeed > 0 ? Colors.white : Colors.white.withOpacity(0.5),
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
                  decoration: BoxDecoration(
                    color: currentSpeed > 0 ? Colors.white : Colors.white.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // 速度標籤
              Positioned(
                top: dotY - 50,
                left: chartEndX - 44,
                child: _buildSpeedLabel(speedValue, currentSpeed > 0),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSpeedLabel(int speed, bool hasSpeed) {
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
                  style: TextStyle(
                    color: hasSpeed
                        ? Color.fromRGBO(255, 255, 255, 0.8)
                        : Color.fromRGBO(255, 255, 255, 0.6),
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

/// 真實數據曲線繪製器
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

    final double normalizedValue = (currentSpeed - minSpeed) / range;
    final double y = size.height - (normalizedValue * size.height);

    // 繪製水平直線
    path.moveTo(0, y);
    path.lineTo(chartWidth, y);

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

/// 速度曲線繪製器
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
    this.isFixedLength = true,
    required this.currentWidthPercentage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (speedData.isEmpty || size.width <= 0 || size.height <= 0) return;

    final double range = maxSpeed - minSpeed;
    if (range <= 0) return;

    final path = Path();
    final double chartWidth = size.width * endAtPercent;
    final double stepX = chartWidth / (speedData.length - 1);

    final List<Offset> points = [];

    for (int i = 0; i < speedData.length; i++) {
      final double x = i * stepX;
      final double normalizedValue = (speedData[i] - minSpeed) / range;
      final double y = size.height - (normalizedValue * size.height);
      points.add(Offset(x, y));
    }

    if (points.isEmpty) return;

    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 1; i < points.length; i++) {
      final cp1 = Offset(
        points[i - 1].dx + (points[i].dx - points[i - 1].dx) * 0.4,
        points[i - 1].dy,
      );
      final cp2 = Offset(
        points[i - 1].dx + (points[i].dx - points[i - 1].dx) * 0.6,
        points[i].dy,
      );
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i].dx, points[i].dy);
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = const LinearGradient(
        colors: [
          Color.fromRGBO(255, 255, 255, 0.3),
          Color(0xFF00EEFF),
        ],
      ).createShader(Rect.fromLTWH(0, 0, chartWidth, size.height));

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF00EEFF).withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SpeedCurvePainter oldDelegate) {
    return oldDelegate.speedData != speedData ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.currentSpeed != currentSpeed ||
        oldDelegate.currentWidthPercentage != currentWidthPercentage;
  }
}