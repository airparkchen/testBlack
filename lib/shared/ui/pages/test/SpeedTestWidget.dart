import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;

class CommercialSpeedTestWidget extends StatefulWidget {
  final Function(String)? onLogUpdate; // 日誌回調
  final bool showInternalButtons; // 是否顯示內部按鈕

  const CommercialSpeedTestWidget({
    Key? key,
    this.onLogUpdate,
    this.showInternalButtons = true,
  }) : super(key: key);

  @override
  State<CommercialSpeedTestWidget> createState() => CommercialSpeedTestWidgetState();
}

class CommercialSpeedTestWidgetState extends State<CommercialSpeedTestWidget>
    with TickerProviderStateMixin {
  bool _isTestRunning = false;
  String _currentPhase = 'idle';
  double _progress = 0.0;

  // 測試結果
  int _pingMs = 0;
  double _downloadSpeed = 0.0;
  double _uploadSpeed = 0.0;
  double _jitter = 0.0;
  String _serverName = 'Cloudflare';
  String _serverLocation = 'Auto';

  // 動畫控制器
  late AnimationController _progressAnimationController;
  late AnimationController _speedMeterAnimationController;
  late Animation<double> _progressAnimation;
  late Animation<double> _speedMeterAnimation;

  // 測試配置
  static const List<String> _cloudflareTestUrls = [
    'https://speed.cloudflare.com/__down?bytes=1000000',  // 1MB
    'https://speed.cloudflare.com/__down?bytes=5000000',  // 5MB
    'https://speed.cloudflare.com/__down?bytes=10000000', // 10MB
    'https://speed.cloudflare.com/__down?bytes=25000000', // 25MB
  ];

  static const List<String> _alternativeTestUrls = [
    'https://httpbin.org/bytes/1048576',    // 1MB
    'https://httpbin.org/bytes/5242880',    // 5MB
    'https://httpbin.org/drip?bytes=10485760&duration=1', // 10MB with 1s duration
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _speedMeterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeInOut,
    ));

    _speedMeterAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _speedMeterAnimationController,
      curve: Curves.easeOutBack,
    ));
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    _speedMeterAnimationController.dispose();
    super.dispose();
  }

  // 添加日誌的輔助方法
  void _addLog(String message) {
    if (widget.onLogUpdate != null) {
      widget.onLogUpdate!(message);
    }
    print(message); // 保留原有的 print
  }

  // 公開方法供外部調用
  Future<void> startSpeedTest() async {
    await _startSpeedTest();
  }

  void restartTest() {
    _restartTest();
  }

  // 主要測試函數 - 真正的HTTP測試
  Future<void> _startSpeedTest() async {
    if (_isTestRunning) return;

    setState(() {
      _isTestRunning = true;
      _currentPhase = 'ping';
      _progress = 0.0;
      _pingMs = 0;
      _downloadSpeed = 0.0;
      _uploadSpeed = 0.0;
      _jitter = 0.0;
    });

    try {
      _addLog('🚀 Starting Commercial Speed Test');

      // 1. Ping測試
      await _performPingTest();

      // 2. 下載測試
      await _performDownloadTest();

      // 3. 上傳測試
      await _performUploadTest();

      // 完成
      setState(() {
        _isTestRunning = false;
        _currentPhase = 'complete';
        _progress = 100.0;
      });

      _progressAnimationController.animateTo(1.0);
      _showMessage('測試完成！');

      _addLog('✅ Speed Test Results:');
      _addLog('   Ping: ${_pingMs}ms');
      _addLog('   Download: ${_downloadSpeed.toStringAsFixed(2)} Mbps');
      _addLog('   Upload: ${_uploadSpeed.toStringAsFixed(2)} Mbps');
      _addLog('   Jitter: ${_jitter.toStringAsFixed(2)}ms');

    } catch (e) {
      _addLog('❌ Speed test error: $e');
      setState(() {
        _isTestRunning = false;
        _currentPhase = 'error';
      });
      _showMessage('測試失敗: $e');
    }
  }

  // Ping測試 - 使用多個伺服器測量延遲
  Future<void> _performPingTest() async {
    setState(() {
      _currentPhase = 'ping';
      _progress = 0.0;
    });

    final List<String> pingTargets = [
      'https://1.1.1.1/',           // Cloudflare DNS
      'https://8.8.8.8/',           // Google DNS
      'https://httpbin.org/get',    // HTTPBin
      'https://api.github.com/',    // GitHub API
    ];

    List<int> pingResults = [];

    for (int i = 0; i < pingTargets.length; i++) {
      if (!_isTestRunning) return;

      try {
        final stopwatch = Stopwatch()..start();

        final response = await http.head(
          Uri.parse(pingTargets[i]),
          headers: {'Cache-Control': 'no-cache'},
        ).timeout(const Duration(seconds: 5));

        stopwatch.stop();

        if (response.statusCode < 400) {
          final pingTime = stopwatch.elapsedMilliseconds;
          pingResults.add(pingTime);
          _addLog('🏓 Ping to ${pingTargets[i]}: ${pingTime}ms');
        }

      } catch (e) {
        _addLog('⚠️ Ping failed for ${pingTargets[i]}: $e');
      }

      // 更新進度
      setState(() {
        _progress = ((i + 1) / pingTargets.length) * 100;
        _progressAnimationController.animateTo(_progress / 100);
      });

      await Future.delayed(const Duration(milliseconds: 200));
    }

    // 計算平均ping和抖動
    if (pingResults.isNotEmpty) {
      final avgPing = pingResults.reduce((a, b) => a + b) / pingResults.length;
      final variance = pingResults.map((ping) => math.pow(ping - avgPing, 2)).reduce((a, b) => a + b) / pingResults.length;
      final jitter = math.sqrt(variance);

      setState(() {
        _pingMs = avgPing.round();
        _jitter = jitter;
      });
    }

    await Future.delayed(const Duration(milliseconds: 500));
  }

  // 下載測試 - 測量真實的下載速度
  Future<void> _performDownloadTest() async {
    setState(() {
      _currentPhase = 'download';
      _progress = 0.0;
    });

    List<double> downloadSpeeds = [];

    for (int i = 0; i < _cloudflareTestUrls.length; i++) {
      if (!_isTestRunning) return;

      try {
        _addLog('📥 Download test ${i + 1}/${_cloudflareTestUrls.length}');

        final stopwatch = Stopwatch()..start();
        final response = await http.get(
          Uri.parse(_cloudflareTestUrls[i]),
          headers: {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
            'Expires': '0',
          },
        ).timeout(const Duration(seconds: 30));

        stopwatch.stop();

        if (response.statusCode == 200) {
          final bytes = response.bodyBytes.length;
          final timeInSeconds = stopwatch.elapsedMilliseconds / 1000.0;
          final speedMbps = (bytes * 8) / (timeInSeconds * 1000000); // Convert to Mbps

          downloadSpeeds.add(speedMbps);

          setState(() {
            _downloadSpeed = speedMbps;
            _updateSpeedMeter();
          });

          _addLog('📊 Download speed: ${speedMbps.toStringAsFixed(2)} Mbps (${bytes} bytes in ${timeInSeconds.toStringAsFixed(2)}s)');
        }

      } catch (e) {
        _addLog('⚠️ Download test ${i + 1} failed: $e');

        // 嘗試備用URL
        if (i < _alternativeTestUrls.length) {
          try {
            _addLog('🔄 Trying alternative URL...');
            final stopwatch = Stopwatch()..start();
            final response = await http.get(Uri.parse(_alternativeTestUrls[i])).timeout(const Duration(seconds: 30));
            stopwatch.stop();

            if (response.statusCode == 200) {
              final bytes = response.bodyBytes.length;
              final timeInSeconds = stopwatch.elapsedMilliseconds / 1000.0;
              final speedMbps = (bytes * 8) / (timeInSeconds * 1000000);

              downloadSpeeds.add(speedMbps);
              setState(() {
                _downloadSpeed = speedMbps;
                _updateSpeedMeter();
              });
            }
          } catch (altError) {
            _addLog('⚠️ Alternative download test also failed: $altError');
          }
        }
      }

      // 更新進度
      setState(() {
        _progress = ((i + 1) / _cloudflareTestUrls.length) * 100;
        _progressAnimationController.animateTo(_progress / 100);
      });

      await Future.delayed(const Duration(milliseconds: 300));
    }

    // 使用最高速度作為最終結果
    if (downloadSpeeds.isNotEmpty) {
      final maxSpeed = downloadSpeeds.reduce(math.max);
      setState(() {
        _downloadSpeed = maxSpeed;
        _updateSpeedMeter();
      });
    }

    await Future.delayed(const Duration(milliseconds: 500));
  }

  // 上傳測試 - 測量真實的上傳速度
  Future<void> _performUploadTest() async {
    setState(() {
      _currentPhase = 'upload';
      _progress = 0.0;
    });

    final uploadSizes = [
      100 * 1024,    // 100KB
      500 * 1024,    // 500KB
      1024 * 1024,   // 1MB
      2 * 1024 * 1024, // 2MB
    ];

    List<double> uploadSpeeds = [];

    for (int i = 0; i < uploadSizes.length; i++) {
      if (!_isTestRunning) return;

      try {
        _addLog('📤 Upload test ${i + 1}/${uploadSizes.length}');

        // 生成測試數據
        final testData = Uint8List(uploadSizes[i]);
        for (int j = 0; j < testData.length; j++) {
          testData[j] = j % 256;
        }

        final stopwatch = Stopwatch()..start();

        final response = await http.post(
          Uri.parse('https://httpbin.org/post'),
          headers: {
            'Content-Type': 'application/octet-stream',
            'Cache-Control': 'no-cache',
          },
          body: testData,
        ).timeout(const Duration(seconds: 30));

        stopwatch.stop();

        if (response.statusCode < 400) {
          final bytes = testData.length;
          final timeInSeconds = stopwatch.elapsedMilliseconds / 1000.0;
          final speedMbps = (bytes * 8) / (timeInSeconds * 1000000); // Convert to Mbps

          uploadSpeeds.add(speedMbps);

          setState(() {
            _uploadSpeed = speedMbps;
            _updateSpeedMeter();
          });

          _addLog('📊 Upload speed: ${speedMbps.toStringAsFixed(2)} Mbps (${bytes} bytes in ${timeInSeconds.toStringAsFixed(2)}s)');
        }

      } catch (e) {
        _addLog('⚠️ Upload test ${i + 1} failed: $e');
      }

      // 更新進度
      setState(() {
        _progress = ((i + 1) / uploadSizes.length) * 100;
        _progressAnimationController.animateTo(_progress / 100);
      });

      await Future.delayed(const Duration(milliseconds: 300));
    }

    // 使用最高速度作為最終結果
    if (uploadSpeeds.isNotEmpty) {
      final maxSpeed = uploadSpeeds.reduce(math.max);
      setState(() {
        _uploadSpeed = maxSpeed;
        _updateSpeedMeter();
      });
    }

    await Future.delayed(const Duration(milliseconds: 500));
  }

  // 取消測試
  void _cancelTest() {
    if (_isTestRunning) {
      setState(() {
        _isTestRunning = false;
        _currentPhase = 'cancelled';
        _progress = 0.0;
      });
      _progressAnimationController.reset();
      _addLog('🛑 測試已取消');
      _showMessage('測試已取消');
    }
  }

  // 重新測試
  void _restartTest() {
    setState(() {
      _isTestRunning = false;
      _currentPhase = 'idle';
      _progress = 0.0;
      _pingMs = 0;
      _downloadSpeed = 0.0;
      _uploadSpeed = 0.0;
      _jitter = 0.0;
    });

    // 重置動畫
    _progressAnimationController.reset();
    _speedMeterAnimationController.reset();

    _addLog('🔄 重新開始測試...');

    // 開始新的測試
    Future.delayed(const Duration(milliseconds: 300), () {
      _startSpeedTest();
    });
  }

  // 更新速度計動畫
  void _updateSpeedMeter() {
    double maxSpeed = _downloadSpeed > _uploadSpeed ? _downloadSpeed : _uploadSpeed;
    double normalizedSpeed = (maxSpeed / 100).clamp(0.0, 1.0);
    _speedMeterAnimationController.animateTo(normalizedSpeed);
  }

  // 顯示消息
  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 獲取測試結果JSON（用於API調用）
  Map<String, dynamic> getTestResults() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'ping_ms': _pingMs,
      'download_mbps': double.parse(_downloadSpeed.toStringAsFixed(2)),
      'upload_mbps': double.parse(_uploadSpeed.toStringAsFixed(2)),
      'jitter_ms': double.parse(_jitter.toStringAsFixed(2)),
      'server': _serverName,
      'location': _serverLocation,
      'test_status': _currentPhase,
    };
  }

  // 程式化調用接口（用於自動化測試）
  Future<Map<String, dynamic>> performAutomatedTest() async {
    await _startSpeedTest();

    // 等待測試完成
    while (_isTestRunning) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    return getTestResults();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 404,
      height: 200,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [
            Color(0x66162140), // rgba(22, 33, 64, 0.4)
            Color(0x669747FF), // rgba(151, 71, 255, 0.4)
          ],
        ),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xB39747FF), // rgba(151, 71, 255, 0.7)
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            offset: const Offset(2, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            // 主要UI內容
            _buildMainContent(),

            // 底部進度條
            _buildBottomProgressBar(),

            // 只在允許顯示內部按鈕時才顯示覆蓋層
            if (widget.showInternalButtons) ...[
              // 測試按鈕覆蓋層
              if (!_isTestRunning && _currentPhase == 'idle')
                _buildStartButton(),

              // 測試中覆蓋層
              if (_isTestRunning)
                _buildTestingOverlay(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // 上排 (60%)
        Expanded(
          flex: 60,
          child: Row(
            children: [
              // Ping 區域
              Expanded(
                child: _buildMetricSection(
                  icon: _buildPingIcon(),
                  label: 'Ping',
                  value: _pingMs.toString(),
                  unit: 'ms',
                  color: const Color(0xFFFFE448),
                  isActive: _currentPhase == 'ping',
                ),
              ),

              // 第一條分割線
              _buildVerticalDivider(),

              // Download 區域
              Expanded(
                child: _buildMetricSection(
                  icon: _buildDownloadIcon(),
                  label: 'Down',
                  value: _downloadSpeed.toStringAsFixed(0),
                  unit: 'Mbps',
                  color: const Color(0xFF00EEFF),
                  isActive: _currentPhase == 'download',
                ),
              ),

              // 第二條分割線
              _buildVerticalDivider(),

              // Upload 區域
              Expanded(
                child: _buildMetricSection(
                  icon: _buildUploadIcon(),
                  label: 'Up',
                  value: _uploadSpeed.toStringAsFixed(0),
                  unit: 'Mbps',
                  color: const Color(0xFFFF6D2F),
                  isActive: _currentPhase == 'upload',
                ),
              ),
            ],
          ),
        ),

        // 水平分隔線
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                const Color(0x809747FF),
                Colors.transparent,
              ],
            ),
          ),
        ),

        // 下排 (40%)
        Expanded(
          flex: 40,
          child: Row(
            children: [
              // 左邊 66% - 伺服器名稱
              Expanded(
                flex: 66,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: const Icon(
                          Icons.cloud,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _serverName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _serverLocation,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 右邊 34% - 速度表
              Expanded(
                flex: 34,
                child: Center(
                  child: _buildSpeedMeter(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricSection({
    required Widget icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
    required bool isActive,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 文字靠左上
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // 速度靠右下
          Align(
            alignment: Alignment.bottomRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  unit,
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: double.infinity,
      child: Column(
        children: [
          const Expanded(flex: 5, child: SizedBox()),
          Expanded(
            flex: 50,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xCC708090),
                    Color(0xCC9747FF),
                  ],
                ),
              ),
            ),
          ),
          const Expanded(flex: 45, child: SizedBox()),
        ],
      ),
    );
  }

  Widget _buildPingIcon() {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFE448), width: 1),
      ),
      child: Center(
        child: Container(
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFFE448),
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadIcon() {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF00EEFF), width: 1),
      ),
      child: const Icon(
        Icons.arrow_downward,
        size: 8,
        color: Color(0xFF00EEFF),
      ),
    );
  }

  Widget _buildUploadIcon() {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFF6D2F), width: 1),
      ),
      child: const Icon(
        Icons.arrow_upward,
        size: 8,
        color: Color(0xFFFF6D2F),
      ),
    );
  }

  Widget _buildSpeedMeter() {
    return AnimatedBuilder(
      animation: _speedMeterAnimation,
      builder: (context, child) {
        return Container(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                ),
              ),
              CustomPaint(
                size: const Size(36, 36),
                painter: SpeedMeterPainter(
                  progress: _speedMeterAnimation.value,
                ),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isTestRunning ? Colors.white : Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomProgressBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _progressAnimation,
        builder: (context, child) {
          return Container(
            height: 4,
            child: Stack(
              children: [
                if (_currentPhase == 'download')
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: _progressAnimation.value,
                      child: Container(
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00EEFF),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),

                if (_currentPhase == 'upload')
                  Align(
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: _progressAnimation.value,
                      child: Container(
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF6D2F),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStartButton() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: ElevatedButton(
            onPressed: _startSpeedTest,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9747FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.speed, size: 16),
                const SizedBox(width: 8),
                const Text(
                  '開始測試',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTestingOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getTestingText(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _cancelTest,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withOpacity(0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
                child: const Text(
                  '取消',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTestingText() {
    switch (_currentPhase) {
      case 'ping':
        return '測試網路延遲...';
      case 'download':
        return '測試下載速度...';
      case 'upload':
        return '測試上傳速度...';
      default:
        return '正在測試...';
    }
  }
}

// 自定義速度表繪製器
class SpeedMeterPainter extends CustomPainter {
  final double progress;

  SpeedMeterPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final backgroundPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF162140), Color(0xFF9747FF)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // 繪製背景弧（半圓）
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -2.356, // -135度
      1.571,  // 90度（半圓）
      false,
      backgroundPaint,
    );

    // 繪製進度弧
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -2.356, // -135度
        1.571 * progress, // 根據進度繪製
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}