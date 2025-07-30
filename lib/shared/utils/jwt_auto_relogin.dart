// lib/shared/utils/jwt_auto_relogin.dart
// 原本的 JWT 自動重新登入管理器 + 最小化網路功能添加 +網路問題處理

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:whitebox/shared/api/wifi_api/login_process.dart';
import 'package:whitebox/shared/api/wifi_api_service.dart';

// ==================== 🎯 配置模組 ====================
class NetworkRetryConfig {
  // 重試狀態控制配置
  static const Duration retryTimeout = Duration(seconds: 5);
  static const Duration retryDebounceTime = Duration(milliseconds: 1500);
  static const Duration snackBarDisplayTime = Duration(seconds: 1);
  static const Duration networkRestoredSnackBarTime = Duration(seconds: 2);

  // 按鈕狀態配置
  static const double disabledButtonOpacity = 0.5;
  static const Color retryButtonColor = Color(0xFF9747FF);
}

// ==================== 🎯 網路重試狀態管理服務 ====================
class NetworkRetryService {
  // 重試狀態控制
  bool _isRetrying = false;
  DateTime? _lastRetryTime;

  /// 檢查是否可以執行重試
  bool canRetry() {
    final now = DateTime.now();

    // 如果正在重試中，不允許新的重試
    if (_isRetrying) {
      print('🚫 重試進行中，忽略點擊');
      return false;
    }

    // 防抖處理：檢查與上次重試的時間間隔
    if (_lastRetryTime != null) {
      final timeSinceLastRetry = now.difference(_lastRetryTime!);
      if (timeSinceLastRetry < NetworkRetryConfig.retryDebounceTime) {
        print('🚫 重試太頻繁，忽略點擊 (間隔: ${timeSinceLastRetry.inMilliseconds}ms)');
        return false;
      }
    }

    return true;
  }

  /// 開始重試操作
  void startRetry() {
    _isRetrying = true;
    _lastRetryTime = DateTime.now();
    print('🔄 開始網路重試操作');
  }

  /// 完成重試操作
  void completeRetry() {
    _isRetrying = false;
    print('✅ 網路重試操作完成');
  }

  /// 檢查是否正在重試
  bool get isRetrying => _isRetrying;

  /// 重置重試狀態
  void reset() {
    _isRetrying = false;
    _lastRetryTime = null;
    print('🔄 重試狀態已重置');
  }
}

/// 🎯 網路連線狀態
enum NetworkStatus {
  connected,
  disconnected,
  unknown
}

// ==================== 🎯 增強的 JwtAutoRelogin 類別 ====================
class JwtAutoRelogin {
  static JwtAutoRelogin? _instance;
  static JwtAutoRelogin get instance => _instance ??= JwtAutoRelogin._();

  JwtAutoRelogin._();

  // ==================== 原本的 JWT 功能（不變） ====================
  String? _lastUsername;
  String? _lastPassword;
  bool _isRelogging = false;
  final List<Completer> _waitingCalls = [];

  // ==================== 🎯 增強的網路功能 ====================
  NetworkStatus _currentNetworkStatus = NetworkStatus.unknown;
  bool _isNetworkDialogShowing = false;
  GlobalKey<NavigatorState>? _navigatorKey;
  String? _initialRouteName;

  // 🎯 新增：網路重試服務
  final NetworkRetryService _retryService = NetworkRetryService();

  /// 新增：初始化導航器
  void initializeNavigator(GlobalKey<NavigatorState> navigatorKey, {String? initialRouteName}) {
    _navigatorKey = navigatorKey;
    _initialRouteName = initialRouteName ?? '/';
    print('🎯 JwtAutoRelogin: 導航器已初始化，初始路由: $_initialRouteName');
  }

  /// 🎯 新增：獲取當前網路狀態
  NetworkStatus get networkStatus => _currentNetworkStatus;

  /// 🎯 新增：更新網路狀態並處理彈窗
  void _updateNetworkStatus(NetworkStatus status) {
    if (_currentNetworkStatus != status) {
      final oldStatus = _currentNetworkStatus;
      _currentNetworkStatus = status;
      print('🌐 網路狀態變更: $oldStatus -> $status');
      _handleNetworkStatusChange(status);
    }
  }

  /// 🎯 新增：處理網路狀態變更
  void _handleNetworkStatusChange(NetworkStatus status) {
    switch (status) {
      case NetworkStatus.disconnected:
        if (!_isNetworkDialogShowing) {
          _showNetworkDisconnectedDialog();
        }
        break;
      case NetworkStatus.connected:
        if (_isNetworkDialogShowing) {
          _hideNetworkDisconnectedDialog();
        }
        // 🎯 新增：網路恢復時重置重試狀態
        _retryService.reset();
        break;
      case NetworkStatus.unknown:
        break;
    }
  }

  /// 🎯 改進：顯示網路斷線彈窗 - 添加動態按鈕狀態
  void _showNetworkDisconnectedDialog() {
    if (_isNetworkDialogShowing) return;

    final BuildContext? context = _navigatorKey?.currentContext;
    if (context == null) return;

    _isNetworkDialogShowing = true;
    print('📱 顯示網路斷線彈窗');

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return WillPopScope(
              onWillPop: () async => false,
              child: AlertDialog(
                backgroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1),
                ),
                title: Row(
                  children: [
                    Icon(Icons.wifi_off_rounded, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text(
                        'Network Connection Lost',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold
                        )
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Please check your network connection and try again.',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            height: 1.4
                        )
                    ),
                    SizedBox(height: 16),
                    Text(
                        '• Check your WiFi connection\n• Verify router connectivity\n• Restart network settings if needed',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                            height: 1.3
                        )
                    ),
                  ],
                ),
                actions: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => _goToInitialPage(context),
                          style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1
                                  )
                              )
                          ),
                          child: Text(
                              'Restart',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14
                              )
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextButton(
                          // 🎯 關鍵改進：根據重試狀態動態控制按鈕
                          onPressed: _retryService.isRetrying
                              ? null
                              : () => _retryNetworkConnection(context, setState),
                          style: TextButton.styleFrom(
                              backgroundColor: _retryService.isRetrying
                                  ? NetworkRetryConfig.retryButtonColor.withOpacity(0.1)
                                  : NetworkRetryConfig.retryButtonColor.withOpacity(0.2),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                      color: _retryService.isRetrying
                                          ? NetworkRetryConfig.retryButtonColor.withOpacity(0.3)
                                          : NetworkRetryConfig.retryButtonColor,
                                      width: 1
                                  )
                              )
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_retryService.isRetrying) ...[
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        NetworkRetryConfig.retryButtonColor.withOpacity(0.7)
                                    ),
                                  ),
                                ),
                                SizedBox(width: 6),
                              ],
                              Text(
                                  _retryService.isRetrying ? 'Checking...' : 'Retry',
                                  style: TextStyle(
                                      color: _retryService.isRetrying
                                          ? NetworkRetryConfig.retryButtonColor.withOpacity(0.7)
                                          : NetworkRetryConfig.retryButtonColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14
                                  )
                              ),
                            ],
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
      },
    );
  }

  /// 🎯 新增：隱藏網路斷線彈窗
  void _hideNetworkDisconnectedDialog() {
    final BuildContext? context = _navigatorKey?.currentContext;
    if (context != null && _isNetworkDialogShowing) {
      Navigator.of(context).pop();
      _isNetworkDialogShowing = false;

      // 🎯 重置重試狀態
      _retryService.reset();

      print('✅ 網路恢復，關閉斷線彈窗');
      _showNetworkRestoredSnackBar(context);
    }
  }

  /// 🎯 新增：顯示網路恢復提示
  void _showNetworkRestoredSnackBar(BuildContext context) {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.wifi, color: Colors.green, size: 16),
              SizedBox(width: 8),
              Text(
                  'Network connection restored',
                  style: TextStyle(color: Colors.white, fontSize: 14)
              ),
            ],
          ),
          backgroundColor: Colors.green.withOpacity(0.8),
          duration: NetworkRetryConfig.networkRestoredSnackBarTime,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)
          ),
        ),
      );
    } catch (e) {
      print('⚠️ 無法顯示網路恢復提示: $e');
    }
  }

  /// 🎯 新增：返回初始頁面
  void _goToInitialPage(BuildContext context) {
    try {
      Navigator.of(context).pop();
      _isNetworkDialogShowing = false;

      // 🎯 重置重試狀態
      _retryService.reset();

      _navigatorKey?.currentState?.pushNamedAndRemoveUntil(
          _initialRouteName ?? '/',
              (route) => false
      );
    } catch (e) {
      print('❌ 返回初始頁面失敗: $e');
    }
  }

  /// 🎯 改進：重試網路連線 - 添加併發控制和狀態更新
  void _retryNetworkConnection(BuildContext context, StateSetter setState) {
    // 🎯 關鍵改進：檢查是否可以執行重試
    if (!_retryService.canRetry()) {
      return;
    }

    print('🔄 開始重試網路連線檢測...');

    // 🎯 標記開始重試並更新 UI 狀態
    _retryService.startRetry();
    setState(() {}); // 更新彈窗中的按鈕狀態

    _performNetworkTest().then((isConnected) {
      // 🎯 完成重試操作
      _retryService.completeRetry();

      if (isConnected) {
        print('✅ 網路重試成功，連線已恢復');
        _updateNetworkStatus(NetworkStatus.connected);
      } else {
        print('❌ 網路重試失敗，仍無法連線');
        // 🎯 只有在重試確實失敗時才顯示失敗訊息
        _showRetryFailedMessage(context);
      }

      // 🎯 更新彈窗按鈕狀態
      if (mounted(context)) {
        setState(() {});
      }
    }).catchError((e) {
      print('❌ 網路重試發生異常: $e');

      // 🎯 完成重試操作
      _retryService.completeRetry();

      // 🎯 異常情況下也顯示失敗訊息
      _showRetryFailedMessage(context);

      // 🎯 更新彈窗按鈕狀態
      if (mounted(context)) {
        setState(() {});
      }
    });
  }

  /// 🎯 新增：檢查 BuildContext 是否仍然有效
  bool mounted(BuildContext context) {
    try {
      return context.mounted;
    } catch (e) {
      return false;
    }
  }

  /// 🎯 新增：執行網路測試
  Future<bool> _performNetworkTest() async {
    try {
      final result = await WifiApiService.getSystemDashboard()
          .timeout(NetworkRetryConfig.retryTimeout);

      if (result != null && !result.containsKey('error')) {
        return true;
      }
      return false;
    } catch (e) {
      print('🌐 網路測試異常: $e');
      return false;
    }
  }

  /// 🎯 改進：顯示重試失敗訊息 - 更簡潔的實現
  void _showRetryFailedMessage(BuildContext context) {
    try {
      // 🎯 確保在有效的 context 中顯示 SnackBar
      if (!mounted(context)) {
        print('⚠️ Context 無效，無法顯示重試失敗訊息');
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 16),
              SizedBox(width: 8),
              Text(
                  'Still unable to connect.',
                  style: TextStyle(color: Colors.white, fontSize: 12)
              ),
            ],
          ),
          backgroundColor: Colors.purple.withOpacity(0.8),
          duration: NetworkRetryConfig.snackBarDisplayTime,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)
          ),
        ),
      );
    } catch (e) {
      print('⚠️ 無法顯示重試失敗訊息: $e');
    }
  }

  /// 🎯 新增：檢查是否為網路斷線錯誤
  bool _isNetworkError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('socketexception') && errorStr.contains('network is unreachable') ||
        errorStr.contains('errno = 101') ||
        errorStr.contains('connection failed') && errorStr.contains('network is unreachable') ||
        errorStr.contains('no route to host') ||
        errorStr.contains('network unreachable') ||
        errorStr.contains('host unreachable');
  }

  /// 🎯 新增：檢查回應是否為網路斷線錯誤
  bool _isNetworkErrorResponse(dynamic response) {
    if (response is Map<String, dynamic>) {
      final errorStr = response['error']?.toString().toLowerCase() ?? '';
      final responseBody = response['response_body']?.toString().toLowerCase() ?? '';

      return _isNetworkError(errorStr) || _isNetworkError(responseBody);
    }
    return false;
  }

  // ==================== 原本的 JWT 功能（保持不變） ====================

  /// 初始化：儲存登入憑證
  void saveCredentials(String username, String password) {
    _lastUsername = username;
    _lastPassword = password;
    print('🔐 JWT 自動重新登入：已儲存登入憑證 ($username)');
  }

  /// 檢查錯誤是否為 JWT 相關
  bool isJwtError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('jwt') ||
        errorStr.contains('token') ||
        errorStr.contains('unauthorized') ||
        errorStr.contains('401') ||
        errorStr.contains('403') ||
        errorStr.contains('bearer') ||
        errorStr.contains('authentication') ||
        errorStr.contains('認證錯誤') ||
        errorStr.contains('invalid jwt') ||      // 🔥 新增：Invalid JWT
        errorStr.contains('jwt invalid') ||      // 🔥 新增：JWT invalid
        errorStr.contains('token invalid') ||    // 🔥 新增：Token invalid
        errorStr.contains('jwt expired') ||      // 🔥 新增：JWT expired
        errorStr.contains('token expired');      // 🔥 新增：Token expired
  }

  /// 檢查是否為臨時性錯誤（應該使用快取而非重新登入）
  bool isTemporaryError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('another api request is busy') ||
        errorStr.contains('api request is busy') ||
        errorStr.contains('busy') ||
        errorStr.contains('timeout') ||
        errorStr.contains('connection') ||
        errorStr.contains('network') ||
        errorStr.contains('請求超時') ||
        errorStr.contains('連線超時');
  }

  /// 檢查 API 回應是否包含臨時性錯誤
  bool isTemporaryErrorResponse(dynamic response) {
    if (response is Map<String, dynamic>) {
      // 檢查 error 欄位
      if (response.containsKey('error')) {
        final errorStr = response['error'].toString().toLowerCase();
        if (errorStr.contains('api request is busy') ||
            errorStr.contains('another api request is busy') ||
            errorStr.contains('busy') ||
            errorStr.contains('timeout') ||
            errorStr.contains('connection')) {
          return true;
        }
      }

      // 檢查 response_body 欄位中的錯誤
      if (response.containsKey('response_body')) {
        final responseBodyStr = response['response_body'].toString().toLowerCase();
        if (responseBodyStr.contains('another api request is busy') ||
            responseBodyStr.contains('api request is busy') ||
            responseBodyStr.contains('busy')) {
          return true;
        }
      }

      // 檢查 message 欄位
      if (response.containsKey('message')) {
        final messageStr = response['message'].toString().toLowerCase();
        if (messageStr.contains('another api request is busy') ||
            messageStr.contains('api request is busy') ||
            messageStr.contains('busy')) {
          return true;
        }
      }
    }

    return false;
  }

  /// 檢查 API 回應是否包含 JWT 錯誤
  bool isJwtErrorResponse(dynamic response) {
    if (response is Map<String, dynamic>) {
      // 檢查 error 欄位
      if (response.containsKey('error')) {
        final errorStr = response['error'].toString().toLowerCase();
        if (errorStr.contains('jwt') || errorStr.contains('token') ||
            errorStr.contains('unauthorized') || errorStr.contains('401') ||
            errorStr.contains('403')) {
          return true;
        }
      }

      // 🔥 修正：檢查 response_body 欄位中的 JWT 錯誤（擴展檢測範圍）
      if (response.containsKey('response_body')) {
        final responseBodyStr = response['response_body'].toString().toLowerCase();
        if (responseBodyStr.contains('jwt token has expired') ||
            responseBodyStr.contains('invalid jwt') ||  // 🔥 新增：Invalid JWT
            responseBodyStr.contains('jwt expired') ||
            responseBodyStr.contains('jwt invalid') ||  // 🔥 新增：JWT invalid
            responseBodyStr.contains('token expired') ||
            responseBodyStr.contains('token invalid') ||  // 🔥 新增：Token invalid
            (responseBodyStr.contains('jwt') && responseBodyStr.contains('expired')) ||
            (responseBodyStr.contains('jwt') && responseBodyStr.contains('invalid')) ||  // 🔥 新增
            (responseBodyStr.contains('token') && responseBodyStr.contains('expired')) ||
            (responseBodyStr.contains('token') && responseBodyStr.contains('invalid'))) {  // 🔥 新增
          return true;
        }
      }

      // 檢查狀態碼
      if (response.containsKey('status_code')) {
        final statusCode = response['status_code'].toString();
        if (statusCode == '401' || statusCode == '403') {
          return true;
        }
      }
    }

    return false;
  }

  /// 記錄 API 原始資料
  void logApiRawData(String apiName, dynamic rawData, {String? status}) {
    try {
      print('[API_DATA] 📊 $apiName ${status ?? "RAW_DATA"}');

      if (rawData == null) {
        print('[API_DATA]   💀 NULL_RESPONSE');
        return;
      }

      // 格式化輸出
      if (rawData is Map || rawData is List) {
        final jsonStr = const JsonEncoder.withIndent('  ').convert(rawData);
        _printApiDataInChunks(apiName, jsonStr);
      } else {
        final str = rawData.toString();
        if (str.length > 1000) {
          _printApiDataInChunks(apiName, str);
        } else {
          print('[API_DATA]   📄 $str');
        }
      }

      print('[API_DATA] 🏁 $apiName END');
    } catch (e) {
      print('[API_DATA] ❌ $apiName FORMAT_ERROR: $e');
    }
  }

  /// 分段輸出大型 API 資料
  void _printApiDataInChunks(String apiName, String content) {
    const int chunkSize = 800; // 每段 800 字符
    final int totalLength = content.length;
    final int totalChunks = (totalLength / chunkSize).ceil();

    print('[API_DATA]   📏 LENGTH: $totalLength, CHUNKS: $totalChunks');

    for (int i = 0; i < totalChunks; i++) {
      final int start = i * chunkSize;
      final int end = (start + chunkSize < totalLength) ? start + chunkSize : totalLength;
      final String chunk = content.substring(start, end);

      print('[API_DATA]   📋 CHUNK_${i + 1}/$totalChunks: $chunk');
    }
  }

  /// 包裝 API 調用，自動處理 JWT 過期和臨時錯誤，支援快取回退
  Future<T> wrapApiCallWithFallback<T>(
      Future<T> Function() apiCall,
      T? Function()? getCachedData,
      {String? debugInfo}
      ) async {
    // 如果正在重新登入，等待完成
    if (_isRelogging) {
      print('⏸️ API 調用等待重新登入完成... ${debugInfo ?? ""}');
      final completer = Completer<void>();
      _waitingCalls.add(completer);
      await completer.future;
    }

    try {
      final result = await apiCall();

      // 記錄成功的 API 原始資料
      if (debugInfo != null && _shouldLogApiData(debugInfo)) {
        logApiRawData(debugInfo, result, status: 'SUCCESS');
      }

      // 🎯 新增：檢查是否為網路錯誤
      if (_isNetworkErrorResponse(result)) {
        print('🌐❌ 檢測到網路錯誤，更新網路狀態: $result ${debugInfo ?? ""}');
        _updateNetworkStatus(NetworkStatus.disconnected);

        // 嘗試使用快取資料
        if (getCachedData != null) {
          final cachedData = getCachedData();
          if (cachedData != null) {
            print('📋 網路錯誤，使用快取資料 ${debugInfo ?? ""}');
            return cachedData;
          }
        }

        return result;
      }

      // 關鍵：檢查回應是否包含臨時性錯誤
      if (isTemporaryErrorResponse(result)) {
        print('⚠️ 檢測到臨時性錯誤，使用快取資料: $result ${debugInfo ?? ""}');

        // 嘗試使用快取資料
        if (getCachedData != null) {
          final cachedData = getCachedData();
          if (cachedData != null) {
            print('📋 使用快取資料避免錯誤顯示 ${debugInfo ?? ""}');
            return cachedData;
          }
        }

        // 如果沒有快取，仍返回錯誤結果但記錄日誌
        print('❌ 無快取資料可用，返回錯誤結果 ${debugInfo ?? ""}');
        return result;
      }

      // 檢查回應是否包含 JWT 錯誤
      if (isJwtErrorResponse(result)) {
        print('❌ 檢測到回應中的 JWT 錯誤: $result ${debugInfo ?? ""}');

        // 執行自動重新登入
        await _performAutoRelogin();

        // 重試 API 調用
        try {
          final retryResult = await apiCall();

          // 記錄重試成功的資料
          if (debugInfo != null && _shouldLogApiData(debugInfo)) {
            logApiRawData(debugInfo, retryResult, status: 'RETRY_SUCCESS');
          }

          return retryResult;
        } catch (retryError) {
          print('❌ 重新登入後仍然失敗: $retryError ${debugInfo ?? ""}');

          // 記錄重試失敗
          if (debugInfo != null && _shouldLogApiData(debugInfo)) {
            logApiRawData(debugInfo, retryError, status: 'RETRY_FAILED');
          }

          // JWT 重新登入失敗時也嘗試使用快取
          if (getCachedData != null) {
            final cachedData = getCachedData();
            if (cachedData != null) {
              print('📋 JWT 重新登入失敗，使用快取資料 ${debugInfo ?? ""}');
              return cachedData;
            }
          }

          throw retryError;
        }
      }

      // 🎯 新增：成功時更新網路狀態
      _updateNetworkStatus(NetworkStatus.connected);

      return result;
    } catch (e) {
      // 記錄異常
      if (debugInfo != null && _shouldLogApiData(debugInfo)) {
        logApiRawData(debugInfo, e, status: 'EXCEPTION');
      }

      print('❌ API 調用異常: $e ${debugInfo ?? ""}');

      // 🎯 新增：檢查是否為網路斷線異常
      if (_isNetworkError(e)) {
        print('🌐❌ 檢測到網路斷線異常，更新網路狀態: $e ${debugInfo ?? ""}');
        _updateNetworkStatus(NetworkStatus.disconnected);

        // 嘗試使用快取資料
        if (getCachedData != null) {
          final cachedData = getCachedData();
          if (cachedData != null) {
            print('📋 網路斷線，使用快取資料 ${debugInfo ?? ""}');
            return cachedData;
          }
        }

        throw e;
      }

      // 檢查是否為臨時性錯誤
      if (isTemporaryError(e)) {
        print('⚠️ 檢測到臨時性異常，使用快取資料 ${debugInfo ?? ""}');

        // 嘗試使用快取資料
        if (getCachedData != null) {
          final cachedData = getCachedData();
          if (cachedData != null) {
            print('📋 使用快取資料避免異常錯誤 ${debugInfo ?? ""}');
            return cachedData;
          }
        }
      }

      // 檢查是否為 JWT 相關錯誤
      if (isJwtError(e)) {
        print('❌ 檢測到 JWT 異常錯誤，開始自動重新登入: $e ${debugInfo ?? ""}');

        // 執行自動重新登入
        await _performAutoRelogin();

        // 重試 API 調用
        try {
          final retryResult = await apiCall();

          // 記錄重試成功的資料
          if (debugInfo != null && _shouldLogApiData(debugInfo)) {
            logApiRawData(debugInfo, retryResult, status: 'JWT_RETRY_SUCCESS');
          }

          return retryResult;
        } catch (retryError) {
          print('❌ 重新登入後仍然失敗: $retryError ${debugInfo ?? ""}');

          // 記錄重試失敗
          if (debugInfo != null && _shouldLogApiData(debugInfo)) {
            logApiRawData(debugInfo, retryError, status: 'JWT_RETRY_FAILED');
          }

          // JWT 重新登入失敗時也嘗試使用快取
          if (getCachedData != null) {
            final cachedData = getCachedData();
            if (cachedData != null) {
              print('📋 JWT 重新登入失敗，使用快取資料 ${debugInfo ?? ""}');
              return cachedData;
            }
          }

          throw retryError;
        }
      } else {
        // 其他錯誤，嘗試使用快取
        if (getCachedData != null) {
          final cachedData = getCachedData();
          if (cachedData != null) {
            print('📋 API 錯誤，使用快取資料: $e ${debugInfo ?? ""}');
            return cachedData;
          }
        }

        // 非 JWT 錯誤且無快取，直接拋出
        throw e;
      }
    }
  }

  /// 包裝 API 調用，自動處理 JWT 過期（保持向後兼容）
  Future<T> wrapApiCall<T>(Future<T> Function() apiCall, {String? debugInfo}) async {
    return wrapApiCallWithFallback<T>(apiCall, null, debugInfo: debugInfo);
  }

  /// 判斷是否應該記錄 API 資料
  bool _shouldLogApiData(String debugInfo) {
    final info = debugInfo.toLowerCase();
    return info.contains('dashboard') ||
        info.contains('mesh') ||
        info.contains('throughput');
  }

  /// 執行自動重新登入
  Future<void> _performAutoRelogin() async {
    // 防止重複執行
    if (_isRelogging) {
      print('🔄 已在重新登入中，等待完成...');
      while (_isRelogging) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    if (_lastUsername == null || _lastPassword == null) {
      print('❌ 無法自動重新登入：缺少儲存的登入憑證');
      throw Exception('JWT 過期且無法自動重新登入');
    }

    _isRelogging = true;

    try {
      print('🔐 開始自動重新登入...');
      print('👤 使用者：$_lastUsername');

      // 關鍵：使用現有的 LoginProcess
      final loginProcess = LoginProcess(
          _lastUsername!,
          _lastPassword!,
          baseUrl: WifiApiService.baseUrl
      );

      // 執行 SRP 登入流程
      final loginResult = await loginProcess.startSRPLoginProcess();

      if (loginResult.returnStatus && loginResult.session.jwtToken != null) {
        // 設置新的 JWT token
        WifiApiService.setJwtToken(loginResult.session.jwtToken!);

        print('✅ 自動重新登入成功');
        print('🔐 新 JWT Token 已設置');
      } else {
        print('❌ 自動重新登入失敗：${loginResult.msg}');
        throw Exception('自動重新登入失敗：${loginResult.msg}');
      }
    } catch (e) {
      print('❌ 重新登入過程中發生錯誤：$e');
      throw Exception('重新登入失敗：$e');
    } finally {
      _isRelogging = false;

      // 恢復所有等待的 API 請求
      _resumeWaitingCalls();
    }
  }

  /// 恢復等待中的 API 請求
  void _resumeWaitingCalls() {
    print('🚀 恢復 ${_waitingCalls.length} 個等待中的 API 請求');

    final completers = List<Completer>.from(_waitingCalls);
    _waitingCalls.clear();

    for (final completer in completers) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  // ==================== 🎯 清除和重置方法改進 ====================

  /// 清除憑證（登出時使用） - 增強版
  void clearCredentials() {
    _lastUsername = null;
    _lastPassword = null;
    _isRelogging = false;
    _currentNetworkStatus = NetworkStatus.unknown;

    // 🎯 重置網路重試狀態
    _retryService.reset();

    // 🎯 關閉可能顯示的網路彈窗
    if (_isNetworkDialogShowing) {
      _hideNetworkDisconnectedDialog();
    }

    // 完成所有等待的請求
    for (final completer in _waitingCalls) {
      if (!completer.isCompleted) {
        completer.completeError('登入憑證已清除');
      }
    }
    _waitingCalls.clear();

    print('🗑️ JWT 自動重新登入：已清除登入憑證、網路狀態和重試狀態');
  }

  /// 🎯 新增：檢查是否正在進行網路重試
  bool get isNetworkRetrying => _retryService.isRetrying;

  /// 🎯 新增：手動觸發網路狀態檢查 - 增強版
  Future<void> checkNetworkStatus() async {
    // 🎯 如果正在重試，則不執行新的檢查
    if (_retryService.isRetrying) {
      print('🚫 網路重試進行中，跳過狀態檢查');
      return;
    }

    try {
      final isConnected = await _performNetworkTest();
      _updateNetworkStatus(
          isConnected ? NetworkStatus.connected : NetworkStatus.disconnected
      );
    } catch (e) {
      print('❌ 手動網路檢查失敗: $e');
      _updateNetworkStatus(NetworkStatus.disconnected);
    }
  }

  /// 🎯 新增：手動設置網路狀態（供測試使用）
  void setNetworkStatus(NetworkStatus status) {
    _updateNetworkStatus(status);
  }
}