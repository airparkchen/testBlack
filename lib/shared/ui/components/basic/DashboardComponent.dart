// lib/shared/ui/components/basic/DashboardComponent.dart - 修正版本

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:whitebox/shared/theme/app_theme.dart';
import 'package:whitebox/shared/models/dashboard_data_models.dart';
import 'package:whitebox/shared/services/dashboard_data_service.dart';
import 'package:whitebox/shared/api/wifi_api_service.dart';

class DashboardComponent extends StatefulWidget {
  // ==================== 保持原有的所有參數 ====================

  // 分頁相關配置
  final int totalPages;
  final int initialPageIndex;

  // 回調函數
  final Function(int pageIndex)? onPageChanged;
  final VoidCallback? onRefresh;

  // 尺寸配置
  final double? width;
  final double? height;

  // 資料相關 - 保留原本的參數
  final List<EthernetPageData>? ethernetPages;

  // 自動切換配置（預設停用）
  final bool enableAutoSwitch;
  final Duration autoSwitchDuration;

  const DashboardComponent({
    Key? key,
    // 預設三頁分頁
    this.totalPages = 3,
    this.initialPageIndex = 0,
    this.onPageChanged,
    this.onRefresh,
    this.width,
    this.height,
    this.ethernetPages,
    // 預設停用自動切換
    this.enableAutoSwitch = false,
    this.autoSwitchDuration = const Duration(seconds: 5),
  }) : super(key: key);

  @override
  State<DashboardComponent> createState() => _DashboardComponentState();
}

class _DashboardComponentState extends State<DashboardComponent>
    with TickerProviderStateMixin {

  // ==================== 保持原有的狀態變數 ====================

  // 當前分頁索引
  late int _currentPageIndex;

  // 分頁控制器
  late PageController _pageController;

  // 自動切換計時器
  Timer? _autoSwitchTimer;

  // 動畫控制器
  late AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;

  // 主題實例
  final AppTheme _appTheme = AppTheme();

  // 捲動控制器
  final ScrollController _scrollController = ScrollController();

  // 修正：API 資料狀態（使用新的資料模型）
  bool _isLoadingApiData = false;
  DashboardData? _apiData;

  // ==================== 保持原有的生命週期方法 ====================

  @override
  void initState() {
    super.initState();

    _currentPageIndex = widget.initialPageIndex;
    _pageController = PageController(initialPage: _currentPageIndex);

    // 初始化動畫控制器
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeInOut,
    ));

    // 載入 API 資料
    _loadApiData();

    // 啟動動畫
    _fadeAnimationController.forward();

    // 啟動自動切換
    if (widget.enableAutoSwitch) {
      _startAutoSwitch();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    _autoSwitchTimer?.cancel();
    _fadeAnimationController.dispose();
    super.dispose();
  }

  // ==================== 修正：API 資料載入 ====================

  /// 載入 API 資料（使用新的服務）
  Future<void> _loadApiData() async {
    if (!mounted) return;

    setState(() {
      _isLoadingApiData = true;
    });

    try {
      final data = await DashboardDataService.getDashboardData(forceRefresh: true);
      if (mounted) {
        setState(() {
          _apiData = data;
          _isLoadingApiData = false;
        });
        print('✅ API 資料載入完成');

        // 輸出解析結果（調試用）
        DashboardDataService.printParsedData(data);
      }
    } catch (e) {
      print('❌ API 資料載入失敗: $e');
      if (mounted) {
        setState(() {
          _isLoadingApiData = false;
        });
      }
    }
  }

  // ==================== 保持原有的自動切換邏輯 ====================

  void _startAutoSwitch() {
    _autoSwitchTimer?.cancel();
    _autoSwitchTimer = Timer.periodic(widget.autoSwitchDuration, (timer) {
      if (mounted) {
        _switchToNextPage();
      }
    });
  }

  void _stopAutoSwitch() {
    _autoSwitchTimer?.cancel();
  }

  void _restartAutoSwitch() {
    if (widget.enableAutoSwitch) {
      _startAutoSwitch();
    }
  }

  void _switchToNextPage() {
    int nextIndex = (_currentPageIndex + 1) % widget.totalPages;
    _changePage(nextIndex);
  }

  // ==================== 保持原有的分頁控制方法 ====================

  void _changePage(int newIndex) {
    if (newIndex != _currentPageIndex && newIndex >= 0 && newIndex < widget.totalPages) {
      setState(() {
        _currentPageIndex = newIndex;
      });

      // 平滑切換到新分頁
      _pageController.animateToPage(
        newIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      // 通知外部分頁變更
      widget.onPageChanged?.call(newIndex);
    }
  }

  void _onDotTapped(int index) {
    // 用戶手動切換時，重新啟動自動切換計時器
    _stopAutoSwitch();
    _changePage(index);
    _restartAutoSwitch();
  }

  // ==================== 重寫：資料獲取方法 ====================

  /// 獲取分頁資料（使用新的資料模型）
  List<EthernetPageData> _getEthernetPages() {
    // 如果有外部傳入的資料，優先使用
    if (widget.ethernetPages != null && widget.ethernetPages!.isNotEmpty) {
      return widget.ethernetPages!;
    }

    // 如果有 API 資料，轉換並使用
    if (_apiData != null) {
      return _convertApiDataToEthernetPages(_apiData!);
    }

    // 備用：使用原本的預設資料
    return _getDefaultEthernetPages();
  }

  /// 重寫：將新 API 資料轉換為 EthernetPageData 格式
  List<EthernetPageData> _convertApiDataToEthernetPages(DashboardData apiData) {
    final pages = <EthernetPageData>[];

    // ==================== 第一頁：系統狀態 ====================
    final firstPageConnections = <EthernetConnection>[];

    // Model Name（單行顯示）
    firstPageConnections.add(EthernetConnection(
        speed: 'Model Name',
        status: apiData.modelName
    ));

    // Internet（單行顯示）
    firstPageConnections.add(EthernetConnection(
        speed: 'Internet',
        status: apiData.internetStatus.formattedStatus
    ));

    // WiFi（多行顯示，標題後換行）
    firstPageConnections.add(EthernetConnection(
        speed: 'WiFi',
        status: '' // 空字符串表示標題
    ));

    // WiFi 頻率狀態列表
    for (var freq in apiData.wifiFrequencies) {
      firstPageConnections.add(EthernetConnection(
          speed: freq.displayFrequency,
          status: freq.statusText
      ));
    }

    // Guest WiFi（如果啟用的話）
    if (DashboardConfig.showGuestWiFi && apiData.guestWifiFrequencies.isNotEmpty) {
      firstPageConnections.add(EthernetConnection(
          speed: 'Guest WiFi',
          status: '' // 空字符串表示標題
      ));

      for (var freq in apiData.guestWifiFrequencies) {
        firstPageConnections.add(EthernetConnection(
            speed: freq.displayFrequency,
            status: freq.statusText
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
    final enabledWiFiSSIDs = apiData.wifiSSIDs.where((ssid) => ssid.isEnabled).toList();

    if (enabledWiFiSSIDs.isNotEmpty) {
      // WiFi 標題
      secondPageConnections.add(EthernetConnection(
          speed: 'WiFi',
          status: '' // 空字符串表示標題
      ));

      // 各頻率的 SSID（按照圖片要求，SSID 名稱要換行顯示）
      for (var ssidInfo in enabledWiFiSSIDs) {
        secondPageConnections.add(EthernetConnection(
            speed: ssidInfo.ssidLabel, // 例如：SSID(2.4GHz)
            status: ssidInfo.ssid      // 例如：OWA813V_2.4G（會換行顯示）
        ));
      }
    }

    // Guest WiFi SSID（如果啟用的話）
    if (DashboardConfig.showGuestWiFi && apiData.guestWifiSSIDs.isNotEmpty) {
      final enabledGuestSSIDs = apiData.guestWifiSSIDs.where((ssid) => ssid.isEnabled).toList();

      if (enabledGuestSSIDs.isNotEmpty) {
        secondPageConnections.add(EthernetConnection(
            speed: 'Guest WiFi',
            status: '' // 空字符串表示標題
        ));

        for (var ssidInfo in enabledGuestSSIDs) {
          secondPageConnections.add(EthernetConnection(
              speed: ssidInfo.ssidLabel,
              status: ssidInfo.ssid
          ));
        }
      }
    }

    // 如果沒有啟用的 SSID
    if (secondPageConnections.isEmpty) {
      secondPageConnections.add(EthernetConnection(
          speed: 'WiFi',
          status: 'No enabled networks'
      ));
    }

    pages.add(EthernetPageData(
      pageTitle: "WiFi SSID",
      connections: secondPageConnections,
    ));

    // ==================== 第三頁：Ethernet ====================
    pages.add(EthernetPageData(
      pageTitle: "Ethernet",
      connections: [], // 空的連接列表，只顯示標題
    ));

    return pages;
  }

  /// 獲取預設的分頁資料（保持原有邏輯）
  List<EthernetPageData> _getDefaultEthernetPages() {
    return [
      EthernetPageData(
        pageTitle: "Loading...",
        connections: [
          EthernetConnection(speed: "Loading", status: "Please wait..."),
        ],
      ),
    ];
  }

  // ==================== 保持原有的 UI 構建方法（略作調整） ====================

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // ==================== 響應式尺寸計算 ====================

    // 使用傳入的尺寸或預設值
    double cardWidth = widget.width ?? (screenSize.width * 0.9);
    double cardHeight = widget.height ?? (screenSize.height * 0.45);

    // 鍵盤彈出時調整卡片高度
    if (bottomInset > 0) {
      cardHeight = screenSize.height - bottomInset - 190;
      cardHeight = cardHeight < 300 ? 300 : cardHeight;
    }

    // ==================== 內部尺寸配置 ====================

    final double titleHeight = bottomInset > 0 ? 60.0 : 80.0;
    final double indicatorHeight = 40.0;
    final EdgeInsets contentPadding = EdgeInsets.fromLTRB(
        25,
        bottomInset > 0 ? 10 : 15,
        25,
        bottomInset > 0 ? 10 : 25
    );

    return FadeTransition(
      opacity: _fadeAnimation,
      child: _appTheme.whiteBoxTheme.buildStandardCard(
        width: cardWidth,
        height: cardHeight,
        child: Column(
          children: [
            // ==================== 標題區域 ====================
            Container(
              height: titleHeight,
              padding: EdgeInsets.fromLTRB(
                  25,
                  bottomInset > 0 ? 15 : 25,
                  25,
                  0
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dashboard 標題
                  Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: bottomInset > 0 ? 18 : 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  // 重新整理按鈕
                  IconButton(
                    onPressed: () {
                      // 重新載入 API 資料
                      _loadApiData();
                      widget.onRefresh?.call();
                    },
                    icon: Icon(
                      Icons.refresh,
                      color: Colors.white.withOpacity(0.8),
                      size: bottomInset > 0 ? 20 : 24,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // ==================== 分頁指示器 ====================
            Container(
              height: indicatorHeight,
              child: _buildPageIndicators(bottomInset),
            ),

            // ==================== 分頁內容區域 ====================
            Expanded(
              child: _buildPageContent(contentPadding, bottomInset),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 保持原有的分頁指示器構建 ====================

  Widget _buildPageIndicators(double bottomInset) {
    final double indicatorSize = bottomInset > 0 ? 6.0 : 8.0;
    final double indicatorSpacing = bottomInset > 0 ? 12.0 : 16.0;

    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.totalPages, (index) {
          bool isActive = index == _currentPageIndex;

          return GestureDetector(
            onTap: () => _onDotTapped(index),
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
    );
  }

  // ==================== 修正：分頁內容構建 ====================

  Widget _buildPageContent(EdgeInsets contentPadding, double bottomInset) {
    final ethernetPages = _getEthernetPages();

    return PageView.builder(
      controller: _pageController,
      onPageChanged: (index) {
        setState(() {
          _currentPageIndex = index;
        });
        widget.onPageChanged?.call(index);

        // 用戶手動滑動時重新啟動自動切換
        _restartAutoSwitch();
      },
      itemCount: widget.totalPages,
      itemBuilder: (context, index) {
        if (index < ethernetPages.length) {
          return _buildEthernetPage(
              ethernetPages[index],
              contentPadding,
              bottomInset
          );
        } else {
          return _buildEmptyPage(contentPadding, bottomInset, index);
        }
      },
    );
  }

  // ==================== 重寫：頁面構建方法（符合新的版面需求） ====================

  Widget _buildEthernetPage(
      EthernetPageData pageData,
      EdgeInsets contentPadding,
      double bottomInset
      ) {
    return Padding(
      padding: contentPadding,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // 如果是第三頁（Ethernet）且沒有連接資料，只顯示標題
          if (pageData.pageTitle.contains("Ethernet") && pageData.connections.isEmpty) ...[
            _buildSectionTitle("Ethernet", bottomInset),
            SizedBox(height: 40),
            Center(
              child: Text(
                'Details hidden',
                style: TextStyle(
                  fontSize: bottomInset > 0 ? 14 : 16,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ),
          ] else ...[
            // 其他頁面顯示完整內容
            ...pageData.connections.asMap().entries.map((entry) {
              int index = entry.key;
              EthernetConnection connection = entry.value;
              bool isLastItem = index == pageData.connections.length - 1;

              return Column(
                children: [
                  _buildConnectionItem(connection, bottomInset, index == 0),
                  if (!isLastItem) _buildDivider(bottomInset),
                ],
              );
            }).toList(),
          ],

          // 鍵盤彈出時的額外空間
          if (bottomInset > 0)
            SizedBox(height: bottomInset * 0.5),
        ],
      ),
    );
  }

  // ==================== 重寫：連接項目構建（符合新的版面需求） ====================

  /// 修正：連接項目構建，支援標題左對齊和內容右對齊
  Widget _buildConnectionItem(EthernetConnection connection, double bottomInset, bool isFirstItem) {
    // 如果 status 為空，表示這是一個標題行
    if (connection.status.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(
          top: isFirstItem ? 0 : (bottomInset > 0 ? 15 : 20),
          bottom: bottomInset > 0 ? 8 : 12,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            connection.speed,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    // 檢查是否為單行項目（Model Name, Internet）
    bool isSingleLineItem = _isSingleLineItem(connection.speed);

    if (isSingleLineItem) {
      // 單行項目：標題和內容在同一行
      return Padding(
        padding: EdgeInsets.symmetric(vertical: bottomInset > 0 ? 8 : 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              connection.speed,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              connection.status,
              style: TextStyle(
                fontSize: 16,
                color: _getStatusColor(connection.status),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else {
      // 多行項目：內容右對齊，但在標題下方
      return Padding(
        padding: EdgeInsets.only(
          left: 0, // 不縮進，保持與標題對齊
          bottom: bottomInset > 0 ? 8 : 12,
        ),
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
                color: _getStatusColor(connection.status),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
  }

  /// 判斷是否為單行項目
  bool _isSingleLineItem(String speed) {
    return speed == 'Model Name' || speed == 'Internet';
  }

  // ==================== 保持原有的 UI 元件構建方法 ====================

  Widget _buildEmptyPage(EdgeInsets contentPadding, double bottomInset, int pageIndex) {
    return Padding(
      padding: contentPadding,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off,
              color: Colors.white.withOpacity(0.5),
              size: bottomInset > 0 ? 40 : 48,
            ),
            SizedBox(height: 16),
            Text(
              'Page ${pageIndex + 1}',
              style: TextStyle(
                fontSize: bottomInset > 0 ? 16 : 18,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            Text(
              'Loading...',
              style: TextStyle(
                fontSize: bottomInset > 0 ? 14 : 16,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, double bottomInset) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  /// 獲取狀態顏色
  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase();
    if (statusLower.contains('connect') && !statusLower.contains('disconnect')) {
      return Colors.green.shade300;
    } else if (statusLower.contains('on')) {
      return Colors.green.shade300;
    } else if (statusLower.contains('disconnect') || statusLower.contains('off')) {
      return Colors.red.shade300;
    } else {
      return Colors.white;
    }
  }

  Widget _buildDivider(double bottomInset) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: bottomInset > 0 ? 5 : 8),
      child: Divider(
        height: 1,
        thickness: 1,
        color: AppColors.primary.withOpacity(0.3),
      ),
    );
  }
}

// ==================== 保持原有的資料模型類別 ====================

/// 乙太網路連線資料模型（保持向後兼容）
class EthernetConnection {
  final String speed;    // 連線速度或標籤名稱
  final String status;   // 連線狀態或內容

  const EthernetConnection({
    required this.speed,
    required this.status,
  });

  factory EthernetConnection.fromJson(Map<String, dynamic> json) {
    return EthernetConnection(
      speed: json['speed'] ?? '',
      status: json['status'] ?? 'Unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'speed': speed,
      'status': status,
    };
  }

  @override
  String toString() {
    return 'EthernetConnection(speed: $speed, status: $status)';
  }
}

/// 乙太網路分頁資料模型（保持向後兼容）
class EthernetPageData {
  final String pageTitle;
  final List<EthernetConnection> connections;

  const EthernetPageData({
    required this.pageTitle,
    required this.connections,
  });

  factory EthernetPageData.fromJson(Map<String, dynamic> json) {
    var connectionsJson = json['connections'] as List? ?? [];
    List<EthernetConnection> connections = connectionsJson
        .map((item) => EthernetConnection.fromJson(item))
        .toList();

    return EthernetPageData(
      pageTitle: json['pageTitle'] ?? '',
      connections: connections,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pageTitle': pageTitle,
      'connections': connections.map((item) => item.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'EthernetPageData(pageTitle: $pageTitle, connections: ${connections.length} items)';
  }
}