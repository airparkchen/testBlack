// lib/shared/ui/pages/home/DashboardPage.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:whitebox/shared/theme/app_theme.dart';
import 'package:whitebox/shared/ui/components/basic/DashboardComponent.dart';
import 'package:whitebox/shared/ui/pages/test/NetworkTopoView.dart';
// 在 DashboardPage.dart 頂部添加
import 'package:whitebox/shared/ui/pages/home/DeviceDetailPage.dart';
import 'package:whitebox/shared/ui/components/basic/NetworkTopologyComponent.dart';
import 'package:whitebox/shared/models/dashboard_data_models.dart';
import 'package:whitebox/shared/services/dashboard_data_service.dart';
// 🔥 重要：移除重複的 import，使用 DashboardComponent 中的資料類別

class DashboardPage extends StatefulWidget {
  // ==================== 配置參數 ====================

  // 背景相關配置
  final bool enableBackground;
  final String? customBackgroundPath;

  // API 相關配置
  final String? apiEndpoint;
  final Duration refreshInterval;

  // 自動切換配置（停用）
  final bool enableAutoSwitch;
  final Duration autoSwitchDuration;

  // 新增：是否顯示底部導航欄（預設顯示）
  final bool showBottomNavigation;

  // 新增：初始選中的導航索引
  final int initialNavigationIndex;

  const DashboardPage({
    Key? key,
    this.enableBackground = true,
    this.customBackgroundPath,
    this.apiEndpoint,
    // this.refreshInterval = const Duration(minutes: 1), //api自動更新
    this.refreshInterval = const Duration(seconds: 15),
    this.enableAutoSwitch = false,
    this.autoSwitchDuration = const Duration(seconds: 5),
    this.showBottomNavigation = true,
    this.initialNavigationIndex = 0, // 0: Dashboard, 1: NetworkTopo, 2: Settings
  }) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {

  // ==================== 版面配置變數（可調整） ====================

  // 三個元件的螢幕絕對位置比例 - 直接以螢幕高度為基準
  static const double titleTopRatio = 0.1;           // 標題元件開始位置
  static const double titleBottomRatio = 0.15;       // 標題元件結束位置

  static const double indicatorTopRatio = 0.12;      // 指示點元件開始位置
  static const double indicatorBottomRatio = 0.21;   // 指示點元件結束位置

  static const double contentTopRatio = 0.19;        // 內容元件開始位置
  static const double contentBottomRatio = 0.8;      // 內容元件結束位置

  // 樣式配置
  static const double indicatorSize = 6.0;           // 指示點大小
  static const double indicatorSpacing = 8.0;        // 指示點間距
  static const double titleFontSizeRatio = 0.032;    // 標題字體大小比例
  static const double contentWidthRatio = 0.9;       // 內容寬度比例

  // ==================== 導航相關變數 ====================

  // 當前選中的底部選項卡
  late int _selectedBottomTab;

  // 頁面控制器
  late PageController _mainPageController;

  // 導航動畫控制器
  late AnimationController _navigationAnimationController;

  // ==================== 設備詳情相關變數（新增） ====================

  // 選中的設備（用於顯示詳情頁）
  NetworkDevice? _selectedDeviceForDetail;

  // 是否顯示設備詳情頁
  bool _showDeviceDetail = false;

  // 選中設備是否為網關
  bool _selectedDeviceIsGateway = false;

  // ==================== Dashboard 狀態變數 ====================

  // 主題實例
  final AppTheme _appTheme = AppTheme();

  // 當前分頁索引
  int _currentPageIndex = 0;

  // 總分頁數
  final int _totalPages = 3;

  // 資料載入狀態
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  // 🔥 修正：使用 DashboardComponent 中的 EthernetPageData
  List<EthernetPageData>? _ethernetPages;

  // 重新整理計時器
  Timer? _refreshTimer;

  // ==================== 生命週期方法 ====================

  @override
  void initState() {
    super.initState();

    // 初始化導航狀態
    _selectedBottomTab = widget.initialNavigationIndex;

    // 初始化頁面控制器
    _mainPageController = PageController(initialPage: widget.initialNavigationIndex);

    // 初始化導航動畫控制器
    _navigationAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // 初始載入資料
    _loadDashboardData();

    // 啟動定期重新整理
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _mainPageController.dispose();
    _navigationAnimationController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ==================== 資料載入方法（修正：使用正確的資料類別） ====================

  /// 載入 Dashboard 資料
  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      List<EthernetPageData> data = await _fetchDashboardDataFromAPI();

      setState(() {
        _ethernetPages = data;
        _isLoading = false;
      });

      print('Dashboard 資料載入成功：${data.length} 個分頁');

    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });

      print('Dashboard 資料載入失敗：$e');
      _loadDefaultData();
    }
  }

  /// 模擬 API 呼叫（修正：使用正確的資料類別）
  Future<List<EthernetPageData>> _fetchDashboardDataFromAPI() async {
    try {
      print('🌐 開始載入真實 Dashboard 資料...');

      // 使用 DashboardDataService 獲取真實資料
      final dashboardData = await DashboardDataService.getDashboardData(forceRefresh: true);

      // 輸出解析結果（調試用）
      DashboardDataService.printParsedData(dashboardData);

      // 轉換為 EthernetPageData 格式
      final pages = _convertDashboardDataToEthernetPages(dashboardData);

      print('✅ 成功轉換為 ${pages.length} 個 EthernetPageData 分頁');
      return pages;

    } catch (e) {
      print('❌ 載入真實 Dashboard 資料失敗: $e');

      // 失敗時返回備用資料
      return _getFallbackEthernetPages();
    }
  }

  /// 🔥 修正：將 DashboardData 轉換為 DashboardComponent 中的 EthernetPageData 格式
  List<EthernetPageData> _convertDashboardDataToEthernetPages(DashboardData dashboardData) {
    final pages = <EthernetPageData>[];

    // ==================== 第一頁：系統狀態 ====================
    final firstPageConnections = <EthernetConnection>[];

    // Model Name (單行右對齊)
    firstPageConnections.add(EthernetConnection(
      speed: 'Model Name',
      status: dashboardData.modelName,
    ));

    // Internet (單行右對齊)
    firstPageConnections.add(EthernetConnection(
      speed: 'Internet',
      status: dashboardData.internetStatus.formattedStatus,
    ));

    // WiFi (標題) - 🔥 加上 connectionType
    firstPageConnections.add(EthernetConnection(
      speed: 'WiFi',
      status: '', // 空值，表示這是一個標題行
      connectionType: 'wifi_title',
    ));

    // WiFi 頻率狀態 (列表，右對齊)
    for (var freq in dashboardData.wifiFrequencies) {
      firstPageConnections.add(EthernetConnection(
        speed: freq.displayFrequency,
        status: freq.statusText,
        connectionType: 'wifi_frequency', // 標記為頻率項目
      ));
    }

    // Guest WiFi (如果啟用)
    if (DashboardConfig.showGuestWiFi && dashboardData.guestWifiFrequencies.isNotEmpty) {
      firstPageConnections.add(EthernetConnection(
        speed: 'Guest WiFi',
        status: '', // 標題行
        connectionType: 'guest_wifi_title',
      ));

      for (var freq in dashboardData.guestWifiFrequencies) {
        firstPageConnections.add(EthernetConnection(
          speed: freq.displayFrequency,
          status: freq.statusText,
          connectionType: 'guest_wifi_frequency',
        ));
      }
    }

    pages.add(EthernetPageData(
      pageTitle: "System Status",
      connections: firstPageConnections,
    ));

    // ==================== 第二頁：SSID 列表 ====================
    final secondPageConnections = <EthernetConnection>[];

    // 只顯示啟用的 WiFi SSID
    final enabledWiFiSSIDs = dashboardData.wifiSSIDs.where((ssid) => ssid.isEnabled).toList();

    if (enabledWiFiSSIDs.isNotEmpty) {
      // WiFi SSID (標題) - 🔥 加上 connectionType
      secondPageConnections.add(EthernetConnection(
        speed: 'WiFi',
        status: '', // 標題行
        connectionType: 'wifi_title',
      ));

      for (var ssidInfo in enabledWiFiSSIDs) {
        secondPageConnections.add(EthernetConnection(
          speed: ssidInfo.ssidLabel, // SSID(2.4GHz), SSID(5GHz), etc.
          status: ssidInfo.ssid,     // 實際的 SSID 名稱
          connectionType: 'wifi_ssid', // 🔥 重要：標記為 SSID 項目
        ));
      }
    }

    // Guest WiFi SSID (如果啟用)
    if (DashboardConfig.showGuestWiFi && dashboardData.guestWifiSSIDs.isNotEmpty) {
      final enabledGuestSSIDs = dashboardData.guestWifiSSIDs.where((ssid) => ssid.isEnabled).toList();

      if (enabledGuestSSIDs.isNotEmpty) {
        secondPageConnections.add(EthernetConnection(
          speed: 'Guest WiFi',
          status: '', // 標題行
          connectionType: 'guest_wifi_title',
        ));

        for (var ssidInfo in enabledGuestSSIDs) {
          secondPageConnections.add(EthernetConnection(
            speed: ssidInfo.ssidLabel,
            status: ssidInfo.ssid,
            connectionType: 'guest_wifi_ssid', // 🔥 重要：標記為 Guest SSID 項目
          ));
        }
      }
    }

    // 如果沒有啟用的 SSID，顯示提示
    if (secondPageConnections.length == 1) { // 只有標題
      secondPageConnections.add(EthernetConnection(
        speed: 'No enabled',
        status: 'networks',
      ));
    }

    pages.add(EthernetPageData(
      pageTitle: "WiFi SSID",
      connections: secondPageConnections,
    ));

    // ==================== 第三頁：Ethernet ====================
    final thirdPageConnections = <EthernetConnection>[];

    // 根據配置決定是否顯示詳細資訊
    if (DashboardConfig.showEthernetDetails) {
      // 如果要顯示詳細資訊，可以在這裡添加乙太網路相關的連接資料
      thirdPageConnections.add(EthernetConnection(
        speed: 'Port 1',
        status: 'Connected',
      ));
      // ... 其他乙太網路連接
    }
    // 如果不顯示詳細資訊，connections 保持空列表，只顯示 "Ethernet" 標題

    pages.add(EthernetPageData(
      pageTitle: "Ethernet",
      connections: thirdPageConnections,
    ));

    print('📋 轉換完成：');
    print('  第一頁：${firstPageConnections.length} 個項目');
    print('  第二頁：${secondPageConnections.length} 個項目');
    print('  第三頁：${thirdPageConnections.length} 個項目');

    return pages;
  }

  /// 🔥 修正：備用的 EthernetPageData（使用正確的資料類別）
  List<EthernetPageData> _getFallbackEthernetPages() {
    print('⚠️ 使用備用的 EthernetPageData');
    return [
      EthernetPageData(
        pageTitle: "System Status",
        connections: [
          EthernetConnection(speed: "Model Name", status: "API Error"),
          EthernetConnection(speed: "Internet", status: "Unknown"),
          EthernetConnection(speed: "WiFi", status: "", connectionType: 'wifi_title'),
          EthernetConnection(speed: "2.4GHz", status: "Unknown", connectionType: 'wifi_frequency'),
          EthernetConnection(speed: "5GHz", status: "Unknown", connectionType: 'wifi_frequency'),
        ],
      ),
      EthernetPageData(
        pageTitle: "WiFi SSID",
        connections: [
          EthernetConnection(speed: "WiFi", status: "", connectionType: 'wifi_title'),
          EthernetConnection(speed: "No data", status: "available"),
        ],
      ),
      EthernetPageData(
        pageTitle: "Ethernet",
        connections: [], // 空列表，只顯示標題
      ),
    ];
  }

  /// 🔥 修正：載入預設資料（使用正確的資料類別）
  void _loadDefaultData() {
    setState(() {
      _ethernetPages = [
        EthernetPageData(
          pageTitle: "Default Network Status",
          connections: [
            EthernetConnection(speed: "10Gbps", status: "Unknown"),
            EthernetConnection(speed: "1Gbps", status: "Unknown"),
            EthernetConnection(speed: "10Gbps", status: "Unknown"),
            EthernetConnection(speed: "1Gbps", status: "Unknown"),
          ],
        ),
      ];
    });
  }

  /// 啟動定期重新整理
  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(widget.refreshInterval, (timer) {
      if (mounted && !_isLoading) {
        _loadDashboardData();
      }
    });
  }

  /// 手動重新整理
  Future<void> _handleRefresh() async {
    print('手動重新整理 Dashboard 資料');
    await _loadDashboardData();
  }

  // ==================== 設備詳情事件處理（新增） ====================

  /// 處理設備選擇（顯示設備詳情）
  void _handleDeviceSelected(NetworkDevice device) {
    print('設備被選中，顯示詳情：${device.name}');
    setState(() {
      _selectedDeviceForDetail = device;
      _selectedDeviceIsGateway = device.id == 'router-001' || device.name.contains('Controller');
      _showDeviceDetail = true;
    });
  }

  /// 處理設備詳情頁返回
  void _handleDeviceDetailBack() {
    print('返回設備列表');
    setState(() {
      _showDeviceDetail = false;
      _selectedDeviceForDetail = null;
      _selectedDeviceIsGateway = false;
    });
  }

  // ==================== 導航事件處理方法 ====================

  /// 處理分頁變更
  void _handlePageChanged(int pageIndex) {
    setState(() {
      _currentPageIndex = pageIndex;
    });

    print('Dashboard 分頁切換到：$pageIndex');
  }

  /// 處理指示點點擊
  void _handleIndicatorTapped(int index) {
    setState(() {
      _currentPageIndex = index;
    });
    print('點擊指示點，切換到分頁：$index');
  }

  /// 處理底部導航切換
  void _handleBottomTabChanged(int index) {
    if (index == _selectedBottomTab) return;

    // 如果正在顯示設備詳情，先返回列表
    if (_showDeviceDetail) {
      _handleDeviceDetailBack();
    }

    setState(() {
      _selectedBottomTab = index;
    });

    // 啟動圓圈移動動畫
    _navigationAnimationController.forward().then((_) {
      // 動畫完成後切換頁面
      _mainPageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      // 重置動畫控制器
      _navigationAnimationController.reset();
    });

    print('底部導航：切換到索引 $index');
  }

  /// 處理主頁面切換
  void _handleMainPageChanged(int index) {
    if (index != _selectedBottomTab) {
      setState(() {
        _selectedBottomTab = index;
      });
    }

    // 如果切換到非 NetworkTopo 頁面，隱藏設備詳情
    if (index != 1 && _showDeviceDetail) {
      _handleDeviceDetailBack();
    }
  }

  // ==================== 背景配置方法 ====================

  /// 獲取背景裝飾
  BoxDecoration _getBackgroundDecoration(BuildContext context) {
    if (!widget.enableBackground) {
      return const BoxDecoration(color: Colors.transparent);
    }

    String backgroundPath = widget.customBackgroundPath ??
        BackgroundDecorator.getResponsiveBackground(context);

    return BackgroundDecorator.imageBackground(
      imagePath: backgroundPath,
      fit: BoxFit.cover,
      overlayColor: AppColors.backgroundOverlay,
      opacity: 0.3,
    );
  }

  // ==================== UI 構建方法 ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: _getBackgroundDecoration(context),
        child: widget.showBottomNavigation
            ? _buildNavigationContainer()
            : _buildDashboardOnly(),
      ),
    );
  }

  /// 構建包含導航的容器
  Widget _buildNavigationContainer() {
    return Column(
      children: [
        // 主要內容區域
        Expanded(
          child: PageView(
            controller: _mainPageController,
            onPageChanged: _handleMainPageChanged,
            children: [
              // 頁面 0: Dashboard
              _buildDashboardContent(),

              // 頁面 1: NetworkTopo（可能顯示設備詳情）
              _buildNetworkTopoPage(),

              // 頁面 2: Settings
              _buildSettingsPage(),
            ],
          ),
        ),

        // 底部導航欄
        _buildBottomNavBar(),
      ],
    );
  }

  /// 構建純 Dashboard 內容（不含導航）
  Widget _buildDashboardOnly() {
    return _buildDashboardContent();
  }

  /// 🔥 修正：構建 Dashboard 內容（使用 DashboardComponent）
  Widget _buildDashboardContent() {
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        // ==================== 標題區域 ====================
        Positioned(
          top: screenSize.height * titleTopRatio,
          left: 0,
          right: 0,
          height: screenSize.height * (titleBottomRatio - titleTopRatio),
          child: Center(
            child: Text(
              'Dashboard',
              style: TextStyle(
                fontSize: screenSize.height * titleFontSizeRatio,
                fontWeight: FontWeight.normal,
                color: Colors.white,
              ),
            ),
          ),
        ),

        // ==================== 分頁指示器 ====================
        Positioned(
          top: screenSize.height * indicatorTopRatio,
          left: 0,
          right: 0,
          height: screenSize.height * (indicatorBottomRatio - indicatorTopRatio),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_totalPages, (index) {
                bool isActive = index == _currentPageIndex;

                return GestureDetector(
                  onTap: () => _handleIndicatorTapped(index),
                  child: Container(
                    width: indicatorSize,
                    height: indicatorSize,
                    margin: EdgeInsets.symmetric(horizontal: indicatorSpacing / 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? Colors.white : Colors.transparent,
                      border: Border.all(
                        color: Colors.white,
                        width: 1.0,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),

        // ==================== DashboardComponent 區域 ====================
        Positioned(
          top: screenSize.height * contentTopRatio,
          left: (screenSize.width - screenSize.width * contentWidthRatio) / 2,
          width: screenSize.width * contentWidthRatio,
          height: screenSize.height * (contentBottomRatio - contentTopRatio),
          child: DashboardComponent(
            // 基本配置
            totalPages: _totalPages,
            initialPageIndex: _currentPageIndex,

            // 事件回調
            onPageChanged: _handlePageChanged,
            onRefresh: _handleRefresh,

            // 尺寸配置
            width: screenSize.width * contentWidthRatio,
            height: screenSize.height * (contentBottomRatio - contentTopRatio),

            // 資料傳入
            ethernetPages: _ethernetPages,

            // 停用自動切換
            enableAutoSwitch: widget.enableAutoSwitch,
            autoSwitchDuration: widget.autoSwitchDuration,
          ),
        ),
      ],
    );
  }

  /// 構建 NetworkTopo 頁面（修改：支援設備詳情）
  Widget _buildNetworkTopoPage() {
    return IndexedStack(
      index: _showDeviceDetail ? 1 : 0,
      children: [
        // 0: NetworkTopoView（始終保持活躍）
        Container(
          color: Colors.transparent,
          child: NetworkTopoView(
            showDeviceCountController: false,
            defaultDeviceCount: 4,
            enableInteractions: true,
            showBottomNavigation: false,
            onDeviceSelected: _handleDeviceSelected,
          ),
        ),

        // 1: DeviceDetailPage
        _selectedDeviceForDetail != null
            ? DeviceDetailPage(
          selectedDevice: _selectedDeviceForDetail!,
          isGateway: _selectedDeviceIsGateway,
          showBottomNavigation: false,
          onBack: _handleDeviceDetailBack,
        )
            : Container(),
      ],
    );
  }

  /// 構建設定頁面
  Widget _buildSettingsPage() {
    return Container(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.settings,
              size: 64,
              color: Colors.white.withOpacity(0.7),
            ),
            SizedBox(height: 16),
            Text(
              'Settings Page',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Coming Soon...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 底部導航相關方法（保持原有） ====================

  /// 構建底部導航欄
  Widget _buildBottomNavBar() {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      margin: EdgeInsets.only(
        left: screenWidth * 0.145,
        right: screenWidth * 0.151,
        bottom: MediaQuery.of(context).size.height * 0.08,
      ),
      height: 70,
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
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                left: _getCirclePosition(),
                top: 10,
                child: _buildAnimatedCircle(),
              ),

              // 圖標行
              Row(
                children: [
                  // 左側 Dashboard
                  Expanded(
                    flex: 1,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(left: 3),
                        child: _buildBottomNavIconWithImage(
                            0,
                            'assets/images/icon/dashboard.png',
                            35
                        ),
                      ),
                    ),
                  ),

                  // 中間 NetworkTopo
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: _buildBottomNavIconWithImage(
                          1,
                          'assets/images/icon/topohome.png',
                          35
                      ),
                    ),
                  ),

                  // 右側 Settings
                  Expanded(
                    flex: 1,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: EdgeInsets.only(right: 3),
                        child: _buildBottomNavIconWithImage(
                            2,
                            'assets/images/icon/setting.png',
                            35
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

  /// 構建底部導航圖標
  Widget _buildBottomNavIconWithImage(
      int index,
      String imagePath,
      double iconSize,
      ) {
    final isSelected = index == _selectedBottomTab;

    return GestureDetector(
      onTap: () => _handleBottomTabChanged(index),
      child: Container(
        width: 60,
        height: 60,
        child: Center(
          child: Opacity(
            opacity: isSelected ? 1.0 : 0.5,
            child: Image.asset(
              imagePath,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  _getDefaultIcon(index),
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                  size: iconSize * 0.8,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// 計算圓圈位置
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

  /// 構建動畫圓圈
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

  /// 獲取預設圖標
  IconData _getDefaultIcon(int index) {
    switch (index) {
      case 0:
        return Icons.dashboard;
      case 1:
        return Icons.home;
      case 2:
        return Icons.settings;
      default:
        return Icons.circle;
    }
  }
}

// ==================== Painter 類別 ====================

/// 漸變環形繪製器
class GradientRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 + 2;

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white,
        const Color(0xFF9747FF),
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius + 7, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 底部導航欄背景繪製器
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