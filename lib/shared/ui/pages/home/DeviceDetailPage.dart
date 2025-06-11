// lib/shared/ui/pages/home/TestDeviceDetailPage.dart - 修正版本

import 'package:flutter/material.dart';
import 'package:whitebox/shared/ui/components/basic/NetworkTopologyComponent.dart';
import 'package:whitebox/shared/theme/app_theme.dart';
import 'package:whitebox/shared/services/real_data_integration_service.dart';
import 'package:whitebox/shared/ui/pages/home/Topo/network_topo_config.dart';

/// 設備詳情頁面
class DeviceDetailPage extends StatefulWidget {
  /// 選中的設備（Gateway 或 Agent）
  final NetworkDevice selectedDevice;

  /// 是否為網關設備
  final bool isGateway;

  /// 連接的客戶端列表（將來從 Mesh API 取得）
  final List<ClientDevice>? connectedClients;
  final bool showBottomNavigation;
  final VoidCallback? onBack;

  const DeviceDetailPage({
    Key? key,
    required this.selectedDevice,
    this.isGateway = false,
    this.connectedClients,
    this.showBottomNavigation = true,
    this.onBack,
  }) : super(key: key);

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  final AppTheme _appTheme = AppTheme();

  // 修改：設為可變的列表，初始為空
  List<ClientDevice> _clientDevices = [];

  // 新增：載入狀態
  bool _isLoadingClients = true;

  @override
  void initState() {
    super.initState();
    _loadClientDevices();
  }

  /// 修改：異步載入客戶端設備資料
  Future<void> _loadClientDevices() async {
    if (!mounted) return;

    setState(() {
      _isLoadingClients = true;
    });

    try {
      List<ClientDevice> clientDevices;

      if (NetworkTopoConfig.useRealData) {
        // 使用真實數據
        final deviceId = _generateDeviceId(widget.selectedDevice.mac);
        clientDevices = await RealDataIntegrationService.getClientDevicesForParent(deviceId);
        print('✅ 載入真實客戶端數據: ${clientDevices.length} 個設備');
      } else {
        // 使用假數據
        clientDevices = widget.connectedClients ?? _generateFakeClientData();
        print('🎭 使用假客戶端數據: ${clientDevices.length} 個設備');
      }

      if (mounted) {
        setState(() {
          _clientDevices = clientDevices;
          _isLoadingClients = false;
        });
      }
    } catch (e) {
      print('❌ 載入客戶端設備時發生錯誤: $e');
      if (mounted) {
        setState(() {
          // 發生錯誤時使用假數據
          _clientDevices = _generateFakeClientData();
          _isLoadingClients = false;
        });
      }
    }
  }

  /// 新增：生成設備 ID 的方法
  String _generateDeviceId(String macAddress) {
    return 'device-${macAddress.replaceAll(':', '').toLowerCase()}';
  }

  /// 生成假資料（開發用） - 保留原始方法
  List<ClientDevice> _generateFakeClientData() {
    return [
      ClientDevice(
        name: 'TV',
        deviceType: 'OWA813V_6G',
        mac: '48:21:0B:4A:47:9B',
        ip: '192.168.1.164',
        connectionTime: '1d/22h/22m/12s',
        clientType: ClientType.tv,
      ),
      ClientDevice(
        name: 'Xbox',
        deviceType: 'Connected via Ethernet',
        mac: '48:21:0B:4A:47:9B',
        ip: '192.168.1.164',
        connectionTime: '1d/22h/22m/12s',
        clientType: ClientType.xbox,
      ),
      ClientDevice(
        name: 'Iphone',
        deviceType: 'OWA813V_6G',
        mac: '48:21:0B:4A:47:9B',
        ip: '192.168.1.164',
        connectionTime: '1d/22h/22m/12s',
        clientType: ClientType.iphone,
      ),
      ClientDevice(
        name: 'Laptop',
        deviceType: 'OWA813V_5G',
        mac: '48:21:0B:4A:47:9B',
        ip: '192.168.1.164',
        connectionTime: '1d/22h/22m/12s',
        clientType: ClientType.laptop,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BackgroundDecorator.imageBackground(
          imagePath: AppBackgrounds.mainBackground,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 頂部區域：RSSI + 返回按鈕
              _buildTopArea(),

              // 設備主要資訊區域
              _buildDeviceInfoArea(),

              // 客戶端列表區域
              Expanded(
                child: _buildClientListArea(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🎯 修正：建構頂部區域 - 三段式 RSSI 顏色顯示
// 改進的 RSSI 顯示方法

  /// 🎯 修正：建構頂部區域 - 三段式 RSSI 顏色顯示
  Widget _buildTopArea() {
    // 解析 RSSI 數據
    final rssiData = _parseRSSIData(widget.selectedDevice.additionalInfo['rssi']);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 返回按鈕（較低層級）
          Positioned(
            left: 5,
            top: -9,
            bottom: 0,
            child: GestureDetector(
              onTap: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else {
                  Navigator.of(context).pop();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.transparent,
                child: Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),

          // 🎯 修正：三段式 RSSI 顯示
          Align(
            alignment: Alignment.topCenter, // 在頂部區域中心
            child: Padding(
              padding: const EdgeInsets.only(top: 1), // 距離頂部的偏移
              child: Container(
                width: 175,
                height: 35, // 🎯 現在可以自由調整高度，中心位置不變
                decoration: BoxDecoration(
                  color: rssiData.color,
                  borderRadius: BorderRadius.circular(12.5), // 🎯 圓角 = height/2
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    rssiData.displayText,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14, // 🎯 對應調整字體大小
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🎯 修正：RSSI 數據解析 - 簡化為三段式顏色和指定格式
  RSSIDisplayData _parseRSSIData(dynamic rssiValue) {
    try {
      if (rssiValue == null) {
        return RSSIDisplayData(
          displayText: 'RSSI : N/A',
          color: const Color(0xFFFF6D2F), // 橙色（最差）
          quality: 'Unknown',
          primaryValue: -100,
        );
      }

      String rssiString = rssiValue.toString();
      List<int> rssiValues = [];

      // 解析不同格式的 RSSI
      if (rssiString.contains(',')) {
        // 多頻段格式："0,-22,-19"
        rssiValues = rssiString.split(',')
            .map((s) => int.tryParse(s.trim()) ?? 0)
            // .where((v) => v != 0) // 過濾掉 0 值
            .toList();
      } else {
        // 單一數值格式：-35
        int singleValue = int.tryParse(rssiString) ?? 0;
        if (singleValue != 0) {
          rssiValues.add(singleValue);
        }
      }

      // 如果沒有有效的 RSSI 值（例如以太網路）
      if (rssiValues.isEmpty) {
        return RSSIDisplayData(
          // displayText: 'RSSI : Ethernet',
          displayText: 'RSSI : ',
          color: const Color(0xFF2AFFC3), // 綠色（最佳）
          quality: 'Wired',
          primaryValue: 0,
        );
      }

      // 🎯 按照您的需求格式化顯示：只顯示兩個主要數值
      String displayText;
      if (rssiValues.length >= 2) {
        // 取前兩個數值：RSSI : -35,-16
        displayText = 'RSSI : ${rssiValues[0]},${rssiValues[1]},${rssiValues[2]}';
      } else if (rssiValues.length == 1) {
        // 只有一個數值：RSSI : -35
        displayText = 'RSSI : ${rssiValues[0]}';
      } else {
        displayText = 'RSSI : N/A';
      }

      // 取最強的信號作為顏色判斷依據（數值最大的，因為 RSSI 是負數）
      int bestRSSI = rssiValues.reduce((a, b) => a > b ? a : b);

      // 🎯 三段式顏色判斷
      Color rssiColor = _getThreeStageRSSIColor(bestRSSI);

      return RSSIDisplayData(
        displayText: displayText,
        color: rssiColor,
        quality: _getRSSIQualityLabel(bestRSSI),
        primaryValue: bestRSSI,
      );

    } catch (e) {
      print('解析 RSSI 時發生錯誤: $e');
      return RSSIDisplayData(
        displayText: 'RSSI : Error',
        color: const Color(0xFFFF6D2F), // 橙色（錯誤）
        quality: 'Error',
        primaryValue: -100,
      );
    }
  }

  /// 🎯 新增：三段式 RSSI 顏色判斷
  Color _getThreeStageRSSIColor(int rssi) {
    if (rssi >= -60) {
      // 優秀區段：-60 以上
      return const Color(0xFF2AFFC3); // 您指定的綠色
    } else if (rssi >= -75) {
      // 中等區段：-60 to -75
      return const Color(0xFFFFE448); // 您指定的黃色
    } else {
      // 較差區段：-75 以下
      return const Color(0xFFFF6D2F); // 您指定的橙色
    }
  }

  /// 🎯 新增：簡化的品質標籤
  String _getRSSIQualityLabel(int rssi) {
    if (rssi >= -60) {
      return 'Good';
    } else if (rssi >= -75) {
      return 'Fair';
    } else {
      return 'Poor';
    }
  }

  /// 建構設備主要資訊區域
  Widget _buildDeviceInfoArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 設備圖標（參考 NetworkTopologyComponent 的樣式）
          _buildDeviceIcon(),

          const SizedBox(width: 24),

          // 設備資訊
          Expanded(
            child: _buildDeviceInfo(),
          ),
        ],
      ),
    );
  }

  /// 建構設備圖標（白色圓圈 + 透明背景 + 圖標 + 右下角數字標籤）
  Widget _buildDeviceIcon() {
    final iconSize = widget.isGateway ? 60.0 : 50.0;
    final containerSize = widget.isGateway ? 100.0 : 80.0;
    final clientCount = _clientDevices.length;

    return Container(
      width: containerSize,
      height: containerSize,
      child: Stack(
        children: [
          // 主要圓形圖標
          Container(
            width: containerSize,
            height: containerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              color: Colors.transparent,
            ),
            child: Center(
              child: widget.isGateway
                  ? Image.asset(
                'assets/images/icon/router.png',
                width: iconSize,
                height: iconSize,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.router,
                    color: Colors.white,
                    size: iconSize * 0.6,
                  );
                },
              )
                  : ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.white.withOpacity(1.0),
                  BlendMode.srcIn,
                ),
                child: Image.asset(
                  'assets/images/icon/mesh.png',
                  width: iconSize,
                  height: iconSize,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.lan,
                      color: Colors.white.withOpacity(0.8),
                      size: iconSize * 0.6,
                    );
                  },
                ),
              ),
            ),
          ),

          // 右下角紫色數字標籤
          if (clientCount > 0)
            Positioned(
              right: containerSize * 0.01,
              bottom: containerSize * 0.05,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Color(0xFF9747FF),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Center(
                  child: Text(
                    clientCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 建構設備資訊文字
  Widget _buildDeviceInfo() {
    // 根據設備類型動態生成名稱
    final bool isGatewayDevice = widget.selectedDevice.additionalInfo['type'] == 'gateway';

    String deviceName;
    if (isGatewayDevice) {
      deviceName = 'Controller';
    } else {
      deviceName = widget.selectedDevice.name;
    }

    final clientCount = _clientDevices.length;

    return Expanded( // 🎯 使用 Expanded 防止溢出
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // NAME 標籤
          Text(
            'NAME',
            style: TextStyle(
              color: Colors.white.withOpacity(1.0),
              fontSize: 12, // 🎯 減小字體
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),

          // 設備名稱 + MAC - 防止溢出
          Text(
            '$deviceName ${_formatMacAddress(widget.selectedDevice.mac)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11, // 🎯 減小字體
              fontWeight: FontWeight.normal,
              height: 1.3,
            ),
            maxLines: 2, // 🎯 允許兩行
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // 客戶端數量
          Text(
            'Clients: $clientCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11, // 🎯 減小字體
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  /// 修改：建構客戶端列表區域（加入載入狀態）
  Widget _buildClientListArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRect(
            child: Padding(
              padding: const EdgeInsets.only(top: 0, bottom: 0),
              child: _isLoadingClients
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      '載入客戶端設備中...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              )
                  : _clientDevices.isEmpty
                  ? const Center(
                child: Text(
                  '沒有連接的設備',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              )
                  : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 16),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _clientDevices.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final client = _clientDevices[index];
                  return _buildClientCard(client);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// 建構單個客戶端卡片
  Widget _buildClientCard(ClientDevice client) {
    return _appTheme.whiteBoxTheme.buildStandardCard(
      width: double.infinity,
      height: 120,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: IntrinsicHeight( // 🎯 新增這行
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch, // 🎯 確保是 stretch
            children: [
              // 左側：圖標 + 連線時間 - 使用約束置中
              _buildClientIcon(client),

              const SizedBox(width: 16),

              // 右側：客戶端資訊 - 使用 Expanded 防止溢出
              Expanded(
                child: _buildClientInfo(client),
              ),
            ],
          ), // 🎯 新增這行關閉 IntrinsicHeight
        ),
      ),
    );
  }

  /// 建構客戶端圖標 + 連線時間
  /// 🎯 修正：建構客戶端圖標，使用約束方法完美置中
  Widget _buildClientIcon(ClientDevice client) {
    return SizedBox(
      width: 60, // 🎯 固定寬度
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // 🎯 垂直置中
        crossAxisAlignment: CrossAxisAlignment.center, // 🎯 水平置中
        children: [
          // 圖標容器 - 使用約束確保完美置中
          Container(
            width: 50, // 🎯 固定圖標容器大小
            height: 50,
            alignment: Alignment.center, // 🎯 容器內容置中
            child: Image.asset(
              _getClientIconPath(client.clientType),
              width: 50,
              height: 50,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  _getClientFallbackIcon(client.clientType),
                  color: Colors.white.withOpacity(0.8),
                  size: 30,
                );
              },
            ),
          ),

          const SizedBox(height: 8), // 🎯 固定間距

          // 連線時間 - 約束寬度防止溢出
          SizedBox(
            width: 60, // 🎯 約束文字寬度
            child: Text(
              client.connectionTime,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 9,
                height: 1.2, // 🎯 設定行高確保一致性
              ),
              textAlign: TextAlign.center, // 🎯 文字置中
              maxLines: 2, // 🎯 允許兩行以防文字過長
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 建構客戶端資訊
  Widget _buildClientInfo(ClientDevice client) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start, // 🎯 改為頂部對齊
      children: [
        // 設備名稱 - 防止溢出
        Text(
          client.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            height: 1.3,
          ),
          maxLines: 1, // 🎯 限制行數
          overflow: TextOverflow.ellipsis, // 🎯 超出顯示省略號
        ),
        const SizedBox(height: 4),

        // 網路類型 - 使用 SSID_頻段 格式
        Text(
          _formatConnectionDisplay(client), // 🎯 使用新的格式化方法
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
            height: 1.3,
          ),
          maxLines: 1, // 🎯 限制行數
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),

        // MAC 地址 - 使用較小字體
        Text(
          'MAC: ${_formatMacAddress(client.mac)}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 11, // 🎯 減小字體
            height: 1.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),

        // IP 地址
        Text(
          'IP: ${client.ip}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 11, // 🎯 減小字體
            height: 1.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        // 🎯 如果有額外資訊，顯示 Wi-Fi 標準
        if (client.additionalInfo?['wirelessStandard'] != null &&
            client.additionalInfo!['wirelessStandard'].toString().isNotEmpty) ...[
          const SizedBox(height: 4),
          // Text(
          //   _formatWifiStandard(client.additionalInfo!['wirelessStandard'].toString()),
          //   style: TextStyle(
          //     color: Colors.white.withOpacity(0.7),
          //     fontSize: 10, // 🎯 最小字體
          //   ),
          //   maxLines: 1,
          //   overflow: TextOverflow.ellipsis,
          // ),
        ],
      ],
    );
  }

  /// 🎯 修正：格式化連接類型為 SSID_頻段 格式
  String _formatConnectionType(String connectionType) {
    // 先嘗試從 additionalInfo 中獲取 SSID 和頻段資訊
    // 這個方法會在 _buildClientCard 中傳入 client 物件時使用
    return connectionType; // 這裡先保持原樣，在下面新增專門方法
  }

  /// 🎯 新增：專門格式化連接顯示為 SSID_頻段 格式
  String _formatConnectionDisplay(ClientDevice client) {
    try {
      // 1. 獲取 SSID（從 additionalInfo 或 connectionType 中提取）
      String ssid = '';
      if (client.additionalInfo?['ssid'] != null &&
          client.additionalInfo!['ssid'].toString().isNotEmpty) {
        ssid = client.additionalInfo!['ssid'].toString();
      } else {
        // 從 deviceType 中提取 SSID，例如 "WiFi 5GHz 連接 (SSID: Parker_test)"
        final ssidMatch = RegExp(r'SSID:\s*([^)]+)').firstMatch(client.deviceType);
        if (ssidMatch != null) {
          ssid = ssidMatch.group(1)?.trim() ?? '';
        }
      }

      // 2. 獲取頻段資訊
      String frequency = '';

      // 從 radio 欄位獲取頻段（優先）
      if (client.additionalInfo?['radio'] != null) {
        final radio = client.additionalInfo!['radio'].toString();
        if (radio.contains('6G')) {
          frequency = '6G';
        } else if (radio.contains('5G')) {
          frequency = '5G';
        } else if (radio.contains('2.4G')) {
          frequency = '2.4G';
        }
      }

      // 如果 radio 沒有資訊，從 deviceType 中提取
      if (frequency.isEmpty) {
        if (client.deviceType.contains('6GHz')) {
          frequency = '6G'; // Wi-Fi 6E (802.11ax)
        } else if (client.deviceType.contains('5GHz')) {
          frequency = '5G'; // Wi-Fi 5 (802.11ac) 或 Wi-Fi 6 (802.11ax)
        } else if (client.deviceType.contains('2.4GHz')) {
          frequency = '2.4G'; // Wi-Fi 4 (802.11n) 或更早
        }
      }

      // 3. 特殊情況：Ethernet 連接
      if (client.deviceType.contains('Ethernet') || client.deviceType.contains('ethernet')) {
        return 'Ethernet'; // 有線連接直接顯示 Ethernet
      }

      // 4. 組合 SSID_頻段 格式
      if (ssid.isNotEmpty && frequency.isNotEmpty) {
        return '${ssid}_${frequency}'; // 例如：ParkerTest_5G
      } else if (ssid.isNotEmpty) {
        return ssid; // 只有 SSID
      } else if (frequency.isNotEmpty) {
        return '${frequency} WiFi'; // 只有頻段
      }

      // 5. 備用方案：簡化原始 deviceType
      String fallback = client.deviceType;
      if (fallback.contains('SSID:')) {
        fallback = fallback.split('(SSID:')[0].trim();
      }

      if (fallback.length > 15) {
        fallback = fallback.substring(0, 12) + '...';
      }

      return fallback.isNotEmpty ? fallback : 'WiFi';

    } catch (e) {
      print('⚠️ 格式化連接顯示時發生錯誤: $e');
      return 'WiFi'; // 錯誤時的預設值
    }
  }

  /// 🎯 新增：格式化 MAC 地址，截短顯示
  String _formatMacAddress(String mac) {
    //MAC address截斷 顯示部份
    // if (mac.length <= 12) return mac;
    //
    // // 顯示前 3 組和後 2 組，中間用 ... 代替
    // // 例如：a2:08:5f:...:a2:d7
    // final parts = mac.split(':');
    // if (parts.length >= 5) {
    //   return '${parts[0]}:${parts[1]}:${parts[2]}:...${parts[parts.length-2]}:${parts[parts.length-1]}';
    // }

    return mac;
  }

  /// 🎯 修正：格式化 Wi-Fi 標準顯示（程式備註保留商用名稱）
  // String _formatWifiStandard(String standard) {
  //   // Wi-Fi 標準對應表（商用名稱）
  //   final Map<String, String> standardMap = {
  //     'ax': 'Wi-Fi 6',    // 802.11ax - Wi-Fi 6/6E (2019年)
  //     'ac': 'Wi-Fi 5',    // 802.11ac - Wi-Fi 5 (2013年)
  //     'n': 'Wi-Fi 4',     // 802.11n - Wi-Fi 4 (2009年)
  //     'g': 'Wi-Fi 3',     // 802.11g - Wi-Fi 3 (2003年)
  //     'a': 'Wi-Fi 2',     // 802.11a - Wi-Fi 2 (1999年)
  //     'b': 'Wi-Fi 1',     // 802.11b - Wi-Fi 1 (1999年)
  //   };
  //
  //   final cleanStandard = standard.toLowerCase().trim();
  //
  //   // 返回對應的商用名稱，例如：Wi-Fi 6 (ax)、Wi-Fi 5 (ac)
  //   final commercialName = standardMap[cleanStandard];
  //   if (commercialName != null) {
  //     return '$commercialName ($cleanStandard)'; // 例如："Wi-Fi 6 (ax)"
  //   }
  //
  //   return 'Wi-Fi $standard'; // 未知標準的備用顯示
  // }


  /// 根據客戶端類型取得圖標路徑
  String _getClientIconPath(ClientType type) {
    switch (type) {
      case ClientType.tv:
        return 'assets/images/icon/TV.png';
      case ClientType.xbox:
        return 'assets/images/icon/Xbox.png';
      case ClientType.iphone:
        return 'assets/images/icon/iPhone.png';
      case ClientType.laptop:
        return 'assets/images/icon/laptop.png';
      default:
        return 'assets/images/icon/device.png';
    }
  }

  /// 根據客戶端類型取得後備圖標
  IconData _getClientFallbackIcon(ClientType type) {
    switch (type) {
      case ClientType.tv:
        return Icons.tv;
      case ClientType.xbox:
        return Icons.games;
      case ClientType.iphone:
        return Icons.phone_iphone;
      case ClientType.laptop:
        return Icons.laptop;
      default:
        return Icons.device_unknown;
    }
  }
}

/// 客戶端設備類型枚舉
enum ClientType {
  tv,
  xbox,
  iphone,
  laptop,
}

/// 客戶端設備資料類（預留 API 結構）
class ClientDevice {
  final String name;
  final String deviceType;
  final String mac;
  final String ip;
  final String connectionTime;
  final ClientType clientType;

  // 預留 API 欄位
  final String? rssi;
  final String? status;
  final DateTime? lastSeen;
  final Map<String, dynamic>? additionalInfo;

  ClientDevice({
    required this.name,
    required this.deviceType,
    required this.mac,
    required this.ip,
    required this.connectionTime,
    required this.clientType,
    this.rssi,
    this.status,
    this.lastSeen,
    this.additionalInfo,
  });

  /// 從 API JSON 創建實例（預留方法）
  factory ClientDevice.fromJson(Map<String, dynamic> json) {
    return ClientDevice(
      name: json['name'] ?? '',
      deviceType: json['deviceType'] ?? '',
      mac: json['mac'] ?? '',
      ip: json['ip'] ?? '',
      connectionTime: json['connectionTime'] ?? '',
      clientType: _parseClientType(json['type']),
      rssi: json['rssi'],
      status: json['status'],
      lastSeen: json['lastSeen'] != null ? DateTime.parse(json['lastSeen']) : null,
      additionalInfo: json['additionalInfo'],
    );
  }

  /// 解析客戶端類型（預留方法）
  static ClientType _parseClientType(String? type) {
    switch (type?.toLowerCase()) {
      case 'tv':
        return ClientType.tv;
      case 'xbox':
        return ClientType.xbox;
      case 'iphone':
      case 'phone':
        return ClientType.iphone;
      case 'laptop':
      case 'computer':
        return ClientType.laptop;
      default:
        return ClientType.laptop;
    }
  }
}

/// 🎯 新增：三段式 RSSI 顏色判斷
Color _getThreeStageRSSIColor(int rssi) {
  if (rssi >= -60) {
    // 優秀區段：-60 以上
    return const Color(0xFF2AFFC3); // 您指定的綠色
  } else if (rssi >= -75) {
    // 中等區段：-60 to -75
    return const Color(0xFFFFE448); // 您指定的黃色
  } else {
    // 較差區段：-75 以下
    return const Color(0xFFFF6D2F); // 您指定的橙色
  }
}

/// 🎯 新增：簡化的品質標籤
String _getRSSIQualityLabel(int rssi) {
  if (rssi >= -60) {
    return 'Good';
  } else if (rssi >= -75) {
    return 'Fair';
  } else {
    return 'Poor';
  }
}

/// 🎯 新增：RSSI 顯示數據類
class RSSIDisplayData {
  final String displayText;   // 顯示文字
  final Color color;          // 背景顏色
  final String quality;       // 品質描述
  final int primaryValue;     // 主要 RSSI 值

  RSSIDisplayData({
    required this.displayText,
    required this.color,
    required this.quality,
    required this.primaryValue,
  });
}

/// 🎯 新增：RSSI 品質類
class RSSIQuality {
  final String label;  // 品質標籤
  final Color color;   // 對應顏色

  RSSIQuality({
    required this.label,
    required this.color,
  });
}