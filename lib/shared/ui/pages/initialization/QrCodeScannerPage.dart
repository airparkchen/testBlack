import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrCodeScannerPage extends StatefulWidget {
  const QrCodeScannerPage({super.key});

  @override
  State<QrCodeScannerPage> createState() => _QrCodeScannerPageState();
}

class _QrCodeScannerPageState extends State<QrCodeScannerPage> {
  late MobileScannerController controller;
  String qrResult = '';
  bool isScanning = true;
  bool isFlashOn = false;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _toggleFlash() async {
    await controller.toggleTorch();
    setState(() {
      isFlashOn = !isFlashOn;
    });
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
    final middleButtonSpace = size.width * (100 / buttonWidthProportion);
    final nextButtonWidth = size.width * (150 / buttonWidthProportion);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: SizedBox(
            height: availableHeight,
            child: Column(
              children: [
                // 標題前的空間
                SizedBox(height: topTextMargin),

                // 標題文字 - 使用明確的高度
                SizedBox(
                  height: textHeight,
                  child: const Center(
                    child: Text(
                      'Scan QRcode',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ),

                // 標題與相機之間的空間 - 使用計算得到的空間
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
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // 掃描器視圖
                                MobileScanner(
                                  controller: controller,
                                  onDetect: (capture) {
                                    final List<Barcode> barcodes = capture.barcodes;
                                    if (barcodes.isNotEmpty && isScanning) {
                                      // 獲取掃描結果
                                      setState(() {
                                        qrResult = barcodes.first.rawValue ?? '無法讀取';
                                        isScanning = false;
                                        controller.stop();
                                      });
                                    }
                                  },
                                ),

                                // 掃描框
                                if (isScanning)
                                  Center(
                                    child: Container(
                                      width: cameraWidth * 0.6,  // 相機寬度的60%
                                      height: cameraHeight * 0.6, // 相機高度的60%
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.white, width: 3),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
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
                                            '掃描結果',
                                            style: TextStyle(
                                                fontSize: 18,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            qrResult,
                                            style: const TextStyle(
                                                fontSize: 16,
                                                color: Colors.white
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 右邊距
                      SizedBox(width: leftCameraMargin), // 與左邊距相同
                    ],
                  ),
                ),

                // 底部空間 - 用於放置按鈕
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, // 垂直居中
                    children: [
                      // 按鈕區域 - 根據比例設置
                      Row(
                        children: [
                          // 左側留白
                          SizedBox(width: leftButtonMargin),

                          // 返回按鈕
                          SizedBox(
                            width: backButtonWidth,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[300],
                                foregroundColor: Colors.black,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(0),
                                  side: BorderSide(color: Colors.grey[400]!),
                                ),
                              ),
                              child: const Text(
                                'Back',
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                          ),

                          // 中間間隔
                          SizedBox(width: middleButtonSpace),

                          // 下一步按鈕
                          SizedBox(
                            width: nextButtonWidth,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: qrResult.isEmpty
                                  ? () {
                                if (!isScanning) {
                                  setState(() {
                                    isScanning = true;
                                    controller.start();
                                  });
                                }
                              }
                                  : () {
                                // 如果有掃描結果，可以傳遞結果返回上一頁
                                Navigator.pop(context, qrResult);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[300],
                                foregroundColor: Colors.black,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(0),
                                  side: BorderSide(color: Colors.grey[400]!),
                                ),
                              ),
                              child: Text(
                                qrResult.isEmpty ? 'Next' : 'Next',
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                          ),

                          // 右側留白
                          SizedBox(width: leftButtonMargin), // 與左邊距相同
                        ],
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
}