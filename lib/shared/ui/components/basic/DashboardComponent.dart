// lib/shared/ui/components/basic/DashboardComponent.dart - 保持原布局顯示LAN版本

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

  /// 🔥 修正：將新 API 資料轉換為 EthernetPageData 格式（保持原布局）
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
          connectionType: 'wifi_title' // 新增：標記這是WiFi標題
      ));

      // 🎯 各頻率的 SSID（使用特殊的 SSID 排版）
      for (var ssidInfo in enabledWiFiSSIDs) {
        secondPageConnections.add(EthernetConnection(
            speed: ssidInfo.ssidLabel, // 例如：SSID(2.4GHz)
            status: ssidInfo.ssid,      // 例如：OWA813V_2.4G
            connectionType: 'wifi_ssid' //新增：標記這是WiFi SSID項目
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

    // ==================== 🔥 修正：第三頁：Ethernet（保持原布局，恢復標題顯示） ====================
    final thirdPageConnections = <EthernetConnection>[];

    // 只轉換 LAN 埠資料，標題由 _buildEthernetPage 中的 _buildSectionTitle 處理

    // 🔥 將 LAN 埠資料轉換為連接項目（如果有的話）
    if (DashboardConfig.showEthernetDetails && apiData.lanPorts.isNotEmpty) {
      for (var lanPort in apiData.lanPorts) {
        thirdPageConnections.add(EthernetConnection(
            speed: lanPort.name,                    // LAN 埠名稱（如 "2.5Gbps"）
            status: lanPort.formattedStatus,        // 連接狀態（如 "Connected"）
            connectionType: 'ethernet_port'         // 🔥 標記為 Ethernet 埠項目
        ));
      }

      print('✅ 第三頁：添加了 ${apiData.lanPorts.length} 個 Ethernet 埠');
    } else {
      print('📋 第三頁：沒有 LAN 資料，將顯示空的 Ethernet 區域');
    }

    pages.add(EthernetPageData(
      pageTitle: "Ethernet",
      connections: thirdPageConnections,
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

  // ==================== 🔥 修正：頁面構建方法（整合Ethernet功能） ====================

  Widget _buildEthernetPage(
      EthernetPageData pageData,
      EdgeInsets contentPadding,
      double bottomInset
      ) {
    return Padding(
      padding: contentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔥 整合：第三頁 Ethernet 的完整處理（從檔案1恢復）
          if (pageData.pageTitle.contains("Ethernet")) ...[
            // 🔥 第三頁：顯示 Ethernet 標題
            _buildSectionTitle("Ethernet", bottomInset),

            // 🔥 加上橫線分隔（跟 WiFi 一樣）
            _buildDivider(bottomInset),

            // 🔥 根據是否有 LAN 資料決定顯示內容
            if (pageData.connections.isNotEmpty) ...[
              // 有 LAN 資料：顯示 LAN 埠列表（跟 WiFi 頻段一樣的排版）
              ...pageData.connections.map((connection) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: bottomInset > 0 ? 4 : 6),
                  child: Row(
                    children: [
                      // 左側空間（讓 LAN 埠名稱看起來居中）
                      Expanded(flex: 1, child: SizedBox()),

                      // 中間：LAN 埠名稱（如 "2.5Gbps"）
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

                      // 右側：連接狀態（如 "Connected"）
                      Expanded(
                        flex: 3,
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
              }).toList(),
            ] else ...[
              // 沒有 LAN 資料：顯示提示訊息
              SizedBox(height: 40),
              Center(
                child: Text(
                  'No LAN data available',
                  style: TextStyle(
                    fontSize: bottomInset > 0 ? 14 : 16,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ] else ...[
            // 🔥 第一頁和第二頁的處理（保持檔案2的新功能）
            ...pageData.connections.asMap().entries.map((entry) {
              int index = entry.key;
              EthernetConnection connection = entry.value;
              bool isLastItem = index == pageData.connections.length - 1;

              String connectionType = connection.connectionType ?? '';
              bool isWiFiOrGuestTitle = connectionType == 'wifi_title' || connectionType == 'guest_wifi_title';
              bool isSSIDItem = connectionType == 'wifi_ssid' || connectionType == 'guest_wifi_ssid';
              bool needsDividerAfter = isWiFiOrGuestTitle;

              // 🎯 判斷是否為最後一個SSID項目
              bool isLastSSIDItem = false;
              if (isSSIDItem) {
                isLastSSIDItem = true;
                // 檢查後面是否還有其他SSID項目
                for (int i = index + 1; i < pageData.connections.length; i++) {
                  String futureType = pageData.connections[i].connectionType ?? '';
                  if (futureType == 'wifi_ssid' || futureType == 'guest_wifi_ssid') {
                    isLastSSIDItem = false;
                    break;
                  }
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔥 使用修改後的構建方法
                  _buildConnectionItem(connection, bottomInset, index == 0, isLastSSIDItem),

                  // 原有的分隔線處理
                  if (needsDividerAfter)
                    _buildDivider(bottomInset),

                  if (!isLastItem && !needsDividerAfter && !isSSIDItem) ...[
                    if (pageData.pageTitle.contains("SSID"))
                      SizedBox(height: 2)
                    else if (!_isWiFiOrEthernetRelatedItem(connection.speed))
                      _buildDivider(bottomInset)
                    else
                      SizedBox(height: 2),
                  ],
                ],
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  /// 🎯 修正：判斷是否為 WiFi 或 Ethernet 相關項目
  bool _isWiFiOrEthernetRelatedItem(String speed) {
    // WiFi/Ethernet 相關項目：標題、各頻段、LAN埠等
    final relatedItems = [
      'WiFi', 'Guest WiFi', 'Ethernet',
      '2.4GHz', '5GHz', '6GHz', 'MLO',
      '2.5Gbps', '1Gbps', '10Gbps' // 常見的 Ethernet 速度
    ];
    return relatedItems.contains(speed) || speed.contains('Gbps') || speed.contains('Mbps');
  }

  // ==================== 🔥 重寫：連接項目構建（保持檔案2的新功能） ====================

  /// 🔥 修正：專門為第二頁SSID設計的雙行佈局項目
  Widget _buildSSIDItem(EthernetConnection connection, double bottomInset) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: bottomInset > 0 ? 8 : 10,  // 🎯 增加垂直間距因為是雙行
      ),
      width: double.infinity,  // 🎯 佔滿整個寬度（WiFi標題下方全部空間）
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,  // 🎯 整體左對齊
        children: [
          // 🎯 第一行：SSID(頻率) - 置左對齊
          Align(
            alignment: Alignment.centerLeft,  // 🎯 在整個空間內置左
            child: Text(
              connection.speed,  // 例如："SSID(2.4GHz)", "SSID(5GHz)", "SSID(6GHz)"
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.normal,
              ),
            ),
          ),

          SizedBox(height: 4),  // 🎯 兩行之間的間距

          // 🎯 第二行：實際SSID名稱 - 置右對齊
          Align(
            alignment: Alignment.centerRight,  // 🎯 在整個空間內置右
            child: Text(
              _formatSSIDNameOnly(connection.status),  // 🔥 只省略SSID名稱，不動頻率
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  /// 只處理SSID名稱的省略，保護頻率不被動到
  String _formatSSIDNameOnly(String ssidName) {
    if (ssidName.isEmpty) return ssidName;

    // 計算最大顯示長度
    // 根據您的需求：SSID名稱不能超過頻率標籤的起始位置
    // 假設 "SSID(2.4GHz)" 大約佔據 12 個字元寬度
    // 右側SSID應該不超過大約 15-16 個字元避免重疊
    const int maxSSIDLength = 16;

    if (ssidName.length <= maxSSIDLength) {
      return ssidName;  // 🎯 長度適中，完整顯示
    }

    // 智能省略：保留前面和後面，特別保護頻率後綴
    // 檢查是否有頻率後綴（如 _2.4G, _5G, _6G）
    final frequencyPattern = RegExp(r'_\d+\.?\d*G$');
    final match = frequencyPattern.firstMatch(ssidName);

    if (match != null) {
      // 🔥 有頻率後綴，要保護它
      final frequencySuffix = match.group(0)!;  // 例如 "_5G"
      final nameWithoutSuffix = ssidName.substring(0, match.start);

      // 計算可用空間（扣除後綴和省略號的長度）
      final availableLength = maxSSIDLength - frequencySuffix.length - 3; // 3 for "..."

      if (nameWithoutSuffix.length <= availableLength) {
        return ssidName;  // 即使有後綴也能完整顯示
      } else {
        // 省略中間部分，保留前面 + "..." + 頻率後綴
        final frontLength = (availableLength * 0.6).floor();  // 前面佔60%
        final frontPart = nameWithoutSuffix.substring(0, frontLength);
        return '$frontPart...$frequencySuffix';
        // 例如："Apple_Home_Network_5G" -> "Apple...5G"
      }
    } else {
      // 沒有頻率後綴，使用前後保留的省略方式
      const int frontChars = 8;   // 前面字元數
      const int backChars = 5;    // 後面字元數

      if (ssidName.length > frontChars + backChars + 3) {
        String frontPart = ssidName.substring(0, frontChars);
        String backPart = ssidName.substring(ssidName.length - backChars);
        return '$frontPart...$backPart';
        // 例如："VeryLongSSIDNameWithoutFreq" -> "VeryLong...tFreq"
      } else {
        // 長度不足以前後省略，直接截斷
        return '${ssidName.substring(0, maxSSIDLength - 3)}...';
      }
    }
  }

  /// 修正：連接項目構建，保持原有的排版格式
  Widget _buildConnectionItem(EthernetConnection connection, double bottomInset, bool isFirstItem, bool isLastSSID) {
    String connectionType = connection.connectionType ?? '';

    // 標題行處理
    if (connection.status.isEmpty || connectionType.contains('title')) {
      return Padding(
        padding: EdgeInsets.only(
          top: isFirstItem ? 0 : (bottomInset > 0 ? 8 : 10),
          bottom: bottomInset > 0 ? 4 : 6,
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

    // 🔥 SSID項目：兩行顯示 + 條件性橫線
    if (connectionType == 'wifi_ssid' || connectionType == 'guest_wifi_ssid') {
      return Container(
        margin: EdgeInsets.only(
          left: 50,  // 不超過 WiFi 標題
          right: 0,
          top: bottomInset > 0 ? 6 : 8,
          bottom: isLastSSID ? (bottomInset > 0 ? 6 : 8) : 0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 第一行：SSID頻率標題（置左）
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                connection.speed,  // "SSID(2.4GHz)"
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),

            // 行間距
            SizedBox(height: 6),

            // 第二行：實際SSID名稱（置右）
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                connection.status, // 直接顯示完整SSID，不再使用省略處理
                style: TextStyle(
                  fontSize: _getSSIDFontSize(connection.status), // 動態字體大小
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.visible, // 或改為 TextOverflow.ellipsis 作為最後保險
              ),
            ),

            // 🔥 條件性橫線：只有不是最後一個SSID才顯示
            if (!isLastSSID) ...[
              SizedBox(height: 8),
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withOpacity(0.1),
                indent: 0,
                endIndent: 0,
              ),
            ],
          ],
        ),
      );
    }

    // 其他項目處理（保持原有邏輯）
    if (_isSingleLineItem(connection.speed)) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: bottomInset > 0 ? 4 : 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              connection.speed,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              connection.status,
              style: TextStyle(fontSize: 16, color: _getStatusColor(connection.status), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    // WiFi頻段項目（第一頁用）
    return Padding(
      padding: EdgeInsets.symmetric(vertical: bottomInset > 0 ? 2 : 4),
      child: Row(
        children: [
          Expanded(flex: 1, child: SizedBox()),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                connection.speed,
                style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.normal),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                connection.status,
                style: TextStyle(fontSize: 16, color: _getStatusColor(connection.status), fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getSSIDFontSize(String ssid) {
    final length = ssid.length;

    if (length <= 20) {
      return 16.0; // 標準大小
    } else if (length <= 25) {
      return 14.0; // 中等長度，稍微縮小
    } else if (length <= 32) {
      return 12.0; // 較長，更小字體
    } else {
      return 10.0; // 非常長，最小字體
    }
  }

  /// 🎯 新增：格式化SSID，限制長度並加上省略號
  String _formatSSIDWithSmartEllipsis(String ssid) {
    if (ssid.isEmpty) return ssid;

    const int maxDisplayLength = 22;

    if (ssid.length <= maxDisplayLength) {
      return ssid;
    }

    // 智能識別頻率後綴
    String frequencySuffix = _extractFrequencySuffix(ssid);

    if (frequencySuffix.isNotEmpty) {
      int remainingLength = maxDisplayLength - frequencySuffix.length - 3;
      if (remainingLength > 3) {
        String prefix = ssid.substring(0, remainingLength);
        return '$prefix...$frequencySuffix';
      }
    }

    // 常規省略
    const int frontChars = 12;
    const int backChars = 6;

    if (ssid.length > frontChars + backChars + 3) {
      String frontPart = ssid.substring(0, frontChars);
      String backPart = ssid.substring(ssid.length - backChars);
      return '$frontPart...$backPart';
    } else {
      return '${ssid.substring(0, maxDisplayLength - 3)}...';
    }
  }

  /// 🎯 提取頻率後綴（支援各種頻率格式，為未來擴展做準備）
  String _extractFrequencySuffix(String ssid) {
    final frequencyPatterns = [
      '_2.4G', '_5G', '_6G', '_MLO',
      '_2G', '_5GHz', '_6GHz',
      '2.4G', '5G', '6G', 'MLO',
      '2.4GHz', '5GHz', '6GHz',
    ];

    for (String pattern in frequencyPatterns) {
      if (ssid.endsWith(pattern)) {
        return pattern;
      }
    }

    final RegExp frequencyRegex = RegExp(r'[_]?([\d\.]+G(?:Hz)?|MLO)$', caseSensitive: false);
        final match = frequencyRegex.firstMatch(ssid);
    if (match != null) {
      return match.group(0) ?? '';
    }

    return '';
  }

  /// 判斷是否為單行項目
  bool _isSingleLineItem(String speed) {
    return speed == 'Model Name' || speed == 'Internet';
  }

  /// 🎯 獲取狀態顏色
  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase();
    if (statusLower.contains('connect') && !statusLower.contains('disconnect')) {
      return Colors.white.withOpacity(0.7);
    } else if (statusLower.contains('on')) {
      return Colors.white.withOpacity(0.7);
    } else if (statusLower.contains('disconnect') || statusLower.contains('off')) {
      return Colors.white.withOpacity(0.7);
    } else {
      return Colors.white.withOpacity(0.7);
    }
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

  Widget _buildDivider(double bottomInset) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: bottomInset > 0 ? 2 : 4),
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