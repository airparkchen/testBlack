// lib/shared/ui/components/basic/topology_display_widget.dart - 完整修正版本
// 🎯 雙線速度圖表實現 + 插值動畫 + 重疊處理

import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';
import 'package:whitebox/shared/ui/components/basic/NetworkTopologyComponent.dart';
import 'package:whitebox/shared/theme/app_theme.dart';
import 'package:whitebox/shared/ui/pages/home/Topo/network_topo_config.dart';
import 'package:whitebox/shared/ui/pages/home/Topo/fake_data_generator.dart';
import 'package:whitebox/shared/ui/pages/home/Topo/fake_data_generator.dart' as RealSpeedService;
import 'package:whitebox/shared/services/real_data_integration_service.dart';
import 'package:whitebox/shared/services/dashboard_data_service.dart';
import 'package:whitebox/shared/services/unified_mesh_data_manager.dart';

/// 智能單位格式化工具
/// 根據速度數值自動選擇合適的單位顯示
class SpeedUnitFormatter {
  /// 將 Mbps 數值格式化為適當單位的字串
  static String formatSpeed(double speedMbps) {
    if (speedMbps >= 100) {
      // >= 100 Mbps 顯示為 Gbps
      final gbps = speedMbps / 1000.0;
      return '${gbps.toStringAsFixed(2)} Gbps';
    } else if (speedMbps >= 0.1) {
      // >= 0.1 Mbps 顯示為 Mbps
      return '${speedMbps.toStringAsFixed(2)} Mbps';
    } else {
      // < 0.1 Mbps 顯示為 Kbps
      final kbps = speedMbps * 1000.0;
      return '${kbps.toStringAsFixed(1)} Kbps';
    }
  }

  /// 針對整數速度的格式化（向後兼容現有程式碼）
  static String formatSpeedInt(int speedMbps) {
    return formatSpeed(speedMbps.toDouble());
  }

  /// 將 Mbps 數值格式化為 TextSpan，以便分別設定數字和單位的樣式
  static TextSpan formatSpeedToTextSpan(
      double speedMbps, {
        required TextStyle numberStyle, // 用於數字部分的樣式
        required TextStyle unitStyle,   // 用於單位部分的樣式
      }) {
    String numberPart;
    String unitPart;

    if (speedMbps >= 100) {
      // >= 100 Mbps 顯示為 Gbps
      final gbps = speedMbps / 1000.0;
      numberPart = gbps.toStringAsFixed(2);
      unitPart = ' Gbps'; // 注意前面有一個空格
    } else if (speedMbps >= 0.1) {
      // >= 0.1 Mbps 顯示為 Mbps
      numberPart = speedMbps.toStringAsFixed(2);
      unitPart = ' Mbps'; // 注意前面有一個空格
    } else {
      // < 0.1 Mbps 顯示為 Kbps
      final kbps = speedMbps * 1000.0;
      numberPart = kbps.toStringAsFixed(1);
      unitPart = ' Kbps'; // 注意前面有一個空格
    }

    return TextSpan(
      children: [
        TextSpan(text: numberPart, style: numberStyle), // 數字套用傳入的數字樣式
        TextSpan(text: unitPart, style: unitStyle),     // 單位套用傳入的單位樣式
      ],
    );
  }
}

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

  // 🎯 新增：API 更新計時器（10秒一次）
  Timer? _apiUpdateTimer;

  // 🔥 新增：Internet 狀態更新計時器
  Timer? _internetStatusUpdateTimer;

  Timer? _clientCountUpdateTimer;
  List<DeviceConnection> _latestConnections = [];
  NetworkDevice? _latestGatewayDevice;

  InternetConnectionStatus? _internetStatus;

  @override
  void initState() {
    super.initState();

    // 🎯 原有的速度數據初始化邏輯
    if (NetworkTopoConfig.useRealData) {
      _realSpeedDataGenerator = RealSpeedService.RealSpeedDataGenerator(
        dataPointCount: 20,  //資料點
        minSpeed: 0,
        maxSpeed: 1000,
        updateInterval: Duration(seconds: 10),
      );
      _fakeSpeedDataGenerator = null;
      print('🌐 初始化真實速度數據生成器');

      // 🎯 新增：啟動 API 更新計時器
      _startAPIUpdates();

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
    _loadInternetStatus();
    // if (NetworkTopoConfig.useRealData) {
    //   // _startClientCountUpdates();
    //   _startInternetStatusUpdates();
    // }
  }

  @override
  void dispose() {
    // 🎯 新增：清理 API 更新計時器
    // _clientCountUpdateTimer?.cancel();
    // _internetStatusUpdateTimer?.cancel();
    super.dispose();
  }

  void updateClientCounts(List<DeviceConnection> connections, NetworkDevice? gatewayDevice) {
    if (!mounted) return;

    setState(() {
      _latestConnections = connections;
      _latestGatewayDevice = gatewayDevice;
    });

    print('✅ 拓樸圖客戶端數量已更新：${connections.length} 個連接');
  }

  /// 🎯 新增：統一更新所有數據的方法
  void updateAllData({
    List<DeviceConnection>? connections,
    NetworkDevice? gatewayDevice,
    bool updateSpeed = false,
  }) {
    if (!mounted) return;

    setState(() {
      if (connections != null) {
        _latestConnections = connections;
      }
      if (gatewayDevice != null) {
        _latestGatewayDevice = gatewayDevice;
      }
    });

    // 如果需要更新速度數據
    if (updateSpeed) {
      updateSpeedData();
    }

    print('✅ 拓樸圖所有數據已更新');
  }

  /// 🔥 新增：啟動 Internet 狀態定期更新
  void _startInternetStatusUpdates() {
    _internetStatusUpdateTimer?.cancel();

    // 🔥 每 15 秒更新 Internet 狀態（錯開其他 API 調用）
    print('🌐 啟動 Internet 狀態定期更新，間隔: 15 秒');

    _internetStatusUpdateTimer = Timer.periodic(Duration(seconds: 15), (_) {
      if (mounted) {
        print('🌐 定期更新 Internet 狀態...');
        _loadInternetStatus();
      }
    });
  }

  /// 🟢 新增：啟動客戶端數量更新
  void _startClientCountUpdates() {
    _clientCountUpdateTimer?.cancel();

    // 使用與Mesh API相同的間隔（12秒）
    _clientCountUpdateTimer = Timer.periodic(NetworkTopoConfig.meshApiCallInterval, (_) {
      if (mounted && NetworkTopoConfig.useRealData) {
        _updateClientCountsOnly();
      }
    });

    print('🔄 啟動客戶端數量更新，間隔: ${NetworkTopoConfig.meshApiCacheSeconds}秒');
  }

  /// 🟢 新增：只更新客戶端數量，不重建拓樸結構
  Future<void> _updateClientCountsOnly() async {
    try {
      print('🔄 更新客戶端數量中...');

      // 🎯 使用統一管理器
      final manager = UnifiedMeshDataManager.instance;

      final results = await Future.wait([
        manager.getDeviceConnections(),
        manager.getGatewayDevice(),
      ]);

      final newConnections = results[0] as List<DeviceConnection>;
      final newGatewayDevice = results[1] as NetworkDevice?;

      if (mounted) {
        // 🔥 關鍵修改：使用單一 setState，避免競爭條件
        setState(() {
          // 確保數據一致性：只有當兩個數據都成功獲取時才更新
          if (newConnections.isNotEmpty || newGatewayDevice != null) {
            _latestConnections = newConnections;
            _latestGatewayDevice = newGatewayDevice;
          }
        });

        print('✅ 客戶端數量已更新: ${newConnections.length} 個連接（統一管理器）');
      }
    } catch (e) {
      print('❌ 更新客戶端數量失敗: $e');
      // 🔥 新增：錯誤時不清空現有數據，保持顯示穩定性
    }
  }

  /// 🎯 新增：啟動 API 更新計時器（10秒一次）
  void _startAPIUpdates() {
    _apiUpdateTimer?.cancel();

    print('🔄 啟動 API 更新計時器，間隔: 10 秒');

    _apiUpdateTimer = Timer.periodic(NetworkTopoConfig.throughputApiCallInterval, (_) {
      if (mounted && NetworkTopoConfig.useRealData && _realSpeedDataGenerator != null) {
        print('⏰ API 更新計時器觸發');
        _realSpeedDataGenerator!.updateFromAPI();
      }
    });
  }

  /// 🎯 新增：載入真實 Gateway 設備資料
  Future<void> _loadGatewayDevice() async {
    if (!mounted) return;

    setState(() {
      _isLoadingGateway = true;
    });

    try {
      // 🎯 使用統一管理器
      final manager = UnifiedMeshDataManager.instance;
      final gateway = await manager.getGatewayDevice();

      if (mounted && gateway != null) {
        setState(() {
          _gatewayDevice = gateway;
          _isLoadingGateway = false;
        });
        print('✅ 載入統一管理器 Gateway 設備: ${gateway.name} (${gateway.mac})');
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

  /// 🎯 新增：載入 Internet 連線狀態
  Future<void> _loadInternetStatus() async {
    if (!mounted) return;

    try {
      // 🔥 關鍵：使用相同的快取，而不是獨立調用
      final dashboardData = await DashboardDataService.getDashboardData();

      final internetStatus = InternetConnectionStatus(
        isConnected: dashboardData.internetStatus.pingStatus.toLowerCase() == 'connected',
        status: dashboardData.internetStatus.pingStatus,
        timestamp: DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _internetStatus = internetStatus;
        });

        print('✅ 拓樸圖 Internet 狀態: ${internetStatus.status} -> ${internetStatus.isConnected ? "已連接" : "未連接"}');
      }
    } catch (e) {
      print('❌ 載入 Internet 狀態失敗: $e');
      if (mounted) {
        setState(() {
          _internetStatus = InternetConnectionStatus.unknown();
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
                // 🟢 修改：優先使用最新的Gateway設備數據
                gatewayDevice: _latestGatewayDevice ?? _gatewayDevice,
                gatewayName: widget.gatewayName,
                devices: widget.devices,
                // 🟢 修改：優先使用最新的連接數據
                deviceConnections: (_latestConnections.isNotEmpty ? _latestConnections : widget.deviceConnections) ?? [],
                totalConnectedDevices: _calculateTotalConnectedDevices(),
                height: screenSize.height * NetworkTopoConfig.topologyHeightRatio,
                onDeviceSelected: widget.enableInteractions ? widget.onDeviceSelected : null,
                internetStatus: _internetStatus,
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
            (conn) => conn.deviceId.contains('8c0f6f610a77') ||
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

  //速度區域
  Widget _buildSpeedArea(Size screenSize) {
    final screenWidth = screenSize.width;

    return Container(
      margin: const EdgeInsets.only(left: 3, right: 3),
      child: _appTheme.whiteBoxTheme.buildStandardCard(
        width: screenWidth - 36,
        height: 150,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final chartWidth = constraints.maxWidth * 1;
            final labelWidth = constraints.maxWidth * 0.3;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // 🎯 羽化分界線：移到最底層
                _buildDividerLine(constraints, chartWidth),

                // 🎯 左側 70% 區域：速度圖（包含圓點）- 放在羽化線之上
                Positioned(
                  left: 0,
                  width: chartWidth,
                  top: 0,
                  bottom: 0,
                  child: NetworkTopoConfig.useRealData
                      ? _buildRealSpeedChart()
                      : _buildFakeSpeedChart(),
                ),

                // 🎯 右側 30% 區域：速度標籤
                Positioned(
                  right: 0,
                  width: labelWidth,
                  bottom: 0, // 保持在底部
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      // 讓 Column 的內容垂直方向靠下對齊
                      mainAxisAlignment: MainAxisAlignment.end,
                      // 讓整個 Column 的內容水平置中
                      crossAxisAlignment: CrossAxisAlignment.center, // <-- 這裡改為置中
                      children: [
                        // Download 標籤
                        Column(
                          // 讓 Download 區塊的內容水平置中
                          crossAxisAlignment: CrossAxisAlignment.center, // <-- 這裡改為置中
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start, // 保持靠左對齊，只影響圖標和文字行
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(top: 2.0), // 🎯 向下調整 2 像素
                                  child: Image.asset(
                                    'assets/images/icon/download@2x.png',
                                    width: 12,
                                    height: 12,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Text(
                                  'Download',
                                  style: TextStyle(color: Color(0xFF00EEFF).withOpacity(1), fontSize: 14),
                                ),
                              ],
                            ),
                            SizedBox(height: 1),
                            // 使用 Text.rich 來分別設定數字和單位的樣式
                            Text.rich(
                              SpeedUnitFormatter.formatSpeedToTextSpan(
                                NetworkTopoConfig.useRealData
                                    ? _realSpeedDataGenerator?.currentDownload ?? 0
                                    : _fakeSpeedDataGenerator?.currentSpeed ?? 0,
                                numberStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold, // 數字粗體
                                ),
                                unitStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal, // 單位正常字重
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white38, height: 24, thickness: 0.6),
                        // Upload 標籤
                        Column(
                          // 讓 Upload 區塊的內容水平置中
                          crossAxisAlignment: CrossAxisAlignment.center, // <-- 這裡改為置中
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start, // 保持靠左對齊，只影響圖標和文字行
                              children: [
                                // 🎯 修改：使用自定義上傳圖片
                                Padding(
                                  padding: EdgeInsets.only(top: 2.0), // 🎯 向下調整 2 像素
                                  child: Image.asset(
                                    'assets/images/icon/upload@2x.png',
                                    width: 12,
                                    height: 12,
                                    color: Colors.orange, // 🎯 可選：為圖片添加顏色濾鏡
                                  ),
                                ),
                                SizedBox(width: 2),
                                Text(
                                  'Upload',
                                  style: TextStyle(color: Colors.orange, fontSize: 14),
                                ),
                              ],
                            ),
                            SizedBox(height: 1),
                            // 使用 Text.rich 來分別設定數字和單位的樣式
                            Text.rich(
                              SpeedUnitFormatter.formatSpeedToTextSpan(
                                NetworkTopoConfig.useRealData
                                    ? _realSpeedDataGenerator?.currentUpload ?? 0
                                    : 0,
                                numberStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold, // 數字粗體
                                ),
                                unitStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal, // 單位正常字重
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
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

  /// 🎯 修改：更新速度數據（現在是插值動畫，500ms一次）
  void updateSpeedData() {
    if (!mounted) return;

    if (NetworkTopoConfig.useRealData) {
      // 🎯 修改：現在調用插值更新，不是 API 更新
      // _loadInternetStatus();
      _realSpeedDataGenerator?.update().then((_) {
        if (mounted) {
          setState(() {
            // 觸發 UI 重繪
          });
        }
      });
    } else {
      if (_fakeSpeedDataGenerator != null) {
        setState(() {
          _fakeSpeedDataGenerator!.update();
        });
      }
    }
  }
}

// 🎯 新增：建構白色羽化分界線的方法
Widget _buildDividerLine(BoxConstraints constraints, double chartWidth) {
  // 計算分界線的 X 位置（70% 的位置）
  final double dividerX = constraints.maxWidth * 0.7;

  return Positioned(
    left: dividerX - 1, // 線條寬度的一半，讓線條居中
    top: 0,
    bottom: 0,
    child: Container(
      width: 1.5,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            // 🎯 頂部：透明
            Colors.white.withOpacity(0.0),
            // 🎯 中間：白色（最亮的部分）
            Colors.white.withOpacity(0.4),
            Colors.white.withOpacity(1.0),
            Colors.white.withOpacity(0.4),
            // 🎯 底部：漸變至透明
            Colors.white.withOpacity(0.0),
          ],
          stops: [0.0, 0.3, 0.5, 0.7, 1.0], // 控制漸變的分佈
        ),
        // 🎯 可選：添加羽化效果的模糊
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.2),
            blurRadius: 2,
            spreadRadius: 0,
          ),
        ],
      ),
    ),
  );
}

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
                top: dotY ,
                bottom: 0,
                left: chartEndX - 5,
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
                left: chartEndX - 6,
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
              // Positioned(
              //   top: dotY - 50,
              //   left: chartEndX - 44,
              //   child: _buildSpeedLabel(speedValue),
              // ),
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
                  SpeedUnitFormatter.formatSpeed(speed.toDouble()),
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

/// 🎯 雙線速度標籤小部件
class DualSpeedLabelWidget extends StatelessWidget {
  final double uploadSpeed;
  final double downloadSpeed;
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
                  // 上傳速度行
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
                        '↑ ${SpeedUnitFormatter.formatSpeed(uploadSpeed)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  // 下載速度行
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
                        '↓ ${SpeedUnitFormatter.formatSpeed(downloadSpeed)}',
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
class DualSpeedCurvePainter extends CustomPainter {
  final List<double> uploadData;
  final List<double> downloadData;
  final double minSpeed;
  final double maxSpeed;
  final double animationValue;
  final double endAtPercent;
  final double currentUpload;
  final double currentDownload;

  DualSpeedCurvePainter({
    required this.uploadData,
    required this.downloadData,
    required this.minSpeed,
    required this.maxSpeed,
    required this.animationValue,
    this.endAtPercent = 0.7,
    required this.currentUpload,
    required this.currentDownload,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (uploadData.isEmpty || downloadData.isEmpty) return;
    if (size.width <= 0 || size.height <= 0) return;

    final double range = maxSpeed - minSpeed;
    if (range <= 0) return;

    final double endX = size.width * endAtPercent;

    // 🎯 繪製上傳速度曲線（橘色）- 先繪製背景層
    _drawSpeedCurve(
      canvas,
      size,
      uploadData,
      range,
      endX,
      currentUpload,
      Color(0xFFFF6D2F), // 🎯 修正：確保是橘色 #FF6D2F
      'upload',
    );

    // 🎯 繪製下載速度曲線（藍色）- 後繪製前景層，重疊時優先顯示
    _drawSpeedCurve(
      canvas,
      size,
      downloadData,
      range,
      endX,
      currentDownload,
      Color(0xFF00EEFF), // 確保是藍色
      'download',
    );
  }

  void _drawSpeedCurve(
      Canvas canvas,
      Size size,
      List<double> data,
      double range,
      double endX,
      double currentValue,
      Color primaryColor,
      String curveType,
      ) {
    if (data.isEmpty) return;

    final path = Path();
    final double stepX = endX / (data.length - 1);
    final List<Offset> points = [];

    // 🎯 計算曲線上的所有點
    for (int i = 0; i < data.length; i++) {
      final double x = i * stepX;
      final double normalizedValue = (data[i] - minSpeed) / range;
      final double y = size.height - (normalizedValue * size.height);
      points.add(Offset(x, y));
    }

    if (points.isEmpty) return;

    // 🎯 建立平滑曲線路徑
    path.moveTo(points[0].dx, points[0].dy);

    if (points.length > 1) {
      for (int i = 0; i < points.length - 1; i++) {
        final Offset current = points[i];
        final Offset next = points[i + 1];

        // 使用平滑的貝茲曲線
        final double controlDistance = (next.dx - current.dx) * 0.3;
        final Offset cp1 = Offset(current.dx + controlDistance, current.dy);
        final Offset cp2 = Offset(next.dx - controlDistance, next.dy);

        path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, next.dx, next.dy);
      }
    }

    // 🎯 創建從左到右的透明度漸變著色器
    final Shader transparencyGradient = LinearGradient(
      begin: Alignment.centerLeft,   // 從左邊開始
      end: Alignment.centerRight,    // 到右邊結束
      colors: [
        primaryColor.withOpacity(0.0),  // 左邊完全透明 (0%)
        primaryColor.withOpacity(0.2),  //
        primaryColor.withOpacity(0.6),  //
        primaryColor.withOpacity(1.0),  // 右邊完全不透明 (100%)
      ],
      stops: [0.0, 0.3, 0.7, 1.0],      // 控制漸變分布
    ).createShader(Rect.fromLTWH(0, 0, endX, size.height));

    // 🎯 外層發光效果 - 大範圍模糊
    final Paint outerGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          primaryColor.withOpacity(0.0),  // 左邊透明
          primaryColor.withOpacity(0.1),
          primaryColor.withOpacity(0.3),
          primaryColor.withOpacity(0.5),  // 右邊發光
        ],
        stops: [0.0, 0.3, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, endX, size.height))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.0)
      ..strokeCap = StrokeCap.round;

    // 🎯 中層發光效果 - 中等模糊
    final Paint middleGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          primaryColor.withOpacity(0.0),  // 左邊透明
          primaryColor.withOpacity(0.2),
          primaryColor.withOpacity(0.5),
          primaryColor.withOpacity(0.8),  // 右邊更強發光
        ],
        stops: [0.0, 0.3, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, endX, size.height))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.0)
      ..strokeCap = StrokeCap.round;

    // 🎯 主線條 - 清晰的線條
    final Paint mainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = transparencyGradient
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 🎯 繪製順序：從外到內，從模糊到清晰
    canvas.drawPath(path, outerGlowPaint);   // 最外層發光
    canvas.drawPath(path, middleGlowPaint);  // 中層發光
    canvas.drawPath(path, mainPaint);        // 主線條

    // 🎯 調試：印出顏色資訊確認
    // print('🎨 繪製 $curveType 曲線:');
    // print('   主要顏色: ${primaryColor.toString()}');
    // print('   透明度: 0.0 -> 1.0 (左到右)');
    // print('   數據點數: ${data.length}');
  }

  @override
  bool shouldRepaint(covariant DualSpeedCurvePainter oldDelegate) {
    return oldDelegate.uploadData != uploadData ||
        oldDelegate.downloadData != downloadData ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.currentUpload != currentUpload ||
        oldDelegate.currentDownload != currentDownload ||
        oldDelegate.minSpeed != minSpeed ||
        oldDelegate.maxSpeed != maxSpeed ||
        oldDelegate.endAtPercent != endAtPercent;
  }
}

/// 🎯 真實數據速度圖表小部件（雙線版本 + 重疊處理）
/// 🎯 真實數據速度圖表小部件（雙線版本 + 重疊處理）
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
    // 🎯 獲取雙線資料，保留原始精度
    final double currentUpload = dataGenerator.currentUpload;
    final double currentDownload = dataGenerator.currentDownload;
    final List<double> uploadData = dataGenerator.uploadData;
    final List<double> downloadData = dataGenerator.downloadData;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double actualWidth = constraints.maxWidth;
        final double actualHeight = constraints.maxHeight;
        final double chartEndX = actualWidth * endAtPercent;

        // 🎯 可調整的圓點位置參數
        final double uploadDotOffset = -1.0;    // 🎯 上傳圓點左右偏移（負數向左，正數向右）
        final double downloadDotOffset = -1.0;   // 🎯 下載圓點左右偏移（負數向左，正數向右）
        final double overlapDotOffset = 0.0;    // 🎯 重疊時圓點的偏移

        // 🎯 可調整的垂直線位置參數
        final double uploadLineOffset = -1.0;   // 🎯 上傳垂直線左右偏移
        final double downloadLineOffset = 1.0;  // 🎯 下載垂直線左右偏移
        final double overlapLineOffset = 0.0;   // 🎯 重疊時垂直線的偏移

        // 計算圓點位置
        final double range = dataGenerator.maxSpeed - dataGenerator.minSpeed;
        final double uploadNormalized = range > 0 ? (currentUpload - dataGenerator.minSpeed) / range : 0.0;
        final double downloadNormalized = range > 0 ? (currentDownload - dataGenerator.minSpeed) / range : 0.0;

        final double uploadDotY = (1.0 - uploadNormalized) * actualHeight;
        final double downloadDotY = (1.0 - downloadNormalized) * actualHeight;

        // 檢查是否重疊
        final bool isOverlapping = (uploadDotY - downloadDotY).abs() < 6;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // 雙線速度曲線
            Positioned.fill(
              child: AnimatedBuilder(
                animation: animationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: DualSpeedCurvePainter(
                      uploadData: uploadData,
                      downloadData: downloadData,
                      minSpeed: dataGenerator.minSpeed,
                      maxSpeed: dataGenerator.maxSpeed,
                      animationValue: animationController.value,
                      endAtPercent: endAtPercent,
                      currentUpload: currentUpload,
                      currentDownload: currentDownload,
                    ),
                    size: Size(actualWidth, actualHeight),
                  );
                },
              ),
            ),

            // 🎯 註解掉垂直線：移除圓點底下的線條
            // if (!isOverlapping) ...[
            //   // 上傳速度垂直線（橙色）
            //   if (uploadData.isNotEmpty)
            //     Positioned(
            //       top: uploadDotY + 8,
            //       bottom: 0,
            //       left: chartEndX + uploadLineOffset,  // 🎯 使用可調整參數
            //       child: Container(
            //         width: 1,
            //         decoration: BoxDecoration(
            //           gradient: LinearGradient(
            //             begin: Alignment.topCenter,
            //             end: Alignment.bottomCenter,
            //             colors: [
            //               Colors.orange.withOpacity(0.8),
            //               Colors.orange.withOpacity(0),
            //             ],
            //           ),
            //         ),
            //       ),
            //     ),
            // ],

            // // 下載速度垂直線（藍色）
            // if (downloadData.isNotEmpty)
            //   Positioned(
            //     top: downloadDotY + 8,
            //     bottom: 0,
            //     left: chartEndX + (isOverlapping ? overlapLineOffset : downloadLineOffset), // 🎯 使用可調整參數
            //     child: Container(
            //       width: 1,
            //       decoration: BoxDecoration(
            //         gradient: LinearGradient(
            //           begin: Alignment.topCenter,
            //           end: Alignment.bottomCenter,
            //           colors: [
            //             Color(0xFF00EEFF).withOpacity(0.8),
            //             Color(0xFF00EEFF).withOpacity(0),
            //           ],
            //         ),
            //       ),
            //     ),
            //   ),

            // 🎯 圓點：縮小尺寸，外框改為與內部顏色一致
            if (!isOverlapping) ...[
              // 上傳速度圓點（橙色）
              if (uploadData.isNotEmpty)
                Positioned(
                  top: uploadDotY - 4,  // 🎯 調整位置以配合縮小的尺寸
                  left: chartEndX - 4 + uploadDotOffset,  // 🎯 調整位置以配合縮小的尺寸
                  child: Container(
                    width: 8,   // 🎯 從 12 縮小到 8
                    height: 8,  // 🎯 從 12 縮小到 8
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.orange, width: 1), // 🎯 外框改為橙色
                    ),
                  ),
                ),
            ],

            // 下載速度圓點（藍色）
            if (downloadData.isNotEmpty)
              Positioned(
                top: downloadDotY - 4,  // 🎯 調整位置以配合縮小的尺寸
                left: chartEndX - 4 + (isOverlapping ? overlapDotOffset : downloadDotOffset), // 🎯 調整位置以配合縮小的尺寸
                child: Container(
                  width: 8,   // 🎯 從 12 縮小到 8
                  height: 8,  // 🎯 從 12 縮小到 8
                  decoration: BoxDecoration(
                    color: Color(0xFF00EEFF),
                    shape: BoxShape.circle,
                    border: Border.all(color: Color(0xFF00EEFF), width: 1), // 🎯 外框改為藍色
                  ),
                ),
              ),

            // 🎯 註解掉：雙線速度標籤
            // if (uploadData.isNotEmpty && downloadData.isNotEmpty)
            //   Positioned(
            //     top: math.min(uploadDotY, downloadDotY) - 60,
            //     left: chartEndX - 60,
            //     child: DualSpeedLabelWidget(
            //       uploadSpeed: currentUpload,
            //       downloadSpeed: currentDownload,
            //     ),
            //   ),
          ],
        );
      },
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