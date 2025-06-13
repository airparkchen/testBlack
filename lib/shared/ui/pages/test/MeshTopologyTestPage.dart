// lib/shared/ui/pages/test/EnhancedMeshTopologyTestPage.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'package:whitebox/shared/api/wifi_api_service.dart';
import 'package:whitebox/shared/ui/components/basic/NetworkTopologyComponent.dart';
import 'package:whitebox/shared/theme/app_theme.dart';
import 'package:whitebox/shared/models/mesh_data_models.dart';
import 'package:whitebox/shared/services/mesh_data_analyzer.dart';

/// 增強版 Mesh Topology API 測試頁面
/// 支援測試 Mesh Topology, Dashboard, Throughput API
class EnhancedMeshTopologyTestPage extends StatefulWidget {
  const EnhancedMeshTopologyTestPage({super.key});

  @override
  State<EnhancedMeshTopologyTestPage> createState() => _EnhancedMeshTopologyTestPageState();
}

class _EnhancedMeshTopologyTestPageState extends State<EnhancedMeshTopologyTestPage> {
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

  // ==================== API 數據狀態 ====================

  // 原始 API 響應數據
  dynamic rawMeshData;
  dynamic rawDashboardData;
  dynamic rawThroughputData;

  // 解析後的設備列表（只保留 Mesh 相關）
  List<NetworkDevice> parsedDevices = [];
  List<DeviceConnection> parsedConnections = [];
  List<DetailedDeviceInfo> detailedDevices = [];
  NetworkTopologyStructure? topologyStructure;

  // 數據刷新計時器
  Timer? _refreshTimer;
  bool isAutoRefreshEnabled = false;

  // API 調用計數
  Map<String, int> apiCallCounts = {
    'mesh': 0,
    'dashboard': 0,
    'throughput': 0,
  };

  @override
  void initState() {
    super.initState();
    _addLog("增強版 Mesh API 測試頁面已載入");
    _addLog("支援測試: Mesh Topology, Dashboard, Throughput");
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
          _updateStatus("✅ SRP 登入成功！可以開始測試 API");
        });

        _addLog("✅ SRP 登入成功");
        if (result.jwtToken != null && result.jwtToken!.isNotEmpty) {
          _addLog("JWT 令牌已獲取: ${result.jwtToken!.substring(0, 20)}...");
          WifiApiService.setJwtToken(result.jwtToken!);
        }

        _addLog("登入成功，可以開始測試各個 API 了");
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
      rawDashboardData = null;
      rawThroughputData = null;
      parsedDevices = [];
      parsedConnections = [];
      detailedDevices = [];
      topologyStructure = null;
      apiCallCounts = {'mesh': 0, 'dashboard': 0, 'throughput': 0};
      _updateStatus("已登出");
    });

    // 停止自動刷新
    _stopAutoRefresh();

    WifiApiService.setJwtToken('');
    _addLog("🚪 已清除身份驗證信息並登出");
  }

  // ==================== API 測試功能 ====================

  /// 獲取 Mesh 拓撲數據
  Future<void> _getMeshTopology() async {
    if (!isAuthenticated) {
      _addLog("❌ 請先登入後再測試 Mesh API");
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
        apiCallCounts['mesh'] = (apiCallCounts['mesh'] ?? 0) + 1;
      });

      _addLog("✅ Mesh API 調用完成 (第 ${apiCallCounts['mesh']} 次)");

      // 打印完整的原始數據
      _printRawDataToConsole("MESH_TOPOLOGY", meshResult);

      // 保留原有的 Mesh 分析邏輯
      _analyzeMeshData(meshResult);
      _analyzeDetailedDeviceInfo(meshResult);
      _analyzeTopologyStructure();
      _parseDevicesFromMeshData(meshResult); // 確保在顯示拓撲前解析數據

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

  /// 獲取 Dashboard 數據
  Future<void> _getDashboard() async {
    if (!isAuthenticated) {
      _addLog("❌ 請先登入後再測試 Dashboard API");
      return;
    }

    setState(() {
      isLoading = true;
      _updateStatus("正在獲取 Dashboard 數據...");
    });

    try {
      _addLog("📊 開始調用 getSystemDashboard API");

      final dashboardResult = await WifiApiService.getSystemDashboard();

      setState(() {
        rawDashboardData = dashboardResult;
        apiCallCounts['dashboard'] = (apiCallCounts['dashboard'] ?? 0) + 1;
      });

      _addLog("✅ Dashboard API 調用完成 (第 ${apiCallCounts['dashboard']} 次)");

      // 打印完整的原始數據
      _printRawDataToConsole("DASHBOARD", dashboardResult);

      _updateStatus("✅ Dashboard 數據獲取成功");
    } catch (e) {
      _addLog("❌ 獲取 Dashboard 時發生錯誤: $e");
      _updateStatus("❌ Dashboard API 調用失敗");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// 獲取 Throughput 數據
  Future<void> _getThroughput() async {
    if (!isAuthenticated) {
      _addLog("❌ 請先登入後再測試 Throughput API");
      return;
    }

    setState(() {
      isLoading = true;
      _updateStatus("正在獲取 Throughput 數據...");
    });

    try {
      _addLog("📈 開始調用 Throughput API");
      _addLog("⚠️ 注意：此 API 可能需要在 WifiApiService 中實現");

      // 嘗試調用 Throughput API
      dynamic throughputResult;

      try {
        // 🎯 您需要在 WifiApiService 中添加這個方法
        // 暫時使用可能的方法名稱嘗試
        throughputResult = await WifiApiService.call('getSystemThroughput');
      } catch (e) {
        _addLog("⚠️ getSystemThroughput 方法可能不存在，錯誤: $e");

        // 如果方法不存在，可以嘗試其他可能的方法名
        try {
          throughputResult = await WifiApiService.call('getThroughput');
        } catch (e2) {
          _addLog("⚠️ getThroughput 方法也不存在，錯誤: $e2");

          // 如果都不存在，記錄需要實現的 API
          _addLog("❌ 需要在 WifiApiService 中實現 Throughput API");
          _addLog("建議添加端點: '/api/v1/system/throughput' 或類似的");

          setState(() {
            rawThroughputData = {
              'error': 'API not implemented',
              'message': '需要在 WifiApiService 中實現 Throughput API',
              'suggested_endpoint': '/api/v1/system/throughput'
            };
          });

          _printRawDataToConsole("THROUGHPUT_ERROR", rawThroughputData);
          _updateStatus("⚠️ Throughput API 需要實現");
          return;
        }
      }

      setState(() {
        rawThroughputData = throughputResult;
        apiCallCounts['throughput'] = (apiCallCounts['throughput'] ?? 0) + 1;
      });

      _addLog("✅ Throughput API 調用完成 (第 ${apiCallCounts['throughput']} 次)");

      // 打印完整的原始數據
      _printRawDataToConsole("THROUGHPUT", throughputResult);

      _updateStatus("✅ Throughput 數據獲取成功");
    } catch (e) {
      _addLog("❌ 獲取 Throughput 時發生錯誤: $e");
      _updateStatus("❌ Throughput API 調用失敗");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// 獲取所有 API 數據
  Future<void> _getAllApiData() async {
    if (!isAuthenticated) {
      _addLog("❌ 請先登入後再測試 API");
      return;
    }

    _addLog("🚀 開始獲取所有 API 數據...");

    await _getMeshTopology();
    await Future.delayed(const Duration(milliseconds: 500));

    await _getDashboard();
    await Future.delayed(const Duration(milliseconds: 500));

    await _getThroughput();

    _addLog("✅ 所有 API 數據獲取完成");
  }

  // ==================== 原有的 Mesh 分析方法（保持不變） ====================

  /// 分析 Mesh 數據（保持原有邏輯）
  void _analyzeMeshData(dynamic meshData) {
    _addLog("📊 開始基本數據分析");

    if (meshData == null) {
      _addLog("⚠️  Mesh 數據為 null");
      return;
    }

    if (meshData is Map && meshData.containsKey('error')) {
      _addLog("❌ API 返回錯誤: ${meshData['error']}");
      return;
    }

    if (meshData is List) {
      int totalNodes = meshData.length;
      int totalConnectedDevices = 0;
      Map<String, int> deviceTypeCounts = {};

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

  /// 詳細設備分析（使用新模組）
  void _analyzeDetailedDeviceInfo(dynamic meshResult) {
    _addLog("🔍 開始詳細設備分析...");

    final devices = _analyzer.analyzeDetailedDeviceInfo(meshResult);

    setState(() {
      detailedDevices = devices;
    });

    _addLog("✅ 詳細設備分析完成：找到 ${devices.length} 個有效設備");
    _addLog("🚫 過濾統計: Extender(${_analyzer.filteredExtenders}), Host(${_analyzer.filteredHosts})");

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

  /// 打印原始數據到控制台
  void _printRawDataToConsole(String apiName, dynamic apiData) {
    final timestamp = DateTime.now().toString();

    print("");
    print("╔═══════════════════════════════════════════════════════════════════════════════════════════════════");
    print("║ [$apiName API] 原始響應數據");
    print("║ 時間: $timestamp");
    print("║ 數據類型: ${apiData.runtimeType}");
    print("╠═══════════════════════════════════════════════════════════════════════════════════════════════════");

    try {
      if (apiData != null) {
        String jsonString = JsonEncoder.withIndent('  ').convert(apiData);

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
      print("║ 原始數據: $apiData");
    }

    print("╚═══════════════════════════════════════════════════════════════════════════════════════════════════");
    print("");
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
        _addLog("🔄 自動刷新所有 API 數據...");
        _getAllApiData();
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

  /// 匯出所有原始數據到剪貼板
  void _exportAllRawData() {
    if (!isAuthenticated) {
      _addLog("❌ 沒有可匯出的數據");
      return;
    }

    try {
      final exportData = {
        'export_timestamp': DateTime.now().toIso8601String(),
        'api_call_counts': apiCallCounts,
        'mesh_topology_raw': rawMeshData,
        'dashboard_raw': rawDashboardData,
        'throughput_raw': rawThroughputData,
      };

      final jsonString = JsonEncoder.withIndent('  ').convert(exportData);
      Clipboard.setData(ClipboardData(text: jsonString));
      _addLog("📋 所有原始 API 數據已複製到剪貼板");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('所有原始 API 數據已複製到剪貼板')),
      );
    } catch (e) {
      _addLog("❌ 匯出數據失敗: $e");
    }
  }

  // ==================== UI 構建方法 ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API 測試中心 (Mesh + Dashboard + Throughput)'),
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
              onPressed: isLoading ? null : _getAllApiData,
              tooltip: '刷新所有數據',
            ),
            IconButton(
              icon: const Icon(Icons.file_download),
              onPressed: _exportAllRawData,
              tooltip: '匯出所有原始數據',
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

              // API 測試區域
              if (isAuthenticated) _buildApiTestSection(),

              // 統計區域
              if (isAuthenticated) _buildStatisticsSection(),

              const SizedBox(height: 16),

              // 拓撲圖顯示
              if (isAuthenticated && topologyStructure != null) _buildTopologyView(),

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
              Text(
                'API 調用次數: Mesh(${apiCallCounts['mesh']}), Dashboard(${apiCallCounts['dashboard']}), Throughput(${apiCallCounts['throughput']})',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green[600],
                ),
                textAlign: TextAlign.center,
              ),
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

  /// 建構 API 測試區域
  Widget _buildApiTestSection() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🌐 API 測試區域',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // 第一行：Mesh 和 Dashboard
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : _getMeshTopology,
                    icon: const Icon(Icons.hub),
                    label: Text('Mesh 拓撲\n(${apiCallCounts['mesh']} 次)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : _getDashboard,
                    icon: const Icon(Icons.dashboard),
                    label: Text('Dashboard\n(${apiCallCounts['dashboard']} 次)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 第二行：Throughput 和 All APIs
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : _getThroughput,
                    icon: const Icon(Icons.speed),
                    label: Text('Throughput\n(${apiCallCounts['throughput']} 次)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : _getAllApiData,
                    icon: const Icon(Icons.data_usage),
                    label: const Text('取得所有 API 數據'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
              '📊 數據統計與分析',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatItem('總設備數', '${detailedDevices.length} 個'),
            _buildStatItem('主路由器 (Host)', '${_analyzer.filteredHosts} 個'),
            _buildStatItem('延伸器 (Extender)', '${_analyzer.filteredExtenders} 個'),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Mesh Topology 原始數據概覽:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildRawDataSummary('Mesh Topology', rawMeshData),
            _buildRawDataSummary('Dashboard', rawDashboardData),
            _buildRawDataSummary('Throughput', rawThroughputData),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildRawDataSummary(String title, dynamic data) {
    String summary;
    Color color;
    if (data == null) {
      summary = '無數據';
      color = Colors.grey;
    } else if (data is Map && data.containsKey('error')) {
      summary = 'API 錯誤: ${data['error']}';
      color = Colors.red;
    } else {
      try {
        summary = JsonEncoder.withIndent('  ').convert(data).substring(0, (data.toString().length > 100 ? 100 : data.toString().length)) + '...';
        color = Colors.black87;
      } catch (e) {
        summary = '無法解析數據';
        color = Colors.red;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title:',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            summary,
            style: TextStyle(fontSize: 13, color: color),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 建構拓撲圖顯示區域
  Widget _buildTopologyView() {
    if (topologyStructure == null || parsedDevices.isEmpty) {
      return const Card(
        elevation: 3,
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🌐 網路拓樸圖',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Center(
                child: Text(
                  '沒有可用的拓樸數據。請先獲取 Mesh Topology 數據。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 調整 NetworkTopologyComponent 的高度以適應內容
    double topologyHeight = (parsedDevices.length * 80.0) + (parsedConnections.length * 40.0).clamp(200, 600);


    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🌐 網路拓樸圖',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: topologyHeight, // 可調整高度
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
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
            const Text(
              '📜 操作日誌',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade700),
              ),
              padding: const EdgeInsets.all(8.0),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  return Text(
                    logs[index],
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}