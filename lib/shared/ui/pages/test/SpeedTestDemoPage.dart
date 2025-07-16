import 'package:flutter/material.dart';
import 'package:whitebox/shared/ui/pages/test/SpeedTestWidget.dart';

class SpeedTestDemoPage extends StatefulWidget {
  const SpeedTestDemoPage({Key? key}) : super(key: key);

  @override
  State<SpeedTestDemoPage> createState() => _SpeedTestDemoPageState();
}

class _SpeedTestDemoPageState extends State<SpeedTestDemoPage> {
  // 用於控制測試元件的 GlobalKey
  final GlobalKey<CommercialSpeedTestWidgetState> _speedTestKey =
  GlobalKey<CommercialSpeedTestWidgetState>();

  // 測試日誌列表
  List<String> _testLogs = [];
  ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          '網路速度測試',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A), // slate-900
              Color(0xFF1E1B4B), // indigo-900
              Color(0xFF312E81), // indigo-800
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 標題區域
                _buildHeader(),

                const SizedBox(height: 40),

                // 主要測試卡片區域
                Center(
                  child: Container(
                    constraints: const BoxConstraints(
                      maxWidth: 450,
                    ),
                    child: Column(
                      children: [
                        // 速度測試元件 (移除內部按鈕)
                        CommercialSpeedTestWidget(
                          key: _speedTestKey,
                          onLogUpdate: _addLog, // 傳入日誌回調
                          showInternalButtons: false, // 隱藏內部按鈕
                        ),

                        const SizedBox(height: 20),

                        // 測試控制按鈕區域 (新增)
                        _buildTestControlButtons(),

                        const SizedBox(height: 30),

                        // 測試日誌區域 (取代原本的說明區域)
                        _buildLogSection(),

                        const SizedBox(height: 20),

                        // 功能按鈕 (保留原有功能)
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // 底部資訊
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // 圖示
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF9747FF), Color(0xFF00EEFF)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9747FF).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.speed,
            size: 40,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: 20),

        // 主標題
        const Text(
          '網路速度測試',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        // 副標題
        Text(
          '使用 Cloudflare 全球網路測試您的連線速度',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // 新增：測試控制按鈕區域
  Widget _buildTestControlButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              _clearLogs();
              _speedTestKey.currentState?.startSpeedTest();
            },
            icon: const Icon(Icons.speed, size: 18),
            label: const Text(
              '開始測試',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9747FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
            ),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              _clearLogs();
              _speedTestKey.currentState?.restartTest();
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text(
              '重新測試',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF00EEFF),
              side: const BorderSide(color: Color(0xFF00EEFF), width: 2),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 新增：測試日誌區域 (取代原本的 _buildInfoSection)
  Widget _buildLogSection() {
    return Container(
      height: 280, // 固定高度
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 標題列
          Row(
            children: [
              const Icon(
                Icons.terminal,
                color: Color(0xFF00EEFF),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                '測試日誌',
                style: TextStyle(
                  color: Color(0xFF00EEFF),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // 清除日誌按鈕
              InkWell(
                onTap: _clearLogs,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.clear_all,
                        size: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '清除',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 日誌內容區域
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: _testLogs.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 32,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '點擊開始測試查看詳細日誌',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
                  : Scrollbar(
                controller: _scrollController,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _testLogs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        _testLogs[index],
                        style: TextStyle(
                          color: _getLogColor(_testLogs[index]),
                          fontSize: 11,
                          fontFamily: 'Courier New',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // 底部狀態列
          if (_testLogs.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '共 ${_testLogs.length} 條記錄',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 新增：根據日誌內容返回相應顏色
  Color _getLogColor(String log) {
    if (log.contains('🚀') || log.contains('✅')) {
      return const Color(0xFF00EEFF); // 藍色 - 開始/完成
    } else if (log.contains('🏓')) {
      return const Color(0xFFFFE448); // 黃色 - Ping
    } else if (log.contains('📥') || log.contains('📊') && log.contains('Download')) {
      return const Color(0xFF00EEFF); // 藍色 - 下載
    } else if (log.contains('📤') || log.contains('📊') && log.contains('Upload')) {
      return const Color(0xFFFF6D2F); // 橘色 - 上傳
    } else if (log.contains('⚠️') || log.contains('❌')) {
      return const Color(0xFFFF6B6B); // 紅色 - 錯誤
    } else if (log.contains('🔄')) {
      return const Color(0xFF9747FF); // 紫色 - 重試
    } else {
      return Colors.white.withOpacity(0.8); // 預設白色
    }
  }

  // 新增：添加日誌
  void _addLog(String log) {
    setState(() {
      _testLogs.add('${DateTime.now().toString().substring(11, 19)} $log');
    });

    // 自動滾動到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // 新增：清除日誌
  void _clearLogs() {
    setState(() {
      _testLogs.clear();
    });
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              _showTestHistory();
            },
            icon: const Icon(Icons.history, size: 18),
            label: const Text('測試記錄'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              _showSettings();
            },
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('設定'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        // 技術資訊
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTechSpec('引擎', 'Cloudflare'),
                  _buildTechSpec('授權', 'MIT'),
                  _buildTechSpec('平台', 'Flutter'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 版權資訊
        Text(
          '© 2024 Speed Test Widget',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Powered by Cloudflare Speed Test API',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTechSpec(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showTestHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: 300,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.history,
                  color: Color(0xFF00EEFF),
                ),
                const SizedBox(width: 8),
                const Text(
                  '測試記錄',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '尚無測試記錄',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: 400,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.settings,
                  color: Color(0xFF9747FF),
                ),
                const SizedBox(width: 8),
                const Text(
                  '設定',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSettingItem(
              '自動測試',
              '開啟後將定期自動執行速度測試',
              false,
                  (value) {},
            ),
            _buildSettingItem(
              '詳細記錄',
              '保存更詳細的測試數據',
              true,
                  (value) {},
            ),
            _buildSettingItem(
              '通知',
              '測試完成後顯示通知',
              false,
                  (value) {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem(
      String title,
      String subtitle,
      bool value,
      Function(bool) onChanged,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF9747FF),
          ),
        ],
      ),
    );
  }
}

// main 函數保持不變
void main() {
  runApp(
    MaterialApp(
      title: '速度測試Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SpeedTestDemoPage(),
      debugShowCheckedModeBanner: false,
    ),
  );
}