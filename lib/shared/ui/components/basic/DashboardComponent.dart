// lib/shared/ui/components/basic/DashboardComponent.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:whitebox/shared/theme/app_theme.dart';

class DashboardComponent extends StatefulWidget {
  // ==================== 配置參數 ====================

  // 分頁相關配置
  final int totalPages;
  final int initialPageIndex;

  // 回調函數
  final Function(int pageIndex)? onPageChanged;
  final VoidCallback? onRefresh;

  // 尺寸配置
  final double? width;
  final double? height;

  // 資料相關 - 模擬三頁不同的網路狀態資料
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

  // ==================== 狀態變數 ====================

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

  // ==================== 生命週期方法 ====================

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

  // ==================== 自動切換邏輯 ====================

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

  // ==================== 分頁控制方法 ====================

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

  // ==================== 資料獲取方法 ====================

  List<EthernetPageData> _getEthernetPages() {
    if (widget.ethernetPages != null && widget.ethernetPages!.isNotEmpty) {
      return widget.ethernetPages!;
    }

    // 預設模擬資料 - 三個不同狀態的分頁
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

  // ==================== UI 構建方法 ====================

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // ==================== 響應式尺寸計算 ====================

    // 使用傳入的尺寸或預設值
    double cardWidth = widget.width ?? (screenSize.width * 0.9);
    double cardHeight = widget.height ?? (screenSize.height * 0.45);

    // 鍵盤彈出時調整卡片高度（參考 SummaryComponent）
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

                  // 重新整理按鈕（可選）
                  if (widget.onRefresh != null)
                    IconButton(
                      onPressed: widget.onRefresh,
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

  // ==================== 分頁指示器構建 ====================

  Widget _buildPageIndicators(double bottomInset) {
    // 指示器尺寸配置
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

  // ==================== 分頁內容構建 ====================

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

  // ==================== 乙太網路分頁構建 ====================

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
          // 分頁標題區域
          _buildSectionTitle('Ethernet', bottomInset),
          SizedBox(height: bottomInset > 0 ? 15 : 20),

          // 連線狀態列表
          ...pageData.connections.asMap().entries.map((entry) {
            int index = entry.key;
            EthernetConnection connection = entry.value;
            bool isLastItem = index == pageData.connections.length - 1;

            return Column(
              children: [
                _buildConnectionItem(connection, bottomInset),
                if (!isLastItem) _buildDivider(bottomInset),
              ],
            );
          }).toList(),

          // 鍵盤彈出時的額外空間
          if (bottomInset > 0)
            SizedBox(height: bottomInset * 0.5),
        ],
      ),
    );
  }

  // ==================== 空白分頁構建 ====================

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
              'No data available',
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

  // ==================== UI 元件構建方法 ====================

  Widget _buildSectionTitle(String title, double bottomInset) {
    return Text(
      title,
      style: TextStyle(
        fontSize: bottomInset > 0 ? 16 : 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildConnectionItem(EthernetConnection connection, double bottomInset) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: bottomInset > 0 ? 8 : 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            connection.speed,
            style: TextStyle(
              fontSize: bottomInset > 0 ? 14 : 16,
              color: Colors.white,
            ),
          ),
          Text(
            connection.status,
            style: TextStyle(
              fontSize: bottomInset > 0 ? 14 : 16,
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

// ==================== 資料模型類別 ====================

/// 乙太網路連線資料模型
class EthernetConnection {
  final String speed;    // 連線速度（如 "10Gbps", "1Gbps"）
  final String status;   // 連線狀態（如 "Connected", "Disconnect"）

  const EthernetConnection({
    required this.speed,
    required this.status,
  });

  // JSON 序列化支援
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

/// 乙太網路分頁資料模型
class EthernetPageData {
  final String pageTitle;                    // 分頁標題
  final List<EthernetConnection> connections; // 連線列表

  const EthernetPageData({
    required this.pageTitle,
    required this.connections,
  });

  // JSON 序列化支援
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