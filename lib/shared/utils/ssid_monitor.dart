// lib/shared/utils/ssid_monitor.dart
// 獨立的 SSID 連接監控器

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:whitebox/shared/api/wifi_api_service.dart';
import 'package:whitebox/shared/ui/pages/initialization/InitializationPage.dart';

/// SSID 監控狀態
enum SSIDMonitorStatus {
  idle,           // 閒置
  monitoring,     // 監控中
  disconnected,   // 檢測到斷線
}

/// 獨立的 SSID 連接監控器
/// 專門用於 Wizard 階段檢查是否連接到正確的 SSID
class SSIDMonitor {
  static SSIDMonitor? _instance;
  static SSIDMonitor get instance => _instance ??= SSIDMonitor._();

  SSIDMonitor._();

  // ==================== 監控狀態 ====================

  SSIDMonitorStatus _status = SSIDMonitorStatus.idle;
  String? _targetSSID;
  Timer? _monitorTimer;

  // ==================== 彈窗控制 ====================

  bool _isDialogShowing = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  //全域錯誤對話框狀態管理
  static bool _globalErrorDialogShowing = false;
  static bool _configurationFailed = false;
  // ==================== 監控配置 ====================

  // 檢查間隔（秒）
  static const int _checkIntervalSeconds = 3;

  // 連續失敗次數閾值（避免偶發性檢查失敗）
  static const int _failureThreshold = 3;
  int _consecutiveFailures = 0;

  // ==================== 新增：全域錯誤狀態管理方法 ====================

  /// 設置全域錯誤對話框狀態
  static void setGlobalErrorDialogShowing(bool showing) {
    _globalErrorDialogShowing = showing;
    print('🚨 SSIDMonitor: 全域錯誤對話框狀態設置為 $showing');
  }

  /// 設置配置失敗狀態
  static void setConfigurationFailed(bool failed) {
    _configurationFailed = failed;
    print('🚨 SSIDMonitor: 配置失敗狀態設置為 $failed');
  }

  /// 檢查是否可以顯示 SSID 錯誤對話框
  static bool canShowSSIDErrorDialog() {
    return !_globalErrorDialogShowing && !_configurationFailed;
  }

  /// 重置全域錯誤狀態
  static void resetGlobalErrorState() {
    _globalErrorDialogShowing = false;
    _configurationFailed = false;
    print('🔄 SSIDMonitor: 已重置全域錯誤狀態');
  }

  // ==================== 公開方法 ====================

  /// 初始化導航器（必須在使用前調用）
  void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    print('🔍 SSIDMonitor: 導航器已初始化');
  }

  /// 自動獲取 JwtAutoRelogin 中的導航器（如果已初始化）
  void _tryGetNavigatorFromJwt() {
    // 如果還沒有 navigatorKey，嘗試從 JwtAutoRelogin 獲取
    if (_navigatorKey == null) {
      // 這裡可以添加從 JwtAutoRelogin 獲取 navigatorKey 的邏輯
      // 或者直接使用 context.findRootAncestorStateOfType 等方法
    }
  }

  /// 開始監控指定的 SSID
  /// [targetSSID] 目標 SSID
  void startMonitoring(String targetSSID) {
    if (targetSSID.isEmpty) {
      print('⚠️ SSIDMonitor: 目標 SSID 為空，無法開始監控');
      return;
    }

    // 如果已在監控相同 SSID，直接返回
    if (_status == SSIDMonitorStatus.monitoring && _targetSSID == targetSSID) {
      print('🔍 SSIDMonitor: 已在監控 $targetSSID，跳過重複啟動');
      return;
    }

    // 停止之前的監控
    stopMonitoring();

    // 重置全域錯誤狀態（開始新的監控時）
    resetGlobalErrorState();

    // 開始新的監控
    _targetSSID = targetSSID;
    _status = SSIDMonitorStatus.monitoring;
    _consecutiveFailures = 0;

    print('🔍 SSIDMonitor: 開始監控 SSID: $targetSSID');
    print('🔍 SSIDMonitor: 檢查間隔: $_checkIntervalSeconds 秒');
    print('🔍 SSIDMonitor: 失敗閾值: $_failureThreshold 次');

    // 立即執行第一次檢查
    _performSSIDCheck();

    // 啟動定期檢查
    _startPeriodicCheck();
  }

  /// 停止監控
  void stopMonitoring() {
    if (_status == SSIDMonitorStatus.idle) return;

    print('🔍 SSIDMonitor: 停止監控 ${_targetSSID ?? "unknown"}');

    _status = SSIDMonitorStatus.idle;
    _targetSSID = null;
    _consecutiveFailures = 0;

    // 取消定時器
    _monitorTimer?.cancel();
    _monitorTimer = null;

    // 關閉可能顯示的彈窗
    _hideDisconnectedDialog();
  }

  /// 獲取當前監控狀態
  SSIDMonitorStatus get status => _status;

  /// 獲取目標 SSID
  String? get targetSSID => _targetSSID;

  /// 是否正在監控
  bool get isMonitoring => _status == SSIDMonitorStatus.monitoring;

  /// 是否正在顯示彈窗
  bool get isDialogShowing => _isDialogShowing;

  // ==================== 私有方法 ====================

  /// 啟動定期檢查
  void _startPeriodicCheck() {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(
      Duration(seconds: _checkIntervalSeconds),
          (timer) => _performSSIDCheck(),
    );
  }

  /// 執行 SSID 檢查
  Future<void> _performSSIDCheck() async {
    if (_status != SSIDMonitorStatus.monitoring || _targetSSID == null) {
      return;
    }

    if (_isDialogShowing) {
      // 如果彈窗已顯示，暫停檢查
      return;
    }

    try {
      print('🔍 SSIDMonitor: 檢查當前 SSID...');

      // 使用 WifiApiService 獲取當前 SSID
      final currentSSID = await WifiApiService.getCurrentWifiSSID()
          .timeout(Duration(seconds: 5)); // 5秒超時

      // 🆕 友好化日誌顯示
      String displayCurrentSSID = currentSSID;
      if (currentSSID == 'DefaultSSID') {
        displayCurrentSSID = 'Unconnected';
      } else if (currentSSID.isEmpty) {
        displayCurrentSSID = 'Not connected';
      }

      print('🔍 SSIDMonitor: 目標 SSID: $_targetSSID');
      print('🔍 SSIDMonitor: 當前 SSID: $displayCurrentSSID${currentSSID != displayCurrentSSID ? ' ($currentSSID)' : ''}');

      if (currentSSID == _targetSSID) {
        // SSID 匹配，重置失敗計數
        _consecutiveFailures = 0;
        print('✅ SSIDMonitor: SSID 匹配');
      } else {
        // SSID 不匹配
        _consecutiveFailures++;
        print('❌ SSIDMonitor: SSID 不匹配（連續失敗: $_consecutiveFailures/$_failureThreshold）');

        if (_consecutiveFailures >= _failureThreshold) {
          _handleSSIDDisconnected(currentSSID);
        }
      }

    } catch (e) {
      _consecutiveFailures++;
      print('❌ SSIDMonitor: 檢查 SSID 異常（連續失敗: $_consecutiveFailures/$_failureThreshold）: $e');

      if (_consecutiveFailures >= _failureThreshold) {
        _handleSSIDDisconnected(null, error: e.toString());
      }
    }
  }

  /// 處理 SSID 斷線事件
  void _handleSSIDDisconnected(String? currentSSID, {String? error}) {
    if (_status != SSIDMonitorStatus.monitoring) return;

    // 🆕 友好化日誌顯示
    String displayCurrentSSID;
    if (currentSSID == null || currentSSID.isEmpty) {
      displayCurrentSSID = 'Not connected';
    } else if (currentSSID == 'DefaultSSID') {
      displayCurrentSSID = 'Unconnected';
    } else {
      displayCurrentSSID = currentSSID;
    }

    print('🚨 SSIDMonitor: 檢測到 SSID 斷線');
    print('   目標: $_targetSSID');
    print('   當前: $displayCurrentSSID${currentSSID != null && currentSSID != displayCurrentSSID ? ' ($currentSSID)' : ''}');
    if (error != null) {
      print('   錯誤: $error');
    }

    _status = SSIDMonitorStatus.disconnected;

    // 顯示斷線彈窗
    _showDisconnectedDialog(currentSSID, error);
  }

  /// 顯示 SSID 斷線彈窗
  void _showDisconnectedDialog(String? currentSSID, String? error) {
    // 檢查全域錯誤狀態
    if (!canShowSSIDErrorDialog()) {
      print('⚠️ SSIDMonitor: 已有其他錯誤對話框或配置失敗，跳過 SSID 斷線對話框');
      return;
    }
    if (_isDialogShowing || _navigatorKey?.currentContext == null) return;

    final BuildContext context = _navigatorKey!.currentContext!;
    _isDialogShowing = true;

    // 設置全域錯誤對話框狀態
    setGlobalErrorDialogShowing(true);

    print('📱 SSIDMonitor: 顯示 SSID 斷線彈窗');

    // 🆕 友好化當前 SSID 顯示
    String displayCurrentSSID;
    if (currentSSID == null || currentSSID.isEmpty) {
      displayCurrentSSID = 'Not connected';
    } else if (currentSSID == 'DefaultSSID') {
      displayCurrentSSID = 'Unconnected';
    } else {
      displayCurrentSSID = currentSSID;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            backgroundColor: const Color(0xFF2A2A2A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: const Color(0xFF9747FF).withOpacity(0.5),
                width: 1,
              ),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  color: const Color(0xFFFF00E5),
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'WiFi Connection Lost',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lost connection to the configured WiFi network.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                if (_targetSSID != null) ...[
                  Text(
                    'Expected: $_targetSSID',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  // Text(
                  //   'Current: $displayCurrentSSID',
                  //   style: TextStyle(
                  //     color: Colors.white.withOpacity(0.8),
                  //     fontSize: 14,
                  //   ),
                  // ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Please check your WiFi connection and try again.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => _goToInitializationPage(dialogContext),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF9747FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Back to wifi list',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 隱藏斷線彈窗
  void _hideDisconnectedDialog() {
    if (!_isDialogShowing) return;

    final BuildContext? context = _navigatorKey?.currentContext;
    if (context != null) {
      try {
        Navigator.of(context).pop();
        print('🔍 SSIDMonitor: 已關閉斷線彈窗');
      } catch (e) {
        print('⚠️ SSIDMonitor: 關閉彈窗失敗: $e');
      }
    }

    _isDialogShowing = false;

    //重置全域錯誤對話框狀態
    setGlobalErrorDialogShowing(false);
  }

  /// 跳轉到初始化頁面
  void _goToInitializationPage(BuildContext dialogContext) {
    try {
      print('🔍 SSIDMonitor: 跳轉到 InitializationPage');

      // 關閉彈窗
      Navigator.of(dialogContext).pop();
      _isDialogShowing = false;

      // 重置全域錯誤對話框狀態
      setGlobalErrorDialogShowing(false);

      // 停止監控
      stopMonitoring();

      // 跳轉到初始化頁面
      _navigatorKey?.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const InitializationPage(),
        ),
            (route) => false, // 清除所有路由堆疊
      );

    } catch (e) {
      print('❌ SSIDMonitor: 跳轉失敗: $e');
    }
  }

  // ==================== 調試方法 ====================

  /// 手動觸發檢查（供調試使用）
  Future<void> manualCheck() async {
    print('🔍 SSIDMonitor: 手動觸發檢查');
    await _performSSIDCheck();
  }

  /// 獲取監控統計信息
  Map<String, dynamic> getMonitoringStats() {
    return {
      'status': _status.toString(),
      'targetSSID': _targetSSID,
      'consecutiveFailures': _consecutiveFailures,
      'isDialogShowing': _isDialogShowing,
      'checkInterval': _checkIntervalSeconds,
      'failureThreshold': _failureThreshold,
    };
  }

  /// 清理資源（應用關閉時調用）
  void dispose() {
    print('🔍 SSIDMonitor: 清理資源');
    stopMonitoring();
    _navigatorKey = null;
  }
}