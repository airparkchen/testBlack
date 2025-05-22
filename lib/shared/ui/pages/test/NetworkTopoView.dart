import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'dart:async';
import 'package:whitebox/shared/theme/app_theme.dart';
import 'package:whitebox/shared/ui/components/basic/NetworkTopologyComponent.dart';
import 'package:whitebox/shared/ui/pages/test/DeviceDetailPage.dart';

class NetworkTopoView extends StatefulWidget {
  // 是否顯示測試控制器
  final bool showDeviceCountController;

  // 預設設備數量
  final int defaultDeviceCount;

  // 設備數據源 - 提供外部傳入設備列表的可能性
  final List<NetworkDevice>? externalDevices;

  // 設備連接數據源
  final List<DeviceConnection>? externalDeviceConnections;

  const NetworkTopoView({
    Key? key,
    this.showDeviceCountController = false, // 預設不顯示測試控制器
    this.defaultDeviceCount = 4, // 預設顯示4個設備
    this.externalDevices, // 允許外部傳入設備列表
    this.externalDeviceConnections, // 允許外部傳入連接數據
  }) : super(key: key);

  @override
  State<NetworkTopoView> createState() => _NetworkTopoViewState();
}

class _NetworkTopoViewState extends State<NetworkTopoView> with SingleTickerProviderStateMixin {
  // 視圖模式: 'topology' 或 'list'
  String _viewMode = 'topology';

  // 底部選項卡
  int _selectedBottomTab = 1; // 預設為中間的連線選項

  // 控制裝置數量的控制器(測試用)
  late final TextEditingController _deviceCountController;

  // 當前裝置數量
  late int _deviceCount;

  // 創建 AppTheme 實例
  final AppTheme _appTheme = AppTheme();

  // 速度數據生成器
  late SpeedDataGenerator _speedDataGenerator;

  // 用於動畫更新的計時器
  Timer? _updateTimer;

  // 動畫控制器
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    // 初始化設備數量
    _deviceCount = widget.defaultDeviceCount;

    // 初始化控制器
    _deviceCountController = TextEditingController(text: _deviceCount.toString());

    // 添加監聽器，當數量改變時更新視圖
    _deviceCountController.addListener(_handleDeviceCountChanged);

    // 初始化速度數據生成器
    _speedDataGenerator = SpeedDataGenerator(
      initialSpeed: 87,
      minSpeed: 20,
      maxSpeed: 150,
      dataPointCount: 100,
      smoothingFactor: 0.8,
    );

    // 初始化動畫控制器
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // 啟動數據更新計時器 - 每500毫秒更新一次
    _startDataUpdates();
  }

  // 啟動數據更新
  void _startDataUpdates() {
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) {
        setState(() {
          // 更新速度數據
          _speedDataGenerator.update();
        });

        // 重設並啟動動畫
        _animationController.reset();
        _animationController.forward();
      }
    });
  }

  // 處理設備數量變更
  void _handleDeviceCountChanged() {
    final newCount = int.tryParse(_deviceCountController.text) ?? 0;
    if (newCount != _deviceCount && newCount >= 0 && newCount <= 10) {
      setState(() {
        _deviceCount = newCount;
      });
    }
  }

  @override
  void dispose() {
    _deviceCountController.removeListener(_handleDeviceCountChanged);
    _deviceCountController.dispose();

    // 取消計時器
    _updateTimer?.cancel();

    // 釋放動畫控制器
    _animationController.dispose();

    super.dispose();
  }

  // 處理設備選擇
  void _handleDeviceSelected(NetworkDevice device) {
    // 獲取設備連接的子設備數量
    int connectionCount = 2; // 預設值
    bool isGateway = false;

    // 判斷是否為網關設備
    if (device.id == 'gateway') {
      isGateway = true;
      connectionCount = 4;
    } else {
      // 尋找該設備的連接數量
      try {
        if (widget.externalDeviceConnections != null) {
          final connection = widget.externalDeviceConnections!.firstWhere(
                  (conn) => conn.deviceId == device.id
          );
          connectionCount = connection.connectedDevicesCount;
        }
      } catch (e) {
        // 如果找不到連接信息，使用預設值
        connectionCount = 2;
      }
    }

    // 導航到設備詳情頁
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeviceDetailPage(
          device: device,
          connectedDevicesCount: connectionCount,
          isGateway: isGateway,
        ),
      ),
    );
  }

  // 處理視圖模式切換
  void _handleViewModeChanged(String mode) {
    if (mode != _viewMode) {
      setState(() {
        _viewMode = mode;
      });
    }
  }

  // 處理底部選項卡切換
  void _handleBottomTabChanged(int index) {
    setState(() {
      _selectedBottomTab = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent, // 確保 Scaffold 是透明的
      body: Container(
        // 設置背景圖片
        decoration: BackgroundDecorator.imageBackground(
          imagePath: AppBackgrounds.mainBackground, // 使用預設背景圖片
        ),
        child: Column(
          children: [
            // 裝置數量控制器 - 根據標誌決定是否顯示
            if (widget.showDeviceCountController)
              _buildDeviceCountController(),

            // 視圖切換選項卡 (與AppBar分開)
            SizedBox(height: screenSize.height * 0.08),
            _buildTabBar(),

            // 主要內容區域
            Expanded(
              flex: 5,
              child: _viewMode == 'topology'
                  ? _buildTopologyView()
                  : _buildListView(),
            ),

            // 調整間距 - 只在拓撲視圖模式下減少間距
            if (_viewMode == 'topology')
              const SizedBox(height: 5), // 這裡設置一個較小的間距，讓速度區域更靠近topology

            // 速度區域 (Speed Area) - 只在拓撲視圖模式下顯示
            if (_viewMode == 'topology')
              _buildSpeedArea(),

            // 底部導航欄
            _buildBottomNavBar(),
          ],
        ),
      ),
    );
  }

  // 構建裝置數量控制器
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
            onTap: () {
              if (_deviceCount > 0) {
                setState(() {
                  _deviceCount--;
                  _deviceCountController.text = _deviceCount.toString();
                });
              }
            },
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
            onTap: () {
              if (_deviceCount < 10) {
                setState(() {
                  _deviceCount++;
                  _deviceCountController.text = _deviceCount.toString();
                });
              }
            },
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

  // 構建選項卡
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 60, end: 60, top: 10, bottom: 5),
      height: 30,
      child: CustomPaint(
        painter: GradientBorderPainter(),
        child: Container(
          margin: const EdgeInsets.all(2), // 為邊框留出空間
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            color: Colors.transparent,
          ),
          child: Row(
            children: [
              // Topology 選項卡
              Expanded(
                child: GestureDetector(
                  onTap: () => _handleViewModeChanged('topology'),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _viewMode == 'topology'
                          ? const Color.fromRGBO(255, 255, 255, 0.15)
                          : Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(13),
                        bottomLeft: Radius.circular(13),
                      ),
                    ),
                    child: Text(
                      'Topology',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: _viewMode == 'topology' ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),

              // List 選項卡
              Expanded(
                child: GestureDetector(
                  onTap: () => _handleViewModeChanged('list'),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _viewMode == 'list'
                          ? const Color.fromRGBO(255, 255, 255, 0.15)
                          : Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(13),
                        bottomRight: Radius.circular(13),
                      ),
                    ),
                    child: Text(
                      'List',
                      style: TextStyle(
                        color: _viewMode == 'list'
                            ? const Color.fromRGBO(255, 255, 255, 0.8)
                            : Colors.white,
                        fontWeight: _viewMode == 'list' ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 獲取設備數據 - 從外部數據源或生成測試數據
  List<NetworkDevice> _getDevices() {
    // 如果提供了外部設備數據，優先使用
    if (widget.externalDevices != null && widget.externalDevices!.isNotEmpty) {
      return widget.externalDevices!;
    }

    // 否則生成測試數據
    List<NetworkDevice> dummyDevices = [];

    // 根據裝置數量生成設備
    for (int i = 0; i < _deviceCount; i++) {
      String name = '';
      String deviceType = '';

      // 創建與圖片相符的設備
      switch (i) {
        case 0:
          name = 'TV';
          deviceType = 'OWA813V_6G';
          break;
        case 1:
          name = 'Xbox';
          deviceType = 'Connected via Ethernet';
          break;
        case 2:
          name = 'Iphone';
          deviceType = 'OWA813V_6G';
          break;
        case 3:
          name = 'Laptop';
          deviceType = 'OWA813V_5G';
          break;
        default:
          name = '設備 ${i + 1}';
          deviceType = 'OWA813V_6G';
      }

      // 決定連接類型
      final isWired = (name == 'Xbox');

      final device = NetworkDevice(
        name: name,
        id: 'device-${i + 1}',
        mac: '48:21:0B:4A:47:9B', // 使用與圖片匹配的MAC地址
        ip: '192.168.1.164',      // 使用與圖片匹配的IP地址
        connectionType: isWired ? ConnectionType.wired : ConnectionType.wireless,
        additionalInfo: {
          'type': deviceType,
          'status': 'online',
        },
      );

      dummyDevices.add(device);
    }

    return dummyDevices;
  }

  // 獲取設備連接數據 - 從外部數據源或生成測試數據
  List<DeviceConnection> _getDeviceConnections(List<NetworkDevice> devices) {
    // 如果提供了外部連接數據，優先使用
    if (widget.externalDeviceConnections != null && widget.externalDeviceConnections!.isNotEmpty) {
      return widget.externalDeviceConnections!;
    }

    // 否則生成測試數據
    List<DeviceConnection> connections = [];

    // 為每個設備創建連接數據
    for (var device in devices) {
      connections.add(
        DeviceConnection(
          deviceId: device.id,
          connectedDevicesCount: 2,// 固定為2個連接設備 裝置連接數量
        ),
      );
    }

    return connections;
  }

  // 構建拓撲視圖 - 現在使用新的 Stack + Image.asset 組件
  Widget _buildTopologyView() {
    final screenSize = MediaQuery.of(context).size;

    // 獲取設備數據
    final devices = _getDevices();

    // 獲取設備連接數據
    final deviceConnections = _getDeviceConnections(devices);

    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 0),
      // 移除白色背景，使用透明背景
      color: Colors.transparent,
      child: Center(
        child: NetworkTopologyComponent(
          gatewayName: 'Controller',
          devices: devices,
          deviceConnections: deviceConnections,
          totalConnectedDevices: devices.length, // 主機上的數字顯示 數字標籤預設
          height: screenSize.height * 0.50,  // 調整高度為屏幕高度的50%
          onDeviceSelected: _handleDeviceSelected,
        ),
      ),
    );
  }

  // 構建列表視圖
  Widget _buildListView() {
    // 獲取設備數據
    List<NetworkDevice> devices = _getDevices();

    // 添加網關設備到列表最前方
    devices.insert(0, NetworkDevice(
      name: 'Controller',
      id: 'router-001',
      mac: '48:21:0B:4A:46:CF',
      ip: '192.168.1.1',
      connectionType: ConnectionType.wired,
      additionalInfo: {
        'type': 'router',
        'status': 'online',
        'uptime': '10天3小時',
      },
    ));

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: devices.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final device = devices[index];

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: index == 0 ? Colors.black : const Color(0xFF9747FF),
            child: Text(
              index == 0 ? '4' : '2',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          title: Text(
            device.name,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          subtitle: Text(
            '${device.ip} | ${device.mac}',
            style: const TextStyle(color: Colors.white70),
          ),
          trailing: Icon(
            device.connectionType == ConnectionType.wired
                ? Icons.lan
                : Icons.wifi,
            color: device.connectionType == ConnectionType.wired
                ? Colors.green
                : Colors.blue,
          ),
          onTap: () => _handleDeviceSelected(device),
        );
      },
    );
  }

  // 構建速度區域 (Speed Area)
  Widget _buildSpeedArea() {
    // 使用 MediaQuery 獲取確切的寬度，避免 double.infinity 造成的 NaN 錯誤
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      margin: const EdgeInsets.only(left: 3, right: 3, top: 0, bottom: 20),
      child: _appTheme.whiteBoxTheme.buildStandardCard(
        // 使用實際的寬度而不是 double.infinity
        width: screenWidth - 36, // 考慮水平邊距 3+3
        height: 160,
        child: Stack(
          clipBehavior: Clip.none, // 允許子元素溢出
          children: [
            // 速度曲線
            SpeedChartWidget(
              dataGenerator: _speedDataGenerator,
              animationController: _animationController,
              endAtPercent: 0.7, // 數據線在70%處結束
            ),
          ],
        ),
      ),
    );
  }

// 構建底部導航欄
  Widget _buildBottomNavBar() {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      margin: EdgeInsets.only(
        left: screenWidth * 0.145,     // 15%-85%
        right: screenWidth * 0.151,
        bottom: MediaQuery.of(context).size.height * 0.05,
      ),
      height: 70, // 增加高度
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
                top: 10, // 圓圈垂直居中
                child: _buildAnimatedCircle(),
              ),

              // 圖標行
              Row(
                children: [
                  // 左側 - 靠近左邊緣
                  Expanded(
                    flex: 1,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(left: 3), // 距離左邊緣15px
                        child: _buildBottomNavIconWithImage(0, 'assets/images/icon/dashboard.png', 35),
                      ),
                    ),
                  ),
                  // 中間連線圖標
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: _buildBottomNavIconWithImage(1, 'assets/images/icon/topohome.png', 35),
                    ),
                  ),

                  // 右側 - 靠近右邊緣
                  Expanded(
                    flex: 1,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: EdgeInsets.only(right: 3), // 距離右邊緣15px
                        child: _buildBottomNavIconWithImage(2, 'assets/images/icon/setting.png', 35),
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

// 計算圓圈位置 - 修正 barWidth 計算
  double _getCirclePosition() {
    final screenWidth = MediaQuery.of(context).size.width;
    final barWidth = screenWidth * 0.70; // 修正：bar的實際寬度 (100% - 15% * 2)
    final circleSize = 47.0; // 要與 _buildAnimatedCircle() 中的大小一致

    // Bar 的圓角半徑 (從 BottomNavBarPainter 中的設定)
    final barRadius = 35.0; // bar height (70) / 2

    // 計算圓圈與圓弧切齊時的位置
    final edgeDistance = barRadius - (circleSize / 2); // 圓圈中心距離邊緣的距離

    // 每個區域的寬度（三等分）
    final sectionWidth = barWidth / 3;

    // 計算中間位置
    final centerOffset = (sectionWidth - circleSize) / 2;

    switch (_selectedBottomTab) {
      case 0: // Dashboard - 與左側圓弧切齊
        return edgeDistance - 1.9; // 圓圈與左邊圓弧完美貼合
      case 1: // 中間 - 保持居中
        return sectionWidth + centerOffset;
      case 2: // Setting - 與右側圓弧切齊
        return barWidth - circleSize - edgeDistance -0.2; // 修正右側位置
      default:
        return sectionWidth + centerOffset; // 預設中間
    }
  }

// 構建會移動的圓圈
  Widget _buildAnimatedCircle() {
    return Container(
      width: 47,
      height: 47,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 發光效果
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.1),
                  const Color(0xFF9747FF).withOpacity(0.0),  //圓圈中心顏色模糊
                  Colors.transparent,
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
            ),
          ),

          // 漸變邊框圓圈
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

// 構建底部導航圖標
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
            opacity: isSelected ? 1.0 : 0.5,   //調整點擊透明/明亮程度
            child: Image.asset(
              imagePath,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                print('圖片載入失敗: $imagePath, 錯誤: $error');
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

// 獲取預設圖標
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


  // 構建底部導航項
  Widget _buildBottomNavItem(int index, String label) {
    final isSelected = index == _selectedBottomTab;

    return GestureDetector(
      onTap: () => _handleBottomTabChanged(index),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: isSelected ? Border.all(color: Colors.grey) : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

/// 速度數據生成器
/// 用於生成模擬的網絡速度數據
class SpeedDataGenerator {
  // 數據點的數量
  final int dataPointCount;

  // 最小速度值
  final double minSpeed;

  // 最大速度值
  final double maxSpeed;

  // 存儲生成的數據點
  final List<double> _speedData = [];

  // 存儲平滑後的數據點
  final List<double> _smoothedData = [];

  // 隨機數生成器
  final math.Random _random = math.Random();

  // 平滑係數 (0-1，值越大平滑效果越強)
  final double smoothingFactor;

  // 波動幅度 (值越大波動越明顯)
  final double fluctuationAmplitude;

  // 當前寬度比例
  double _currentWidthPercentage = 0.05; // 開始時只有5%的寬度

  // 目標寬度比例
  final double endAtPercent;

  // 每次更新增加的寬度比例
  final double growthRate;

  // 構造函數
  SpeedDataGenerator({
    this.dataPointCount = 100,  // 預設100個數據點
    this.minSpeed = 20,         // 預設最小速度 20 Mbps
    this.maxSpeed = 1000,        // 預設最大速度 150 Mbps
    double? initialSpeed,       // 初始速度值，可選
    this.smoothingFactor = 1, // 調整平滑係數，允許更多波動
    this.endAtPercent = 0.7,    // 默認目標寬度為70%
    this.growthRate = 0.01,     // 每次更新增加1%的寬度
    this.fluctuationAmplitude = 15.0, // 增加波動幅度，原來是6.0
  }) {
    // 初始化數據點
    final initialValue = initialSpeed ?? 87.0;  // 默認初始值為87

    // 初始只填入少量數據點
    for (int i = 0; i < 5; i++) {
      _speedData.add(initialValue);
      _smoothedData.add(initialValue);
    }
  }

  // 取得當前數據點列表的副本 (平滑處理後的)
  List<double> get data => List.from(_smoothedData);

  // 取得當前速度值 (最新的一筆資料)
  double get currentSpeed => _smoothedData.last;

  // 檢查是否已達到最大寬度
  bool isFullWidth() {
    return _currentWidthPercentage >= endAtPercent;
  }

  // 獲取當前寬度比例
  double getWidthPercentage() {
    return _currentWidthPercentage;
  }

  // 更新數據（添加新的數據點，移除最舊的）
  void update() {
    // 基於最後一個值生成新的速度值
    double newValue = _generateNextValue(_speedData.last);

    // 更新寬度
    if (_currentWidthPercentage < endAtPercent) {
      _currentWidthPercentage += growthRate;
      if (_currentWidthPercentage > endAtPercent) {
        _currentWidthPercentage = endAtPercent;
      }
    }

    // 如果已達到最大寬度，移除最舊的點
    if (_currentWidthPercentage >= endAtPercent && _speedData.length >= dataPointCount) {
      _speedData.removeAt(0);
      _smoothedData.removeAt(0);
    }

    // 添加新點
    _speedData.add(newValue);

    // 計算平滑值
    double smoothedValue;
    if (_smoothedData.isNotEmpty) {
      // 新值 = 前一個平滑值 * 平滑係數 + 當前實際值 * (1 - 平滑係數)
      smoothedValue = _smoothedData.last * smoothingFactor + newValue * (1 - smoothingFactor);
    } else {
      smoothedValue = newValue;
    }

    _smoothedData.add(smoothedValue);
  }

  // 生成下一個數據點
  double _generateNextValue(double currentValue) {
    // 生成較大幅度的隨機波動
    final double fluctuation = (_random.nextDouble() * fluctuationAmplitude * 2) - fluctuationAmplitude;

    // 計算新值
    double newValue = currentValue + fluctuation;

    // 有時添加一個更大的跳變，使曲線更有變化
    if (_random.nextDouble() < 0.1) { // 10%的機率產生較大變化
      newValue += (_random.nextDouble() * 20) - 10;
    }

    // 確保值在範圍內
    if (newValue < minSpeed) newValue = minSpeed;
    if (newValue > maxSpeed) newValue = maxSpeed;

    return newValue;
  }
}

/// 速度圖表小部件
/// 這是一個可重用的小部件，用於顯示速度曲線圖表
class SpeedChartWidget extends StatelessWidget {
  // 數據生成器
  final SpeedDataGenerator dataGenerator;

  // 動畫控制器
  final AnimationController animationController;

  // 曲線結束的位置（0.0-1.0，表示寬度的百分比）
  final double endAtPercent;

  // 構造函數
  const SpeedChartWidget({
    Key? key,
    required this.dataGenerator,
    required this.animationController,
    this.endAtPercent = 0.7,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double currentSpeed = dataGenerator.currentSpeed.round().toDouble();
    final int speedValue = currentSpeed.toInt();

    // 獲取當前寬度比例
    final double currentWidthPercentage = dataGenerator.getWidthPercentage();

    // 檢查是否已達到最大寬度
    final bool isFullWidth = currentWidthPercentage >= endAtPercent;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 取得實際寬度和高度
        final double actualWidth = constraints.maxWidth;
        final double actualHeight = constraints.maxHeight;

        // 檢查並確保使用有效的值
        if (actualWidth <= 0 || actualHeight <= 0) {
          return const SizedBox(); // 返回空小部件避免錯誤
        }

        // 這裡是關鍵修改：使用 currentWidthPercentage 而不是固定的 endAtPercent
        final double chartEndX = actualWidth * currentWidthPercentage;

        // 計算白點的位置 - 確保與曲線終點計算一致
        final double range = dataGenerator.maxSpeed - dataGenerator.minSpeed;
        final double normalizedValue = (currentSpeed - dataGenerator.minSpeed) / range;
        final double dotY = (1.0 - normalizedValue) * actualHeight;

        return Stack(
          clipBehavior: Clip.none, // 允許子元素溢出
          children: [
            // 速度曲線
            Positioned.fill(
              child: AnimatedBuilder(
                animation: animationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _SpeedCurvePainter(
                      speedData: dataGenerator.data,
                      minSpeed: dataGenerator.minSpeed,
                      maxSpeed: dataGenerator.maxSpeed,
                      animationValue: animationController.value,
                      endAtPercent: endAtPercent,
                      currentSpeed: currentSpeed,
                      currentWidthPercentage: currentWidthPercentage,
                      isFullWidth: isFullWidth,
                    ),
                    size: Size(actualWidth, actualHeight),
                  );
                },
              ),
            ),
            // 白點和垂直線只有在有數據時才顯示

            if (dataGenerator.data.isNotEmpty) ...[
              // 垂直線 (從底部到白點)
              Positioned(
                top: dotY + 8, // 白點底部
                bottom: 0,
                left: chartEndX - 1, // 考慮線寬
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

              // 當前速度標記 (白色圓圈)
              Positioned(
                top: dotY - 8, // 修正位置，減去圓的半徑
                left: chartEndX - 8, // 修正位置，減去圓的半徑
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
              Positioned(
                top: dotY - 50, // 在白點上方，考慮標籤高度和三角形
                left: chartEndX - 44, // 居中對齊白點
                child: _buildSpeedLabel(speedValue),
              ),
            ],
          ],
        );
      },
    );
  }

  // 構建速度標籤
  Widget _buildSpeedLabel(int speed) {
    return Stack(
      clipBehavior: Clip.none, // 允許子元素溢出
      children: [
        // 主體部分（圓角矩形）
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
                  '$speed Mb/s',
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

        // 底部三角形
        Positioned(
          bottom: -6, // 位於底部且稍微突出
          left: 0,
          right: 0,
          child: Center(
            child: ClipPath(
              clipper: _TriangleClipper(),
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

/// 三角形裁剪器
class _TriangleClipper extends CustomClipper<Path> {
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
class _SpeedCurvePainter extends CustomPainter {
  // 速度數據點列表
  final List<double> speedData;

  // 添加一個標記，表示是否已滿寬度
  final bool isFullWidth;

  // 當前數據寬度比例
  final double currentWidthPercentage;

  // 最小速度值（用於縮放）
  final double minSpeed;

  // 最大速度值（用於縮放）
  final double maxSpeed;

  // 動畫值
  final double animationValue;

  // 曲線結束的位置（0.0-1.0，表示寬度的百分比）
  final double endAtPercent;

  // 當前速度值
  final double currentSpeed;

  _SpeedCurvePainter({
    required this.speedData,
    required this.minSpeed,
    required this.maxSpeed,
    required this.animationValue,
    this.endAtPercent = 0.7,
    required this.currentSpeed,
    required this.isFullWidth,
    required this.currentWidthPercentage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 確保有數據可畫，並且尺寸有效
    if (speedData.isEmpty || size.width <= 0 || size.height <= 0) return;

    // 計算縮放比例
    final double range = maxSpeed - minSpeed;
    if (range <= 0) return; // 避免除以零錯誤

    // 創建路徑
    final path = Path();

    // 計算當前實際結束位置
    final double currentEndX = size.width * currentWidthPercentage;

    // 每個數據點之間的水平距離 - 根據數據點數量和當前寬度計算
    final double stepX = currentEndX / (speedData.length - 1);

    // 從左側開始繪製
    double x = 0; // 起點在左側

    // 收集點
    final List<Offset> points = [];

    // 繪製所有數據點
    for (int i = 0; i < speedData.length; i++) {
      // 計算Y座標
      final double normalizedValue = (speedData[i] - minSpeed) / range;
      final double y = size.height - (normalizedValue * size.height);

      // 添加點
      points.add(Offset(x, y));

      // 更新X座標
      x += stepX;
    }

    // 沒有足夠的點就直接返回
    if (points.length < 2) return;

    // 繪製路徑
    path.moveTo(points[0].dx, points[0].dy);

    // 使用貝茲曲線平滑連接點
    if (points.length > 2) {
      for (int i = 0; i < points.length - 2; i++) {
        final Offset current = points[i];
        final Offset next = points[i + 1];
        final Offset nextNext = points[i + 2];

        // 計算控制點
        final double controlX1 = current.dx + (next.dx - current.dx) * 0.5;
        final double controlY1 = current.dy;

        final double controlX2 = next.dx - (next.dx - current.dx) * 0.5;
        final double controlY2 = next.dy;

        // 使用三次貝茲曲線
        path.cubicTo(
            controlX1, controlY1,
            controlX2, controlY2,
            next.dx, next.dy
        );
      }

      // 連接最後兩個點
      path.lineTo(points[points.length - 1].dx, points[points.length - 1].dy);
    } else {
      // 只有兩個點，直接連線
      path.lineTo(points[1].dx, points[1].dy);
    }

    // 創建漸變色的畫筆
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF00EEFF),
          Color.fromRGBO(255, 255, 255, 0.5),
        ],
      ).createShader(Rect.fromLTWH(0, 0, currentEndX, size.height));

    // 創建發光效果的畫筆
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF00EEFF),
          Color.fromRGBO(255, 255, 255, 0.5),
        ],
      ).createShader(Rect.fromLTWH(0, 0, currentEndX, size.height))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    // 先繪製發光效果
    canvas.drawPath(path, glowPaint);

    // 再繪製主線條
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SpeedCurvePainter oldDelegate) {
    return oldDelegate.speedData != speedData ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.currentSpeed != currentSpeed;
  }
}
/// 漸變環形繪製器
class GradientRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 + 2; // 調整圓圈半徑

    // 創建垂直漸變（從上到下：白色到紫色）
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white,
        const Color(0xFF9747FF),
      ],
    );

    // 創建邊框畫筆
    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.stroke // 只繪製邊框
      ..strokeWidth = 2; // 邊框厚度

    // 繪製圓形邊框
    canvas.drawCircle(center, radius + 7, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 上方 TabBar 的漸變邊框繪製器
class GradientBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gradient = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Colors.white,
        Color.fromRGBO(255, 255, 255, 0.6),
      ],
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

/// 底部導航欄背景繪製器
class BottomNavBarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gradient = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        // Colors.white,
        Color.fromRGBO(255, 255, 255, 0.3),
        Color.fromRGBO(255, 255, 255, 0.3),   //調整底下bar的顏色
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