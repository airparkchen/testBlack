// lib/shared/ui/pages/test/MeshTopologyTestPage.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'package:whitebox/shared/api/wifi_api_service.dart';
import 'package:whitebox/shared/ui/components/basic/NetworkTopologyComponent.dart';
import 'package:whitebox/shared/theme/app_theme.dart';
import 'package:whitebox/shared/models/mesh_data_models.dart';
import 'package:whitebox/shared/services/mesh_data_analyzer.dart';

/// Mesh Topology API 測試頁面
/// 專門用於測試登入後的 mesh_topology API 功能
class MeshTopologyTestPage extends StatefulWidget {
  const MeshTopologyTestPage({super.key});

  @override
  State<MeshTopologyTestPage> createState() => _MeshTopologyTestPageState();
}

class _MeshTopologyTestPageState extends State<MeshTopologyTestPage> {
  // ==================== 基本狀態 ====================

  // 日誌和狀態
  List<String> logs = [];
  bool isLoading = false;
  String statusMessage = "請先完成登入";

  // 輸入控制器
  final TextEditingController _usernameController = TextEditingController(text: 'admin');
  final TextEditingController _passwordController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 主題和分析器
  final AppTheme _appTheme = AppTheme();
  final MeshDataAnalyzer _analyzer = MeshDataAnalyzer();

  // ==================== 認證狀態 ====================

  bool isAuthenticated = false;
  String? jwtToken;

  // ==================== Mesh 數據狀態 ====================

  // 原始 Mesh API 響應
  dynamic rawMeshData;

  // 解析後的設備列表
  List<NetworkDevice> parsedDevices = [];
  List<DeviceConnection> parsedConnections = [];

  // 新增：詳細設備分析結果
  List<DetailedDeviceInfo> detailedDevices = [];

  // 新增：網路拓樸連接結構
  NetworkTopologyStructure? topologyStructure;

  // 數據刷新計時器
  Timer? _refreshTimer;
  bool isAutoRefreshEnabled = false;

  // 數據統計
  int totalNodes = 0;
  int totalConnectedDevices = 0;
  Map<String, int> deviceTypeCounts = {};

  // 新增：過濾統計（透過分析器獲取）
  int get filteredExtenders => _analyzer.filteredExtenders;
  int get filteredHosts => _analyzer.filteredHosts;

  @override
  void initState() {
    super.initState();
    _addLog("Mesh Topology API 測試頁面已載入");
    _addLog("請先完成登入以測試 API");
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _scrollController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ==================== 日誌管理 ====================

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    setState(() {
      logs.add("[$timestamp] $message");
    });

    // 自動滾動到底部
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    print("[$timestamp] $message");
  }

  void _updateStatus(String message) {
    setState(() {
      statusMessage = message;
    });
  }

  void _clearLogs() {
    setState(() {
      logs = [];
    });
    _addLog("日誌已清除");
  }

  // ==================== 認證功能 ====================

  /// 使用 SRP 方法登入
  Future<void> _loginWithSRP() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      _addLog("❌ 錯誤: 用戶名或密碼不能為空");
      _updateStatus("請輸入用戶名和密碼");
      return;
    }

    setState(() {
      isLoading = true;
      _updateStatus("正在執行 SRP 登入...");
    });

    try {
      _addLog("🔐 開始 SRP 登入流程");
      _addLog("用戶名: ${_usernameController.text}");

      final result = await WifiApiService.loginWithSRP(
        _usernameController.text,
        _passwordController.text,
      );

      _addLog("SRP 登入響應: ${result.message}");

      if (result.success) {
        setState(() {
          isAuthenticated = true;
          jwtToken = result.jwtToken;
          _updateStatus("✅ SRP 登入成功！可以開始測試 Mesh API");
        });

        _addLog("✅ SRP 登入成功");
        if (result.jwtToken != null && result.jwtToken!.isNotEmpty) {
          _addLog("JWT 令牌已獲取: ${result.jwtToken!.substring(0, 20)}...");
          WifiApiService.setJwtToken(result.jwtToken!);
        }

        // 登入成功後自動獲取一次 Mesh 數據
        _addLog("登入成功，準備獲取 Mesh 拓撲數據...");
        await Future.delayed(const Duration(milliseconds: 500));
        await _getMeshTopology();

      } else {
        _updateStatus("❌ SRP 登入失敗");
        _addLog("❌ SRP 登入失敗: ${result.message}");
      }
    } catch (e) {
      _addLog("❌ SRP 登入發生異常: $e");
      _updateStatus("SRP 登入異常");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// 登出
  void _logout() {
    setState(() {
      isAuthenticated = false;
      jwtToken = null;
      rawMeshData = null;
      parsedDevices = [];
      parsedConnections = [];
      detailedDevices = [];
      topologyStructure = null;
      totalNodes = 0;
      totalConnectedDevices = 0;
      deviceTypeCounts = {};
      _updateStatus("已登出");
    });

    // 停止自動刷新
    _stopAutoRefresh();

    WifiApiService.setJwtToken('');
    _addLog("🚪 已清除身份驗證信息並登出");
  }

  // ==================== Mesh API 測試功能 ====================

  /// 獲取 Mesh 拓撲數據
  Future<void> _getMeshTopology() async {
    if (!isAuthenticated) {
      _addLog("❌ 請先登入後再測試 API");
      return;
    }

    setState(() {
      isLoading = true;
      _updateStatus("正在獲取 Mesh 拓撲數據...");
    });

    try {
      _addLog("🌐 開始調用 getMeshTopology API");

      final meshResult = await WifiApiService.getMeshTopology();

      setState(() {
        rawMeshData = meshResult;
        // 重置解析數據
        detailedDevices = [];
        topologyStructure = null;
      });

      _addLog("✅ Mesh API 調用完成");
      _analyzeMeshData(meshResult);
      _parseDevicesFromMeshData(meshResult);

      // 新增：詳細設備分析
      _analyzeDetailedDeviceInfo(meshResult);

      // 新增：拓樸結構分析
      _analyzeTopologyStructure();

      _updateStatus("✅ Mesh 數據獲取成功");

    } catch (e) {
      _addLog("❌ 獲取 Mesh 拓撲時發生錯誤: $e");
      _updateStatus("❌ Mesh API 調用失敗");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// 詳細設備分析（使用新模組）
  void _analyzeDetailedDeviceInfo(dynamic meshResult) {
    _addLog("🔍 開始詳細設備分析...");

    final devices = _analyzer.analyzeDetailedDeviceInfo(meshResult);

    setState(() {
      detailedDevices = devices;
    });

    _addLog("✅ 詳細設備分析完成：找到 ${devices.length} 個有效設備");
    _addLog("🚫 過濾統計: Extender($filteredExtenders), Host($filteredHosts)");

    // 輸出詳細分析結果
    _analyzer.printDetailedDeviceAnalysis(devices);
  }

  /// 拓樸結構分析（使用新模組）
  void _analyzeTopologyStructure() {
    _addLog("🌐 開始拓樸結構分析...");

    final topology = _analyzer.analyzeTopologyStructure(detailedDevices);

    setState(() {
      topologyStructure = topology;
    });

    if (topology != null) {
      _addLog("✅ 拓樸結構分析完成");
      _analyzer.printTopologyStructure(topology);
    } else {
      _addLog("❌ 拓樸結構分析失敗");
    }
  }

  // ==================== 原有的分析方法（保留簡化版本） ====================

  /// 分析 Mesh 數據（簡化版本）
  void _analyzeMeshData(dynamic meshData) {
    _addLog("📊 開始基本數據分析");
    _printRawDataToConsole(meshData);

    if (meshData == null) {
      _addLog("⚠️  Mesh 數據為 null");
      return;
    }

    if (meshData is Map && meshData.containsKey('error')) {
      _addLog("❌ API 返回錯誤: ${meshData['error']}");
      return;
    }

    if (meshData is List) {
      setState(() {
        totalNodes = meshData.length;
        totalConnectedDevices = 0;
        deviceTypeCounts = {};
      });

      _addLog("📋 發現 ${meshData.length} 個主要節點");

      for (int i = 0; i < meshData.length; i++) {
        final node = meshData[i];
        if (node is Map) {
          // 統計設備類型
          String deviceType = node['type'] ?? 'unknown';
          deviceTypeCounts[deviceType] = (deviceTypeCounts[deviceType] ?? 0) + 1;

          // 統計連接的設備
          if (node.containsKey('connectedDevices') && node['connectedDevices'] is List) {
            final devices = node['connectedDevices'] as List;
            totalConnectedDevices += devices.length;
          }
        }
      }

      _addLog("📊 基本統計: 總節點($totalNodes), 連接設備($totalConnectedDevices)");
    }
  }

  /// 打印原始數據到控制台（簡化版本）
  void _printRawDataToConsole(dynamic meshData) {
    final timestamp = DateTime.now().toString();

    print("");
    print("╔═══════════════════════════════════════════════════════════════════════════════════════════════════");
    print("║ [MESH_RAW_DATA] 原始 Mesh Topology API 響應數據");
    print("║ 時間: $timestamp");
    print("║ 數據類型: ${meshData.runtimeType}");
    print("╠═══════════════════════════════════════════════════════════════════════════════════════════════════");

    try {
      if (meshData != null) {
        String jsonString = JsonEncoder.withIndent('  ').convert(meshData);

        // 分段輸出，避免過長
        List<String> lines = jsonString.split('\n');
        for (int i = 0; i < lines.length; i++) {
          print("║ ${lines[i]}");
        }
      } else {
        print("║ null");
      }
    } catch (e) {
      print("║ 無法序列化為 JSON: $e");
      print("║ 原始數據: $meshData");
    }

    print("╚═══════════════════════════════════════════════════════════════════════════════════════════════════");
    print("");
  }

  /// 解析設備數據（保留原有邏輯）
  void _parseDevicesFromMeshData(dynamic meshData) {
    _addLog("🔄 開始基本設備解析...");

    List<NetworkDevice> devices = [];
    List<DeviceConnection> connections = [];

    if (meshData is List) {
      for (int i = 0; i < meshData.length; i++) {
        final node = meshData[i];
        if (node is Map) {
          final device = NetworkDevice(
            name: node['devName'] ?? 'Device ${i + 1}',
            id: node['macAddr'] ?? 'device-$i',
            mac: node['macAddr'] ?? '00:00:00:00:00:00',
            ip: node['ipAddress'] ?? '192.168.1.1',
            connectionType: _parseConnectionType(node['connectionType']),
            additionalInfo: {
              'type': node['type'] ?? 'unknown',
              'status': 'online',
              'rssi': node['rssi']?.toString() ?? '',
              'rawData': node,
            },
          );

          devices.add(device);

          int connectedCount = 0;
          if (node.containsKey('connectedDevices') && node['connectedDevices'] is List) {
            connectedCount = (node['connectedDevices'] as List).length;
          }

          connections.add(DeviceConnection(
            deviceId: device.id,
            connectedDevicesCount: connectedCount,
          ));
        }
      }
    }

    setState(() {
      parsedDevices = devices;
      parsedConnections = connections;
    });

    _addLog("✅ 基本設備解析完成: ${devices.length} 個設備");
  }

  /// 解析連接類型
  ConnectionType _parseConnectionType(dynamic connectionType) {
    if (connectionType == null) return ConnectionType.wireless;

    String connStr = connectionType.toString().toLowerCase();
    if (connStr.contains('ethernet') || connStr.contains('wired')) {
      return ConnectionType.wired;
    }
    return ConnectionType.wireless;
  }

  // ==================== 自動刷新功能 ====================

  /// 開始自動刷新
  void _startAutoRefresh() {
    if (!isAuthenticated) {
      _addLog("❌ 請先登入後再啟用自動刷新");
      return;
    }

    _stopAutoRefresh(); // 先停止現有的

    setState(() {
      isAutoRefreshEnabled = true;
    });

    _addLog("🔄 啟用自動刷新 (每30秒)");

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (isAuthenticated && mounted) {
        _addLog("🔄 自動刷新 Mesh 數據...");
        _getMeshTopology();
      } else {
        _stopAutoRefresh();
      }
    });
  }

  /// 停止自動刷新
  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    setState(() {
      isAutoRefreshEnabled = false;
    });
    _addLog("⏹️ 自動刷新已停止");
  }

  // ==================== 數據匯出功能 ====================

  /// 匯出原始數據到剪貼板
  void _exportRawData() {
    if (rawMeshData == null) {
      _addLog("❌ 沒有可匯出的數據");
      return;
    }

    try {
      final jsonString = JsonEncoder.withIndent('  ').convert(rawMeshData);
      Clipboard.setData(ClipboardData(text: jsonString));
      _addLog("📋 原始數據已複製到剪貼板");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('原始數據已複製到剪貼板')),
      );
    } catch (e) {
      _addLog("❌ 匯出數據失敗: $e");
    }
  }

  /// 匯出詳細分析數據
  void _exportDetailedData() {
    if (detailedDevices.isEmpty) {
      _addLog("❌ 沒有可匯出的詳細數據");
      return;
    }

    try {
      final exportData = {
        'detailedDevices': detailedDevices.map((device) => {
          'macAddress': device.macAddress,
          'ipAddress': device.ipAddress,
          'deviceType': device.deviceType,
          'deviceName': device.deviceName,
          'clientCount': device.clientCount,
          'connectionInfo': {
            'method': device.connectionInfo.method,
            'description': device.connectionInfo.description,
            'ssid': device.connectionInfo.ssid,
            'radio': device.connectionInfo.radio,
          },
          'parentAccessPoint': device.parentAccessPoint,
          'hops': device.hops,
          'rssiValues': device.rssiValues,
        }).toList(),
        'topology': topologyStructure != null ? {
          'gateway': topologyStructure!.gateway.macAddress,
          'totalDevices': topologyStructure!.totalDevices,
          'totalClients': topologyStructure!.totalClients,
          'maxHops': topologyStructure!.maxHops,
        } : null,
        'statistics': {
          'totalNodes': totalNodes,
          'totalConnectedDevices': totalConnectedDevices,
          'deviceTypeCounts': deviceTypeCounts,
          'filteredExtenders': filteredExtenders,
          'filteredHosts': filteredHosts,
        }
      };

      final jsonString = JsonEncoder.withIndent('  ').convert(exportData);
      Clipboard.setData(ClipboardData(text: jsonString));
      _addLog("📋 詳細分析數據已複製到剪貼板");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('詳細分析數據已複製到剪貼板')),
      );
    } catch (e) {
      _addLog("❌ 匯出詳細數據失敗: $e");
    }
  }

  // ==================== UI 構建方法 ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesh Topology API 測試'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (isAuthenticated) ...[
            IconButton(
              icon: Icon(isAutoRefreshEnabled ? Icons.pause : Icons.play_arrow),
              onPressed: isAutoRefreshEnabled ? _stopAutoRefresh : _startAutoRefresh,
              tooltip: isAutoRefreshEnabled ? '停止自動刷新' : '開始自動刷新',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: isLoading ? null : _getMeshTopology,
              tooltip: '手動刷新',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearLogs,
            tooltip: '清除日誌',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 狀態卡片
              _buildStatusCard(),
              const SizedBox(height: 16),

              // 認證區域
              if (!isAuthenticated) _buildAuthSection(),

              // Mesh API 測試區域
              if (isAuthenticated) _buildMeshTestSection(),

              // 數據統計區域
              if (isAuthenticated && rawMeshData != null) _buildStatisticsSection(),

              // 數據匯出區域
              if (isAuthenticated && rawMeshData != null) _buildExportSection(),

              const SizedBox(height: 16),

              // 日誌區域
              _buildLogSection(),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== UI 元件構建方法 ====================

  /// 建構狀態卡片
  Widget _buildStatusCard() {
    return Card(
      elevation: 3,
      color: isAuthenticated ? Colors.green[100] : Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(
              isAuthenticated ? Icons.verified_user : Icons.login,
              size: 40,
              color: isAuthenticated ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 8),
            Text(
              statusMessage,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isAuthenticated ? Colors.green[800] : Colors.orange[800],
              ),
              textAlign: TextAlign.center,
            ),
            if (isAuthenticated) ...[
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('登出'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 建構認證區域
  Widget _buildAuthSection() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔐 身份驗證',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: '用戶名',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              enabled: !isLoading,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: '密碼',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
              enabled: !isLoading,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : _loginWithSRP,
                icon: const Icon(Icons.security),
                label: Text(isLoading ? '登入中...' : 'SRP 安全登入'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 建構 Mesh 測試區域
  Widget _buildMeshTestSection() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🌐 Mesh Topology API 測試',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : _getMeshTopology,
                    icon: const Icon(Icons.download),
                    label: Text(isLoading ? '獲取中...' : '獲取 Mesh 數據'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: isAutoRefreshEnabled ? _stopAutoRefresh : _startAutoRefresh,
                  icon: Icon(isAutoRefreshEnabled ? Icons.pause : Icons.play_arrow),
                  label: Text(isAutoRefreshEnabled ? '停止自動刷新' : '自動刷新'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAutoRefreshEnabled ? Colors.orange : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 建構統計區域
  Widget _buildStatisticsSection() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 數據統計',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('總節點數', totalNodes.toString(), Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard('連接設備數', totalConnectedDevices.toString(), Colors.green),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('詳細設備', detailedDevices.length.toString(), Colors.purple),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard('過濾設備', '${filteredExtenders + filteredHosts}', Colors.orange),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 建構統計卡片
  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(1.0)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(1.0),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 建構匯出區域
  Widget _buildExportSection() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📤 數據匯出',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _exportRawData,
                    icon: const Icon(Icons.code),
                    label: const Text('匯出原始數據'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _exportDetailedData,
                    icon: const Icon(Icons.analytics),
                    label: const Text('匯出分析數據'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 建構日誌區域
  Widget _buildLogSection() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '📋 測試日誌',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Text(
                      '${logs.length} 條日誌',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _clearLogs,
                      tooltip: '清除日誌',
                      iconSize: 20,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    Color textColor = Colors.green;

                    // 根據日誌內容設置不同顏色
                    if (log.contains('❌') || log.contains('錯誤') || log.contains('失敗')) {
                      textColor = Colors.red;
                    } else if (log.contains('⚠️') || log.contains('警告')) {
                      textColor = Colors.orange;
                    } else if (log.contains('✅') || log.contains('成功')) {
                      textColor = Colors.lightGreen;
                    } else if (log.contains('🔐') || log.contains('🌐') || log.contains('📊')) {
                      textColor = Colors.cyan;
                    } else if (log.contains('🔄') || log.contains('⏹️')) {
                      textColor = Colors.yellow;
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text(
                        log,
                        style: TextStyle(
                          color: textColor,
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '日誌會自動滾動到最新內容。不同顏色代表不同類型的訊息：綠色(一般)、紅色(錯誤)、橙色(警告)、青色(重要操作)',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}