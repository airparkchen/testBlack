// lib/shared/ui/pages/initialization/WifiSettingFlowPage.dart

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:wifi_iot/wifi_iot.dart';

import 'package:whitebox/shared/api/wifi_api_service.dart';
import 'package:whitebox/shared/models/StaticIpConfig.dart';
import 'package:whitebox/shared/ui/components/basic/AccountPasswordComponent.dart';
import 'package:whitebox/shared/ui/components/basic/ConnectionTypeComponent.dart';
import 'package:whitebox/shared/ui/components/basic/FinishingWizardComponent.dart';
import 'package:whitebox/shared/ui/components/basic/SetSSIDComponent.dart';
import 'package:whitebox/shared/ui/components/basic/StepperComponent.dart';
import 'package:whitebox/shared/ui/components/basic/SummaryComponent.dart';
import 'package:whitebox/shared/ui/pages/initialization/InitializationPage.dart';
import 'package:whitebox/shared/ui/pages/initialization/LoginPage.dart';
import 'package:whitebox/shared/theme/app_theme.dart';
import 'package:whitebox/shared/ui/components/basic/WifiScannerComponent.dart';

class WifiSettingFlowPage extends StatefulWidget {
  // 新增：總開關，用於繞過所有限制
  final bool bypassAllRestrictions;
  // 🔧 新增：控制資料保留的參數
  final bool preserveDataOnBack;
  final bool preserveDataOnNext;

  const WifiSettingFlowPage({
    super.key,
    this.bypassAllRestrictions = false, // 預設為 false，啟用所有限制
    this.preserveDataOnBack = true, // 🔧 預設為 true，保留返回時的資料
    this.preserveDataOnNext = true, // 🔧 預設為 true，保留前進時下一步的資料
  });

  @override
  State<WifiSettingFlowPage> createState() => _WifiSettingFlowPageState();
}

class _WifiSettingFlowPageState extends State<WifiSettingFlowPage> {
  final AppTheme _appTheme = AppTheme();

  bool _forceWPA3Only = true;  // 設為 true 時只有 WPA3 選項
  bool showDebugMessages = true; // 或設為 false 以關閉調試訊息
  //追蹤用戶是否已經修改過設置(DHCP/Static_IP/PPPOE)
  bool _userHasModifiedWanSettings = false;
  bool _isLoadingWanSettings = false;  // 🔧 新增：防重複載入標記
  // ==================== 模型與步驟控制 ====================
  String currentModel = 'Micky';
  int currentStepIndex = 0;
  bool isLastStepCompleted = false;
  bool isCurrentStepComplete = false;
  bool _isUpdatingStep = false;

  // ==================== 精靈狀態控制 ====================
  bool isShowingFinishingWizard = false;
  bool isLoading = true;

  // 完成精靈的步驟名稱
  final List<String> _processNames = [
    'Process 01', 'Process 02', 'Process 03', 'Process 04', 'Process 05',
  ];

  // ==================== 權限與限制 ====================
  // 檢查是否應該繞過限制
  bool get _shouldBypassRestrictions => widget.bypassAllRestrictions;

  // ==================== 認證與登入狀態 ====================
  bool isAuthenticated = false;
  String? jwtToken;
  String currentSSID = '';
  String calculatedPassword = '';
  bool isAuthenticating = false;
  bool hasInitialized = false;

  // ==================== 網路連線狀態 ====================
  bool isConnecting = false; // 追蹤 Wi-Fi 連線狀態

  // ==================== UI 動畫效果 ====================
  // 省略號動畫
  String _ellipsis = '';
  late Timer _ellipsisTimer;

  // ==================== 表單配置與靜態 IP 設定 ====================
  Map<String, dynamic> stepsConfig = {};
  StaticIpConfig staticIpConfig = StaticIpConfig();

  // ==================== 用戶帳號設定 ====================
  String userName = 'admin'; // 預設用戶名
  String password = '';
  String confirmPassword = '';

  // ==================== 網路連線設定 ====================
  String connectionType = 'DHCP';
  String pppoeUsername = '';
  String pppoePassword = '';

  // ==================== Wi-Fi 無線網路設定 ====================
  String ssid = '';
  String securityOption = 'WPA3 Personal';
  String ssidPassword = '';

  // ==================== 控制器 ====================
  late PageController _pageController;
  final StepperController _stepperController = StepperController();

  // ==================== 進度控制 ====================
  Function(double, {String? status})? _progressUpdateFunction;

  // ==================== 當前設定快取 ====================
  Map<String, dynamic> _currentWanSettings = {};
  Map<String, dynamic> _currentWirelessSettings = {};
  bool _isLoadingWirelessSettings = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _pageController = PageController(initialPage: currentStepIndex);
    _stepperController.addListener(_onStepperControllerChanged);
    _startEllipsisAnimation();

    print('🎯 WifiSettingFlowPage 初始化，當前配置的 SSID: ${WifiScannerComponent.configuredSSID}');

    // 修改：更完整的繞過限制處理
    if (_shouldBypassRestrictions) {
      // 如果繞過限制，直接設定為已認證並停止載入
      setState(() {
        isAuthenticated = true;
        hasInitialized = true;
        isLoading = false; // 重要：停止載入狀態
        isAuthenticating = false; // 停止認證動畫
      });
      print('繞過限制模式：已設定為認證完成狀態');
    } else if (!hasInitialized) {
      // 正常模式下才執行認證流程
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeAuthentication();
      });
    }
  }


  @override
  void dispose() {
    _pageController.dispose();
    _stepperController.removeListener(_onStepperControllerChanged);
    _stepperController.dispose();
    _ellipsisTimer.cancel();
    // 重置初始化狀態，以便下次進入頁面重新執行
    hasInitialized = false;
    super.dispose();
  }

//!!!!!!流程寫死的部分/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  // 在 _WifiSettingFlowPageState 類中添加這個方法
  Future<void> _changePassword() async {
    if (password.isEmpty) {
      _updateStatus("錯誤: 沒有設置新密碼");
      _updateStatus("錯誤: 沒有設置新密碼");
      return;
    }

    setState(() {
      isLoading = true;
      _updateStatus("正在更改密碼...");
    });

    try {
      _updateStatus("\n===== 開始變更密碼流程 =====");
      _updateStatus("用戶名: $userName");
      _updateStatus("新密碼: [已隱藏]");

      final result = await WifiApiService.changePasswordWithSRP(
          username: userName,
          newPassword: password
      );

      if (result['success']) {
        _updateStatus("密碼變更成功!");
        _updateStatus("密碼已成功變更");
      } else {
        _updateStatus("密碼變更失敗: ${result['message']}");
        _updateStatus("密碼變更失敗");
      }

      if (result['data'] != null) {
        _updateStatus("服務器響應: ${json.encode(result['data'])}");
      }

      _updateStatus("===== 變更密碼流程結束 =====");
    } catch (e) {
      _updateStatus("變更密碼過程中發生錯誤: $e");
      _updateStatus("變更密碼失敗");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future _initializeAuthentication() async {
    // 在方法開始就檢查是否要繞過
    if (_shouldBypassRestrictions) {
      setState(() {
        isAuthenticated = true;
        hasInitialized = true;
        isAuthenticating = false;
        isLoading = false;
        _updateStatus("Authentication bypassed");
      });
      return;
    }
    try {
      setState(() {
        isAuthenticating = true;
        _updateStatus("Initializing connection...");
      });

      // 模擬初始延遲
      await Future.delayed(const Duration(milliseconds: 200));

      // 步驟 1: 獲取當前 SSID
      setState(() {
        _updateStatus("Getting WiFi information...");
      });

      final ssid = await WifiApiService.getCurrentWifiSSID();

      // 早期 SSID 驗證
      if (ssid.isEmpty || ssid == "DefaultSSID") {
        setState(() {
          _updateStatus("Unable to get valid WiFi SSID");
        });
        _handleAuthenticationFailure("Unable to get valid WiFi SSID. Please confirm connection to router's WiFi");
        return;
      }

      setState(() {
        currentSSID = ssid;
        this.ssid = ssid;
        _updateStatus("WiFi information obtained: $ssid");
      });

      // 步驟間延遲
      await Future.delayed(const Duration(milliseconds: 200));

      // 步驟 2: 早期連接測試
      setState(() {
        _updateStatus("Testing router connection...");
      });

      // 步驟 3: 計算初始密碼（現在包含早期驗證）
      setState(() {
        _updateStatus("Calculating initial password...");
      });

      try {
        final password = await WifiApiService.calculatePasswordWithLogs(
          providedSSID: currentSSID,
        );

        setState(() {
          calculatedPassword = password;
          this.password = password;
          _updateStatus("Initial password calculated successfully");
        });
      } catch (e) {
        print('密碼計算錯誤: $e');

        // 🚨 檢查 API 繁忙相關錯誤 - 這些都應該觸發 "Login Too Frequent"
        if (e.toString().contains('SSID_UNKNOWN_ERROR') ||
            e.toString().contains('WiFi information unavailable due to API connection limits') ||
            e.toString().contains('Another API request is busy') ||
            e.toString().contains('請求失敗，狀態碼: 400') ||
            e.toString().contains('請求失敗，狀態碼: 500') ||
            e.toString().contains('無法從系統資訊獲取序列號') ||
            e.toString().contains('無法獲取計算密碼所需的系統資訊')) {
          print('🚨 檢測到 API 繁忙相關錯誤，顯示 Login Too Frequent 對話框');
          _handleFrequentApiCallError();
          return;
        }

        // 提供更友好的錯誤信息
        String errorMessage = "Password calculation failed";
        if (e.toString().contains('Unable to connect')) {
          errorMessage = "Unable to connect to router. Please check network connection";
        } else if (e.toString().contains('Serial number cannot be empty')) {
          errorMessage = "Unable to get router serial number. Please confirm connection to correct device";
        } else if (e.toString().contains('Login salt cannot be empty')) {
          errorMessage = "Unable to get login authentication information. Please check router status";
        }

        setState(() {
          _updateStatus(errorMessage);
        });
        _handleAuthenticationFailure(errorMessage);
        return;
      }

      // 步驟間延遲
      await Future.delayed(const Duration(milliseconds: 200));

      // 步驟 4: 執行登入
      setState(() {
        _updateStatus("Performing login...");
      });

      // 🔥 修改：不直接調用 performFullLogin，改為分步驟處理
      try {
        // 先嘗試 SRP 登入
        print("嘗試 SRP 登入方式...");
        final srpResult = await WifiApiService.loginWithSRP(userName, calculatedPassword);

        if (srpResult.success) {
          print("SRP 登入成功");
          setState(() {
            jwtToken = srpResult.jwtToken;
            isAuthenticated = true;
            _updateStatus("Login successful");
            hasInitialized = true;
          });

          if (jwtToken != null && jwtToken!.isNotEmpty) {
            WifiApiService.setJwtToken(jwtToken!);
          }
        } else {
          print("SRP 登入失敗，嘗試傳統登入");

          // 🚨 傳統登入時直接使用已計算的密碼，避免再次調用 calculatePasswordWithLogs
          try {
            final loginData = {
              'user': userName,
              'password': calculatedPassword,
            };

            final response = await WifiApiService.call('postUserLogin', loginData);

            // 檢查登入結果
            bool loginSuccess = false;
            String message = '登入失敗';

            if (response.containsKey('token')) {
              loginSuccess = true;
              message = '登入成功，獲取到 JWT 令牌';
              WifiApiService.setJwtToken(response['token']);
              jwtToken = response['token'];
            } else if (response.containsKey('jwt')) {
              loginSuccess = true;
              message = '登入成功，獲取到 JWT 令牌';
              WifiApiService.setJwtToken(response['jwt']);
              jwtToken = response['jwt'];
            } else if (response.containsKey('status') && response['status'] == 'success') {
              loginSuccess = true;
              message = '登入成功';
            }

            setState(() {
              if (loginSuccess) {
                isAuthenticated = true;
                _updateStatus("Login successful");
                hasInitialized = true;
              } else {
                _updateStatus("Login failed: $message");
                _handleAuthenticationFailure("Login failed: $message");
              }
            });

          } catch (traditionalLoginError) {
            print('傳統登入錯誤: $traditionalLoginError');

            // 🚨 檢查傳統登入中的 SSID UNKNOWN 錯誤
            if (traditionalLoginError.toString().contains('SSID_UNKNOWN_ERROR') ||
                traditionalLoginError.toString().contains('WiFi information unavailable due to API connection limits')) {
              print('🚨 傳統登入階段檢測到 SSID UNKNOWN 錯誤');
              _handleFrequentApiCallError();
              return;
            }

            setState(() {
              _updateStatus("Traditional login error: $traditionalLoginError");
            });
            _handleAuthenticationFailure("Traditional login error: $traditionalLoginError");
            return;
          }
        }

      } catch (loginError) {
        print('登入過程錯誤: $loginError');

        // 🚨 檢查登入過程中的 SSID UNKNOWN 錯誤
        if (loginError.toString().contains('SSID_UNKNOWN_ERROR') ||
            loginError.toString().contains('WiFi information unavailable due to API connection limits')) {
          print('🚨 登入過程檢測到 SSID UNKNOWN 錯誤');
          _handleFrequentApiCallError();
          return;
        }

        setState(() {
          _updateStatus("Login error: $loginError");
        });
        _handleAuthenticationFailure("Login error: $loginError");
        return;
      }

      await Future.delayed(const Duration(milliseconds: 200));

    } catch (e) {
      print('Error during authentication initialization: $e');

      // 🚨 最外層也檢查 SSID UNKNOWN 錯誤
      if (e.toString().contains('SSID_UNKNOWN_ERROR') ||
          e.toString().contains('WiFi information unavailable due to API connection limits')) {
        print('🚨 最外層檢測到 SSID UNKNOWN 錯誤');
        _handleFrequentApiCallError();
        return;
      }

      setState(() {
        _updateStatus("Initialization error: $e");
      });
      _handleAuthenticationFailure("Initialization error: $e");
    } finally {
      setState(() {
        isAuthenticating = false;
      });
    }
  }

// API頻繁 錯誤提示
  void _handleFrequentApiCallError() {
    if (!mounted) return;

    print('🚨 準備顯示頻繁 API 調用錯誤對話框');

    // 🔥 重要：停止認證動畫和載入狀態
    setState(() {
      isAuthenticating = false;
      isLoading = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
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
                Icons.warning_amber_outlined,
                color: const Color(0xFFFF00E5),
                size: 24,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Login Too Frequent',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Login attempts are too frequent. \nPlease wait a moment and try again.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                print('🚨 用戶點擊 OK，準備跳轉回 InitializationPage');
                Navigator.of(context).pop(); // 關閉對話框
                // 跳轉回 InitializationPage
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const InitializationPage(),
                  ),
                      (route) => false, // 清除所有路由堆疊
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9747FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  // 修改認證失敗處理
  void _handleAuthenticationFailure(String errorMessage) {
    if (_shouldBypassRestrictions) {
      setState(() {
        isAuthenticated = true;
        hasInitialized = true;
        isLoading = false;
      });
      return;
    }

    if (mounted) {
      // 🚨 檢查是否是登入頻繁錯誤，修改錯誤訊息
      String displayMessage = errorMessage;

      // 檢查各種登入頻繁相關的錯誤
      if (errorMessage.contains('登入失敗') ||
          errorMessage.contains('HTTPS POST 請求失敗: 500') ||
          errorMessage.contains('Another API request is busy') ||
          errorMessage.contains('請求失敗，狀態碼: 500') ||
          errorMessage.contains('請求失敗，狀態碼: 400') ||
          errorMessage.contains('無法從系統資訊獲取序列號') ||
          errorMessage.contains('無法獲取計算密碼所需的系統資訊') ||
          errorMessage.contains('Password calculation failed')) {
        displayMessage = 'Login requests are too frequent. \nPlease wait a moment and try again.';
      }

      showDialog(
        context: context,
        barrierDismissible: false, // 禁止點擊外部關閉
        builder: (BuildContext context) {
          return AlertDialog(
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
                  Icons.warning_amber_outlined, // 改為警告圖示
                  color: const Color(0xFFFF00E5),
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Authentication Failed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'Unable to complete initial authentication: \n$displayMessage',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            actions: <Widget>[
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const InitializationPage()),
                        (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9747FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _loadCurrentWanSettings() async {
    // 🔧 新增：防重複調用檢查
    if (_isLoadingWanSettings) {
      print('⚠️ WAN 設置正在載入中，跳過重複請求');
      return;
    }

    // 如果用戶已經修改過設置，不要覆蓋用戶的選擇
    if (_userHasModifiedWanSettings) {
      print('用戶已修改 WAN 設置，跳過 API 重新載入');
      return;
    }

    try {
      _isLoadingWanSettings = true;  // 🔧 新增：設置載入狀態

      setState(() {
        _updateStatus("Getting network settings...");
      });

      // 調用API獲取當前網絡設置
      final wanSettings = await WifiApiService.getWanEth();

      print('GET 獲取的完整 WAN 設置: ${json.encode(wanSettings)}');

      // 完整保存 GET 到的設置（包含所有字段和結構）
      _currentWanSettings = Map<String, dynamic>.from(wanSettings);

      String apiConnectionType = wanSettings['connection_type'] ?? 'dhcp';

      // 轉換為UI使用的格式
      String uiConnectionType;
      if (apiConnectionType == 'dhcp') {
        uiConnectionType = 'DHCP';
      } else if (apiConnectionType == 'static') {
        uiConnectionType = 'Static IP';
      } else if (apiConnectionType == 'pppoe') {
        uiConnectionType = 'PPPoE';
      } else {
        uiConnectionType = 'DHCP';
      }

      setState(() {
        _updateStatus("Network settings obtained");
        connectionType = uiConnectionType;

        // 根據API返回的設置更新UI狀態
        if (apiConnectionType == 'static') {
          staticIpConfig.ipAddress = wanSettings['static_ip']?['static_ip_addr'] ?? '';
          staticIpConfig.subnetMask = wanSettings['static_ip']?['static_ip_mask'] ?? '';
          staticIpConfig.gateway = wanSettings['static_ip']?['static_ip_gateway'] ?? '';
          staticIpConfig.primaryDns = wanSettings['dns']?['dns1'] ?? '';
          staticIpConfig.secondaryDns = wanSettings['dns']?['dns2'] ?? '';
        } else if (apiConnectionType == 'pppoe') {
          pppoeUsername = wanSettings['pppoe']?['username'] ?? '';
          pppoePassword = wanSettings['pppoe']?['password'] ?? '';
        }
      });

      print('UI 狀態已更新: connectionType=$connectionType');

    } catch (e) {
      print('獲取WAN設置時出錯: $e');
      setState(() {
        _updateStatus("Failed to get network settings: $e");
      });
    } finally {
      _isLoadingWanSettings = false;  // 🔧 新增：重置載入狀態
    }
  }
  // wireless/basic改動在這裡
  Future _loadWirelessSettings() async {
    try {
      setState(() {
        _isLoadingWirelessSettings = true;
        _updateStatus("正在獲取無線設置...");
      });

      // 調用API獲取當前無線設置
      final wirelessSettings = await WifiApiService.getWirelessBasic();

      setState(() {
        _currentWirelessSettings = wirelessSettings;
        _updateStatus("無線設置已獲取");

        if (wirelessSettings.containsKey('vaps') &&
            wirelessSettings['vaps'] is List &&
            wirelessSettings['vaps'].isNotEmpty) {

          final vap = wirelessSettings['vaps'][0];

          // 🔧 修正：只在沒有用戶輸入時才使用 API 的值
          if (vap.containsKey('ssid') && vap['ssid'] is String) {
            // 只在 ssid 為空時才設置（避免覆蓋用戶輸入）
            if (ssid.isEmpty) {
              ssid = vap['ssid'];
              print('設置SSID為: $ssid (從API)');
            } else {
              print('保留用戶輸入的SSID: $ssid');
            }
          }

          // 固定使用 WPA3 Personal
          securityOption = 'WPA3 Personal';

          if (vap.containsKey('password')) {
            if (vap['password'] is String) {
              // 🔧 修改：API 有密碼且不為空時才更新，否則保持預設值
              if (ssidPassword == '12345678' && vap['password'].isNotEmpty) {
                ssidPassword = vap['password'];
                print('更新為API密碼: 已設置，長度: ${ssidPassword.length} (從API)');
              } else if (ssidPassword.isEmpty) {
                ssidPassword = vap['password'].isNotEmpty ? vap['password'] : '12345678';
                print('設置密碼: 已設置，長度: ${ssidPassword.length}');
              } else {
                print('保留用戶輸入的WiFi密碼，長度: ${ssidPassword.length}');
              }
            }
          }
        }

        _isLoadingWirelessSettings = false;
      });
    } catch (e) {
      print('獲取無線設置時出錯: $e');
      setState(() {
        _updateStatus("獲取無線設置失敗: $e");
        _isLoadingWirelessSettings = false;
      });
    }
  }

  // 添加提交網絡設置的方法
  Future<void> _submitWanSettings() async {
    try {
      setState(() {
        _updateStatus("正在更新網絡設置...");
      });

      // 確保使用最新準備的設置
      _prepareWanSettingsForSubmission();

      print('即將提交的網絡設置: ${json.encode(_currentWanSettings)}');

      // 調用API提交網絡設置
      final result = await WifiApiService.updateWanEth(_currentWanSettings);

      print('網絡設置更新結果: ${json.encode(result)}');

      setState(() {
        _updateStatus("網絡設置已更新");
      });
    } catch (e) {
      print('提交WAN設置時出錯: $e');
      setState(() {
        _updateStatus("更新網絡設置失敗: $e");
      });
    }
  }

  Future<void> _submitWirelessSettings() async {
    try {
      setState(() {
        _updateStatus("正在更新無線設置...");
      });

      print('🔍 提交無線設置前的密碼確認:');
      print('  - 當前 ssidPassword 變數: "$ssidPassword"');

      // 準備無線設置提交數據
      Map<String, dynamic> wirelessConfig = {};

      // 保留原始結構中的其他字段
      if (_currentWirelessSettings.containsKey('wifi_mlo')) {
        wirelessConfig['wifi_mlo'] = _currentWirelessSettings['wifi_mlo'];
      }

      // 設置VAPs數組
      List<Map<String, dynamic>> vaps = [];

      if (_currentWirelessSettings.containsKey('vaps') &&
          _currentWirelessSettings['vaps'] is List &&
          _currentWirelessSettings['vaps'].isNotEmpty) {
        print("保留VAP結構，只更新值並修正數據類型");

        for (int i = 0; i < _currentWirelessSettings['vaps'].length; i++) {
          Map<String, dynamic> originalVap = Map<String, dynamic>.from(_currentWirelessSettings['vaps'][i]);

          if (i == 0) {
            // 既然只支援 WPA3，固定使用 'sae' 安全類型
            String apiSecurityType = 'sae'; // WPA3 Personal

            print('🔍 密碼同步檢查:');
            print('  - 當前 ssidPassword 變數: "$ssidPassword"');
            print('  - 原始 VAP 密碼: "${originalVap['password']}"');

            // 更新值
            originalVap['ssid'] = ssid;
            originalVap['security_type'] = apiSecurityType;
            originalVap['password'] = ssidPassword; // WPA3 需要密碼

            print('  - 更新後 VAP 密碼: "${originalVap['password']}"');
          }

          vaps.add(originalVap);
        }
      }
      else {
        print("創建新的VAP結構");
        Map<String, dynamic> newVap = {
          'vap_index': 1,
          'vap_type': 'primary',
          'vap_enabled': 'true',
          'security_type': 'sae', // WPA3 Personal
          'ssid': ssid,
          'password': ssidPassword
          // TODO: 未來 API 團隊會添加 band 字段支援，屆時需要在此處添加：
          // 'band': "2g", // 或 "5g", "6g" 根據需要
        };

        vaps.add(newVap);
      }

      wirelessConfig['vaps'] = vaps;

      if (wirelessConfig['vaps'] != null && wirelessConfig['vaps'].isNotEmpty) {
        print('🔍 最終密碼確認: "${wirelessConfig['vaps'][0]['password']}"');
      }

      print('即將提交的無線設置: ${json.encode(wirelessConfig)}');

      final result = await WifiApiService.updateWirelessBasic(wirelessConfig);
      print('無線設置更新結果: ${json.encode(result)}');

      // 在無線設置提交成功後，記錄配置的 SSID
      if (result != null && !result.containsKey('error')) {
        WifiScannerComponent.setConfiguredSSID(ssid);
        print('已記錄配置完成的 SSID: $ssid');
      }

      setState(() {
        _updateStatus("無線設置已更新");
      });
    } catch (e) {
      print('提交無線設置時出錯: $e');
      setState(() {
        _updateStatus("更新無線設置失敗: $e");
      });
    }
  }

  // 修改 WiFi 重連方法
  Future<void> _reconnectToWifi() async {
    if (_shouldBypassRestrictions) {
      // 繞過限制時，跳過 WiFi 連線檢查
      print('跳過 WiFi 連線（繞過限制模式）');
      setState(() {
        _updateStatus('Wi-Fi connection bypassed');
      });
      return;
    }

    // 原有的 WiFi 連線邏輯
    if (ssid.isEmpty || ssidPassword.isEmpty) {
      print('No SSID or password set, skipping Wi-Fi connection');
      _handleConnectionFailure('No SSID or password set');
      return;
    }
    setState(() {
      isConnecting = true;
      _updateStatus('Connecting to Wi-Fi...');
    });

    try {
      // 根據 securityOption 選擇安全類型
      NetworkSecurity getNetworkSecurity() {
        switch (securityOption) {
          case 'WPA3 Personal':
          case 'WPA2/WPA3 Personal':
            return NetworkSecurity.WPA;
          case 'WPA2 Personal':
            return NetworkSecurity.WPA;
          case 'no authentication':
            return NetworkSecurity.NONE;
          default:
            return NetworkSecurity.WPA;
        }
      }

      // 使用 wifi_iot 連接到 Wi-Fi，縮短超時時間為15秒
      bool? isConnected = await WiFiForIoTPlugin.connect(
        ssid,
        password: ssidPassword,
        security: getNetworkSecurity(),
        joinOnce: true,
        timeoutInSeconds: 15, // 縮短超時時間為15秒
      );

      if (isConnected != true) {
        setState(() {
          _updateStatus('Failed to connect to Wi-Fi');
        });
        _handleConnectionFailure('Failed to connect to Wi-Fi');
        return;
      }

      // 確認當前連線的 SSID
      String? currentWifiSSID = await WiFiForIoTPlugin.getWiFiAPSSID();
      if (currentWifiSSID != ssid) {
        setState(() {
          _updateStatus('Connected to wrong Wi-Fi network');
        });
        _handleConnectionFailure('Connected to wrong Wi-Fi network');
        return;
      }

      setState(() {
        _updateStatus('Wi-Fi connected successfully');
      });
    } catch (e) {
      print('Error connecting to Wi-Fi: $e');
      setState(() {
        _updateStatus('Error connecting to Wi-Fi: $e');
      });
      _handleConnectionFailure('Error connecting to Wi-Fi: $e');
    } finally {
      setState(() {
        isConnecting = false;
      });
    }
  }

// 修改連線失敗處理 - 顯示設定提示
  void _handleConnectionFailure(String errorMessage) {
    if (_shouldBypassRestrictions) {
      // 繞過限制時，不顯示錯誤，繼續流程
      print('連線失敗（已繞過）: $errorMessage');
      // 直接導航到 LoginPage
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
              (route) => false,
        );
      }
      return;
    }

    // 修改錯誤處理邏輯 - 提示用戶手動連接WiFi
    if (mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Wi-Fi Connection Failed'),
            content: const Text('Unable to connect to Wi-Fi automatically.\nPlease go to Settings to connect to Wi-Fi manually.'),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                        (route) => false,
                  );
                },
              ),
            ],
          );
        },
      );
    }
  }


  // 新增：執行配置並更新進度（保留所有原有 setState 邏輯）
  Future<void> _executeConfigurationWithProgress() async {
    if (_progressUpdateFunction == null) return;

    try {
      if (!_shouldBypassRestrictions) {
        // Step 1: 提交網路設定 (0% -> 10%)
        _progressUpdateFunction!(0.0, status: 'Submitting network settings...');
        await _submitWanSettings(); // 使用原有方法，保留所有 setState 邏輯
        _progressUpdateFunction!(10.0);
        await Future.delayed(const Duration(seconds: 1));

        // Step 2: 提交無線設定 (10% -> 20%)
        _progressUpdateFunction!(10.0, status: 'Submitting wireless settings...');
        await _submitWirelessSettings(); // 使用原有方法，保留所有 setState 邏輯
        _progressUpdateFunction!(20.0);
        await Future.delayed(const Duration(seconds: 1));

        // Step 3: 變更密碼 (20% -> 30%)
        if (password.isNotEmpty && confirmPassword.isNotEmpty && password == confirmPassword) {
          _progressUpdateFunction!(20.0, status: 'Changing user password...');
          await _changePassword(); // 使用原有方法，保留所有 setState 邏輯
          _progressUpdateFunction!(30.0);
          await Future.delayed(const Duration(seconds: 1));
        } else {
          _progressUpdateFunction!(30.0);
        }

        // Step 4: 完成配置 (30% -> 40%)
        _progressUpdateFunction!(30.0, status: 'Completing configuration...');
        await WifiApiService.configFinish();
        _progressUpdateFunction!(40.0, status: 'Applying settings, please wait...');
        await Future.delayed(const Duration(seconds: 1));

        // Step 5: 等待設定生效 (40% -> 100% 在 218 秒內完成)
        await _waitWithProgress();

      } else {
        // 繞過模式下，快速完成
        _progressUpdateFunction!(100.0, status: 'Configuration completed');
      }

    } catch (e) {
      print('配置過程中發生錯誤: $e');
      _progressUpdateFunction!(100.0, status: 'Configuration failed');

      // 保留原有的錯誤處理邏輯
      if (_shouldBypassRestrictions) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
          );
        }
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Setup Failed'),
                content: Text('Unable to complete setup: $e'),
                actions: <Widget>[
                  TextButton(
                    child: const Text('OK'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                            (route) => false,
                      );
                    },
                  ),
                ],
              );
            },
          );
        }
      }
    }
  }

// 新增：帶進度的等待方法
  Future<void> _waitWithProgress() async {
    const int totalWaitSeconds = 218; // 218 秒
    const int updateIntervalMs = 500; // 每 500 毫秒更新一次進度
    const int totalUpdates = totalWaitSeconds * 1000 ~/ updateIntervalMs;

    // 從 40% 到 100%，需要增加 60%
    const double progressIncrement = 60.0 / totalUpdates;

    double currentProgress = 40.0;

    for (int i = 0; i < totalUpdates && mounted; i++) {
      await Future.delayed(const Duration(milliseconds: updateIntervalMs));

      currentProgress += progressIncrement;
      if (currentProgress > 100.0) currentProgress = 100.0;

      // 計算剩餘時間
      int remainingSeconds = totalWaitSeconds - (i * updateIntervalMs ~/ 1000);
      String status = 'Applying settings... (${remainingSeconds}s remaining)';

      _progressUpdateFunction!(currentProgress, status: status);

      // 如果達到 100% 就提前結束
      if (currentProgress >= 100.0) break;
    }

    // 確保最終達到 100%
    _progressUpdateFunction!(100.0, status: 'Configuration completed');
  }

// 修改精靈完成處理 - 縮短等待時間
  void _handleWizardCompleted() async {
    print('🎯 _handleWizardCompleted 被調用');

    try {
      if (mounted) {
        print('🎯 導航到 InitializationPage 並標記需要自動搜尋');

        // 🔥 關鍵修改：導航時傳遞自動搜尋參數
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const InitializationPage(
              shouldAutoSearch: true, // 🔥 新增參數，表示需要自動搜尋
            ),
          ),
              (route) => false,
        );
      }
    } catch (e) {
      print('❌ 導航過程中發生錯誤: $e');
    }
  }

  // 省略號動畫
  void _startEllipsisAnimation() {
    _ellipsisTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        _ellipsis = _ellipsis.length < 3 ? _ellipsis + '.' : '';
      });
    });
  }

  // 更新狀態消息
  void _updateStatus(String message) {
    print('狀態更新: $message');
  }

  // 準備用於提交的WAN設置
  void _prepareWanSettingsForSubmission() {
    // 如果沒有獲取到當前設置，先獲取
    if (_currentWanSettings.isEmpty) {
      print('警告: 沒有當前的 WAN 設置，使用預設結構');
      _currentWanSettings = {
        'connection_type': 'dhcp',
        'static_ip': {'static_ip_addr': '', 'static_ip_mask': '', 'static_ip_gateway': ''},
        'pppoe': {'username': '', 'password': ''},
        'dns': {'dns1': '', 'dns2': ''}
      };
    }

    // 複製當前設置作為基礎（保持所有原有字段和結構）
    Map<String, dynamic> wanSettings = Map<String, dynamic>.from(_currentWanSettings);

    // 移除不需要 PUT 回去的字段（如果有的話）
    wanSettings.remove('message');
    wanSettings.remove('status_code');
    wanSettings.remove('wait_time');

    // print('原始 WAN 設置: ${json.encode(wanSettings)}');

    // 根據用戶選擇，只修改需要更改的字段
    if (connectionType == 'DHCP') {
      // 修改連接類型為 DHCP
      wanSettings['connection_type'] = 'dhcp';

      // 清空 static_ip 配置
      wanSettings['static_ip'] = {
        'static_ip_addr': '',
        'static_ip_mask': '',
        'static_ip_gateway': '',
      };

      // 清空 pppoe 配置
      wanSettings['pppoe'] = {
        'username': '',
        'password': '',
      };

      // DNS 設定（可選）
      if (staticIpConfig.primaryDns.isNotEmpty || staticIpConfig.secondaryDns.isNotEmpty) {
        wanSettings['dns'] = {
          'dns1': staticIpConfig.primaryDns.isNotEmpty ? staticIpConfig.primaryDns : '',
          'dns2': staticIpConfig.secondaryDns.isNotEmpty ? staticIpConfig.secondaryDns : '',
        };
      }

    } else if (connectionType == 'Static IP') {
      // 修改連接類型為 static
      wanSettings['connection_type'] = 'static';

      // 更新 static_ip 配置
      wanSettings['static_ip'] = {
        'static_ip_addr': staticIpConfig.ipAddress,
        'static_ip_mask': staticIpConfig.subnetMask,
        'static_ip_gateway': staticIpConfig.gateway,
      };

      // 清空 pppoe 配置
      wanSettings['pppoe'] = {
        'username': '',
        'password': '',
      };

      // 更新 DNS 設定
      wanSettings['dns'] = {
        'dns1': staticIpConfig.primaryDns.isNotEmpty ? staticIpConfig.primaryDns : '8.8.8.8',
        'dns2': staticIpConfig.secondaryDns.isNotEmpty ? staticIpConfig.secondaryDns : '8.8.4.4',
      };

    } else if (connectionType == 'PPPoE') {
      // 修改連接類型為 pppoe
      wanSettings['connection_type'] = 'pppoe';

      // 清空 static_ip 配置
      wanSettings['static_ip'] = {
        'static_ip_addr': '',
        'static_ip_mask': '',
        'static_ip_gateway': '',
      };

      // 更新 pppoe 配置
      wanSettings['pppoe'] = {
        'username': pppoeUsername,
        'password': pppoePassword,
      };

      // DNS 設定（可選）
      if (staticIpConfig.primaryDns.isNotEmpty || staticIpConfig.secondaryDns.isNotEmpty) {
        wanSettings['dns'] = {
          'dns1': staticIpConfig.primaryDns.isNotEmpty ? staticIpConfig.primaryDns : '',
          'dns2': staticIpConfig.secondaryDns.isNotEmpty ? staticIpConfig.secondaryDns : '',
        };
      }
    }

    // 保存設置以便後續提交
    _currentWanSettings = wanSettings;

    // print('修改後的 WAN 設置 (GET-修改-PUT模式): ${json.encode(wanSettings)}');
  }

  // 處理連接類型變更（增強版本）
  void _handleConnectionTypeChanged(String type, bool isComplete, StaticIpConfig? config, dynamic pppoeConfig) {
    setState(() {
      // 標記用戶已經修改過設置
      _userHasModifiedWanSettings = true;

      bool isTypeChanged = connectionType != type;

      connectionType = type;

      if (config != null) {
        staticIpConfig = config;
      } else if (isTypeChanged && type != 'Static IP') {
        staticIpConfig = StaticIpConfig();
      }

      if (pppoeConfig != null) {
        // 使用動態類型處理 PPPoE 配置
        if (pppoeConfig.runtimeType.toString().contains('PPPoEConfig')) {
          pppoeUsername = pppoeConfig.username;
          pppoePassword = pppoeConfig.password;
        }
      } else if (isTypeChanged && type != 'PPPoE') {
        pppoeUsername = '';
        pppoePassword = '';
      }

      // 重新驗證當前配置
      bool isCurrentConfigValid = false;
      if (type == 'DHCP') {
        isCurrentConfigValid = true; // DHCP 不需要額外配置
      } else if (type == 'Static IP') {
        isCurrentConfigValid = _isStaticIpConfigValid();
      } else if (type == 'PPPoE') {
        isCurrentConfigValid = _isPppoeConfigValid();
      }

      isCurrentStepComplete = isCurrentConfigValid;

      // 準備API提交格式
      _prepareWanSettingsForSubmission();

      print('連接類型更新 (用戶修改): 類型=$connectionType, 有效=$isCurrentStepComplete');
      if (type == 'Static IP') {
        print('靜態IP配置: IP=${staticIpConfig.ipAddress}, 子網掩碼=${staticIpConfig.subnetMask}, 網關=${staticIpConfig.gateway}');
      } else if (type == 'PPPoE') {
        print('PPPoE配置: 用戶名=$pppoeUsername');
      }
    });
  }

  // 增強的輸入驗證方法
  bool _isValidIpAddress(String ip) {
    if (ip.isEmpty) return false;

    // 使用 IPv4 正則表達式驗證
    final RegExp ipRegex = RegExp(
        r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
    );

    if (!ipRegex.hasMatch(ip)) return false;

    // 額外檢查：確保每個段都在 0-255 範圍內
    List<String> segments = ip.split('.');
    if (segments.length != 4) return false;

    for (String segment in segments) {
      int? value = int.tryParse(segment);
      if (value == null || value < 0 || value > 255) return false;
    }

    return true;
  }

// 子網掩碼驗證方法
  bool _isValidSubnetMask(String mask) {
    if (!_isValidIpAddress(mask)) return false;

    // 檢查是否為有效的子網掩碼
    List<String> segments = mask.split('.');
    List<int> bytes = segments.map((s) => int.parse(s)).toList();

    // 轉換為二進制並檢查是否為連續的1後跟連續的0
    String binary = '';
    for (int byte in bytes) {
      binary += byte.toRadixString(2).padLeft(8, '0');
    }

    // 檢查模式：應該是1...10...0或全1或全0
    if (!RegExp(r'^1*0*$').hasMatch(binary)) return false;

    return true;
  }

// 檢查 IP 是否在同一子網
  bool _isInSameSubnet(String ip1, String ip2, String mask) {
    if (!_isValidIpAddress(ip1) || !_isValidIpAddress(ip2) || !_isValidSubnetMask(mask)) {
      return false;
    }

    List<int> ip1Bytes = ip1.split('.').map((s) => int.parse(s)).toList();
    List<int> ip2Bytes = ip2.split('.').map((s) => int.parse(s)).toList();
    List<int> maskBytes = mask.split('.').map((s) => int.parse(s)).toList();

    for (int i = 0; i < 4; i++) {
      if ((ip1Bytes[i] & maskBytes[i]) != (ip2Bytes[i] & maskBytes[i])) {
        return false;
      }
    }

    return true;
  }

// PPPoE 用戶名驗證
  bool _isValidPppoeUsername(String username) {
    if (username.isEmpty) return false;
    if (username.length > 64) return false;

    // PPPoE 用戶名通常允許字母、數字、點、下劃線、連字符和@符號
    final RegExp usernameRegex = RegExp(r'^[a-zA-Z0-9._@-]+$');
    return usernameRegex.hasMatch(username);
  }

// PPPoE 密碼驗證
  bool _isValidPppoePassword(String password) {
    if (password.isEmpty) return false;
    if (password.length > 64) return false;

    // PPPoE 密碼允許大部分可打印字符，使用十六進制範圍定義
    // 包含: 空格(0x20) + 所有可打印字符(0x21-0x7E)
    final RegExp passwordRegex = RegExp(
        r'^[\x20-\x7E]+$'
    );
    return passwordRegex.hasMatch(password);
  }

//!!!!!!流程寫死的部分/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  // 步驟控制器監聽
  void _onStepperControllerChanged() {
    if (_isUpdatingStep) return;

    final newStep = _stepperController.currentStep;
    if (newStep != currentStepIndex) {
      _isUpdatingStep = true;
      setState(() {
        currentStepIndex = newStep;
        isCurrentStepComplete = false;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(newStep);
        }
      });
      _isUpdatingStep = false;
    }
  }

  // 載入配置
  Future<void> _loadConfig() async {
    try {
      setState(() => isLoading = true);

      final String configPath = 'lib/shared/config/flows/initialization/wifi.json';
      final String jsonContent = await rootBundle.loadString(configPath);

      setState(() {
        stepsConfig = json.decode(jsonContent);
        isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) => _syncStepperState());
    } catch (e) {
      print('載入配置出錯: $e');
      setState(() {
        isLoading = false;
        stepsConfig = {};
      });

      WidgetsBinding.instance.addPostFrameCallback((_) => _showErrorDialog());
    }
  }

  // 顯示錯誤對話框
  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('配置載入失敗'),
          content: const Text('無法載入設定流程，請確認 wifi.json 檔案是否存在並格式正確。'),
          actions: <Widget>[
            TextButton(
              child: const Text('確定'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  // 同步 Stepper 狀態
  void _syncStepperState() {
    _isUpdatingStep = true;
    _stepperController.jumpToStep(currentStepIndex);
    _isUpdatingStep = false;
  }

  // 更新當前步驟
  void _updateCurrentStep(int stepIndex) {
    if (_isUpdatingStep || stepIndex == currentStepIndex) return;

    _isUpdatingStep = true;
    setState(() {
      currentStepIndex = stepIndex;
      isCurrentStepComplete = false;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          stepIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      if (stepIndex < _getCurrentModelSteps().length - 1) {
        isLastStepCompleted = false;
      }
    });

    _stepperController.jumpToStep(stepIndex);
    _isUpdatingStep = false;
  }

  // 處理表單變更
  void _handleFormChanged(String user, String pwd, String confirmPwd, bool isValid) {
    setState(() {
      userName = user;
      password = pwd;
      confirmPassword = confirmPwd;
      isCurrentStepComplete = isValid;
    });
  }

  // 修改密碼驗證
  bool _validateForm() {
    if (_shouldBypassRestrictions) {
      // 繞過限制時，總是返回 true
      return true;
    }
    List<String> detailOptions = _getStepDetailOptions();

    if (detailOptions.isEmpty) {
      detailOptions = ['User', 'Password', 'Confirm Password'];
    }

    if (detailOptions.contains('User') && userName.isEmpty) {
      return false;
    }

    if (detailOptions.contains('Password')) {
      // 基本長度檢查
      if (password.isEmpty || password.length < 8 || password.length > 32) {
        return false;
      }

      // 檢查是否只包含合法字元
      final RegExp validChars = RegExp(
          r'^[\x21\x23-\x2F\x30-\x39\x3A-\x3B\x3D\x3F-\x40\x41-\x5A\x5B\x5D-\x60\x61-\x7A\x7B-\x7E]+$'
      );
      if (!validChars.hasMatch(password)) {
        return false;
      }

      // 新增的密碼複雜度要求
      // 檢查是否至少包含一個大寫字母
      final RegExp hasUppercase = RegExp(r'[A-Z]');
      if (!hasUppercase.hasMatch(password)) {
        return false;
      }

      // 檢查是否至少包含一個小寫字母
      final RegExp hasLowercase = RegExp(r'[a-z]');
      if (!hasLowercase.hasMatch(password)) {
        return false;
      }

      // 檢查是否至少包含一個數字
      final RegExp hasDigit = RegExp(r'[0-9]');
      if (!hasDigit.hasMatch(password)) {
        return false;
      }

      // 檢查是否至少包含一個特殊字元
      final RegExp hasSpecialChar = RegExp(r'[\x21\x23-\x2F\x3A-\x3B\x3D\x3F-\x40\x5B\x5D-\x60\x7B-\x7E]');
      if (!hasSpecialChar.hasMatch(password)) {
        return false;
      }
    }

    if (detailOptions.contains('Confirm Password') &&
        (confirmPassword.isEmpty || confirmPassword != password)) {
      return false;
    }

    return true;
  }

  // 獲取帳戶密碼錯誤訊息
  String _getAccountPasswordError(List<String> detailOptions) {
    if (detailOptions.contains('User') && userName.isEmpty) {
      return 'Please enter a username';
    } else if (detailOptions.contains('Password')) {
      if (password.isEmpty) {
        return 'Please enter a password';
      } else if (password.length < 8) {
        return 'Password must be at least 8 characters';
      } else if (password.length > 32) {
        return 'Password must be 32 characters or less';
      } else {
        // 檢查是否只包含合法字元
        final RegExp validChars = RegExp(
            r'^[\x21\x23-\x2F\x30-\x39\x3A-\x3B\x3D\x3F-\x40\x41-\x5A\x5B\x5D-\x60\x61-\x7A\x7B-\x7E]+$'
        );
        if (!validChars.hasMatch(password)) {
          return 'Password contains invalid characters';
        }

        // 新增的密碼複雜度錯誤信息
        // 檢查是否至少包含一個大寫字母
        final RegExp hasUppercase = RegExp(r'[A-Z]');
        if (!hasUppercase.hasMatch(password)) {
          return 'Password must contain at least one uppercase letter';
        }

        // 檢查是否至少包含一個小寫字母
        final RegExp hasLowercase = RegExp(r'[a-z]');
        if (!hasLowercase.hasMatch(password)) {
          return 'Password must contain at least one lowercase letter';
        }

        // 檢查是否至少包含一個數字
        final RegExp hasDigit = RegExp(r'[0-9]');
        if (!hasDigit.hasMatch(password)) {
          return 'Password must contain at least one digit';
        }

        // 檢查是否至少包含一個特殊字元
        final RegExp hasSpecialChar = RegExp(r'[\x21\x23-\x2F\x3A-\x3B\x3D\x3F-\x40\x5B\x5D-\x60\x7B-\x7E]');
        if (!hasSpecialChar.hasMatch(password)) {
          return 'Password must contain at least one special character';
        }
      }
    }

    if (detailOptions.contains('Confirm Password')) {
      if (confirmPassword.isEmpty) {
        return 'Please confirm your password';
      } else if (confirmPassword != password) {
        return 'Passwords do not match';
      }
    }

    return 'Please complete all required fields';
  }

  // 獲取當前步驟詳細選項
  List<String> _getStepDetailOptions() {
    List<String> detailOptions = [];
    final steps = _getCurrentModelSteps();

    if (steps.isNotEmpty && currentStepIndex < steps.length) {
      var currentStep = steps[currentStepIndex];
      if (currentStep.containsKey('detail')) {
        detailOptions = List<String>.from(currentStep['detail']);
      }
    }

    return detailOptions;
  }


  // 處理 SSID 表單變更（增強版本）
  void _handleSSIDFormChanged(String newSsid, String newSecurityOption, String newPassword, bool isValid) {
    setState(() {
      // 只有當值真正改變時才更新，避免無必要的重建
      if (ssid != newSsid || securityOption != newSecurityOption || ssidPassword != newPassword || isCurrentStepComplete != isValid) {
        ssid = newSsid;
        securityOption = newSecurityOption;
        ssidPassword = newPassword;
        isCurrentStepComplete = isValid;

        // Debug 輸出
        print('SSID 表單更新: SSID=$ssid, 安全選項=$securityOption, 密碼=${ssidPassword.isEmpty ? "空" : "已設置"}, 有效=$isValid');
      }
    });
  }

  // 確認並保存當前步驟資料
  void _confirmAndSaveCurrentStepData() {
    final currentComponents = _getCurrentStepComponents();

    // 確認帳戶密碼資料
    if (currentComponents.contains('AccountPasswordComponent')) {
      print('確認帳戶密碼資料: 用戶名=$userName, 密碼長度=${password.length}');
    }

    // 確認並準備WAN設置資料
    else if (currentComponents.contains('ConnectionTypeComponent')) {
      _prepareWanSettingsForSubmission();
      print('確認連接類型資料: 類型=$connectionType');
      if (connectionType == 'Static IP') {
        print('靜態IP: ${staticIpConfig.ipAddress}');
      } else if (connectionType == 'PPPoE') {
        print('PPPoE: 用戶名=$pppoeUsername');
      }
    }

    // 確認SSID設置資料
    else if (currentComponents.contains('SetSSIDComponent')) {
      print('確認SSID資料: SSID=$ssid, 安全選項=$securityOption, 密碼長度=${ssidPassword.length}');
    }
  }

  // 修改 handleNext 方法
  void _handleNext() {
    final steps = _getCurrentModelSteps();
    if (steps.isEmpty) return;
    final currentComponents = _getCurrentStepComponents();

    // 只對非最後一步進行表單驗證
    if (currentStepIndex < steps.length - 1) {
      // 如果不是繞過限制模式，才進行驗證
      if (!_shouldBypassRestrictions && !_validateCurrentStep(currentComponents)) {
        return;
      }

      _confirmAndSaveCurrentStepData();

      _isUpdatingStep = true;
      setState(() {
        currentStepIndex++;
        isCurrentStepComplete = _shouldBypassRestrictions ? true : false;
      });

      _reloadStepData(currentStepIndex);

      _stepperController.jumpToStep(currentStepIndex);
      _pageController.animateToPage(
        currentStepIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _isUpdatingStep = false;
    }
    else if (currentStepIndex == steps.length - 1 && !isLastStepCompleted) {
      _isUpdatingStep = true;
      setState(() {
        isLastStepCompleted = true;
        isShowingFinishingWizard = true;
      });
      _stepperController.jumpToStep(currentStepIndex);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _stepperController.notifyListeners();
      });
      _isUpdatingStep = false;
    }
  }

  // 修改表單驗證
  bool _validateCurrentStep(List<String> currentComponents) {
    if (_shouldBypassRestrictions) {
      // 繞過限制時，總是返回 true
      setState(() {
        isCurrentStepComplete = true;
      });
      return true;
    }
    // 檢查 AccountPasswordComponent
    if (currentComponents.contains('AccountPasswordComponent')) {
      if (!_validateForm()) {
        List<String> detailOptions = _getStepDetailOptions();
        if (detailOptions.isEmpty) {
          detailOptions = ['User', 'Password', 'Confirm Password'];
        }

        String errorMessage = _getAccountPasswordError(detailOptions);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
        return false;
      }
      setState(() {
        isCurrentStepComplete = true;
      });
    }

    // 檢查 ConnectionTypeComponent
    else if (currentComponents.contains('ConnectionTypeComponent')) {
      if (!isCurrentStepComplete) {
        String errorMessage = _getConnectionTypeError();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
        return false;
      }
    }

    // 檢查 SetSSIDComponent
    else if (currentComponents.contains('SetSSIDComponent')) {
      if (!isCurrentStepComplete) {
        String errorMessage = _getSSIDError();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
        return false;
      }
    }

    return true;
  }

  // 獲取連接類型錯誤訊息
  String _getConnectionTypeError() {
    if (connectionType == 'Static IP') {
      if (staticIpConfig.ipAddress.isEmpty) {
        return 'Please enter an IP address';
      } else if (!_isValidIpAddress(staticIpConfig.ipAddress)) {
        return 'Please enter a valid IP address (e.g., 192.168.1.100)';
      } else if (staticIpConfig.subnetMask.isEmpty) {
        return 'Please enter a subnet mask';
      } else if (!_isValidSubnetMask(staticIpConfig.subnetMask)) {
        return 'Please enter a valid subnet mask (e.g., 255.255.255.0)';
      } else if (staticIpConfig.gateway.isEmpty) {
        return 'Please enter a gateway address';
      } else if (!_isValidIpAddress(staticIpConfig.gateway)) {
        return 'Please enter a valid gateway address';
      } else if (!_isInSameSubnet(staticIpConfig.ipAddress, staticIpConfig.gateway, staticIpConfig.subnetMask)) {
        return 'IP address and gateway must be in the same subnet';
      } else if (staticIpConfig.primaryDns.isEmpty) {
        return 'Please enter a primary DNS server address';
      } else if (!_isValidIpAddress(staticIpConfig.primaryDns)) {
        return 'Please enter a valid primary DNS server address';
      } else if (staticIpConfig.secondaryDns.isNotEmpty && !_isValidIpAddress(staticIpConfig.secondaryDns)) {
        return 'Please enter a valid secondary DNS server address';
      }
    } else if (connectionType == 'PPPoE') {
      if (pppoeUsername.isEmpty) {
        return 'Please enter a PPPoE username';
      } else if (!_isValidPppoeUsername(pppoeUsername)) {
        return 'Username can only contain letters, numbers, dots, underscores, hyphens, and @ symbol';
      } else if (pppoePassword.isEmpty) {
        return 'Please enter a PPPoE password';
      } else if (!_isValidPppoePassword(pppoePassword)) {
        return 'Password contains invalid characters';
      }
    }

    return 'Please complete all required fields correctly';
  }

  bool _isStaticIpConfigValid() {
    if (connectionType != 'Static IP') return true;

    return staticIpConfig.ipAddress.isNotEmpty &&
        _isValidIpAddress(staticIpConfig.ipAddress) &&
        staticIpConfig.subnetMask.isNotEmpty &&
        _isValidSubnetMask(staticIpConfig.subnetMask) &&
        staticIpConfig.gateway.isNotEmpty &&
        _isValidIpAddress(staticIpConfig.gateway) &&
        _isInSameSubnet(staticIpConfig.ipAddress, staticIpConfig.gateway, staticIpConfig.subnetMask) &&
        staticIpConfig.primaryDns.isNotEmpty &&
        _isValidIpAddress(staticIpConfig.primaryDns) &&
        (staticIpConfig.secondaryDns.isEmpty || _isValidIpAddress(staticIpConfig.secondaryDns));
  }

  bool _isPppoeConfigValid() {
    if (connectionType != 'PPPoE') return true;

    return pppoeUsername.isNotEmpty &&
        _isValidPppoeUsername(pppoeUsername) &&
        pppoePassword.isNotEmpty &&
        _isValidPppoePassword(pppoePassword);
  }

  // 獲取 SSID 錯誤訊息
  String _getSSIDError() {
    // 驗證 SSID
    if (ssid.isEmpty) {
      return 'Please enter an SSID';
    } else if (ssid.length > 32) {
      return 'SSID must be 32 characters or less';
    } else {
      // 驗證 SSID 字符
      final RegExp validChars = RegExp(
          r'^[\x21\x23-\x2F\x30-\x39\x3A-\x3B\x3D\x3F-\x40\x41-\x5A\x5B\x5D-\x60\x61-\x7A\x7B-\x7E]+$'
      );
      if (!validChars.hasMatch(ssid)) {
        return 'SSID contains invalid characters';
      }
    }

    // 驗證密碼
    if (securityOption != 'no authentication' && securityOption != 'Enhanced Open (OWE)') {
      if (ssidPassword.isEmpty) {
        return 'Please enter a password';
      } else if (ssidPassword.length < 8) {
        return 'Password must be at least 8 characters';
      } else if (ssidPassword.length > 64) {
        return 'Password must be 64 characters or less';
      } else {
        // 驗證密碼字符
        final RegExp validChars = RegExp(
            r'^[\x21\x23-\x2F\x30-\x39\x3A-\x3B\x3D\x3F-\x40\x41-\x5A\x5B\x5D-\x60\x61-\x7A\x7B-\x7E]+$'
        );
        if (!validChars.hasMatch(ssidPassword)) {
          return 'Password contains invalid characters';
        }
      }
    }

    return 'Please complete all required fields';
  }

  // 清理當前步驟的資料
  void _clearCurrentStepData() {
    // 🔧 新增：檢查是否要保留返回時的資料
    if (widget.preserveDataOnBack) {
      print('🔧 保留返回時的資料，跳過清理當前步驟資料');
      return;
    }

    final currentComponents = _getCurrentStepComponents();

    // 清理帳戶密碼相關資料
    if (currentComponents.contains('AccountPasswordComponent')) {
      setState(() {
        userName = 'admin'; // 重置為預設值
        password = '';
        confirmPassword = '';
        isCurrentStepComplete = false; // 重要：重置完成狀態
      });
      print('已清理帳戶密碼資料，重置完成狀態為 false');
    }

    // 清理連接類型相關資料
    else if (currentComponents.contains('ConnectionTypeComponent')) {
      setState(() {
        connectionType = 'DHCP'; // 重置為預設值
        staticIpConfig = StaticIpConfig(); // 重置靜態IP配置
        pppoeUsername = '';
        pppoePassword = '';
        _currentWanSettings = {}; // 清空當前WAN設置
        isCurrentStepComplete = false; // 重要：重置完成狀態
      });
      print('已清理連接類型資料，重置完成狀態為 false');
    }

    // 清理SSID相關資料
    else if (currentComponents.contains('SetSSIDComponent')) {
      setState(() {
        ssid = ''; // 清空SSID
        securityOption = 'WPA3 Personal'; // 重置為預設值
        ssidPassword = ''; // 清空WiFi密碼
        _currentWirelessSettings = {}; // 清空當前無線設置
        _isLoadingWirelessSettings = false; // 重置載入狀態
        isCurrentStepComplete = false; // 重要：重置完成狀態
      });
      print('已清理SSID設置資料，重置完成狀態為 false');
    }

    // 清理摘要相關狀態（如果有的話）
    else if (currentComponents.contains('SummaryComponent')) {
      setState(() {
        isCurrentStepComplete = false; // 摘要頁面也重置狀態
      });
      print('摘要頁面，重置完成狀態為 false');
    }
  }

  void _clearNextStepData() {
    // 🔧 新增：檢查是否要保留前進時下一步的資料
    if (widget.preserveDataOnNext) {
      print('🔧 保留前進時下一步的資料，跳過清理');
      return;
    }

    final nextStepIndex = currentStepIndex;
    if (nextStepIndex >= _getCurrentModelSteps().length) return;

    final nextComponents = _getCurrentStepComponents(stepIndex: nextStepIndex);

    // 清理下一步的帳戶密碼相關資料
    if (nextComponents.contains('AccountPasswordComponent')) {
      setState(() {
        userName = 'admin'; // 重置為預設值
        password = '';
        confirmPassword = '';
      });
      if (showDebugMessages) {
        print('🗑️ 已清理下一步的帳戶密碼資料');
      }
    }

    // 清理下一步的連接類型相關資料
    else if (nextComponents.contains('ConnectionTypeComponent')) {
      setState(() {
        connectionType = 'DHCP'; // 重置為預設值
        staticIpConfig = StaticIpConfig(); // 重置靜態IP配置
        pppoeUsername = '';
        pppoePassword = '';
        _currentWanSettings = {}; // 清空當前WAN設置
        _userHasModifiedWanSettings = false; // 重置修改標記
      });
      if (showDebugMessages) {
        print('🗑️ 已清理下一步的連接類型資料');
      }
    }

    // 清理下一步的SSID相關資料
    else if (nextComponents.contains('SetSSIDComponent')) {
      setState(() {
        ssid = ''; // 清空SSID
        securityOption = 'WPA3 Personal'; // 重置為預設值
        ssidPassword = ''; // 清空WiFi密碼
        _currentWirelessSettings = {}; // 清空當前無線設置
        _isLoadingWirelessSettings = false; // 重置載入狀態
      });
      if (showDebugMessages) {
        print('🗑️ 已清理下一步的SSID設置資料');
      }
    }
  }

  void _revalidateCurrentStepDataAfterBack() {
    final currentComponents = _getCurrentStepComponents();

    // 重新驗證帳戶密碼資料
    if (currentComponents.contains('AccountPasswordComponent')) {
      bool isValid = _validateForm();
      setState(() {
        isCurrentStepComplete = isValid;
      });
      print('🔍 返回後重新驗證帳戶密碼資料: 有效=$isValid');
      print('  - 用戶名: $userName');
      print('  - 密碼長度: ${password.length}');
      print('  - 確認密碼長度: ${confirmPassword.length}');
    }

    // 重新驗證連接類型資料
    else if (currentComponents.contains('ConnectionTypeComponent')) {
      bool isValid = false;
      if (connectionType == 'DHCP') {
        isValid = true; // DHCP 不需要額外配置
      } else if (connectionType == 'Static IP') {
        isValid = _isStaticIpConfigValid();
      } else if (connectionType == 'PPPoE') {
        isValid = _isPppoeConfigValid();
      }
      setState(() {
        isCurrentStepComplete = isValid;
      });
      print('🔍 返回後重新驗證連接類型資料: 類型=$connectionType, 有效=$isValid');
      if (connectionType == 'Static IP') {
        print('  - IP: ${staticIpConfig.ipAddress}');
        print('  - 子網掩碼: ${staticIpConfig.subnetMask}');
        print('  - 網關: ${staticIpConfig.gateway}');
        print('  - 主要DNS: ${staticIpConfig.primaryDns}');
      } else if (connectionType == 'PPPoE') {
        print('  - 用戶名: $pppoeUsername');
        print('  - 密碼長度: ${pppoePassword.length}');
      }
    }

    // 重新驗證SSID設置資料
    else if (currentComponents.contains('SetSSIDComponent')) {
      bool isValid = _validateSSIDData();
      setState(() {
        isCurrentStepComplete = isValid;
      });
      print('🔍 返回後重新驗證SSID設置資料: SSID=$ssid, 安全選項=$securityOption, 有效=$isValid');
      print('  - SSID長度: ${ssid.length}');
      print('  - 密碼長度: ${ssidPassword.length}');
    }

    // 重新驗證摘要資料
    else if (currentComponents.contains('SummaryComponent')) {
      setState(() {
        isCurrentStepComplete = true; // 摘要頁面通常都是有效的
      });
      print('🔍 摘要頁面，設定為有效');
    }
  }

  // 重新載入指定步驟的資料
  void _reloadStepData(int stepIndex) {
    final components = _getCurrentStepComponents(stepIndex: stepIndex);

    // 重新載入連接類型資料 - 只在用戶未修改時
    if (components.contains('ConnectionTypeComponent') && !_userHasModifiedWanSettings) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCurrentWanSettings();
      });
      print('重新載入連接類型資料 (僅限首次)');
    }

    // 重新載入無線設置資料
    else if (components.contains('SetSSIDComponent')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadWirelessSettings();
      });
      print('重新載入無線設置資料');
    }
  }

  // 處理返回操作 - 增強版本，包含狀態清理
  void _handleBack() {
    if (currentStepIndex > 0) {
      // 如果不是第一步，則回到上一步
      _isUpdatingStep = true;

      setState(() {
        currentStepIndex--;
        isCurrentStepComplete = false; // 先重置當前狀態
        isLastStepCompleted = false; // 重置最後一步完成狀態
      });

      // 🔧 修改：根據設定決定是否清理資料
      if (!widget.preserveDataOnBack) {
        // 清理上一步的數據（現在的當前步驟）
        _clearCurrentStepData();

        // 回到上一步後，重新載入該步驟的資料
        _reloadStepData(currentStepIndex);
      } else {
        // 🔧 新增：如果保留資料，重新驗證當前步驟的完成狀態
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _revalidateCurrentStepDataAfterBack();
        });
      }

      _stepperController.jumpToStep(currentStepIndex);
      _pageController.animateToPage(
        currentStepIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _isUpdatingStep = false;
    } else {
      // 如果是第一步，則回到上一個頁面
      Navigator.of(context).pop();
    }
  }

  // 獲取當前模型步驟
  List<dynamic> _getCurrentModelSteps() {
    if (stepsConfig.isEmpty ||
        !stepsConfig.containsKey('models') ||
        !stepsConfig['models'].containsKey(currentModel) ||
        !stepsConfig['models'][currentModel].containsKey('steps')) {
      return [];
    }
    return stepsConfig['models'][currentModel]['steps'];
  }

  // 獲取當前步驟組件
  List<String> _getCurrentStepComponents({int? stepIndex}) {
    final index = stepIndex ?? currentStepIndex;
    final steps = _getCurrentModelSteps();
    if (steps.isEmpty || index >= steps.length) {
      return [];
    }
    var currentStep = steps[index];
    if (!currentStep.containsKey('components')) {
      return [];
    }
    return List<String>.from(currentStep['components']);
  }

  @override
  String _getCurrentStepName() {
    final steps = _getCurrentModelSteps();
    if (steps.isNotEmpty && currentStepIndex < steps.length) {
      return steps[currentStepIndex]['name'] ?? 'Step ${currentStepIndex + 1}';
    }
    return 'Step ${currentStepIndex + 1}';
  }

  // 修改 _createComponentByName 方法，為所有組件傳遞高度
  Widget? _createComponentByName(String componentName) {
    List<String> detailOptions = _getStepDetailOptions();
    final screenSize = MediaQuery.of(context).size;

    // 為所有組件設置的共同高度比例
    final componentHeightRatio = 0.45;
    final componentHeight = screenSize.height * componentHeightRatio;

    switch (componentName) {
      case 'AccountPasswordComponent':
        return AccountPasswordComponent(
          displayOptions: detailOptions.isNotEmpty ? detailOptions : const [
            'User',
            'Password',
            'Confirm Password'
          ],
          onFormChanged: _handleFormChanged,
          onNextPressed: _handleNext,
          onBackPressed: _handleBack,
          height: componentHeight,
          // 🔧 新增：傳遞初始密碼值
          initialPassword: password.isNotEmpty ? password : null,
          initialConfirmPassword: confirmPassword.isNotEmpty ? confirmPassword : null,
        );

      case 'ConnectionTypeComponent':
      // 在創建組件前，確保已調用獲取網絡設置的方法
        if (_currentWanSettings.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadCurrentWanSettings();
          });
        }

        // 明確指定連接類型選項，不依賴 detailOptions
        List<String> connectionTypeOptions = ['DHCP', 'Static IP', 'PPPoE'];

        return ConnectionTypeComponent(
          displayOptions: connectionTypeOptions,
          initialConnectionType: connectionType,
          initialStaticIpConfig: connectionType == 'Static IP'
              ? staticIpConfig
              : null,
          initialPppoeUsername: pppoeUsername,
          initialPppoePassword: pppoePassword,
          onSelectionChanged: _handleConnectionTypeChanged,
          onNextPressed: _handleNext,
          onBackPressed: _handleBack,
          height: componentHeight,
        );

      case 'SetSSIDComponent':
      // 🔧 新增：確保第一次進入時有預設密碼
        if (ssidPassword.isEmpty) {
          ssidPassword = '12345678';
          print('🔧 設置初始預設密碼: $ssidPassword');
        }
      // 在創建組件前，確保已調用獲取無線設置的方法
        if (_currentWirelessSettings.isEmpty && !_isLoadingWirelessSettings) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadWirelessSettings();
          });
        }

        // 明確指定安全選項，不依賴 detailOptions
        List<String> securityOptions = _forceWPA3Only
            ? ['WPA3 Personal']  // 只有 WPA3
            : [                  // 完整選項
          'no authentication',
          'Enhanced Open (OWE)',
          'WPA2 Personal',
          'WPA3 Personal',
          'WPA2/WPA3 Personal',
          'WPA2 Enterprise'
        ];

        // 如果當前 securityOption 不在有效選項中，重置為預設值
        if (!securityOptions.contains(securityOption)) {
          print('當前安全選項 "$securityOption" 不在安全選項中，重置為 WPA3 Personal');
          securityOption = 'WPA3 Personal';
        }

        return SetSSIDComponent(
          displayOptions: securityOptions,
          initialSsid: ssid,
          initialSecurityOption: securityOption,
          initialPassword: ssidPassword,
          onFormChanged: _handleSSIDFormChanged,
          onNextPressed: _handleNext,
          onBackPressed: _handleBack,
          height: componentHeight,
        );

      case 'SummaryComponent':
        return SummaryComponent(
          username: userName,
          connectionType: connectionType,
          ssid: ssid,
          securityOption: securityOption,
          password: password,
          staticIpConfig: connectionType == 'Static IP' ? staticIpConfig : null,
          pppoeUsername: connectionType == 'PPPoE' ? pppoeUsername : null,
          pppoePassword: connectionType == 'PPPoE' ? pppoePassword : null,
          onNextPressed: _handleNext,
          onBackPressed: _handleBack,
          height: componentHeight,
        );

      default:
        print('不支援的組件名稱: $componentName');
        return null;
    }
  }

  bool _validateSSIDData() {
    // 驗證 SSID
    if (ssid.isEmpty) {
      print('❌ SSID 驗證失敗: SSID 為空');
      return false;
    }

    if (ssid.length > 32) {
      print('❌ SSID 驗證失敗: SSID 長度超過 32 字元');
      return false;
    }

    // // 🔧 新增：檢查 SSID 長度（32 字節限制）
    // if (ssid.length > 32) {
    //   print('❌ SSID 驗證失敗: SSID 長度超過 32 字元 (當前: ${ssid.length})');
    //   return false;
    // }

    // 驗證 SSID 字符
    final RegExp validChars = RegExp(
        r'^[\x21\x23-\x2F\x30-\x39\x3A-\x3B\x3D\x3F-\x40\x41-\x5A\x5B\x5D-\x60\x61-\x7A\x7B-\x7E]+$'
    );
    if (!validChars.hasMatch(ssid)) {
      print('❌ SSID 驗證失敗: SSID 包含無效字元');
      return false;
    }

    // 驗證密碼（如果需要）
    if (securityOption != 'no authentication' &&
        securityOption != 'Enhanced Open (OWE)') {
      if (ssidPassword.isEmpty) {
        print('❌ SSID 驗證失敗: 需要密碼但密碼為空');
        return false;
      }

      if (ssidPassword.length < 8) {
        print('❌ SSID 驗證失敗: 密碼長度小於 8 字元');
        return false;
      }

      if (ssidPassword.length > 64) {
        print('❌ SSID 驗證失敗: 密碼長度超過 64 字元');
        return false;
      }

      // 驗證密碼字符
      if (!validChars.hasMatch(ssidPassword)) {
        print('❌ SSID 驗證失敗: 密碼包含無效字元');
        return false;
      }
    }

    print('✅ SSID 驗證成功');
    return true;
  }

  // 修改後的 WifiSettingFlowPage build 方法
  @override
  Widget build(BuildContext context) {
    // 獲取螢幕尺寸和鍵盤高度
    final screenSize = MediaQuery.of(context).size;
    final screenHeight = screenSize.height;
    final screenWidth = screenSize.width;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;

    // ===== 全域比例設定 =====
    // 主要區域高度比例
    final stepperAreaHeightRatio = 0.17; // Stepper區域佔總高度的17%
    final contentAreaHeightRatio = 0.55; // 內容區域佔總高度的55%
    final navigationAreaHeightRatio = 0.15; // 導航按鈕區域佔總高度的15%

    // 內容區域內部比例
    final titleHeightRatio = 0.07; // 標題區域佔總高度的7%
    final contentHeightRatio = 0.45; // 內容區域佔總高度的45%

    // 間距和內邊距比例
    final horizontalPaddingRatio = 0.06; // 水平內邊距為螢幕寬度的6%
    final verticalPaddingRatio = 0.025; // 垂直內邊距為螢幕高度的2.5%
    final itemSpacingRatio = 0.025; // 元素間距為螢幕高度的2.5%
    final buttonSpacingRatio = 0.05; // 按鈕間距為螢幕寬度的5%

    // 字體大小比例
    final titleFontSizeRatio = 0.042; // 標題字體大小為螢幕高度的4.2%
    final subtitleFontSizeRatio = 0.028; // 副標題字體大小為螢幕高度的2.8%
    final bodyTextFontSizeRatio = 0.018; // 正文字體大小為螢幕高度的1.8%
    final buttonTextFontSizeRatio = 0.022; // 按鈕字體大小為螢幕高度的2.2%
    final smallTextFontSizeRatio = 0.016; // 小字體大小為螢幕高度的1.6%

    // 按鈕尺寸比例
    final buttonHeightRatio = 0.07; // 按鈕高度為螢幕高度的7%
    final buttonBorderRadiusRatio = 0.01; // 按鈕圓角為螢幕高度的1%

    // ===== 計算實際尺寸 =====
    // 主要區域高度
    final stepperAreaHeight = screenHeight * stepperAreaHeightRatio;
    final contentAreaHeight = screenHeight * contentAreaHeightRatio;
    final navigationAreaHeight = screenHeight * navigationAreaHeightRatio;

    // 內容區域內部高度
    final titleHeight = screenHeight * titleHeightRatio;
    final contentHeight = screenHeight * contentHeightRatio;

    // 間距和內邊距
    final horizontalPadding = screenWidth * horizontalPaddingRatio;
    final verticalPadding = screenHeight * verticalPaddingRatio;
    final itemSpacing = screenHeight * itemSpacingRatio;
    final buttonSpacing = screenWidth * buttonSpacingRatio;

    // 字體大小
    final titleFontSize = screenHeight * titleFontSizeRatio;
    final subtitleFontSize = screenHeight * subtitleFontSizeRatio;
    final bodyTextFontSize = screenHeight * bodyTextFontSizeRatio;
    final buttonTextFontSize = screenHeight * buttonTextFontSizeRatio;
    final smallTextFontSize = screenHeight * smallTextFontSizeRatio;

    // 按鈕尺寸
    final buttonHeight = screenHeight * buttonHeightRatio;
    final buttonBorderRadius = screenHeight * buttonBorderRadiusRatio;

    // 計算可用的高度（扣除鍵盤高度）
    final availableHeight = screenHeight - keyboardHeight;

    // 當鍵盤彈出時，檢查內容是否需要滑動
    final minRequiredHeight = stepperAreaHeight + titleHeight + navigationAreaHeight + 100; // 額外100像素緩衝
    final needsScrolling = isKeyboardVisible && (availableHeight < minRequiredHeight);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false, // 防止自動調整大小
      body: Stack(
        children: [
          // 主內容 - 使用 DraggableScrollableSheet 實現可滑動隱藏效果
          SafeArea(
            child: _buildScrollableContent(
              screenHeight: screenHeight,
              stepperAreaHeight: stepperAreaHeight,
              contentAreaHeight: contentAreaHeight,
              navigationAreaHeight: navigationAreaHeight,
              titleHeight: titleHeight,
              contentHeight: contentHeight,
              horizontalPadding: horizontalPadding,
              verticalPadding: verticalPadding,
              itemSpacing: itemSpacing,
              buttonSpacing: buttonSpacing,
              titleFontSize: titleFontSize,
              subtitleFontSize: subtitleFontSize,
              bodyTextFontSize: bodyTextFontSize,
              buttonTextFontSize: buttonTextFontSize,
              buttonHeight: buttonHeight,
              buttonBorderRadius: buttonBorderRadius,
              needsScrolling: needsScrolling,
              keyboardHeight: keyboardHeight,
            ),
          ),

          // 認證期間顯示遮罩層
          if (isAuthenticating)
            Container(
              color: Colors.black.withOpacity(0.5), // 半透明黑色遮罩
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: verticalPadding),
                    Text(
                      'Logging in$_ellipsis',
                      style: TextStyle(
                        fontSize: bodyTextFontSize,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 構建可滑動的內容區域
  Widget _buildScrollableContent({
    required double screenHeight,
    required double stepperAreaHeight,
    required double contentAreaHeight,
    required double navigationAreaHeight,
    required double titleHeight,
    required double contentHeight,
    required double horizontalPadding,
    required double verticalPadding,
    required double itemSpacing,
    required double buttonSpacing,
    required double titleFontSize,
    required double subtitleFontSize,
    required double bodyTextFontSize,
    required double buttonTextFontSize,
    required double buttonHeight,
    required double buttonBorderRadius,
    required bool needsScrolling,
    required double keyboardHeight,
  }) {
    if (!needsScrolling) {
      // 不需要滑動時，使用原來的固定佈局
      return _buildFixedLayout(
        stepperAreaHeight: stepperAreaHeight,
        contentAreaHeight: contentAreaHeight,
        navigationAreaHeight: navigationAreaHeight,
        titleHeight: titleHeight,
        contentHeight: contentHeight,
        horizontalPadding: horizontalPadding,
        verticalPadding: verticalPadding,
        itemSpacing: itemSpacing,
        buttonSpacing: buttonSpacing,
        titleFontSize: titleFontSize,
        subtitleFontSize: subtitleFontSize,
        bodyTextFontSize: bodyTextFontSize,
        buttonTextFontSize: buttonTextFontSize,
        buttonHeight: buttonHeight,
        buttonBorderRadius: buttonBorderRadius,
      );
    }

    // 需要滑動時，使用 DraggableScrollableSheet
    return DraggableScrollableSheet(
      initialChildSize: 1.0, // 初始大小為全螢幕
      minChildSize: 0.3, // 最小大小為30%（可以幾乎完全隱藏）
      maxChildSize: 1.0, // 最大大小為全螢幕
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // 滑動指示器
              Container(
                width: 60,
                height: 4,
                margin: EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 主要內容
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    children: [
                      // Stepper 區域
                      Container(
                        height: stepperAreaHeight,
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                        child: AbsorbPointer(
                          absorbing: isAuthenticating || !isAuthenticated,
                          child: Opacity(
                            opacity: isAuthenticating || !isAuthenticated ? 0.5 : 1.0,
                            child: StepperComponent(
                              configPath: 'lib/shared/config/flows/initialization/wifi.json',
                              modelType: currentModel,
                              onStepChanged: _updateCurrentStep,
                              controller: _stepperController,
                              isLastStepCompleted: isLastStepCompleted,
                            ),
                          ),
                        ),
                      ),

                      // 主內容區域
                      Container(
                        height: contentAreaHeight,
                        child: isShowingFinishingWizard
                            ? _buildFinishingWizard(
                          titleHeight: titleHeight,
                          contentHeight: contentHeight,
                          titleFontSize: titleFontSize,
                          horizontalPadding: horizontalPadding,
                          verticalPadding: verticalPadding,
                        )
                            : Column(
                          children: [
                            // 步驟標題
                            Container(
                              height: titleHeight,
                              width: double.infinity,
                              alignment: Alignment.center,
                              child: Text(
                                _getCurrentStepName(),
                                style: TextStyle(
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.normal,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            // 步驟內容
                            Expanded(
                              child: AbsorbPointer(
                                absorbing: isAuthenticating || !isAuthenticated,
                                child: Opacity(
                                  opacity: isAuthenticating || !isAuthenticated ? 0.5 : 1.0,
                                  child: _buildPageView(
                                    horizontalPadding: horizontalPadding,
                                    verticalPadding: verticalPadding,
                                    itemSpacing: itemSpacing,
                                    subtitleFontSize: subtitleFontSize,
                                    bodyTextFontSize: bodyTextFontSize,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 導航按鈕區域
                      if (!isShowingFinishingWizard)
                        Container(
                          height: navigationAreaHeight,
                          child: _buildNavigationButtons(
                            buttonHeight: buttonHeight,
                            buttonSpacing: buttonSpacing,
                            horizontalPadding: horizontalPadding,
                            buttonBorderRadius: buttonBorderRadius,
                            buttonTextFontSize: buttonTextFontSize,
                          ),
                        ),

                      // 額外的底部空間，避免被鍵盤遮擋
                      SizedBox(height: keyboardHeight + 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 新增：構建固定佈局（不需要滑動時使用）
  Widget _buildFixedLayout({
    required double stepperAreaHeight,
    required double contentAreaHeight,
    required double navigationAreaHeight,
    required double titleHeight,
    required double contentHeight,
    required double horizontalPadding,
    required double verticalPadding,
    required double itemSpacing,
    required double buttonSpacing,
    required double titleFontSize,
    required double subtitleFontSize,
    required double bodyTextFontSize,
    required double buttonTextFontSize,
    required double buttonHeight,
    required double buttonBorderRadius,
  }) {
    return Column(
      children: [
        // Stepper 區域
        Container(
          height: stepperAreaHeight,
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: AbsorbPointer(
            absorbing: isAuthenticating || !isAuthenticated,
            child: Opacity(
              opacity: isAuthenticating || !isAuthenticated ? 0.5 : 1.0,
              child: StepperComponent(
                configPath: 'lib/shared/config/flows/initialization/wifi.json',
                modelType: currentModel,
                onStepChanged: _updateCurrentStep,
                controller: _stepperController,
                isLastStepCompleted: isLastStepCompleted,
              ),
            ),
          ),
        ),

        // 主內容區域
        Container(
          height: contentAreaHeight,
          child: isShowingFinishingWizard
              ? _buildFinishingWizard(
            titleHeight: titleHeight,
            contentHeight: contentHeight,
            titleFontSize: titleFontSize,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
          )
              : Column(
            children: [
              // 步驟標題
              Container(
                height: titleHeight,
                width: double.infinity,
                alignment: Alignment.center,
                child: Text(
                  _getCurrentStepName(),
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.normal,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // 步驟內容
              Expanded(
                child: AbsorbPointer(
                  absorbing: isAuthenticating || !isAuthenticated,
                  child: Opacity(
                    opacity: isAuthenticating || !isAuthenticated ? 0.5 : 1.0,
                    child: _buildPageView(
                      horizontalPadding: horizontalPadding,
                      verticalPadding: verticalPadding,
                      itemSpacing: itemSpacing,
                      subtitleFontSize: subtitleFontSize,
                      bodyTextFontSize: bodyTextFontSize,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 導航按鈕區域
        if (!isShowingFinishingWizard)
          Container(
            height: navigationAreaHeight,
            child: _buildNavigationButtons(
              buttonHeight: buttonHeight,
              buttonSpacing: buttonSpacing,
              horizontalPadding: horizontalPadding,
              buttonBorderRadius: buttonBorderRadius,
              buttonTextFontSize: buttonTextFontSize,
            ),
          ),
      ],
    );
  }

  // 完成精靈介面 - 使用固定高度
  Widget _buildFinishingWizard({
    required double titleHeight,
    required double contentHeight,
    required double titleFontSize,
    required double horizontalPadding,
    required double verticalPadding,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final componentHeight = contentHeight * 0.25;   //符合1條process
    // final componentHeight = contentHeight * 0.85;  //4條process

    return Column(
      children: [
        // 標題
        Container(
          height: titleHeight,
          width: double.infinity,
          alignment: Alignment.center,
          child: Text(
            'Finishing Wizard$_ellipsis',
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.normal,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // 內容
        Container(
          height: contentHeight,
          width: double.infinity,
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: FinishingWizardComponent(
                onProgressControllerReady: (updateFunction) {
                  _progressUpdateFunction = updateFunction;
                  // 延遲到下一個 frame 執行配置流程，避免在 build 期間調用 setState
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    // 🔥 修改：從原本的9秒改為2秒，配合新的單一Process模式
                    Timer(const Duration(seconds: 2), () {
                      _executeConfigurationWithProgress();
                    });

                    /* 保留原本的觸發時機（可能之後又會要求改回4條）
                  // 等待前 3 個 process 完成（9 秒）後再開始 API
                  Timer(const Duration(seconds: 9), () {
                    _executeConfigurationWithProgress();
                  });
                  */
                  });
                },
                onCompleted: _handleWizardCompleted,
                height: componentHeight,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 修改 _buildPageView 確保有適當的高度
  Widget _buildPageView({
    required double horizontalPadding,
    required double verticalPadding,
    required double itemSpacing,
    required double subtitleFontSize,
    required double bodyTextFontSize,
  }) {
    final steps = _getCurrentModelSteps();
    if (steps.isEmpty) {
      return Center(
        child: Text(
          '沒有可用的步驟',
          style: TextStyle(
            fontSize: bodyTextFontSize,
            color: Colors.white,
          ),
        ),
      );
    }

    // 使用 Container 確保 PageView 有固定高度
    return Container(
      height: double.infinity, // 確保使用父容器提供的全部高度
      child: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: steps.length,
        onPageChanged: (index) {
          if (_isUpdatingStep || index == currentStepIndex) return;
          _isUpdatingStep = true;
          setState(() {
            currentStepIndex = index;
            isCurrentStepComplete = false;
          });
          _stepperController.jumpToStep(index);
          _isUpdatingStep = false;
        },
        itemBuilder: (context, index) {
          return _buildStepContent(
            index,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            itemSpacing: itemSpacing,
            subtitleFontSize: subtitleFontSize,
            bodyTextFontSize: bodyTextFontSize,
          );
        },
      ),
    );
  }

  // 構建步驟內容 - 確保內容可滾動且不溢出
  Widget _buildStepContent(
      int index, {
        required double horizontalPadding,
        required double verticalPadding,
        required double itemSpacing,
        required double subtitleFontSize,
        required double bodyTextFontSize,
      }) {
    final componentNames = _getCurrentStepComponents(stepIndex: index);
    final steps = _getCurrentModelSteps();

    // 內容的內邊距
    final contentPadding = EdgeInsets.symmetric(
      horizontal: horizontalPadding,
      vertical: verticalPadding,
    );

    // 如果是最後一個步驟，顯示摘要
    if (index == steps.length - 1) {
      return SingleChildScrollView( // 使用 SingleChildScrollView 確保內容可滾動
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          width: double.infinity,
          padding: contentPadding,
          child: SummaryComponent(
            username: userName,
            connectionType: connectionType,
            ssid: ssid,
            securityOption: securityOption,
            password: ssidPassword,
            staticIpConfig: connectionType == 'Static IP' ? staticIpConfig : null,
            pppoeUsername: connectionType == 'PPPoE' ? pppoeUsername : null,
            pppoePassword: connectionType == 'PPPoE' ? pppoePassword : null,
            onNextPressed: _handleNext,
            onBackPressed: _handleBack,
          ),
        ),
      );
    }

    // 創建當前步驟的組件
    List<Widget> components = [];
    for (String componentName in componentNames) {
      Widget? component = _createComponentByName(componentName);
      if (component != null) {
        components.add(component);
      }
    }

    if (components.isNotEmpty) {
      return SingleChildScrollView( // 使用 SingleChildScrollView 確保內容可滾動
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          width: double.infinity,
          padding: contentPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, // 使用 min 避免撐大 Column
            children: components,
          ),
        ),
      );
    }

    // 沒有定義組件的步驟
    return SingleChildScrollView( // 使用 SingleChildScrollView 確保內容可滾動
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        width: double.infinity,
        padding: contentPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // 使用 min 避免撐大 Column
          children: [
            Text(
              'Step ${index + 1} Content',
              style: TextStyle(
                fontSize: subtitleFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: itemSpacing),
            Text(
              'This step has no defined components. Please use the buttons below to continue.',
              style: TextStyle(
                fontSize: bodyTextFontSize,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 修改導航按鈕，禁用交互
  Widget _buildNavigationButtons({
    required double buttonHeight,
    required double buttonSpacing,
    required double horizontalPadding,
    required double buttonBorderRadius,
    required double buttonTextFontSize,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(horizontalPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 返回按鈕
          Expanded(
            child: GestureDetector(
              onTap: (isAuthenticating || !isAuthenticated) ? null : _handleBack, // 認證期間或未認證時禁用
              child: Container(
                width: double.infinity,
                height: buttonHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(buttonBorderRadius),
                  color: (isAuthenticating || !isAuthenticated)
                      ? const Color(0xFF9747FF).withOpacity(0.1)
                      : const Color(0xFF9747FF).withOpacity(0.2), // 禁用時更透明
                  border: Border.all(
                    color: const Color(0xFF9747FF),
                    width: 1.0,
                  ),
                ),
                child: Center(
                  child: Text(
                    'Back',
                    style: TextStyle(
                      fontSize: buttonTextFontSize,
                      color: (isAuthenticating || !isAuthenticated)
                          ? Colors.white.withOpacity(0.5)
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: buttonSpacing),
          // 下一步按鈕
          Expanded(
            child: GestureDetector(
              onTap: (isAuthenticating || !isAuthenticated) ? null : _handleNext, // 認證期間或未認證時禁用
              child: _appTheme.whiteBoxTheme.buildSimpleColorButton(
                width: double.infinity,
                height: buttonHeight,
                borderRadius: BorderRadius.circular(buttonBorderRadius),
                child: Center(
                  child: Text(
                    _isLastStep() ? 'Apply' : 'Next',
                    style: TextStyle(
                      fontSize: buttonTextFontSize,
                      color: (isAuthenticating || !isAuthenticated)
                          ? Colors.white.withOpacity(0.5)
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  // 🔧 新增：判斷是否為最後一個步驟的方法
  bool _isLastStep() {
    final steps = _getCurrentModelSteps();
    return steps.isNotEmpty && currentStepIndex == steps.length - 1;
  }
}