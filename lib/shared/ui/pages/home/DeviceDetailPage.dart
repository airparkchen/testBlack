// lib/shared/ui/pages/home/DeviceDetailPage.dart - RSSI 修正版本

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:whitebox/shared/ui/components/basic/NetworkTopologyComponent.dart';
import 'package:whitebox/shared/theme/app_theme.dart';
// import 'package:whitebox/shared/services/real_data_integration_service.dart'; 舊的API調用機制
import 'package:whitebox/shared/ui/pages/home/Topo/network_topo_config.dart';
import 'package:whitebox/shared/services/unified_mesh_data_manager.dart';

/// 設備詳情頁面 - 修正 RSSI 顯示
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

  // 設為可變的列表，初始為空
  List<ClientDevice> _clientDevices = [];

  // 載入狀態
  bool _isLoadingClients = true;

  // 🆕 新增：定期更新的計時器
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _loadClientDevices();

    // ✅ 新增：啟動定期更新
    _startPeriodicUpdate();
  }

  void _startPeriodicUpdate() {
    _updateTimer = Timer.periodic(NetworkTopoConfig.meshApiCallInterval, (_) {
      if (mounted) {  // 確保頁面還在顯示
        print('🔄 DeviceDetailPage 定期更新客戶端數據');
        _loadClientDevices();  // 重新載入客戶端數據
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();  // ✅ 重要：頁面關閉時取消計時器
    super.dispose();
  }

  /// 異步載入客戶端設備資料
  Future<void> _loadClientDevices() async {
    if (!mounted) return;

    setState(() {
      _isLoadingClients = true;
    });

    try {
      List<ClientDevice> clientDevices;

      if (NetworkTopoConfig.useRealData) {
        // 🎯 使用統一管理器，不重新調用 API
        final manager = UnifiedMeshDataManager.instance;
        final deviceId = _generateDeviceId(widget.selectedDevice.mac);
        clientDevices = await manager.getClientDevicesForParent(deviceId);
        print('✅ 載入統一管理器客戶端數據: ${clientDevices.length} 個設備（無API調用）');
      } else {
        // 假數據邏輯保持不變
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

  /// 生成設備 ID 的方法
  String _generateDeviceId(String macAddress) {
    return 'device-${macAddress.replaceAll(':', '').toLowerCase()}';
  }

  /// 生成假資料（開發用）
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
              // 頂部區域：RSSI + 返回按鈕（修正：Gateway 不顯示 RSSI）
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

  /// 🎯 修正：建構頂部區域 - Gateway 不顯示 RSSI bar
  Widget _buildTopArea() {
    // 🎯 修正1：檢查是否為 Gateway，Gateway 不顯示 RSSI
    final String? rssiString = widget.selectedDevice.additionalInfo['rssi'];
    final int rssiValue = int.tryParse(rssiString ?? '') ?? 0;
    final bool isGatewayDevice = widget.selectedDevice.additionalInfo['type'] == 'gateway';
    final bool shouldShowRssiBar = !isGatewayDevice && rssiValue != 0;


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

          // 🎯 修正：只有非 Gateway 設備才顯示 RSSI bar
          if (shouldShowRssiBar) ...[
            // 解析 RSSI 數據
            Builder(
              builder: (context) {
                final rssiData = _parseRSSIData(widget.selectedDevice.additionalInfo['rssi']);

                return Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Container(
                      width: 175,
                      height: 35,
                      decoration: BoxDecoration(
                        color: rssiData.color,
                        borderRadius: BorderRadius.circular(12.5),
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
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  /// 🎯 修正：RSSI 數據解析 - 修正顏色判斷範圍
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
        // 多頻段格式："0,-22,-19" 或 "-27,-35"
        rssiValues = rssiString.split(',')
            .map((s) => int.tryParse(s.trim()) ?? 0)
            .where((v) => v != 0) // 🎯 修正：過濾掉 0 值
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
          displayText: 'RSSI : ',
          color: const Color(0xFF2AFFC3), // 綠色（最佳，有線連接）
          quality: 'Wired',
          primaryValue: 0,
        );
      }

      // 🎯 按照您的需求格式化顯示
      String displayText;
      if (rssiValues.length >= 3) {
        // 取前三個數值：RSSI : -27,-35,-20
        displayText = 'RSSI : ${rssiValues[0]},${rssiValues[1]},${rssiValues[2]}';
      } else if (rssiValues.length == 2) {
        // 取兩個數值：RSSI : -27,-35
        displayText = 'RSSI : ${rssiValues[0]},${rssiValues[1]}';
      } else if (rssiValues.length == 1) {
        // 只有一個數值：RSSI : -35
        displayText = 'RSSI : ${rssiValues[0]}';
      } else {
        displayText = 'RSSI : N/A';
      }

      // 取最強的信號作為顏色判斷依據（數值最大的，因為 RSSI 是負數）
      int bestRSSI = rssiValues.reduce((a, b) => a > b ? a : b);

      // 🎯 修正2：修正三段式顏色判斷範圍
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

  /// 🎯 修正2：三段式 RSSI 顏色判斷 - 修正範圍
  Color _getThreeStageRSSIColor(int rssi) {
    if (rssi > -65) {
      // 🎯 修正：0 < RSSI < -65dBm（綠色 - 優秀）
      return const Color(0xFF2AFFC3); // 綠色
    } else if (rssi > -75) {
      // 🎯 修正：-65 < RSSI < -75dBm（黃色 - 中等）
      return const Color(0xFFFFE448); // 黃色
    } else {
      // 🎯 修正：-75dBm < RSSI（橙色 - 較差）
      return const Color(0xFFFF6D2F); // 橙色
    }
  }

  /// 🎯 修正：簡化的品質標籤 - 對應新範圍
  String _getRSSIQualityLabel(int rssi) {
    if (rssi > -65) {
      return 'Good';
    } else if (rssi > -75) {
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
    final clientCount = _clientDevices.length;

    // 🎯 修正：重新定義顯示邏輯
    String labelText;      // 上方標籤
    String deviceText;     // 下方設備資訊

    if (isGatewayDevice) {
      // Gateway: 標籤顯示 "Controller"，下方只顯示 MAC
      labelText = 'Controller';
      deviceText = _formatMacAddress(widget.selectedDevice.mac);
    } else {
      // Extender: 標籤顯示偵測到的設備名稱，下方顯示 "Agent" + MAC
      final String detectedDeviceName = widget.selectedDevice.additionalInfo['devName']?.toString() ??
          widget.selectedDevice.name;
      labelText = detectedDeviceName.isNotEmpty ? detectedDeviceName : 'Agent';
      deviceText = 'Agent ${_formatMacAddress(widget.selectedDevice.mac)}';
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 🎯 修正：動態標籤文字
          Text(
            labelText,  // 🔥 Gateway 顯示 "Controller"，Extender 顯示偵測到的設備名稱
            style: TextStyle(
              color: Colors.white.withOpacity(1.0),
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),

          // 🎯 修正：動態設備資訊
          Text(
            deviceText,  // 🔥 Gateway 只顯示 MAC，Extender 顯示 "Agent" + MAC
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.normal,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // 客戶端數量
          Text(
            'Clients: $clientCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  /// 建構客戶端列表區域
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
                      'Loading...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              )
                  : _clientDevices.isEmpty
                  ? const Center(
                child: Text(
                  'No Detected Device',
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
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 左側：圖標 + 連線時間
              _buildClientIcon(client),

              const SizedBox(width: 16),

              // 右側：客戶端資訊
              Expanded(
                child: _buildClientInfo(client),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 建構客戶端圖標 + 連線時間
  Widget _buildClientIcon(ClientDevice client) {
    return SizedBox(
      width: 60,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 圖標容器
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
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

          const SizedBox(height: 8),

          // 連線時間
          SizedBox(
            width: 60,
            child: Text(
              client.connectionTime,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 9,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  double _getSSIDFontSizeForDeviceDetail(String ssid) {
    final length = ssid.length;

    if (length <= 20) {
      return 12.0; // 標準大小
    } else if (length <= 25) {
      return 11.0; // 中等長度，稍微縮小
    } else if (length <= 32) {
      return 10.0; // 較長，更小字體
    } else {
      return 10.0; // 非常長，最小字體
    }
  }

  /// 建構客戶端資訊
  Widget _buildClientInfo(ClientDevice client) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        // 設備名稱
        Text(
          client.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            height: 1.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),

        // 網路類型
        Text(
          _formatConnectionDisplay(client),
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: _getSSIDFontSizeForDeviceDetail(_formatConnectionDisplay(client)),
            height: 1.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),

        // MAC 地址
        Text(
          'MAC: ${_formatMacAddress(client.mac)}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 11,
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
            fontSize: 11,
            height: 1.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// 格式化連接顯示為 SSID_頻段 格式
  String _formatConnectionDisplay(ClientDevice client) {
    try {
      // 1. 獲取 SSID
      String ssid = '';
      if (client.additionalInfo?['ssid'] != null &&
          client.additionalInfo!['ssid'].toString().isNotEmpty) {
        ssid = client.additionalInfo!['ssid'].toString();
      } else {
        final ssidMatch = RegExp(r'SSID:\s*([^)]+)').firstMatch(client.deviceType);
        if (ssidMatch != null) {
          ssid = ssidMatch.group(1)?.trim() ?? '';
        }
      }

      // 2. 獲取頻段資訊
      String frequency = '';

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

      if (frequency.isEmpty) {
        if (client.deviceType.contains('6GHz')) {
          frequency = '6G';
        } else if (client.deviceType.contains('5GHz')) {
          frequency = '5G';
        } else if (client.deviceType.contains('2.4GHz')) {
          frequency = '2.4G';
        }
      }

      // 3. 特殊情況：Ethernet 連接
      if (client.deviceType.contains('Ethernet') || client.deviceType.contains('ethernet')) {
        return 'Ethernet';
      }

      // 4. 組合 SSID_頻段 格式
      if (ssid.isNotEmpty && frequency.isNotEmpty) {
        return '${ssid} /${frequency}';
      } else if (ssid.isNotEmpty) {
        return ssid;
      } else if (frequency.isNotEmpty) {
        return '${frequency} WiFi';
      }

      // 5. 備用方案
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
      return 'WiFi';
    }
  }

  /// 格式化 MAC 地址
  String _formatMacAddress(String mac) {
    return mac;
  }

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
        return 'assets/images/icon/unknown_2.png';
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

// ==================== 數據類別保持不變 ====================

/// 客戶端設備類型枚舉
enum ClientType {
  tv,
  xbox,
  iphone,
  laptop,
  unknown,
}

/// 客戶端設備資料類
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

  /// 從 API JSON 創建實例
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

  /// 解析客戶端類型
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
        return ClientType.unknown;
    }
  }
}

/// RSSI 顯示數據類
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