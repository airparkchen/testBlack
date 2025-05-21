import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'dart:async';
import 'package:whitebox/shared/theme/app_theme.dart';

/// 速度視圖測試頁面
///
/// 此頁面專門用於測試速度區域的顯示效果
class SpeedAreaTestPage extends StatefulWidget {
  const SpeedAreaTestPage({Key? key}) : super(key: key);

  @override
  State<SpeedAreaTestPage> createState() => _SpeedAreaTestPageState();
}

/// 速度數據生成器
/// 用於生成模擬的網絡速度數據
class SpeedDataGenerator {
  // 數據點的數量
  final int dataPointCount;

  // 最小速度值
  final double minSpeed;

  // 最大速度值
  final double maxSpeed;

  // 存儲生成的數據點
  final List<double> _speedData = [];

  // 存儲平滑後的數據點
  final List<double> _smoothedData = [];

  // 隨機數生成器
  final math.Random _random = math.Random();

  // 平滑係數 (0-1，值越大平滑效果越強)
  final double smoothingFactor;

  // 構造函數
  SpeedDataGenerator({
    this.dataPointCount = 100,  // 預設100個數據點
    this.minSpeed = 20,         // 預設最小速度 20 Mbps
    this.maxSpeed = 150,        // 預設最大速度 150 Mbps
    double? initialSpeed,       // 初始速度值，可選
    this.smoothingFactor = 0.8, // 預設平滑係數
  }) {
    // 初始化數據點
    final initialValue = initialSpeed ?? 87.0;  // 默認初始值為87

    // 填充數據點列表
    for (int i = 0; i < dataPointCount; i++) {
      _speedData.add(initialValue);
      _smoothedData.add(initialValue);
    }
  }

  // 取得當前數據點列表的副本 (平滑處理後的)
  List<double> get data => List.from(_smoothedData);

  // 取得當前速度值 (最新的一筆資料)
  double get currentSpeed => _smoothedData.last;

  // 更新數據（添加新的數據點，移除最舊的）
  void update() {
    // 基於最後一個值生成新的速度值
    double newValue = _generateNextValue(_speedData.last);

    // 添加到原始數據
    if (_speedData.length >= dataPointCount) {
      _speedData.removeAt(0);
    }
    _speedData.add(newValue);

    // 應用平滑算法
    if (_smoothedData.length >= dataPointCount) {
      _smoothedData.removeAt(0);
    }

    // 使用指數移動平均 (EMA) 進行平滑處理
    double smoothedValue;
    if (_smoothedData.isNotEmpty) {
      // 新值 = 前一個平滑值 * 平滑係數 + 當前實際值 * (1 - 平滑係數)
      smoothedValue = _smoothedData.last * smoothingFactor + newValue * (1 - smoothingFactor);
    } else {
      smoothedValue = newValue;
    }

    _smoothedData.add(smoothedValue);

    // 打印日誌用於調試
    print('Updated speed: $newValue, Smoothed: $smoothedValue, data points: ${_speedData.length}');
  }

  // 生成下一個數據點
  double _generateNextValue(double currentValue) {
    // 生成 -3 到 3 的隨機波動 (減小波動範圍)
    final double fluctuation = (_random.nextDouble() * 6) - 3;

    // 計算新值
    double newValue = currentValue + fluctuation;

    // 確保值在範圍內
    if (newValue < minSpeed) newValue = minSpeed;
    if (newValue > maxSpeed) newValue = maxSpeed;

    return newValue;
  }
}

class _SpeedAreaTestPageState extends State<SpeedAreaTestPage> with SingleTickerProviderStateMixin {
  // 創建 AppTheme 實例
  final AppTheme _appTheme = AppTheme();

  // 速度數據生成器
  late SpeedDataGenerator _speedDataGenerator;

  // 用於動畫更新的計時器
  Timer? _updateTimer;

  // 動畫控制器
  late AnimationController _animationController;

  // 是否顯示調試信息
  bool _showDebugInfo = false;

  @override
  void initState() {
    super.initState();

    // 初始化速度數據生成器（起始值設為 87Mbps）
    _speedDataGenerator = SpeedDataGenerator(
      initialSpeed: 87,
      minSpeed: 20,
      maxSpeed: 150,
      dataPointCount: 100,
      smoothingFactor: 0.8, // 較高的平滑係數
    );

    // 初始化動畫控制器
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // 啟動數據更新計時器 - 每500毫秒更新一次
    _startDataUpdates();
  }

  // 啟動數據更新
  void _startDataUpdates() {
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setState(() {
        // 更新速度數據
        _speedDataGenerator.update();
      });

      // 重設並啟動動畫
      _animationController.reset();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    // 取消計時器
    _updateTimer?.cancel();

    // 釋放動畫控制器
    _animationController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('速度區域測試'),
        actions: [
          // 添加顯示/隱藏調試信息的按鈕
          IconButton(
            icon: Icon(_showDebugInfo ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() {
                _showDebugInfo = !_showDebugInfo;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 調試信息區域
          if (_showDebugInfo)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('當前速度: ${_speedDataGenerator.currentSpeed.toInt()} Mbps'),
                  Text('數據點數量: ${_speedDataGenerator.data.length}'),
                  Text('動畫值: ${_animationController.value.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          _updateTimer?.cancel();
                          setState(() {
                            _speedDataGenerator.update();
                          });
                          _animationController.reset();
                          _animationController.forward();
                        },
                        child: const Text('單步更新'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          _updateTimer?.cancel();
                          _startDataUpdates();
                        },
                        child: const Text('開始自動更新'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          _updateTimer?.cancel();
                        },
                        child: const Text('停止更新'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // 速度區域
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildSpeedArea(),
          ),

          // 說明文字
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '這是一個測試頁面，用於檢視速度區域的顯示效果。每500毫秒更新一次數據，右上角按鈕可切換顯示調試信息。',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  // 構建速度區域 (Speed Area)
  Widget _buildSpeedArea() {
    //使用MediaQuery避免width: double.infinity造成的Nan計算錯誤
    final screenWidth = MediaQuery.of(context).size.width;
    // 使用 buildStandardCard 作為背景
    return _appTheme.whiteBoxTheme.buildStandardCard(
      // width: double.infinity,
      width: screenWidth,
      height: 154,
      child: SpeedChartWidget(
        dataGenerator: _speedDataGenerator,
        animationController: _animationController,
        endAtPercent: 0.7, // 數據線在70%處結束
      ),
    );
  }
}
/// 速度標籤小部件
/// 一個獨立的顯示速度值的標籤，帶有模糊背景和底部指向
class SpeedLabelWidget extends StatelessWidget {
  // 當前速度值
  final int speed;

  // 標籤寬度
  final double width;

  // 標籤高度
  final double height;

  // 構造函數
  const SpeedLabelWidget({
    Key? key,
    required this.speed,
    this.width = 88,
    this.height = 32,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none, // 允許子元素溢出
      children: [
        // 主體部分（圓角矩形）
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(
              width: width,
              height: height,
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

        // 底部三角形
        Positioned(
          bottom: -6, // 位於底部且稍微突出
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

/// 速度圖表小部件
/// 這是一個可重用的小部件，用於顯示速度圖表
class SpeedChartWidget extends StatefulWidget {
  // 數據生成器
  final SpeedDataGenerator dataGenerator;

  // 動畫控制器
  final AnimationController animationController;

  // 曲線結束的位置（0.0-1.0，表示寬度的百分比）
  final double endAtPercent;

  // 構造函數
  const SpeedChartWidget({
    Key? key,
    required this.dataGenerator,
    required this.animationController,
    this.endAtPercent = 0.7,
  }) : super(key: key);

  @override
  State<SpeedChartWidget> createState() => _SpeedChartWidgetState();
}

class _SpeedChartWidgetState extends State<SpeedChartWidget> {
  @override
  Widget build(BuildContext context) {
    final double currentSpeed = widget.dataGenerator.currentSpeed.round().toDouble();
    final int speedValue = currentSpeed.toInt();

    return LayoutBuilder(
      builder: (context, constraints) {
        // 取得實際寬度和高度
        final double actualWidth = constraints.maxWidth;
        final double actualHeight = constraints.maxHeight;
        final double chartEndX = actualWidth * widget.endAtPercent;

        // 計算白點的位置 - 確保與曲線終點計算一致
        final double normalizedValue = (currentSpeed - widget.dataGenerator.minSpeed) /
            (widget.dataGenerator.maxSpeed - widget.dataGenerator.minSpeed);
        final double dotY = (1.0 - normalizedValue) * actualHeight;

        return Stack(
          clipBehavior: Clip.none, // 允許子元素溢出
          children: [
            // 速度曲線
            Positioned.fill(
              child: AnimatedBuilder(
                animation: widget.animationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _SpeedCurvePainter(
                      speedData: widget.dataGenerator.data,
                      minSpeed: widget.dataGenerator.minSpeed,
                      maxSpeed: widget.dataGenerator.maxSpeed,
                      animationValue: widget.animationController.value,
                      endAtPercent: widget.endAtPercent,
                      currentSpeed: currentSpeed,
                    ),
                    size: Size(actualWidth, actualHeight),
                  );
                },
              ),
            ),

            // 垂直線 (從底部到白點)
            Positioned(
              top: dotY + 8, // 白點底部
              bottom: 0,
              left: chartEndX - 1, // 考慮線寬
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

            // 當前速度標記 (白色圓圈)
            Positioned(
              top: dotY - 8, // 修正位置，減去圓的半徑
              left: chartEndX - 8, // 修正位置，減去圓的半徑
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // 速度標籤 (使用獨立元件)
            Positioned(
              top: dotY - 50, // 在白點上方，考慮標籤高度和三角形
              left: chartEndX - 44, // 居中對齊白點
              child: SpeedLabelWidget(
                speed: speedValue,
              ),
            ),
          ],
        );
      },
    );
  }
}

//   // 根據速度計算Y位置
//   double _calculateYPositionForSpeed(double speed) {
//     final double range = widget.dataGenerator.maxSpeed - widget.dataGenerator.minSpeed;
//     final double normalizedValue = (speed - widget.dataGenerator.minSpeed) / range;
//     final double relativePosition = 1.0 - normalizedValue;
//     return 20 + (relativePosition * 114);
//   }
// }

/// 速度曲線繪製器
class _SpeedCurvePainter extends CustomPainter {
  // 速度數據點列表
  final List<double> speedData;

  // 最小速度值（用於縮放）
  final double minSpeed;

  // 最大速度值（用於縮放）
  final double maxSpeed;

  // 動畫值
  final double animationValue;

  // 曲線結束的位置（0.0-1.0，表示寬度的百分比）
  final double endAtPercent;

  // 當前速度值
  final double currentSpeed;

  _SpeedCurvePainter({
    required this.speedData,
    required this.minSpeed,
    required this.maxSpeed,
    required this.animationValue,
    this.endAtPercent = 1.0,
    required this.currentSpeed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 確保有數據可畫
    if (speedData.isEmpty) return;

    // 計算縮放比例
    final double range = maxSpeed - minSpeed;

    // 創建路徑
    final path = Path();

    // 計算實際結束位置
    final double endX = size.width * endAtPercent;

    // 每個數據點之間的水平距離
    final double stepX = endX / (speedData.length - 1);

    // 初始位置 (右側開始，但不超過指定的結束位置)
    double startX = endX;

    // 計算終點的Y位置 - 直接使用當前速度
    double normalizedValue = (currentSpeed - minSpeed) / range;
    double startY = size.height - (normalizedValue * size.height);

    // 移動到第一個點 (右側) - 這是白點的位置
    path.moveTo(startX, startY);

    // 從右到左逐點繪製曲線 - 使用更平滑的曲線
    final List<Offset> points = [];

    // 首先收集所有點
    points.add(Offset(startX, startY));

    for (int i = speedData.length - 2; i >= 0; i--) {
      // 計算X座標 (向左移動)
      double x = startX - ((speedData.length - 1 - i) * stepX);

      // 確保不超出左邊界
      if (x < 0) break;

      // 計算Y座標
      normalizedValue = (speedData[i] - minSpeed) / range;
      double y = size.height - (normalizedValue * size.height);

      // 添加點
      points.add(Offset(x, y));
    }

    // 使用貝茲曲線平滑連接點
    if (points.length > 2) {
      path.moveTo(points[0].dx, points[0].dy);

      for (int i = 0; i < points.length - 2; i++) {
        final Offset current = points[i];
        final Offset next = points[i + 1];
        final Offset nextNext = points[i + 2];

        // 計算控制點 (比例為0.5，可以調整以改變曲線的平滑度)
        final double controlX1 = current.dx + (next.dx - current.dx) * 0.5;
        final double controlY1 = current.dy;

        final double controlX2 = next.dx - (next.dx - current.dx) * 0.5;
        final double controlY2 = next.dy;

        // 使用三次貝茲曲線
        path.cubicTo(
            controlX1, controlY1,
            controlX2, controlY2,
            next.dx, next.dy
        );
      }

      // 連接最後兩個點
      if (points.length >= 2) {
        path.lineTo(points[points.length - 1].dx, points[points.length - 1].dy);
      }
    } else if (points.length == 2) {
      // 只有兩個點，直接連線
      path.lineTo(points[1].dx, points[1].dy);
    }

    // 創建漸變色的畫筆
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF00EEFF),
          Color.fromRGBO(255, 255, 255, 0.5),
        ],
      ).createShader(Rect.fromLTWH(0, 0, endX, size.height));

    // 創建發光效果的畫筆
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF00EEFF),
          Color.fromRGBO(255, 255, 255, 0.5),
        ],
      ).createShader(Rect.fromLTWH(0, 0, endX, size.height))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    // 調試：繪製終點指示器
    final Paint dotPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    // 先繪製發光效果
    canvas.drawPath(path, glowPaint);

    // 再繪製主線條
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SpeedCurvePainter oldDelegate) {
    return oldDelegate.speedData != speedData ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.currentSpeed != currentSpeed;
  }
}