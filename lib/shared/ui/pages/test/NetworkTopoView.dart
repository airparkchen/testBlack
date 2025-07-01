// lib/shared/ui/pages/test/NetworkTopoView.dart - 重構版本

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
// import 'package:whitebox/shared/services/real_data_integration_service.dart';   舊的API調用機制
import 'package:whitebox/shared/api/wifi_api_service.dart';
import 'package:whitebox/shared/services/unified_mesh_data_manager.dart';

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

class _NetworkTopoViewState extends State<NetworkTopoView>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Timer? _unifiedUpdateTimer;
  // ==================== 狀態變數 ====================

  // 視圖模式和導航
  String _viewMode = 'topology';
  int _selectedBottomTab = 1;

  //分離的載入狀態
  bool _isLoadingTopologyData = false;  // 只追蹤拓樸數據
  bool _isSpeedDataInitialized = false; // 追蹤速度數據初始化

  // 設備數量控制
  late final TextEditingController _deviceCountController;
  late int _deviceCount;

  // 動畫控制器
  late AnimationController _animationController;

  // 資料更新計時器
  Timer? _updateTimer;
  Timer? _autoReloadTimer; //自動重新載入計時器

  // 主題
  final AppTheme _appTheme = AppTheme();

  // 參考到拓樸顯示組件的 GlobalKey（修正類型）
  final GlobalKey<TopologyDisplayWidgetState> _topologyDisplayKey = GlobalKey<TopologyDisplayWidgetState>();

  // 新增：數據載入狀態
  bool _isLoadingData = false;
  List<NetworkDevice> _topologyDevices = [];  // 拓撲圖設備（只有 Extender）
  List<NetworkDevice> _listDevices = [];      // 列表設備（Gateway + Extender）
  List<DeviceConnection> _currentConnections = [];
  String _gatewayName = 'Controller';
  NetworkDevice? _gatewayDevice;

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

    // 新增：載入數據
    _loadTopologyData();
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        _initializeSpeedData();
        _startDataUpdates();
      }
    });

    // 🟢 修改：使用新的36秒間隔啟動自動重新載入
    if (NetworkTopoConfig.enableAutoReload) {
      _startAutoReload();

    if (NetworkTopoConfig.useRealData) {
      _startUnifiedUpdates();
    }
    }
  }

  void _initializeSpeedData() {
    if (!_isSpeedDataInitialized) {
      _startDataUpdates(); // 原有的速度更新邏輯
      _isSpeedDataInitialized = true;
      print('✅ 速度數據已初始化，將持續運行');
    }
  }

  /// 新增：異步載入數據的方法
  /// 🎯 修正：異步載入數據的方法 - 加強調試和資料流追蹤
  Future<void> _loadTopologyData() async {
    if (!mounted) return;

    setState(() {
      _isLoadingTopologyData = true;
    });

    try {
      if (NetworkTopoConfig.useRealData) {
        print('載入真實拓樸數據...');

        final manager = UnifiedMeshDataManager.instance;

        await manager.printCompleteDataStatistics();

        final topologyDevices = await manager.getNetworkDevices();
        final listDevices = await manager.getListViewDevices();
        final connections = await manager.getDeviceConnections();
        final gatewayName = await manager.getGatewayName();
        final gatewayDevice = await manager.getGatewayDevice();

        if (mounted) {
          setState(() {
            _topologyDevices = topologyDevices;
            _listDevices = listDevices;
            _currentConnections = connections;
            _gatewayName = gatewayName;
            _gatewayDevice = gatewayDevice;  // 🎯 確保設置 Gateway 設備
            _isLoadingTopologyData = false;
          });

          // 🎯 關鍵：載入完成後通知拓樸圖更新
          _notifyTopologyDisplayUpdate();
        }

        print('✅ 真實數據載入完成並已通知拓樸圖');

      } else {
        // 假數據邏輯...
      }
    } catch (e) {
      print('❌ 載入拓樸數據時發生錯誤: $e');
      if (mounted) {
        setState(() {
          _isLoadingTopologyData = false;
        });
      }
    }
  }

  void _notifyTopologyDisplayUpdate() {
    if (!mounted) return;

    // 通知拓樸顯示組件更新客戶端數量
    _topologyDisplayKey.currentState?.updateClientCounts(_currentConnections, _gatewayDevice);

    print('📢 已通知拓樸圖更新：${_currentConnections.length} 個連接');
  }

  Future<void> _updateFromUnifiedManagerAndNotify() async {
    try {
      final manager = UnifiedMeshDataManager.instance;

      // 獲取最新數據
      final results = await Future.wait([
        manager.getDeviceConnections(),
        manager.getGatewayDevice(),
        manager.getListViewDevices(),
        manager.getNetworkDevices(),
      ]);

      final connections = results[0] as List<DeviceConnection>;
      final gatewayDevice = results[1] as NetworkDevice?;


      // 更新本地狀態
      if (mounted) {
        setState(() {
          _currentConnections = connections;
          _gatewayDevice = gatewayDevice;
          _listDevices = results[2] as List<NetworkDevice>;
          _topologyDevices = results[3] as List<NetworkDevice>;
        });
      }

      // 通知拓樸圖更新
      _notifyTopologyDisplayUpdate();

      print('✅ 統一管理器數據更新並通知完成');

    } catch (e) {
      print('❌ 統一管理器更新通知失敗: $e');
    }
  }


  @override
  void dispose() {
    _deviceCountController.removeListener(_handleDeviceCountChanged);
    _deviceCountController.dispose();
    _updateTimer?.cancel();
    _autoReloadTimer?.cancel();
    _animationController.dispose();
    _unifiedUpdateTimer?.cancel();
    super.dispose();
  }

  void _startUnifiedUpdates() {
    _unifiedUpdateTimer?.cancel();

    final updateInterval = NetworkTopoConfig.meshApiCallInterval;
    print('🔄 啟動統一更新機制，間隔: ${updateInterval.inSeconds} 秒');

    _unifiedUpdateTimer = Timer.periodic(updateInterval, (_) {
      if (mounted && NetworkTopoConfig.useRealData) {
        print('⏰ 統一更新觸發');
        _updateFromUnifiedManagerAndNotify();
      }
    });
  }

  /// 啟動自動重新載入計時器
  void _startAutoReload() {
    _autoReloadTimer?.cancel();

    print('🔄 啟動自動重新載入，間隔: ${NetworkTopoConfig.autoReloadIntervalSeconds} 秒');

    // 🟢 修改：使用新的36秒間隔
    _autoReloadTimer = Timer.periodic(Duration(seconds: NetworkTopoConfig.autoReloadIntervalSeconds), (_) {
      if (mounted && NetworkTopoConfig.useRealData) {
        print('⏰ 自動重新載入觸發 (${NetworkTopoConfig.autoReloadIntervalSeconds}秒間隔)');
        _forceReloadData();
      }
    });
  }

  /// 新增：強制重新載入數據
  Future<void> _forceReloadData() async {
    if (!mounted) return;

    try {
      print('🔄 執行拓樸數據強制重新載入...');

      final manager = UnifiedMeshDataManager.instance;
      await manager.forceReload();

      // 重新載入拓樸數據並通知更新
      await _loadTopologyData();

      print('✅ 拓樸數據重新載入完成並已通知');
    } catch (e) {
      print('❌ 拓樸數據重新載入失敗: $e');
    }
  }



  // ==================== 資料管理 ====================

  /// 取得設備列表（統一的資料存取點）
  /// 🎯 修正：根據當前視圖模式返回對應的設備列表
  List<NetworkDevice> _getDevices() {
    // 優先使用外部傳入的設備
    if (widget.externalDevices != null && widget.externalDevices!.isNotEmpty) {
      return widget.externalDevices!;
    }

    // 根據視圖模式返回不同的設備列表
    if (_viewMode == 'topology') {
      return _topologyDevices ?? [];  // 拓撲圖：只有 Extender
    } else {
      return _listDevices ?? [];      // 列表：Gateway + Extender
    }
  }

  /// 取得設備連接資料
  /// 修改：同步版本的取得連接方法
  List<DeviceConnection> _getDeviceConnections(List<NetworkDevice> devices) {
    // 優先使用外部傳入的連接資料
    if (widget.externalDeviceConnections != null && widget.externalDeviceConnections!.isNotEmpty) {
      return widget.externalDeviceConnections!;
    }

    // 返回已載入的當前連接列表
    return _currentConnections;
  }

  // ==================== 事件處理 ====================

  /// 修正：處理設備數量變更（需要重新載入數據）
  void _handleDeviceCountChanged() {
    final newCount = int.tryParse(_deviceCountController.text) ?? 0;
    if (newCount != _deviceCount && newCount >= 0 && newCount <= NetworkTopoConfig.maxDeviceCount) {
      setState(() {
        _deviceCount = newCount;
      });

      // 如果使用假數據，重新載入
      if (!NetworkTopoConfig.useRealData) {
        _loadTopologyData();
      }
    }
  }

  /// 手動重新載入數據的方法
  Future<void> _refreshData() async {
    print('🔄 手動觸發重新載入');
    await _forceReloadData();
  }

  /// 處理設備選擇
  void _handleDeviceSelected(NetworkDevice device) {
    if (!widget.enableInteractions) return;
    print('設備被選中: ${device.name}');

    // 如果有外部回調，使用外部回調（優先）
    if (widget.onDeviceSelected != null) {
      widget.onDeviceSelected!(device);
    } else {
      print('沒有外部回調，執行預設行為');
    }
  }

  /// 處理視圖模式變更
  void _handleViewModeChanged(String mode) {
    if (!widget.enableInteractions) return;
    if (mode != _viewMode) {
      setState(() {
        _viewMode = mode;
      });
      print('視圖模式切換到: $mode');
    }
  }

  /// 處理底部導航切換
  void _handleBottomTabChanged(int index) {
    if (!widget.enableInteractions) return;
    setState(() {
      _selectedBottomTab = index;
    });
    print('底部導航切換到：$index');
  }

  /// 處理主頁面切換
  void _handleMainPageChanged(int index) {
    if (index != _selectedBottomTab) {
      setState(() {
        _selectedBottomTab = index;
      });
    }
  }

  // ==================== 資料更新 ====================

  /// 啟動數據更新
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
    super.build(context);
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

  /// 建構主要內容  (切換 topo / List 的地方)
  /// 建構主要內容（加入載入狀態和正確的數據源）
  Widget _buildMainContent() {
    final devices = _getDevices();
    final connections = _getDeviceConnections(devices);

    return Stack(
      children: [
        IndexedStack(
          index: _viewMode == 'topology' ? 0 : 1,
          children: [
            TopologyDisplayWidget(
              key: _topologyDisplayKey,
              devices: devices,
              deviceConnections: connections,
              gatewayName: _gatewayName,
              enableInteractions: widget.enableInteractions,
              animationController: _animationController,
              onDeviceSelected: _handleDeviceSelected,
            ),
            DeviceListWidget(
              devices: devices,
              enableInteractions: widget.enableInteractions,
              onDeviceSelected: _handleDeviceSelected,
            ),
          ],
        ),

        // 🟢 Loading 覆蓋層：只在載入時顯示，不影響底層組件
        if (_isLoadingTopologyData && _topologyDevices.isEmpty)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                      'Loading topology...',
                      style: TextStyle(color: Colors.white, fontSize: 16)
                  ),
                ],
              ),
            ),
          ),
      ],
    );
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

          // 🎯 新增：重新載入按鈕（用於真實數據）
          if (NetworkTopoConfig.useRealData) ...[
            const SizedBox(width: 16),
            InkWell(
              onTap: widget.enableInteractions ? () async {
                print('🔄 手動觸發重新載入');
                final manager = UnifiedMeshDataManager.instance;
                await manager.forceReload();
              } : null,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF9747FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.refresh, color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

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

              // 點擊區域層
              Row(
                children: [
                  // Topology 選項卡 - 整個區域可點擊
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.enableInteractions ? () => _handleViewModeChanged('topology') : null,
                      child: Container(
                        color: Colors.transparent,
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
                        color: Colors.transparent,
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