// lib/shared/ui/pages/test/NetworkTopoView123.dart - 重構版本

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';
import 'package:whitebox/shared/theme/app_theme.dart';
import 'package:whitebox/shared/ui/components/basic/NetworkTopologyComponent.dart';
import 'package:whitebox/shared/ui/pages/home/Topo/network_topo_config.dart';
import 'package:whitebox/shared/ui/pages/home/Topo/fake_data_generator.dart';
import 'package:whitebox/shared/ui/components/basic/topology_display_widget.dart';
import 'package:whitebox/shared/ui/components/basic/device_list_widget.dart';

class NetworkTopoView extends StatefulWidget {
  // 保持原有的所有參數，確保對外介面不變
  final bool showDeviceCountController;
  final int defaultDeviceCount;
  final List<NetworkDevice>? externalDevices;
  final List<DeviceConnection>? externalDeviceConnections;
  final bool enableInteractions;
  final bool showBottomNavigation;
  final Function(NetworkDevice)? onDeviceSelected;

  const NetworkTopoView({
    Key? key,
    this.showDeviceCountController = false,
    this.defaultDeviceCount = 0,
    this.externalDevices,
    this.externalDeviceConnections,
    this.enableInteractions = true,
    this.showBottomNavigation = true,
    this.onDeviceSelected,
  }) : super(key: key);

  @override
  State<NetworkTopoView> createState() => _NetworkTopoViewState();
}

class _NetworkTopoViewState extends State<NetworkTopoView> with SingleTickerProviderStateMixin {
  // ==================== 狀態變數 ====================

  // 視圖模式和導航
  String _viewMode = 'topology';
  int _selectedBottomTab = 1;

  // 設備數量控制
  late final TextEditingController _deviceCountController;
  late int _deviceCount;

  // 動畫控制器
  late AnimationController _animationController;

  // 資料更新計時器
  Timer? _updateTimer;

  // 主題
  final AppTheme _appTheme = AppTheme();

  // 參考到拓樸顯示組件的 GlobalKey（修正類型）
  final GlobalKey<TopologyDisplayWidgetState> _topologyDisplayKey =
  GlobalKey<TopologyDisplayWidgetState>();

  @override
  void initState() {
    super.initState();

    // 初始化設備數量
    _deviceCount = widget.defaultDeviceCount;
    _deviceCountController = TextEditingController(text: _deviceCount.toString());
    _deviceCountController.addListener(_handleDeviceCountChanged);

    // 初始化動畫控制器
    _animationController = AnimationController(
      vsync: this,
      duration: NetworkTopoConfig.animationDuration,
    );

    // 啟動數據更新
    _startDataUpdates();
  }

  @override
  void dispose() {
    _deviceCountController.removeListener(_handleDeviceCountChanged);
    _deviceCountController.dispose();
    _updateTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  // ==================== 資料管理 ====================

  /// 取得設備列表（統一的資料存取點）
  List<NetworkDevice> _getDevices() {
    // 優先使用外部傳入的設備
    if (widget.externalDevices != null && widget.externalDevices!.isNotEmpty) {
      return widget.externalDevices!;
    }

    // 根據配置決定使用真實或假資料
    if (NetworkTopoConfig.useRealData) {
      // TODO: 這裡將來要接入真實的 Mesh API
      // return await RealDataService.loadDevicesFromMeshAPI();
      print('🌐 使用真實資料 (目前使用假資料代替)');
      return FakeDataGenerator.generateDevices(_deviceCount);
    } else {
      return FakeDataGenerator.generateDevices(_deviceCount);
    }
  }

  /// 取得設備連接資料
  List<DeviceConnection> _getDeviceConnections(List<NetworkDevice> devices) {
    // 優先使用外部傳入的連接資料
    if (widget.externalDeviceConnections != null && widget.externalDeviceConnections!.isNotEmpty) {
      return widget.externalDeviceConnections!;
    }

    // 根據配置決定使用真實或假資料
    if (NetworkTopoConfig.useRealData) {
      // TODO: 這裡將來要接入真實的 Mesh API
      print('🌐 使用真實連接資料 (目前使用假資料代替)');
      return FakeDataGenerator.generateConnections(devices);
    } else {
      return FakeDataGenerator.generateConnections(devices);
    }
  }

  // ==================== 事件處理 ====================

  void _handleDeviceCountChanged() {
    final newCount = int.tryParse(_deviceCountController.text) ?? 0;
    if (newCount != _deviceCount && newCount >= 0 && newCount <= NetworkTopoConfig.maxDeviceCount) {
      setState(() {
        _deviceCount = newCount;
      });
    }
  }

  void _handleDeviceSelected(NetworkDevice device) {
    if (!widget.enableInteractions) return;
    print('設備被選中: ${device.name}');
    // 這裡可以加入設備詳情頁面導航
    // 👈 如果有外部回調，使用外部回調（優先）
    if (widget.onDeviceSelected != null) {
      widget.onDeviceSelected!(device);
    } else {
      // 👈 如果沒有外部回調，使用原本的邏輯（可以加入設備詳情頁面導航）
      print('沒有外部回調，執行預設行為');
      // 這裡可以加入原本的 Navigator.push 邏輯
    }
  }

  void _handleViewModeChanged(String mode) {
    if (!widget.enableInteractions) return;
    if (mode != _viewMode) {
      setState(() {
        _viewMode = mode;
      });
    }
  }

  void _handleBottomTabChanged(int index) {
    if (!widget.enableInteractions) return;
    setState(() {
      _selectedBottomTab = index;
    });
    print('底部導航切換到：$index');
  }

  // ==================== 資料更新 ====================

  void _startDataUpdates() {
    _updateTimer = Timer.periodic(NetworkTopoConfig.speedUpdateInterval, (_) {
      if (mounted && _viewMode == 'topology') {
        // 更新速度數據（只在拓樸模式下）
        _topologyDisplayKey.currentState?.updateSpeedData();

        // 啟動動畫
        _animationController.reset();
        _animationController.forward();
      }
    });
  }

  // ==================== UI 建構 ====================

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: widget.showBottomNavigation
            ? BackgroundDecorator.imageBackground(
          imagePath: AppBackgrounds.mainBackground,
        )
            : null,
        child: Stack(
          children: [
            // 主要內容
            Column(
              children: [
                // 設備數量控制器（可選）
                if (widget.showDeviceCountController)
                  _buildDeviceCountController(),

                // TabBar 區域預留空間
                SizedBox(height: widget.showBottomNavigation
                    ? screenSize.height * NetworkTopoConfig.tabBarTopRatio
                    : screenSize.height * NetworkTopoConfig.tabBarTopEmbeddedRatio),

                // 主要內容區域
                Expanded(
                  child: _buildMainContent(),
                ),

                // 底部導航
                if (widget.showBottomNavigation)
                  _buildBottomNavBar(),
                if (!widget.showBottomNavigation)
                  SizedBox(height: screenSize.height * 0.02),
              ],
            ),

            // TabBar 絕對定位
            Positioned(
              top: widget.showBottomNavigation
                  ? screenSize.height * NetworkTopoConfig.tabBarTopRatio
                  : screenSize.height * NetworkTopoConfig.tabBarTopEmbeddedRatio,
              left: 0,
              right: 0,
              child: _buildTabBar(),
            ),
          ],
        ),
      ),
    );
  }

  /// 建構主要內容
  Widget _buildMainContent() {
    final devices = _getDevices();
    final connections = _getDeviceConnections(devices);

    if (_viewMode == 'topology') {
      return TopologyDisplayWidget(
        key: _topologyDisplayKey,
        devices: devices,
        connections: connections,
        gatewayName: 'Controller',
        enableInteractions: widget.enableInteractions,
        animationController: _animationController,
        onDeviceSelected: _handleDeviceSelected,
      );
    } else {
      return DeviceListWidget(
        devices: devices,
        enableInteractions: widget.enableInteractions,
        onDeviceSelected: _handleDeviceSelected,
      );
    }
  }

  /// 建構設備數量控制器
  Widget _buildDeviceCountController() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFEFEFEF),
      child: Row(
        children: [
          const Text(
            '裝置數量:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),

          // 減少按鈕
          InkWell(
            onTap: widget.enableInteractions ? () {
              if (_deviceCount > 0) {
                setState(() {
                  _deviceCount--;
                  _deviceCountController.text = _deviceCount.toString();
                });
              }
            } : null,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFD9D9D9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.remove),
            ),
          ),

          // 數量輸入框
          Container(
            width: 60,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: TextField(
              controller: _deviceCountController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              enabled: widget.enableInteractions,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
            ),
          ),

          // 增加按鈕
          InkWell(
            onTap: widget.enableInteractions ? () {
              if (_deviceCount < NetworkTopoConfig.maxDeviceCount) {
                setState(() {
                  _deviceCount++;
                  _deviceCountController.text = _deviceCount.toString();
                });
              }
            } : null,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFD9D9D9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  /// 建構 TabBar
  /// 建構 TabBar
  Widget _buildTabBar() {
    return Container(
      margin: NetworkTopoConfig.tabBarMargin,
      height: NetworkTopoConfig.tabBarHeight,
      child: CustomPaint(
        painter: GradientBorderPainter(),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            color: Colors.transparent,
          ),
          child: Stack(
            children: [
              // 移動的白色膠囊背景
              AnimatedPositioned(
                duration: NetworkTopoConfig.animationDuration,
                curve: NetworkTopoConfig.animationCurve,
                left: _getTabCapsulePosition(),
                top: 0,
                bottom: 0,
                child: _buildTabCapsule(),
              ),

              // 點擊區域層（修改這裡）
              Row(
                children: [
                  // Topology 選項卡 - 整個區域可點擊
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.enableInteractions ? () => _handleViewModeChanged('topology') : null,
                      child: Container(
                        color: Colors.transparent, // 👈 確保整個區域可點擊
                        alignment: Alignment.center,
                        child: Text(
                          'Topology',
                          style: TextStyle(
                            color: _viewMode == 'topology'
                                ? NetworkTopoConfig.secondaryColor
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // List 選項卡 - 整個區域可點擊
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.enableInteractions ? () => _handleViewModeChanged('list') : null,
                      child: Container(
                        color: Colors.transparent, // 👈 確保整個區域可點擊
                        alignment: Alignment.center,
                        child: Text(
                          'List',
                          style: TextStyle(
                            color: _viewMode == 'list'
                                ? Colors.black
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  /// 建構底部導航欄
  Widget _buildBottomNavBar() {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      margin: EdgeInsets.only(
        left: screenWidth * NetworkTopoConfig.bottomNavLeftRatio,
        right: screenWidth * NetworkTopoConfig.bottomNavRightRatio,
        bottom: MediaQuery.of(context).size.height * NetworkTopoConfig.bottomNavBottomRatio,
      ),
      height: NetworkTopoConfig.bottomNavHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(35),
      ),
      child: CustomPaint(
        painter: BottomNavBarPainter(),
        child: Container(
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(33.5),
            color: Colors.transparent,
          ),
          child: Stack(
            children: [
              // 移動的圓圈背景
              AnimatedPositioned(
                duration: NetworkTopoConfig.animationDuration,
                curve: NetworkTopoConfig.animationCurve,
                left: _getCirclePosition(),
                top: 10,
                child: _buildAnimatedCircle(),
              ),

              // 圖標行
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(left: 3),
                        child: _buildBottomNavIcon(0, 'assets/images/icon/dashboard.png', Icons.dashboard),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: _buildBottomNavIcon(1, 'assets/images/icon/topohome.png', Icons.home),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: EdgeInsets.only(right: 3),
                        child: _buildBottomNavIcon(2, 'assets/images/icon/setting.png', Icons.settings),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== UI 輔助方法 ====================

  double _getTabCapsulePosition() {
    final screenWidth = MediaQuery.of(context).size.width;
    final totalMargin = (NetworkTopoConfig.tabBarMargin.left + NetworkTopoConfig.tabBarMargin.right) + 4;
    final tabBarWidth = screenWidth - totalMargin;
    final capsuleWidth = tabBarWidth / 2;

    return _viewMode == 'topology' ? 0 : capsuleWidth;
  }

  Widget _buildTabCapsule() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final totalMargin = (NetworkTopoConfig.tabBarMargin.left + NetworkTopoConfig.tabBarMargin.right) + 4;
        final tabBarWidth = screenWidth - totalMargin;
        final capsuleWidth = tabBarWidth / 2;

        return Container(
          width: capsuleWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.2),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomNavIcon(int index, String imagePath, IconData fallbackIcon) {
    final isSelected = index == _selectedBottomTab;

    return GestureDetector(
      onTap: widget.enableInteractions ? () => _handleBottomTabChanged(index) : null,
      child: Container(
        width: 60,
        height: 60,
        child: Center(
          child: Opacity(
            opacity: isSelected ? 1.0 : 0.5,
            child: Image.asset(
              imagePath,
              width: NetworkTopoConfig.iconSize,
              height: NetworkTopoConfig.iconSize,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  fallbackIcon,
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                  size: NetworkTopoConfig.iconSize * 0.8,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  double _getCirclePosition() {
    final screenWidth = MediaQuery.of(context).size.width;
    final barWidth = screenWidth * 0.70;
    final circleSize = 47.0;
    final barRadius = 35.0;
    final edgeDistance = barRadius - (circleSize / 2);
    final sectionWidth = barWidth / 3;
    final centerOffset = (sectionWidth - circleSize) / 2;

    switch (_selectedBottomTab) {
      case 0:
        return edgeDistance - 1.9;
      case 1:
        return sectionWidth + centerOffset;
      case 2:
        return barWidth - circleSize - edgeDistance - 0.2;
      default:
        return sectionWidth + centerOffset;
    }
  }

  Widget _buildAnimatedCircle() {
    return Container(
      width: 47,
      height: 47,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.1),
                  const Color(0xFF9747FF).withOpacity(0.0),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
            ),
          ),
          Container(
            width: 47,
            height: 47,
            child: CustomPaint(
              painter: GradientRingPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== 繪製器類別 ====================

class GradientBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gradient = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Colors.white, Color.fromRGBO(255, 255, 255, 0.6)],
    );

    final outerRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final outerRRect = RRect.fromRectAndRadius(outerRect, const Radius.circular(15));
    final innerRect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    final innerRRect = RRect.fromRectAndRadius(innerRect, const Radius.circular(13));

    final path = Path()
      ..addRRect(outerRRect)
      ..addRRect(innerRRect);
    path.fillType = PathFillType.evenOdd;

    final paint = Paint()
      ..shader = gradient.createShader(outerRect)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BottomNavBarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gradient = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Color.fromRGBO(255, 255, 255, 0.3),
        Color.fromRGBO(255, 255, 255, 0.3),
      ],
    );

    final outerRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final outerRRect = RRect.fromRectAndRadius(outerRect, Radius.circular(size.height / 2));
    final innerRect = Rect.fromLTWH(1.5, 1.5, size.width - 3, size.height - 3);
    final innerRRect = RRect.fromRectAndRadius(innerRect, Radius.circular((size.height - 3) / 2));

    final path = Path()
      ..addRRect(outerRRect)
      ..addRRect(innerRRect);
    path.fillType = PathFillType.evenOdd;

    final paint = Paint()
      ..shader = gradient.createShader(outerRect)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GradientRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 + 2;

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.white, const Color(0xFF9747FF)],
    );

    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius + 7, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}