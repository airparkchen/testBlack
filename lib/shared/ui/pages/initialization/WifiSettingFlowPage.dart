// lib/shared/ui/pages/initialization/WifiSettingFlowPage.dart

import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:whitebox/shared/ui/components/basic/StepperComponent.dart';
import 'package:whitebox/shared/ui/components/basic/AccountPasswordComponent.dart';
import 'package:whitebox/shared/ui/components/basic/ConnectionTypeComponent.dart';
import 'package:whitebox/shared/ui/components/basic/SetSSIDComponent.dart';
import 'package:whitebox/shared/ui/components/basic/SummaryComponent.dart';
import 'package:whitebox/shared/ui/components/basic/FinishingWizardComponent.dart';
import 'package:whitebox/shared/ui/pages/initialization/InitializationPage.dart';
import 'package:whitebox/shared/models/StaticIpConfig.dart';

// 引入需要的 API 服務類
import 'package:whitebox/shared/api/wifi_api_service.dart';
import 'package:wifi_iot/wifi_iot.dart';

import '../../../theme/app_theme.dart';
import 'LoginPage.dart';

class WifiSettingFlowPage extends StatefulWidget {
  const WifiSettingFlowPage({super.key});

  @override
  State<WifiSettingFlowPage> createState() => _WifiSettingFlowPageState();
}

class _WifiSettingFlowPageState extends State<WifiSettingFlowPage> {
  final AppTheme _appTheme = AppTheme();
  // 基本設定
  String currentModel = 'Micky';
  int currentStepIndex = 0;
  bool isLastStepCompleted = false;
  bool isShowingFinishingWizard = false;
  bool isLoading = true;
  bool isCurrentStepComplete = false;
  bool _isUpdatingStep = false;

  // 登入相關變數
  bool isAuthenticated = false;
  String? jwtToken;
  String currentSSID = '';
  String calculatedPassword = '';
  bool isAuthenticating = false;
  bool hasInitialized = false;
  bool isConnecting = false; // 新增變數，追蹤 Wi-Fi 連線狀態

  // 省略號動畫
  String _ellipsis = '';
  late Timer _ellipsisTimer;

  // 表單狀態
  Map<String, dynamic> stepsConfig = {};
  StaticIpConfig staticIpConfig = StaticIpConfig();
  String userName = 'admin'; // 預設用戶名
  String password = '';
  String confirmPassword = '';
  String connectionType = 'DHCP';
  String ssid = '';
  String securityOption = 'WPA3 Personal';
  String ssidPassword = '';
  String pppoeUsername = '';
  String pppoePassword = '';

  // 控制器
  late PageController _pageController;
  final StepperController _stepperController = StepperController();

  // 完成精靈的步驟名稱
  final List<String> _processNames = [
    'Process 01', 'Process 02', 'Process 03', 'Process 04', 'Process 05',
  ];
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

    // 僅在尚未初始化時執行認證
    if (!hasInitialized) {
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

      final loginResult = await WifiApiService.performFullLogin(
          userName: userName,
          calculatedPassword: calculatedPassword
      );

      setState(() {
        if (loginResult['success'] == true) {
          jwtToken = loginResult['jwtToken'];
          isAuthenticated = loginResult['isAuthenticated'] ?? false;
          _updateStatus("Login successful");
          hasInitialized = true;
        } else {
          _updateStatus("Login failed: ${loginResult['message']}");
          _handleAuthenticationFailure("Login failed: ${loginResult['message']}");
        }
      });

      if (jwtToken != null && jwtToken!.isNotEmpty) {
        WifiApiService.setJwtToken(jwtToken!);
      }

      await Future.delayed(const Duration(milliseconds: 200));

    } catch (e) {
      print('Error during authentication initialization: $e');
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

  // Handle authentication failure
  void _handleAuthenticationFailure(String errorMessage) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Authentication Failed'),
            content: Text('Unable to complete initial authentication: $errorMessage\nPlease try again.'),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                  // Navigate back to InitializationPage and remove current page
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const InitializationPage()),
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

  Future<void> _loadCurrentWanSettings() async {
    try {
      setState(() {
        _updateStatus("Getting network settings...");
      });

      // 調用API獲取當前網絡設置
      final wanSettings = await WifiApiService.getWanEth();

      String apiConnectionType = wanSettings['connection_type'] ?? 'dhcp';

      // 正確轉換為UI使用的格式
      String uiConnectionType;
      if (apiConnectionType == 'dhcp') {
        uiConnectionType = 'DHCP';
      } else if (apiConnectionType == 'static_ip') {
        uiConnectionType = 'Static IP';
      } else if (apiConnectionType == 'pppoe') {
        uiConnectionType = 'PPPoE';
      } else {
        uiConnectionType = 'DHCP'; // 預設值
      }

      // 添加詳細的 debug 輸出
      print('API返回的連接類型: $apiConnectionType');
      print('轉換後的UI連接類型: $uiConnectionType');
      print('獲取到的網絡設置: ${json.encode(wanSettings)}');

      setState(() {
        _currentWanSettings = wanSettings;
        _updateStatus("Network settings obtained");

        // 使用轉換後的UI格式
        connectionType = uiConnectionType;

        print('設置連接類型為: $connectionType');

        // 如果是靜態IP，則設置相關參數
        if (apiConnectionType == 'static_ip') {
          staticIpConfig.ipAddress = wanSettings['static_ip_addr'] ?? '';
          staticIpConfig.subnetMask = wanSettings['static_ip_mask'] ?? '';
          staticIpConfig.gateway = wanSettings['static_ip_gateway'] ?? '';
          staticIpConfig.primaryDns = wanSettings['dns_1'] ?? '';
          staticIpConfig.secondaryDns = wanSettings['dns_2'] ?? '';

          print('靜態IP配置: IP=${staticIpConfig.ipAddress}, 子網掩碼=${staticIpConfig.subnetMask}, 網關=${staticIpConfig.gateway}, DNS1=${staticIpConfig.primaryDns}, DNS2=${staticIpConfig.secondaryDns}');
        }
        // 如果是PPPoE，則設置相關參數
        else if (apiConnectionType == 'pppoe' && wanSettings.containsKey('pppoe')) {
          pppoeUsername = wanSettings['pppoe']['username'] ?? '';
          pppoePassword = wanSettings['pppoe']['password'] ?? '';

          print('PPPoE配置: 用戶名=$pppoeUsername, 密碼=${pppoePassword.isEmpty ? "空" : "已設置"}');
        }
      });
    } catch (e) {
      print('獲取WAN設置時出錯: $e');
      setState(() {
        _updateStatus("Failed to get network settings: $e");
      });
    }
  }

  Future _loadWirelessSettings() async {
    try {
      setState(() {
        _isLoadingWirelessSettings = true;
        _updateStatus("正在獲取無線設置...");
      });

      // 調用API獲取當前無線設置
      final wirelessSettings = await WifiApiService.getWirelessBasic();

      // 添加詳細的 debug 輸出
      print('獲取到的無線設置: ${json.encode(wirelessSettings)}');

      setState(() {
        _currentWirelessSettings = wirelessSettings;
        _updateStatus("無線設置已獲取");

        // 如果存在有效的VAP配置，使用它填充無線設置
        if (wirelessSettings.containsKey('vaps') &&
            wirelessSettings['vaps'] is List &&
            wirelessSettings['vaps'].isNotEmpty) {

          // 通常使用第一個VAP配置（主要配置）
          final vap = wirelessSettings['vaps'][0];

          // 設置SSID
          if (vap.containsKey('ssid') && vap['ssid'] is String) {
            ssid = vap['ssid'];
            print('設置SSID為: $ssid');
          }

          // 由於只支援 WPA3，直接設置為 WPA3 Personal
          securityOption = 'WPA3 Personal';
          print('設置安全選項為: $securityOption');

          // 設置密碼
          if (vap.containsKey('password')) {
            if (vap['password'] is String) {
              ssidPassword = vap['password'];
              print('設置WiFi密碼: ${ssidPassword.isEmpty ? "未設置" : "已設置，長度: ${ssidPassword.length}"}');
              // 快速密碼值檢查
              if (ssidPassword.isNotEmpty) {
                print('密碼前4個字符: ${ssidPassword.substring(0, ssidPassword.length > 4 ? 4 : ssidPassword.length)}...');
              }
            } else {
              print('警告: 密碼不是字符串類型: ${vap['password']}');
              ssidPassword = ''; // 重置為空字符串
            }
          } else {
            print('警告: VAP配置中沒有password字段');
            ssidPassword = ''; // WPA3 需要密碼，設置為空以便提示用戶
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

      // 準備無線設置提交數據
      Map<String, dynamic> wirelessConfig = {};

      // 保留原始結構中的其他字段
      if (_currentWirelessSettings.containsKey('wifi_mlo')) {
        wirelessConfig['wifi_mlo'] = _currentWirelessSettings['wifi_mlo'];
      }

      // 設置VAPs數組
      List<Map<String, dynamic>> vaps = [];

      // 如果已經有VAPs，保留其結構但更新值
      if (_currentWirelessSettings.containsKey('vaps') &&
          _currentWirelessSettings['vaps'] is List &&
          _currentWirelessSettings['vaps'].isNotEmpty) {

        for (int i = 0; i < _currentWirelessSettings['vaps'].length; i++) {
          Map<String, dynamic> originalVap = Map<String, dynamic>.from(_currentWirelessSettings['vaps'][i]);

          // 只更新第一個（主要的）VAP
          if (i == 0) {
            // 既然只支援 WPA3，固定使用 'sae' 安全類型
            String apiSecurityType = 'sae'; // WPA3 Personal

            // 更新值
            originalVap['ssid'] = ssid;
            originalVap['security_type'] = apiSecurityType;
            originalVap['password'] = ssidPassword; // WPA3 需要密碼
          }

          vaps.add(originalVap);
        }
      }
      // 如果沒有現有VAPs，創建新的結構
      else {
        Map<String, dynamic> newVap = {
          'vap_index': 1,
          'vap_type': 'primary',
          'vap_enabled': 'true',
          'security_type': 'sae', // WPA3 Personal
          'ssid': ssid,
          'password': ssidPassword
        };

        vaps.add(newVap);
      }

      // 設置VAPs數組到配置中
      wirelessConfig['vaps'] = vaps;

      print('即將提交的無線設置: ${json.encode(wirelessConfig)}');

      // 調用API提交無線設置
      final result = await WifiApiService.updateWirelessBasic(wirelessConfig);

      print('無線設置更新結果: ${json.encode(result)}');

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
  // 修改自動重新連線方法
  Future<void> _reconnectToWifi() async {
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

      // 使用 wifi_iot 連接到 Wi-Fi
      bool? isConnected = await WiFiForIoTPlugin.connect(
        ssid,
        password: ssidPassword,
        security: getNetworkSecurity(),
        joinOnce: true,
        timeoutInSeconds: 30,
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

  // 新增處理連線失敗的方法
  void _handleConnectionFailure(String errorMessage) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Wi-Fi Connection Failed'),
            content: Text('Unable to connect to Wi-Fi: $errorMessage\nPlease try again.'),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const InitializationPage()),
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

  // 修改處理精靈完成的方法
  void _handleWizardCompleted() async {
    try {
      print('Step 1: Submitting network settings...');
      await _submitWanSettings();
      await Future.delayed(const Duration(seconds: 2));

      print('Step 2: Submitting wireless settings...');
      await _submitWirelessSettings();
      await Future.delayed(const Duration(seconds: 2));

      if (password.isNotEmpty && confirmPassword.isNotEmpty && password == confirmPassword) {
        print('Step 3: Changing user password...');
        await _changePassword();
      }

      print('Step 4: Completing configuration...');
      await WifiApiService.configFinish();
      print('Configuration completed');

      print('Step 5: Applying settings and waiting for 220 seconds...');
      setState(() {
        _updateStatus("Applying settings, please wait...");
      });

      try {
        await Future.delayed(const Duration(seconds: 220));
        print('Settings applied and wait completed');
      } catch (e) {
        print('Error during settings application or wait: $e');
        setState(() {
          _updateStatus("Failed to apply settings: $e");
        });
        throw e; // 繼續拋出異常以進入 catch 塊
      }

      // 步驟 6: 重新連接到新的 Wi-Fi
      print('Step 6: Reconnecting to Wi-Fi with new SSID and password...');
      setState(() {
        _updateStatus("Connecting to Wi-Fi...");
        isConnecting = true;
      });
      await _reconnectToWifi();

      // 連線成功，導航到 LoginPage
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
              (route) => false,
        );
      }
    } catch (e) {
      print('Error during setup process: $e');
      setState(() {
        isConnecting = false;
      });
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
    Map<String, dynamic> wanSettings = {};

    // 根據連接類型設置不同的參數 - 轉換為API格式
    if (connectionType == 'DHCP') {
      wanSettings['connection_type'] = 'dhcp'; // 轉換為小寫
    } else if (connectionType == 'Static IP') {
      wanSettings['connection_type'] = 'static_ip'; // 轉換為API格式
      wanSettings['static_ip_addr'] = staticIpConfig.ipAddress;
      wanSettings['static_ip_mask'] = staticIpConfig.subnetMask;
      wanSettings['static_ip_gateway'] = staticIpConfig.gateway;
      wanSettings['dns_1'] = staticIpConfig.primaryDns;
      wanSettings['dns_2'] = staticIpConfig.secondaryDns;
    } else if (connectionType == 'PPPoE') {
      wanSettings['connection_type'] = 'pppoe'; // 轉換為小寫
      wanSettings['pppoe'] = {
        'username': pppoeUsername,
        'password': pppoePassword
      };
    }

    // 保存設置以便後續提交
    _currentWanSettings = wanSettings;

    print('準備提交的WAN設置: ${json.encode(wanSettings)}');
  }

  // 處理連接類型變更（增強版本）
  void _handleConnectionTypeChanged(String type, bool isComplete, StaticIpConfig? config, PPPoEConfig? pppoeConfig) {
    setState(() {
      // 檢查類型是否改變
      bool isTypeChanged = connectionType != type;

      // 只有當值真正改變時才更新
      if (isTypeChanged || isCurrentStepComplete != isComplete) {
        connectionType = type;
        isCurrentStepComplete = isComplete;

        if (config != null) {
          staticIpConfig = config;
        } else if (isTypeChanged && type != 'Static IP') {
          // 如果不是靜態IP，重置靜態IP配置
          staticIpConfig = StaticIpConfig();
        }

        if (pppoeConfig != null) {
          pppoeUsername = pppoeConfig.username;
          pppoePassword = pppoeConfig.password;
        } else if (isTypeChanged && type != 'PPPoE') {
          // 如果不是PPPoE，重置PPPoE配置
          pppoeUsername = '';
          pppoePassword = '';
        }

        // 準備API提交格式
        _prepareWanSettingsForSubmission();

        // Debug 輸出
        print('連接類型更新: 類型=$connectionType, 有效=$isCurrentStepComplete');
        if (type == 'Static IP') {
          print('靜態IP配置: ${staticIpConfig.ipAddress}');
        } else if (type == 'PPPoE') {
          print('PPPoE配置: 用戶名=$pppoeUsername');
        }
      }
    });
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

  // 驗證表單
  bool _validateForm() {
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
  // 處理下一步操作 - 增強版本
  void _handleNext() {
    final steps = _getCurrentModelSteps();
    if (steps.isEmpty) return;
    final currentComponents = _getCurrentStepComponents();

    // 只對非最後一步進行表單驗證
    if (currentStepIndex < steps.length - 1) {
      if (!_validateCurrentStep(currentComponents)) {
        return;
      }

      // 在進入下一步前，確認並保存當前步驟資料
      _confirmAndSaveCurrentStepData();

      _isUpdatingStep = true;
      setState(() {
        currentStepIndex++;
        isCurrentStepComplete = false;
      });

      // 載入下一步的資料
      _reloadStepData(currentStepIndex);

      _stepperController.jumpToStep(currentStepIndex);
      _pageController.animateToPage(
        currentStepIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _isUpdatingStep = false;
    }
    // 最後一步（摘要頁）不需要驗證，直接進入完成精靈
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

  // 驗證當前步驟
  bool _validateCurrentStep(List<String> currentComponents) {
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

  // 獲取連接類型錯誤訊息
  String _getConnectionTypeError() {
    if (connectionType == 'Static IP') {
      if (staticIpConfig.ipAddress.isEmpty) {
        return 'Please enter an IP address';
      } else if (staticIpConfig.subnetMask.isEmpty) {
        return 'Please enter a subnet mask';
      } else if (staticIpConfig.gateway.isEmpty) {
        return 'Please enter a gateway address';
      } else if (staticIpConfig.primaryDns.isEmpty) {
        return 'Please enter a DNS server address';
      }
    } else if (connectionType == 'PPPoE') {
      if (pppoeUsername.isEmpty) {
        return 'Please enter a PPPoE username';
      } else if (pppoePassword.isEmpty) {
        return 'Please enter a PPPoE password';
      }
    }

    return 'Please complete all required fields';
  }

  // 獲取 SSID 錯誤訊息
  String _getSSIDError() {
    // 驗證 SSID
    if (ssid.isEmpty) {
      return 'Please enter an SSID';
    } else if (ssid.length > 64) {
      return 'SSID must be 64 characters or less';
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
  // 重新載入指定步驟的資料
  void _reloadStepData(int stepIndex) {
    final components = _getCurrentStepComponents(stepIndex: stepIndex);

    // 重新載入連接類型資料
    if (components.contains('ConnectionTypeComponent')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCurrentWanSettings();
      });
      print('重新載入連接類型資料');
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

      // 清理上一步的數據（現在的當前步驟）
      _clearCurrentStepData();

      // 回到上一步後，重新載入該步驟的資料
      _reloadStepData(currentStepIndex);

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

  @override
  Widget build(BuildContext context) {
    // 獲取螢幕尺寸
    final screenSize = MediaQuery.of(context).size;
    final screenHeight = screenSize.height;
    final screenWidth = screenSize.width;

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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 主內容
          SafeArea(
            child: Column(
              children: [
                // Stepper 區域
                Container(
                  height: stepperAreaHeight,
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: AbsorbPointer(
                    absorbing: isAuthenticating || !isAuthenticated, // 認證期間或未認證時禁用交互
                    child: Opacity(
                      opacity: isAuthenticating || !isAuthenticated ? 0.5 : 1.0, // 視覺上降低透明度
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
                          absorbing: isAuthenticating || !isAuthenticated, // 認證期間或未認證時禁用交互
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

// 完成精靈介面 - 使用固定高度
  Widget _buildFinishingWizard({
    required double titleHeight,
    required double contentHeight,
    required double titleFontSize,
    required double horizontalPadding,
    required double verticalPadding,
  }) {
    final screenSize = MediaQuery.of(context).size;

    // 計算適合的組件高度 - 使用 contentHeight
    final componentHeight = contentHeight * 0.85; // 使用內容區域的85%，預留一些空間

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

        // 內容 - 使用固定高度替代 Expanded
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
                processNames: _processNames,
                totalDurationSeconds: 10,
                onCompleted: _handleWizardCompleted,
                height: componentHeight, // 傳入計算好的高度
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

// 修改 _createComponentByName 方法，為所有組件傳遞高度
  Widget? _createComponentByName(String componentName) {
    List<String> detailOptions = _getStepDetailOptions();
    final screenSize = MediaQuery.of(context).size;

    // 為所有組件設置的共同高度比例
    final componentHeightRatio = 0.45; // 使用螢幕高度的 45%
    final componentHeight = screenSize.height * componentHeightRatio;

    switch (componentName) {
      case 'AccountPasswordComponent':
        return AccountPasswordComponent(
          displayOptions: detailOptions.isNotEmpty ? detailOptions : const ['User', 'Password', 'Confirm Password'],
          onFormChanged: _handleFormChanged,
          onNextPressed: _handleNext,
          onBackPressed: _handleBack,
          height: componentHeight, // 使用共同的比例高度
        );

      case 'ConnectionTypeComponent':
      // 在創建組件前，確保已調用獲取網絡設置的方法
        if (_currentWanSettings.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadCurrentWanSettings();
          });
        }

        // 確保連接類型選項標準化且唯一
        List<String> validConnectionTypes = ['DHCP', 'Static IP', 'PPPoE'];

        // 使用 LinkedHashSet 保持順序且去除重複
        List<String> uniqueConnectionTypes = LinkedHashSet<String>.from(
            detailOptions.isNotEmpty ? detailOptions : validConnectionTypes
        ).toList();

        // 如果當前 connectionType 不在有效選項中，重置為預設值
        if (!uniqueConnectionTypes.contains(connectionType)) {
          connectionType = 'DHCP';
        }

        return ConnectionTypeComponent(
          displayOptions: uniqueConnectionTypes,
          initialConnectionType: connectionType,
          initialStaticIpConfig: connectionType == 'Static IP' ? staticIpConfig : null,
          initialPppoeUsername: pppoeUsername,
          initialPppoePassword: pppoePassword,
          onSelectionChanged: _handleConnectionTypeChanged,
          onNextPressed: _handleNext,
          onBackPressed: _handleBack,
          height: componentHeight,
        );

      case 'SetSSIDComponent':
      // 在創建組件前，確保已調用獲取無線設置的方法
        if (_currentWirelessSettings.isEmpty && !_isLoadingWirelessSettings) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadWirelessSettings();
          });
        }

        // 確保安全選項有效且唯一 - 去除重複並檢查當前值
        List<String> validSecurityOptions = [
          'no authentication',
          'Enhanced Open (OWE)',
          'WPA2 Personal',
          'WPA3 Personal',
          'WPA2/WPA3 Personal',
          'WPA2 Enterprise'
        ];

        // 使用 LinkedHashSet 保持順序且去除重複
        List<String> uniqueOptions = LinkedHashSet<String>.from(
            detailOptions.isNotEmpty ? detailOptions : validSecurityOptions
        ).toList();

        // 如果當前 securityOption 不在有效選項中，重置為預設值
        if (!uniqueOptions.contains(securityOption)) {
          securityOption = 'WPA3 Personal';
        }

        return SetSSIDComponent(
          displayOptions: uniqueOptions,
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
          password: ssidPassword,
          staticIpConfig: connectionType == 'Static IP' ? staticIpConfig : null,
          pppoeUsername: connectionType == 'PPPoE' ? pppoeUsername : null,
          pppoePassword: connectionType == 'PPPoE' ? pppoePassword : null,
          onNextPressed: _handleNext,
          onBackPressed: _handleBack,
          height: componentHeight, // 添加比例高度
        );
      default:
        print('不支援的組件名稱: $componentName');
        return null;
    }
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
                    'Next',
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
}