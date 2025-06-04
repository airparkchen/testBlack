// lib/shared/ui/pages/home/DashboardPage.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:whitebox/shared/theme/app_theme.dart';
import 'package:whitebox/shared/ui/components/basic/DashboardComponent.dart';
import 'package:whitebox/shared/ui/pages/test/NetworkTopoView.dart';

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
    this.refreshInterval = const Duration(minutes: 1),
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

  // Dashboard 資料
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

  // ==================== 資料載入方法（保持原有邏輯） ====================

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

  /// 模擬 API 呼叫
  Future<List<EthernetPageData>> _fetchDashboardDataFromAPI() async {
    await Future.delayed(const Duration(milliseconds: 500));

    return [
      EthernetPageData(
        pageTitle: "Network Status - Group 1",
        connections: [
          EthernetConnection(speed: "10Gbps", status: "Disconnect"),
          EthernetConnection(speed: "1Gbps", status: "Connected"),
          EthernetConnection(speed: "10Gbps", status: "Connected"),
          EthernetConnection(speed: "1Gbps", status: "Connected"),
        ],
      ),
      EthernetPageData(
        pageTitle: "Network Status - Group 2",
        connections: [
          EthernetConnection(speed: "10Gbps", status: "Connected"),
          EthernetConnection(speed: "1Gbps", status: "Disconnect"),
          EthernetConnection(speed: "10Gbps", status: "Connected"),
          EthernetConnection(speed: "1Gbps", status: "Disconnect"),
        ],
      ),
      EthernetPageData(
        pageTitle: "Network Status - Group 3",
        connections: [
          EthernetConnection(speed: "10Gbps", status: "Connected"),
          EthernetConnection(speed: "1Gbps", status: "Connected"),
          EthernetConnection(speed: "10Gbps", status: "Disconnect"),
          EthernetConnection(speed: "1Gbps", status: "Connected"),
        ],
      ),
    ];
  }

  /// 載入預設資料
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

              // 頁面 1: NetworkTopo
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

  /// 構建 Dashboard 內容（保持原有的三個元件結構）
  Widget _buildDashboardContent() {
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        // ==================== 元件 1: Dashboard 標題 ====================
        DashboardTitleComponent(
          screenSize: screenSize,
          topRatio: titleTopRatio,
          bottomRatio: titleBottomRatio,
          fontSizeRatio: titleFontSizeRatio,
        ),

        // ==================== 元件 2: 分頁指示器 ====================
        DashboardIndicatorComponent(
          screenSize: screenSize,
          topRatio: indicatorTopRatio,
          bottomRatio: indicatorBottomRatio,
          currentPageIndex: _currentPageIndex,
          totalPages: _totalPages,
          indicatorSize: indicatorSize,
          indicatorSpacing: indicatorSpacing,
          onIndicatorTapped: _handleIndicatorTapped,
        ),

        // ==================== 元件 3: 內容區域 ====================
        DashboardContentComponent(
          screenSize: screenSize,
          topRatio: contentTopRatio,
          bottomRatio: contentBottomRatio,
          widthRatio: contentWidthRatio,
          currentPageIndex: _currentPageIndex,
          totalPages: _totalPages,
          ethernetPages: _ethernetPages,
          isLoading: _isLoading,
          hasError: _hasError,
          errorMessage: _errorMessage,
          onPageChanged: _handlePageChanged,
          onRefresh: _handleRefresh,
          appTheme: _appTheme,
        ),
      ],
    );
  }

  /// 構建 NetworkTopo 頁面
  Widget _buildNetworkTopoPage() {
    return Container(
      // 移除背景，使用透明背景避免衝突
      color: Colors.transparent,
      child: NetworkTopoView(
        showDeviceCountController: false,
        defaultDeviceCount: 4,
        enableInteractions: true,
        showBottomNavigation: false, // 不顯示自己的底部導航
      ),
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

// ==================== 保持原有的三個 Dashboard 元件 ====================

/// Dashboard 標題組件
class DashboardTitleComponent extends StatelessWidget {
  final Size screenSize;
  final double topRatio;
  final double bottomRatio;
  final double fontSizeRatio;

  const DashboardTitleComponent({
    Key? key,
    required this.screenSize,
    required this.topRatio,
    required this.bottomRatio,
    required this.fontSizeRatio,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenHeight = screenSize.height;
    final top = screenHeight * topRatio;
    final height = screenHeight * (bottomRatio - topRatio);
    final fontSize = screenHeight * fontSizeRatio;

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      height: height,
      child: Container(
        width: double.infinity,
        child: Center(
          child: Text(
            'Dashboard',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.normal, // 移除粗體
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// 分頁指示器組件
class DashboardIndicatorComponent extends StatelessWidget {
  final Size screenSize;
  final double topRatio;
  final double bottomRatio;
  final int currentPageIndex;
  final int totalPages;
  final double indicatorSize;
  final double indicatorSpacing;
  final Function(int) onIndicatorTapped;

  const DashboardIndicatorComponent({
    Key? key,
    required this.screenSize,
    required this.topRatio,
    required this.bottomRatio,
    required this.currentPageIndex,
    required this.totalPages,
    required this.indicatorSize,
    required this.indicatorSpacing,
    required this.onIndicatorTapped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenHeight = screenSize.height;
    final top = screenHeight * topRatio;
    final height = screenHeight * (bottomRatio - topRatio);

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      height: height,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalPages, (index) {
            bool isActive = index == currentPageIndex;

            return GestureDetector(
              onTap: () => onIndicatorTapped(index),
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
    );
  }
}

/// 內容區域組件
class DashboardContentComponent extends StatefulWidget {
  final Size screenSize;
  final double topRatio;
  final double bottomRatio;
  final double widthRatio;
  final int currentPageIndex;
  final int totalPages;
  final List<EthernetPageData>? ethernetPages;
  final bool isLoading;
  final bool hasError;
  final String errorMessage;
  final Function(int) onPageChanged;
  final VoidCallback onRefresh;
  final AppTheme appTheme;

  const DashboardContentComponent({
    Key? key,
    required this.screenSize,
    required this.topRatio,
    required this.bottomRatio,
    required this.widthRatio,
    required this.currentPageIndex,
    required this.totalPages,
    this.ethernetPages,
    required this.isLoading,
    required this.hasError,
    required this.errorMessage,
    required this.onPageChanged,
    required this.onRefresh,
    required this.appTheme,
  }) : super(key: key);

  @override
  State<DashboardContentComponent> createState() => _DashboardContentComponentState();
}

class _DashboardContentComponentState extends State<DashboardContentComponent> {
  late PageController _pageController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.currentPageIndex);
  }

  @override
  void didUpdateWidget(DashboardContentComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPageIndex != widget.currentPageIndex) {
      _pageController.animateToPage(
        widget.currentPageIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = widget.screenSize.height;
    final screenWidth = widget.screenSize.width;
    final top = screenHeight * widget.topRatio;
    final height = screenHeight * (widget.bottomRatio - widget.topRatio);
    final width = screenWidth * widget.widthRatio;
    final left = (screenWidth - width) / 2;

    return Positioned(
      top: top,
      left: left,
      width: width,
      height: height,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (widget.isLoading && widget.ethernetPages == null) {
      return _buildLoadingState();
    }

    if (widget.hasError && widget.ethernetPages == null) {
      return _buildErrorState();
    }

    return _buildNormalContent();
  }

  Widget _buildLoadingState() {
    return widget.appTheme.whiteBoxTheme.buildStandardCard(
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            SizedBox(height: 24),
            Text(
              'Loading Dashboard...',
              style: AppTextStyles.bodyLarge.copyWith(
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return widget.appTheme.whiteBoxTheme.buildStandardCard(
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red.shade300,
                size: 48,
              ),
              SizedBox(height: 16),
              Text(
                'Failed to load data',
                style: AppTextStyles.heading3.copyWith(
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                widget.errorMessage.isNotEmpty ? widget.errorMessage : 'Unknown error occurred',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 24),
              widget.appTheme.whiteBoxTheme.buildStandardButton(
                width: 120,
                height: 40,
                text: 'Retry',
                onPressed: widget.onRefresh,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNormalContent() {
    final ethernetPages = _getEthernetPages();

    return widget.appTheme.whiteBoxTheme.buildStandardCard(
      width: double.infinity,
      height: double.infinity,
      child: Padding(
        padding: EdgeInsets.all(25),
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            widget.onPageChanged(index);
          },
          itemCount: widget.totalPages,
          itemBuilder: (context, index) {
            if (index < ethernetPages.length) {
              return _buildEthernetPage(ethernetPages[index]);
            } else {
              return _buildEmptyPage(index);
            }
          },
        ),
      ),
    );
  }

  List<EthernetPageData> _getEthernetPages() {
    if (widget.ethernetPages != null && widget.ethernetPages!.isNotEmpty) {
      return widget.ethernetPages!;
    }

    return [
      EthernetPageData(
        pageTitle: "Ethernet Status - Page 1",
        connections: [
          EthernetConnection(speed: "10Gbps", status: "Disconnect"),
          EthernetConnection(speed: "1Gbps", status: "Connected"),
          EthernetConnection(speed: "10Gbps", status: "Connected"),
          EthernetConnection(speed: "1Gbps", status: "Connected"),
        ],
      ),
      EthernetPageData(
        pageTitle: "Ethernet Status - Page 2",
        connections: [
          EthernetConnection(speed: "10Gbps", status: "Connected"),
          EthernetConnection(speed: "1Gbps", status: "Disconnect"),
          EthernetConnection(speed: "10Gbps", status: "Connected"),
          EthernetConnection(speed: "1Gbps", status: "Disconnect"),
        ],
      ),
      EthernetPageData(
        pageTitle: "Ethernet Status - Page 3",
        connections: [
          EthernetConnection(speed: "10Gbps", status: "Connected"),
          EthernetConnection(speed: "1Gbps", status: "Connected"),
          EthernetConnection(speed: "10Gbps", status: "Disconnect"),
          EthernetConnection(speed: "1Gbps", status: "Connected"),
        ],
      ),
    ];
  }

  Widget _buildEthernetPage(EthernetPageData pageData) {
    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildSectionTitle('Ethernet'),
        SizedBox(height: 20),

        ...pageData.connections.asMap().entries.map((entry) {
          int index = entry.key;
          EthernetConnection connection = entry.value;
          bool isLastItem = index == pageData.connections.length - 1;

          return Column(
            children: [
              _buildConnectionItem(connection),
              if (!isLastItem) _buildDivider(),
            ],
          );
        }).toList(),
      ],
    );
  }

  Widget _buildEmptyPage(int pageIndex) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off,
            color: Colors.white.withOpacity(0.5),
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            'Page ${pageIndex + 1}',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          Text(
            'No data available',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildConnectionItem(EthernetConnection connection) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            connection.speed,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          Text(
            connection.status,
            style: TextStyle(
              fontSize: 16,
              color: connection.status == "Connected"
                  ? Colors.green.shade300
                  : Colors.red.shade300,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(
        height: 1,
        thickness: 1,
        color: AppColors.primary.withOpacity(0.3),
      ),
    );
  }
}

// ==================== 複製必要的 Painter 類別 ====================

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