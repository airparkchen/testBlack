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

  // ==================== 分頁控制方法（簡化） ====================

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

    // 🎯 修正：WiFi 區域 - 標題與頻段項目不用橫線分隔
    firstPageConnections.add(EthernetConnection(
        speed: 'WiFi',
        status: '' // 空字符串表示標題
    ));

    // WiFi 頻率狀態列表（這些項目將使用居中排版）
    for (var freq in apiData.wifiFrequencies) {
      firstPageConnections.add(EthernetConnection(
          speed: freq.displayFrequency,
          status: freq.statusText
      ));
    }

    // Guest WiFi（如果啟用）
    if (DashboardConfig.showGuestWiFi && apiData.guestWifiFrequencies.isNotEmpty) {
      firstPageConnections.add(EthernetConnection(
          speed: 'Guest WiFi',
          status: ''
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

    final enabledWiFiSSIDs = apiData.wifiSSIDs.where((ssid) => ssid.isEnabled).toList();

    if (enabledWiFiSSIDs.isNotEmpty) {
      // 🎯 WiFi 標題
      secondPageConnections.add(EthernetConnection(
          speed: 'WiFi',
          status: '',
          connectionType: 'wifi_title' // 🔥 新增：標記這是WiFi標題
      ));

      // 🎯 各頻率的 SSID（使用特殊的 SSID 排版）
      for (var ssidInfo in enabledWiFiSSIDs) {
        secondPageConnections.add(EthernetConnection(
            speed: ssidInfo.ssidLabel, // 例如：SSID(2.4GHz)
            status: ssidInfo.ssid,      // 例如：OWA813V_2.4G
            connectionType: 'wifi_ssid' // 🔥 新增：標記這是WiFi SSID項目
        ));
      }
    }

    // Guest WiFi SSID（如果啟用）
    if (DashboardConfig.showGuestWiFi && apiData.guestWifiSSIDs.isNotEmpty) {
      final enabledGuestSSIDs = apiData.guestWifiSSIDs.where((ssid) => ssid.isEnabled).toList();

      if (enabledGuestSSIDs.isNotEmpty) {
        secondPageConnections.add(EthernetConnection(
            speed: 'Guest WiFi',
            status: '',
            connectionType: 'guest_wifi_title' // 🔥 新增：標記這是Guest WiFi標題
        ));

        for (var ssidInfo in enabledGuestSSIDs) {
          secondPageConnections.add(EthernetConnection(
              speed: ssidInfo.ssidLabel,
              status: ssidInfo.ssid,
              connectionType: 'guest_wifi_ssid' // 🔥 新增：標記這是Guest WiFi SSID項目
          ));
        }
      }
    }

    pages.add(EthernetPageData(
      pageTitle: "WiFi SSID",  // 🎯 明確標示這是 SSID 頁面
      connections: secondPageConnections,
    ));

    // ==================== 第三頁：Ethernet ====================
    pages.add(EthernetPageData(
      pageTitle: "Ethernet",
      connections: [], // 🎯 空的連接列表，只顯示標題
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

    final EdgeInsets contentPadding = EdgeInsets.fromLTRB(
        25,
        bottomInset > 0 ? 15 : 25,
        25,
        bottomInset > 0 ? 15 : 25
    );

    return FadeTransition(
      opacity: _fadeAnimation,
      child: _appTheme.whiteBoxTheme.buildStandardCard(
        width: cardWidth,
        height: cardHeight,
        child: _buildPageContent(contentPadding, bottomInset),
      ),
    );
  }

  // ==================== 修正：分頁內容構建（移除分頁指示器邏輯） ====================

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
          // 🎯 修正：根據頁面類型決定是否顯示內容
          if (pageData.pageTitle.contains("Ethernet")) ...[
            // 第三頁：只顯示 Ethernet 標題，其他內容隱藏
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
            // 第一頁和第二頁：顯示連接項目
            ...pageData.connections.asMap().entries.map((entry) {
              int index = entry.key;
              EthernetConnection connection = entry.value;
              bool isLastItem = index == pageData.connections.length - 1;

              // 🔥 修正：根據connectionType來決定排版方式
              String connectionType = connection.connectionType ?? '';
              bool isWiFiOrGuestTitle = connectionType == 'wifi_title' || connectionType == 'guest_wifi_title';
              bool isSSIDItem = connectionType == 'wifi_ssid' || connectionType == 'guest_wifi_ssid';
              bool needsDividerAfter = isWiFiOrGuestTitle; // 只有WiFi/Guest WiFi標題後需要橫線

              return Column(
                children: [
                  _buildConnectionItem(connection, bottomInset, index == 0),

                  // 🎯 關鍵：只在WiFi或Guest WiFi標題後加橫線
                  if (needsDividerAfter)
                    _buildDivider(bottomInset),

                  // 其他項目的間距處理
                  if (!isLastItem && !needsDividerAfter) ...[
                    if (pageData.pageTitle.contains("SSID"))
                      SizedBox(height: 2) // SSID頁面的小間距
                    else if (!_isWiFiRelatedItem(connection.speed))
                      _buildDivider(bottomInset) // 第一頁非WiFi項目的橫線
                    else
                      SizedBox(height: 2), // 第一頁WiFi項目的小間距
                  ],
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

  /// 🎯 新增：判斷是否為 WiFi 相關項目
  bool _isWiFiRelatedItem(String speed) {
    // WiFi 頻段相關項目：WiFi 標題、各頻段、Guest WiFi 標題等
    final wifiRelatedItems = [
      'WiFi', 'Guest WiFi',
      '2.4GHz', '5GHz', '6GHz', 'MLO'
    ];
    return wifiRelatedItems.contains(speed);
  }

  // ==================== 🔥 重寫：連接項目構建（完全重新設計） ====================

  /// 修正：連接項目構建，支援多種排版格式
  Widget _buildConnectionItem(EthernetConnection connection, double bottomInset, bool isFirstItem) {
    String connectionType = connection.connectionType ?? '';

    // 🔥 情況1：標題行（如 "WiFi", "Guest WiFi"）
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

    // 🔥 情況2：SSID項目（左上角標題，右下角SSID名稱）
    if (connectionType == 'wifi_ssid' || connectionType == 'guest_wifi_ssid') {
      return Padding(
        padding: EdgeInsets.only(
          top: bottomInset > 0 ? 12 : 15,
          bottom: bottomInset > 0 ? 12 : 15,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左上角：SSID 標題（如 "SSID(2.4GHz)"）
            Align(
              alignment: Alignment.center,
              child: Text(
                connection.speed,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
            SizedBox(height: 6),
            // 右下角：SSID 名稱
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                connection.status,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 🔥 情況3：單行項目（Model Name, Internet）
    if (_isSingleLineItem(connection.speed)) {
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
    }

    // 🔥 情況4：WiFi頻段項目（第一頁的 2.4GHz, 5GHz 等 - 頻段居中，狀態右對齊）
    return Padding(
      padding: EdgeInsets.symmetric(vertical: bottomInset > 0 ? 6 : 8),
      child: Row(
        children: [
          // 左側空間（讓頻段名稱看起來居中）
          Expanded(flex: 1, child: SizedBox()),

          // 中間：頻段名稱
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                connection.speed,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ),

          // 右側：狀態
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                connection.status,
                style: TextStyle(
                  fontSize: 16,
                  color: _getStatusColor(connection.status),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
            Text(
              'Page ${pageIndex + 1}',
              style: TextStyle(
                fontSize: bottomInset > 0 ? 16 : 18,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            SizedBox(height: 8),
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

  /// 獲取狀態顏色 不同狀態不同顏色
  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase();
    if (statusLower.contains('connect') && !statusLower.contains('disconnect')) {
      // return Colors.green.shade300;
      return Colors.white.withOpacity(0.7);
    } else if (statusLower.contains('on')) {
      // return Colors.green.shade300;
      return Colors.white.withOpacity(0.7);
    } else if (statusLower.contains('disconnect') || statusLower.contains('off')) {
      // return Colors.red.shade300;
      return Colors.white.withOpacity(0.7);
    } else {
      return Colors.white.withOpacity(0.7);
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

// ==================== 🔥 修正：資料模型類別（新增connectionType欄位） ====================

/// 乙太網路連線資料模型（新增connectionType欄位）
class EthernetConnection {
  final String speed;    // 連線速度或標籤名稱
  final String status;   // 連線狀態或內容
  final String? connectionType; // 🔥 新增：連接類型標記

  const EthernetConnection({
    required this.speed,
    required this.status,
    this.connectionType, // 🔥 新增可選參數
  });

  factory EthernetConnection.fromJson(Map<String, dynamic> json) {
    return EthernetConnection(
      speed: json['speed'] ?? '',
      status: json['status'] ?? 'Unknown',
      connectionType: json['connectionType'], // 🔥 新增從JSON讀取
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'speed': speed,
      'status': status,
      if (connectionType != null) 'connectionType': connectionType, // 🔥 新增到JSON
    };
  }

  @override
  String toString() {
    return 'EthernetConnection(speed: $speed, status: $status, connectionType: $connectionType)';
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