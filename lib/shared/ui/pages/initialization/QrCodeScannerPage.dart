import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:whitebox/shared/theme/app_theme.dart';

class QrCodeScannerPage extends StatefulWidget {
  const QrCodeScannerPage({super.key});

  @override
  State<QrCodeScannerPage> createState() => _QrCodeScannerPageState();
}

class _QrCodeScannerPageState extends State<QrCodeScannerPage> {
  final AppTheme _appTheme = AppTheme();
  MobileScannerController? _controller;
  String qrResult = '';
  bool isScanning = true;
  bool _isCameraInitFailed = false;

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  void _initializeScanner() {
    try {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      );
    } catch (e) {
      print('Camera initialization failed: $e');
      setState(() {
        _isCameraInitFailed = true;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final safeAreaPadding = MediaQuery.of(context).padding;

    // 計算安全區域內的可用高度
    final availableHeight = size.height - safeAreaPadding.top - safeAreaPadding.bottom;

    // 文字高度比例：225-36-695 (總計956)
    const textHeightTotal = 201 + 60 + 695; // 956
    final topTextMargin = availableHeight * (201 / textHeightTotal);
    final textHeight = availableHeight * (60 / textHeightTotal);

    // 相機高度比例：281-394-281 (總計956)
    const cameraHeightTotal = 281 + 394 + 281; // 956
    final cameraAreaTop = availableHeight * (281 / cameraHeightTotal);
    final cameraHeight = availableHeight * (394 / cameraHeightTotal);

    // 相機寬度比例：20-400-20 (總計440)
    const cameraWidthProportion = 20 + 400 + 20; // 440
    final leftCameraMargin = size.width * (20 / cameraWidthProportion);
    final cameraWidth = size.width * (400 / cameraWidthProportion);

    // 按鈕寬度比例：20-150-100-150-20 (總計440)
    const buttonWidthProportion = 20 + 150 + 100 + 150 + 20; // 440
    final leftButtonMargin = size.width * (20 / buttonWidthProportion);
    final backButtonWidth = size.width * (150 / buttonWidthProportion);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          child: SizedBox(
            height: availableHeight,
            child: Column(
              children: [
                // 標題前的空間
                SizedBox(height: topTextMargin),

                // 標題文字
                SizedBox(
                  height: textHeight,
                  child: Center(
                    child: Text(
                      'Wi-Fi on/off Check',
                      style: AppTextStyles.heading1,
                    ),
                  ),
                ),

                // 標題與相機之間的空間
                SizedBox(height: cameraAreaTop - topTextMargin - textHeight),

                // 相機預覽容器
                SizedBox(
                  height: cameraHeight,
                  child: Row(
                    children: [
                      // 左邊距
                      SizedBox(width: leftCameraMargin),

                      // 相機預覽
                      SizedBox(
                        width: cameraWidth,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey[400]!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: _buildCameraView(cameraWidth, cameraHeight),
                          ),
                        ),
                      ),

                      // 右邊距
                      SizedBox(width: leftCameraMargin),
                    ],
                  ),
                ),

                // 底部空間 - 用於放置按鈕
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 按鈕區域 - 只保留Back按鈕
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            // 左側留白
                            SizedBox(width: leftButtonMargin),

                            // 返回按鈕使用紫色邊框樣式
                            SizedBox(
                              width: backButtonWidth,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.pop(context, qrResult.isNotEmpty ? qrResult : null);
                                },
                                child: Container(
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                                    color: const Color(0xFF9747FF).withOpacity(0.2),
                                    border: Border.all(
                                      color: const Color(0xFF9747FF),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                        'Back',
                                        style: AppTextStyles.buttonText
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraView(double width, double height) {
    // 如果相機初始化失敗，顯示錯誤信息
    if (_isCameraInitFailed) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              'Camera initialization failed',
              style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Please check camera permissions',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      );
    }

    // 如果相機控制器為空，顯示加載動畫
    if (_controller == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      );
    }

    // 正常顯示相機和掃描結果
    return Stack(
      alignment: Alignment.center,
      children: [
        // 相機視圖
        MobileScanner(
          controller: _controller!,
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty && isScanning) {
              setState(() {
                qrResult = barcodes.first.rawValue ?? 'Unable to read';
                isScanning = false;
                _controller!.stop();
              });
            }
          },
        ),

        // 掃描框
        if (isScanning)
          Container(
            width: width * 0.6,
            height: height * 0.6,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(12),
            ),
          ),

        // 顯示掃描結果
        if (qrResult.isNotEmpty)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              color: Colors.black54,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Scan Result',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    qrResult,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}