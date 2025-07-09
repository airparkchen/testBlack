import 'package:flutter/material.dart';
import 'dart:async';
import 'package:whitebox/shared/theme/app_theme.dart';
import 'package:whitebox/shared/ui/components/basic/WifiScannerComponent.dart';

class ProcessInfo {
  final String name;
  final double percentage;

  ProcessInfo(this.name, this.percentage);
}

class FinishingWizardComponent extends StatefulWidget {
  // 保留舊版本的參數以維持向後相容性
  final List<String>? processNames;
  final int? totalDurationSeconds;

  // 新版本的參數
  final Function(Function(double, {String? status}) updateProgress)? onProgressControllerReady;
  final Function()? onCompleted;
  final double? height;

  const FinishingWizardComponent({
    Key? key,
    // 舊版本參數（已棄用但保留相容性）
    this.processNames,
    this.totalDurationSeconds,
    // 新版本參數
    this.onProgressControllerReady,
    this.onCompleted,
    this.height,
  }) : super(key: key);

  @override
  State<FinishingWizardComponent> createState() => _FinishingWizardComponentState();
}

class _FinishingWizardComponentState extends State<FinishingWizardComponent> {
  // 🔥 修改：改為單一Process
  late List<ProcessInfo> _processes;
  Timer? _timer;
  int _currentProcessIndex = 0; // 🔥 修正：添加缺少的變數（舊模式需要）
  double _currentProgress = 0.0;
  String _currentStatus = 'Initializing...';
  bool _isCompleted = false;
  final AppTheme _appTheme = AppTheme();
  bool _isNewMode = false; // 判斷是否使用新模式

  // API 進度控制
  double _apiProgress = 0.0;
  bool _isApiPhase = false; // 是否進入 API 執行階段

  @override
  void initState() {
    super.initState();

    // 判斷使用模式
    _isNewMode = widget.onProgressControllerReady != null;

    if (_isNewMode) {
      // 🔥 新模式：單一Process，延遲2秒後開始API
      _initializeSingleProcessMode();
    } else {
      // 舊模式：內部定時器控制進度（保持原有邏輯）
      _initializeOldMode();
    }
  }

  // 🔥 新增：單一Process模式初始化
  void _initializeSingleProcessMode() {
    // 🔥 只使用 1 個 process，名稱改為 'Process 04'（保持原本的樣子）
    final processNames = ['Process 01'];

    // 初始化進程列表
    _processes = processNames.map((name) => ProcessInfo(name, 0.0)).toList();

    // 將進度更新函數傳給父組件
    if (widget.onProgressControllerReady != null) {
      widget.onProgressControllerReady!(_updateApiProgress);
    }

    // 🔥 延遲2秒後直接進入API階段
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isApiPhase = true; // 進入 API 階段
        });
        print('🔥 延遲2秒完成，開始API階段');
      }
    });
  }

  /* 🔥 保留原本4個Process的混合模式邏輯（備註保存）
  // 新增：混合模式初始化
  void _initializeHybridMode() {
    // 固定使用 4 個 process
    final processNames = ['Process 01', 'Process 02', 'Process 03', 'Process 04'];

    // 初始化進程列表
    _processes = processNames.map((name) => ProcessInfo(name, 0.0)).toList();

    // 將進度更新函數傳給父組件
    if (widget.onProgressControllerReady != null) {
      widget.onProgressControllerReady!(_updateApiProgress);
    }

    // Process 01-03: 每個 process 3 秒完成
    const int msPerProcess = 3000; // 3 秒
    const int updateInterval = 100; // 100ms 更新一次
    const double incrementPerUpdate = 100.0 / (msPerProcess / updateInterval);

    // 設置定時器，控制前 3 個 process
    _timer = Timer.periodic(Duration(milliseconds: updateInterval), (timer) {
      if (_currentProcessIndex >= 3) { // 只跑前 3 個 process
        _timer?.cancel();
        _isApiPhase = true; // 進入 API 階段
        return;
      }

      setState(() {
        // 增加當前進程的進度
        _currentProgress += incrementPerUpdate;

        // 更新進程信息
        _processes[_currentProcessIndex] = ProcessInfo(
            processNames[_currentProcessIndex],
            _currentProgress > 100.0 ? 100.0 : _currentProgress
        );

        // 如果當前進程完成，移到下一個進程
        if (_currentProgress >= 100.0) {
          _currentProcessIndex++;
          _currentProgress = 0.0;
        }
      });
    });
  }
  */

  // 舊模式初始化（保留原有邏輯）
  void _initializeOldMode() {
    final processNames = widget.processNames ?? ['Process 01', 'Process 02', 'Process 03', 'Process 04', 'Process 05'];
    final totalDurationSeconds = widget.totalDurationSeconds ?? 10;

    // 初始化進程列表
    _processes = processNames.map((name) => ProcessInfo(name, 0.0)).toList();

    // 每個進程的目標完成時間（毫秒）
    final int msPerProcess = (totalDurationSeconds * 1000) ~/ processNames.length;

    // 每次更新的間隔（毫秒）
    const int updateInterval = 100;

    // 每次更新增加的百分比
    final double incrementPerUpdate = 100.0 / (msPerProcess / updateInterval);

    // 設置定時器，更新進度
    _timer = Timer.periodic(Duration(milliseconds: updateInterval), (timer) {
      if (_currentProcessIndex >= processNames.length) {
        _timer?.cancel();
        // 全部完成，延遲一小段時間後回調
        if (!_isCompleted) {
          _isCompleted = true;
          Future.delayed(const Duration(milliseconds: 500), () {
            if (widget.onCompleted != null) {
              widget.onCompleted!();
            }
          });
        }
        return;
      }

      setState(() {
        // 增加當前進程的進度
        _currentProgress += incrementPerUpdate;

        // 更新進程信息
        _processes[_currentProcessIndex] = ProcessInfo(
            processNames[_currentProcessIndex],
            _currentProgress > 100.0 ? 100.0 : _currentProgress
        );

        // 如果當前進程完成，移到下一個進程
        if (_currentProgress >= 100.0) {
          _currentProcessIndex++;
          _currentProgress = 0.0;
        }
      });
    });
  }

  // 🔥 修改：單一Process的API進度更新方法
  void _updateApiProgress(double progress, {String? status}) {
    if (mounted && _isApiPhase) {
      setState(() {
        _apiProgress = progress.clamp(0.0, 100.0);

        // 🔥 更新 Process 04 的進度（保持原本的樣子）
        _processes[0] = ProcessInfo('Process 04', _apiProgress);

        // 🔥 修正：當 API 進度達到100%時，先顯示對話框，再執行完成邏輯
        if (_apiProgress >= 100.0 && !_isCompleted) {
          _isCompleted = true;

          print('🎯 API 進度達到 100%，準備顯示重連對話框');

          // 🔥 重要修正：延遲一小段時間確保UI更新完成，然後直接顯示對話框
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              print('🎯 顯示重連對話框');
              _showReconnectDialogWithNavigation();
            }
          });
        }
      });
    }
  }

  // 🔥 修復：顯示重連對話框並處理導航
  void _showReconnectDialogWithNavigation() {
    String configuredSSID = WifiScannerComponent.configuredSSID ?? 'your configured network';

    print('🎯 準備顯示重連對話框，配置的 SSID: $configuredSSID');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: const Color(0xFF9747FF).withOpacity(0.5),
              width: 1,
            ),
          ),
          title: Row(
            children: [
              Icon(
                Icons.wifi,
                color: const Color(0xFF9747FF),
                size: 24,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Configuration Complete',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configuration has been completed successfully.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please reconnect to the WiFi network:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF9747FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF9747FF).withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  configuredSSID,
                  style: const TextStyle(
                    color: Color(0xFF9747FF),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                print('🎯 用戶點擊 OK，關閉對話框並執行完成邏輯');
                Navigator.of(context).pop(); // 關閉對話框

                // 🔥 修正：在用戶點擊 OK 後執行完成邏輯，並傳遞自動搜尋標記
                if (widget.onCompleted != null) {
                  print('🎯 執行 onCompleted 回調，標記需要自動搜尋');
                  widget.onCompleted!();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9747FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // 🔥 修改卡片高度：原本裝4條，現在裝1條
    // 原本: screenSize.height * 1.6
    // 修改: 根據Process數量調整高度
    double cardHeight;
    if (widget.height != null) {
      cardHeight = widget.height!;
    } else {
      if (_isNewMode) {
        // 🔥 單一Process模式：縮小卡片高度
        cardHeight = screenSize.height * 0.4; // 原本的1/4高度
      } else {
        // 舊模式：保持原有高度
        cardHeight = screenSize.height * 1.6;
      }
    }

    /* 🔥 保留原本的卡片高度計算邏輯（備註保存）
    // 使用傳入的高度參數或默認值（保持原有邏輯）
    double cardHeight = widget.height ?? (screenSize.height * 1.6);
    */

    // 使用 buildStandardCard 替代原始的 Container（保持原有樣式）
    return _appTheme.whiteBoxTheme.buildStandardCard(
      width: screenSize.width * 0.9,
      height: cardHeight,
      child: Padding(
        padding: const EdgeInsets.all(25.0),
        child: _isNewMode ? _buildNewModeContent() : _buildOldModeContent(),
      ),
    );
  }

  // 🔥 修改：新模式內容（單一Process模式）
  Widget _buildNewModeContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔥 只顯示 1 個 process（完全像原本的 Process 04）
          ..._processes.map((process) => _buildProcessItem(process)),
        ],
      ),
    );
  }

  /* 🔥 保留原本的新模式內容（備註保存）
  // 新模式內容（混合模式：Process 01-03 固定速率，Process 04 API 控制）
  Widget _buildNewModeContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顯示所有 4 個 process
          ..._processes.map((process) => _buildProcessItem(process)),
        ],
      ),
    );
  }
  */

  // 舊模式內容（保留原有邏輯）
  Widget _buildOldModeContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 進程列表
          ..._processes.map((process) => _buildProcessItem(process)),
        ],
      ),
    );
  }

  // 計算總體進度（舊模式使用）
  double _calculateTotalProgress() {
    if (_processes.isEmpty) return 0.0;

    double totalPercentage = 0.0;
    for (var process in _processes) {
      totalPercentage += process.percentage;
    }

    return totalPercentage / (_processes.length * 100.0);
  }

  // 構建單個進程項目
  Widget _buildProcessItem(ProcessInfo process) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              process.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            Text(
              '${process.percentage.toInt()}%',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        // 進度條
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: _buildDashedProgressBar(process.percentage / 100.0),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  // 建立虛線進度條
  Widget _buildDashedProgressBar(double progress) {
    return CustomPaint(
      painter: DashedProgressBarPainter(
        progress: progress,
        backgroundColor: Colors.grey[700]!,
        progressColor: AppColors.textLight,
      ),
      child: Container(
        width: double.infinity,
        height: 2.0,
      ),
    );
  }
}

// 虛線進度條繪製器保持不變
class DashedProgressBarPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;
  final double dashWidth = 10.0;
  final double dashSpacing = 3.0;

  DashedProgressBarPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 繪製背景
    final Paint backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(2.0),
      ),
      backgroundPaint,
    );

    // 計算進度條寬度
    final double progressWidth = size.width * progress;

    // 繪製進度虛線
    if (progress > 0) {
      final Paint progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.fill;

      double startX = 0;
      while (startX < progressWidth) {
        double currentDashWidth = dashWidth;
        if (startX + dashWidth > progressWidth) {
          currentDashWidth = progressWidth - startX;
        }

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(startX, 0, currentDashWidth, size.height),
            const Radius.circular(1.0),
          ),
          progressPaint,
        );

        startX += dashWidth + dashSpacing;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedProgressBarPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}