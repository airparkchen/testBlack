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

/// 速度數據生成器 - 雙線版本
/// 用於生成模擬的網絡速度數據（上傳 + 下載）
class SpeedDataGenerator {
  final int dataPointCount;
  final double minSpeed;
  final double maxSpeed;

  // 🎯 雙線數據存儲
  final List<double> _uploadData = [];
  final List<double> _downloadData = [];
  final List<double> _uploadSmoothed = [];
  final List<double> _downloadSmoothed = [];

  final math.Random _random = math.Random();
  final double smoothingFactor;

  SpeedDataGenerator({
    this.dataPointCount = 100,
    this.minSpeed = 20,
    this.maxSpeed = 150,
    double? initialUploadSpeed,   // 🎯 上傳初始速度
    double? initialDownloadSpeed, // 🎯 下載初始速度
    this.smoothingFactor = 0.8,
  }) {
    final initialUpload = initialUploadSpeed ?? 65.0;
    final initialDownload = initialDownloadSpeed ?? 87.0;

    // 🎯 填充雙線數據
    for (int i = 0; i < dataPointCount; i++) {
      _uploadData.add(initialUpload);
      _downloadData.add(initialDownload);
      _uploadSmoothed.add(initialUpload);
      _downloadSmoothed.add(initialDownload);
    }
  }
  // 🎯 新的 getter 方法（SpeedChartWidget 需要的）
  List<double> get uploadData => List.from(_uploadSmoothed);
  List<double> get downloadData => List.from(_downloadSmoothed);
  double get currentUpload => _uploadSmoothed.isNotEmpty ? _uploadSmoothed.last : 65.0;
  double get currentDownload => _downloadSmoothed.isNotEmpty ? _downloadSmoothed.last : 87.0;

  // 🎯 向後兼容的方法
  List<double> get data => downloadData;
  double get currentSpeed => currentDownload;


  // 更新數據（添加新的數據點，移除最舊的）
  // 更新方法 - 雙線版本
  void update() {
    double newUpload = _generateNextValue(_uploadData.last, isUpload: true);
    double newDownload = _generateNextValue(_downloadData.last, isUpload: false);

    // 管理滑動窗口
    if (_uploadData.length >= dataPointCount) {
      _uploadData.removeAt(0);
      _downloadData.removeAt(0);
      _uploadSmoothed.removeAt(0);
      _downloadSmoothed.removeAt(0);
    }

    _uploadData.add(newUpload);
    _downloadData.add(newDownload);

    // 平滑處理
    double smoothedUpload = _uploadSmoothed.isNotEmpty
        ? _uploadSmoothed.last * smoothingFactor + newUpload * (1 - smoothingFactor)
        : newUpload;

    double smoothedDownload = _downloadSmoothed.isNotEmpty
        ? _downloadSmoothed.last * smoothingFactor + newDownload * (1 - smoothingFactor)
        : newDownload;

    _uploadSmoothed.add(smoothedUpload);
    _downloadSmoothed.add(smoothedDownload);

    print('Updated speeds - Upload: ${smoothedUpload.toStringAsFixed(1)} Mbps, Download: ${smoothedDownload.toStringAsFixed(1)} Mbps');
  }

  double _generateNextValue(double currentValue, {required bool isUpload}) {
    double fluctuationRange = isUpload ? 4.0 : 6.0;
    final double fluctuation = (_random.nextDouble() * fluctuationRange * 2) - fluctuationRange;
    double newValue = currentValue + fluctuation;

    if (isUpload) {
      // 上傳速度範圍較低
      double uploadMax = minSpeed + (maxSpeed - minSpeed) * 0.7;
      newValue = newValue.clamp(minSpeed, uploadMax);
    } else {
      // 下載速度使用完整範圍
      newValue = newValue.clamp(minSpeed, maxSpeed);
    }

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
      initialUploadSpeed: 65,    // 🎯 新增：上傳初始速度
      initialDownloadSpeed: 87,  // 🎯 新增：下載初始速度
      minSpeed: 20,
      maxSpeed: 150,
      dataPointCount: 100,
      smoothingFactor: 0.8,
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
                  Text('當前上傳速度: ${_speedDataGenerator.currentUpload.toInt()} Mbps'),
                  Text('當前下載速度: ${_speedDataGenerator.currentDownload.toInt()} Mbps'),
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
//// 速度圖表小部件 - 雙線版本
class SpeedChartWidget extends StatefulWidget {
  // 資料生成器 (支援雙線)
  final dynamic dataGenerator; // SpeedDataGenerator 或 RealSpeedDataGenerator

  // 動畫控制器
  final AnimationController animationController;

  // 曲線結束的位置（0.0-1.0，表示寬度的百分比）
  final double endAtPercent;

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

    print('\n=== SpeedChartWidget 調試開始 ===');
    print('dataGenerator 類型: ${widget.dataGenerator.runtimeType}');
    print('當前上傳速度: ${widget.dataGenerator.currentUpload}');
    print('當前下載速度: ${widget.dataGenerator.currentDownload}');
    print('上傳資料點數: ${widget.dataGenerator.uploadData.length}');
    print('下載資料點數: ${widget.dataGenerator.downloadData.length}');
    print('=== 調試結束 ===\n');

    // 🎯 獲取雙線資料
    final double currentUpload = widget.dataGenerator.currentUpload.round().toDouble();
    final double currentDownload = widget.dataGenerator.currentDownload.round().toDouble();
    final List<double> uploadData = widget.dataGenerator.uploadData;
    final List<double> downloadData = widget.dataGenerator.downloadData;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double actualWidth = constraints.maxWidth;
        final double actualHeight = constraints.maxHeight;
        final double chartEndX = actualWidth * widget.endAtPercent;

        // 🎯 計算兩個白點的位置
        final double uploadNormalized = (currentUpload - widget.dataGenerator.minSpeed) /
            (widget.dataGenerator.maxSpeed - widget.dataGenerator.minSpeed);
        final double downloadNormalized = (currentDownload - widget.dataGenerator.minSpeed) /
            (widget.dataGenerator.maxSpeed - widget.dataGenerator.minSpeed);

        final double uploadDotY = (1.0 - uploadNormalized) * actualHeight;
        final double downloadDotY = (1.0 - downloadNormalized) * actualHeight;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // 🎯 雙線速度曲線
            Positioned.fill(
              child: AnimatedBuilder(
                animation: widget.animationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _DualSpeedCurvePainter(
                      uploadData: uploadData,
                      downloadData: downloadData,
                      minSpeed: widget.dataGenerator.minSpeed,
                      maxSpeed: widget.dataGenerator.maxSpeed,
                      animationValue: widget.animationController.value,
                      endAtPercent: widget.endAtPercent,
                      currentUpload: currentUpload,
                      currentDownload: currentDownload,
                    ),
                    size: Size(actualWidth, actualHeight),
                  );
                },
              ),
            ),

            // 🎯 上傳速度垂直線
            Positioned(
              top: uploadDotY + 8,
              bottom: 0,
              left: chartEndX - 1,
              child: Container(
                width: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.orange.withOpacity(0.8), // 上傳線顏色
                      Colors.orange.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),

            // 🎯 下載速度垂直線
            Positioned(
              top: downloadDotY + 8,
              bottom: 0,
              left: chartEndX + 1, // 稍微偏移避免重疊
              child: Container(
                width: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF00EEFF).withOpacity(0.8), // 下載線顏色
                      Color(0xFF00EEFF).withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),

            // 🎯 上傳速度標記 (橙色圓圈)
            Positioned(
              top: uploadDotY - 6,
              left: chartEndX - 6,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
            ),

            // 🎯 下載速度標記 (藍色圓圈)
            Positioned(
              top: downloadDotY - 6,
              left: chartEndX + 6, // 稍微偏移
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Color(0xFF00EEFF),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
            ),

            // 🎯 雙線速度標籤
            Positioned(
              top: math.min(uploadDotY, downloadDotY) - 60, // 在較高的點上方
              left: chartEndX - 60, // 居中對齊
              child: DualSpeedLabelWidget(
                uploadSpeed: currentUpload.toInt(),
                downloadSpeed: currentDownload.toInt(),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 🎯 雙線速度標籤小部件
class DualSpeedLabelWidget extends StatelessWidget {
  final int uploadSpeed;
  final int downloadSpeed;
  final double width;
  final double height;

  const DualSpeedLabelWidget({
    Key? key,
    required this.uploadSpeed,
    required this.downloadSpeed,
    this.width = 120,
    this.height = 50,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 主體部分（圓角矩形）
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 上傳速度
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        '↑ $uploadSpeed Mb/s',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  // 下載速度
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Color(0xFF00EEFF),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        '↓ $downloadSpeed Mb/s',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // 底部三角形
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
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}


/// 🎯 雙線速度曲線繪製器
class _DualSpeedCurvePainter extends CustomPainter {
  final List<double> uploadData;
  final List<double> downloadData;
  final double minSpeed;
  final double maxSpeed;
  final double animationValue;
  final double endAtPercent;
  final double currentUpload;
  final double currentDownload;

  _DualSpeedCurvePainter({
    required this.uploadData,
    required this.downloadData,
    required this.minSpeed,
    required this.maxSpeed,
    required this.animationValue,
    this.endAtPercent = 1.0,
    required this.currentUpload,
    required this.currentDownload,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (uploadData.isEmpty || downloadData.isEmpty) return;

    final double range = maxSpeed - minSpeed;
    final double endX = size.width * endAtPercent;
    final double stepX = endX / (uploadData.length - 1);

    // 🎯 繪製上傳速度曲線（橙色）
    _drawSpeedCurve(
      canvas,
      size,
      uploadData,
      range,
      endX,
      stepX,
      currentUpload,
      Colors.orange,
      Colors.orange.withOpacity(0.6),
    );

    // 🎯 繪製下載速度曲線（藍色）
    _drawSpeedCurve(
      canvas,
      size,
      downloadData,
      range,
      endX,
      stepX,
      currentDownload,
      Color(0xFF00EEFF),
      Color(0xFF00EEFF).withOpacity(0.6),
    );
  }

  void _drawSpeedCurve(
      Canvas canvas,
      Size size,
      List<double> data,
      double range,
      double endX,
      double stepX,
      double currentValue,
      Color primaryColor,
      Color secondaryColor,
      ) {
    final path = Path();

    // 計算起始點
    double normalizedValue = (currentValue - minSpeed) / range;
    double startY = size.height - (normalizedValue * size.height);
    path.moveTo(endX, startY);

    // 收集所有點
    final List<Offset> points = [Offset(endX, startY)];

    for (int i = data.length - 2; i >= 0; i--) {
      double x = endX - ((data.length - 1 - i) * stepX);
      if (x < 0) break;

      normalizedValue = (data[i] - minSpeed) / range;
      double y = size.height - (normalizedValue * size.height);
      points.add(Offset(x, y));
    }

    // 使用貝茲曲線平滑連接
    if (points.length > 2) {
      for (int i = 0; i < points.length - 2; i++) {
        final current = points[i];
        final next = points[i + 1];

        final controlX1 = current.dx + (next.dx - current.dx) * 0.5;
        final controlY1 = current.dy;
        final controlX2 = next.dx - (next.dx - current.dx) * 0.5;
        final controlY2 = next.dy;

        path.cubicTo(controlX1, controlY1, controlX2, controlY2, next.dx, next.dy);
      }

      if (points.length >= 2) {
        path.lineTo(points.last.dx, points.last.dy);
      }
    }

    // 創建漸變畫筆
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = LinearGradient(
        colors: [primaryColor, secondaryColor],
      ).createShader(Rect.fromLTWH(0, 0, endX, size.height));

    // 發光效果
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..shader = LinearGradient(
        colors: [primaryColor, secondaryColor],
      ).createShader(Rect.fromLTWH(0, 0, endX, size.height))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2);

    // 繪製
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DualSpeedCurvePainter oldDelegate) {
    return oldDelegate.uploadData != uploadData ||
        oldDelegate.downloadData != downloadData ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.currentUpload != currentUpload ||
        oldDelegate.currentDownload != currentDownload;
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
//
// /// 速度曲線繪製器
// class _SpeedCurvePainter extends CustomPainter {
//   // 速度數據點列表
//   final List<double> speedData;
//
//   // 最小速度值（用於縮放）
//   final double minSpeed;
//
//   // 最大速度值（用於縮放）
//   final double maxSpeed;
//
//   // 動畫值
//   final double animationValue;
//
//   // 曲線結束的位置（0.0-1.0，表示寬度的百分比）
//   final double endAtPercent;
//
//   // 當前速度值
//   final double currentSpeed;
//
//   _SpeedCurvePainter({
//     required this.speedData,
//     required this.minSpeed,
//     required this.maxSpeed,
//     required this.animationValue,
//     this.endAtPercent = 1.0,
//     required this.currentSpeed,
//   });
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     // 確保有數據可畫
//     if (speedData.isEmpty) return;
//
//     // 計算縮放比例
//     final double range = maxSpeed - minSpeed;
//
//     // 創建路徑
//     final path = Path();
//
//     // 計算實際結束位置
//     final double endX = size.width * endAtPercent;
//
//     // 每個數據點之間的水平距離
//     final double stepX = endX / (speedData.length - 1);
//
//     // 初始位置 (右側開始，但不超過指定的結束位置)
//     double startX = endX;
//
//     // 計算終點的Y位置 - 直接使用當前速度
//     double normalizedValue = (currentSpeed - minSpeed) / range;
//     double startY = size.height - (normalizedValue * size.height);
//
//     // 移動到第一個點 (右側) - 這是白點的位置
//     path.moveTo(startX, startY);
//
//     // 從右到左逐點繪製曲線 - 使用更平滑的曲線
//     final List<Offset> points = [];
//
//     // 首先收集所有點
//     points.add(Offset(startX, startY));
//
//     for (int i = speedData.length - 2; i >= 0; i--) {
//       // 計算X座標 (向左移動)
//       double x = startX - ((speedData.length - 1 - i) * stepX);
//
//       // 確保不超出左邊界
//       if (x < 0) break;
//
//       // 計算Y座標
//       normalizedValue = (speedData[i] - minSpeed) / range;
//       double y = size.height - (normalizedValue * size.height);
//
//       // 添加點
//       points.add(Offset(x, y));
//     }
//
//     // 使用貝茲曲線平滑連接點
//     if (points.length > 2) {
//       path.moveTo(points[0].dx, points[0].dy);
//
//       for (int i = 0; i < points.length - 2; i++) {
//         final Offset current = points[i];
//         final Offset next = points[i + 1];
//         final Offset nextNext = points[i + 2];
//
//         // 計算控制點 (比例為0.5，可以調整以改變曲線的平滑度)
//         final double controlX1 = current.dx + (next.dx - current.dx) * 0.5;
//         final double controlY1 = current.dy;
//
//         final double controlX2 = next.dx - (next.dx - current.dx) * 0.5;
//         final double controlY2 = next.dy;
//
//         // 使用三次貝茲曲線
//         path.cubicTo(
//             controlX1, controlY1,
//             controlX2, controlY2,
//             next.dx, next.dy
//         );
//       }
//
//       // 連接最後兩個點
//       if (points.length >= 2) {
//         path.lineTo(points[points.length - 1].dx, points[points.length - 1].dy);
//       }
//     } else if (points.length == 2) {
//       // 只有兩個點，直接連線
//       path.lineTo(points[1].dx, points[1].dy);
//     }
//
//     // 創建漸變色的畫筆
//     final paint = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 2
//       ..shader = const LinearGradient(
//         colors: [
//           Color(0xFF00EEFF),
//           Color.fromRGBO(255, 255, 255, 0.5),
//         ],
//       ).createShader(Rect.fromLTWH(0, 0, endX, size.height));
//
//     // 創建發光效果的畫筆
//     final glowPaint = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 3
//       ..shader = const LinearGradient(
//         colors: [
//           Color(0xFF00EEFF),
//           Color.fromRGBO(255, 255, 255, 0.5),
//         ],
//       ).createShader(Rect.fromLTWH(0, 0, endX, size.height))
//       ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
//
//     // 調試：繪製終點指示器
//     final Paint dotPaint = Paint()
//       ..color = Colors.red
//       ..style = PaintingStyle.fill;
//
//     // 先繪製發光效果
//     canvas.drawPath(path, glowPaint);
//
//     // 再繪製主線條
//     canvas.drawPath(path, paint);
//   }
//
//   @override
//   bool shouldRepaint(covariant _SpeedCurvePainter oldDelegate) {
//     return oldDelegate.speedData != speedData ||
//         oldDelegate.animationValue != animationValue ||
//         oldDelegate.currentSpeed != currentSpeed;
//   }
// }