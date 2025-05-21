// lib/shared/ui/pages/initialization/WifiSettingFlowPage.dart

import 'dart:async';

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

import '../../../theme/app_theme.dart';

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

    // 初始化時自動執行獲取 SSID 和登入流程
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAuthentication();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _stepperController.removeListener(_onStepperControllerChanged);
    _stepperController.dispose();
    _ellipsisTimer.cancel();
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

  // 初始化認證流程
  Future<void> _initializeAuthentication() async {
    try {
      setState(() {
        isAuthenticating = true;
        _updateStatus("正在初始化連接...");
      });

      // 模擬初始延遲，開始處理前的視覺效果
      await Future.delayed(const Duration(milliseconds: 200));

      // 步驟 1: 獲取當前 SSID
      setState(() {
        _updateStatus("正在獲取 WiFi 資訊...");
      });
      final ssid = await WifiApiService.getCurrentWifiSSID();
      setState(() {
        currentSSID = ssid;
        this.ssid = ssid;
        _updateStatus("WiFi 資訊已獲取");
      });

      // 步驟間延遲
      await Future.delayed(const Duration(milliseconds: 200));

      // 步驟 2: 計算初始密碼
      if (currentSSID.isEmpty) {
        print("無法計算密碼: 缺少 SSID");
        setState(() {
          _updateStatus("無法計算密碼: 缺少 SSID");
        });
        return;
      }

      setState(() {
        _updateStatus("正在計算初始密碼...");
      });
      final password = await WifiApiService.calculatePasswordWithLogs(
        providedSSID: currentSSID,
      );

      if (password.isEmpty) {
        setState(() {
          _updateStatus("密碼計算失敗");
        });
        return;
      }

      setState(() {
        calculatedPassword = password;
        this.password = password;
        _updateStatus("初始密碼已計算完成");
      });

      // 步驟間延遲
      await Future.delayed(const Duration(milliseconds: 200));

      // 步驟 3: 執行登入
      if (calculatedPassword.isEmpty) {
        setState(() {
          _updateStatus("無法登入: 缺少密碼");
        });
        return;
      }

      setState(() {
        _updateStatus("正在執行登入...");
      });

      final loginResult = await WifiApiService.performFullLogin(
          userName: userName,
          calculatedPassword: calculatedPassword
      );

      setState(() {
        if (loginResult['success'] == true) {
          jwtToken = loginResult['jwtToken'];
          isAuthenticated = loginResult['isAuthenticated'] ?? false;
          _updateStatus("登入成功");
        } else {
          _updateStatus("登入失敗: ${loginResult['message']}");
        }
      });

      if (jwtToken != null && jwtToken!.isNotEmpty) {
        WifiApiService.setJwtToken(jwtToken!);
      }

      // 最終延遲，讓用戶有時間看到最終狀態
      await Future.delayed(const Duration(milliseconds: 200));

    } catch (e) {
      print('初始化認證過程中出錯: $e');
      setState(() {
        _updateStatus("初始化過程出錯: $e");
      });
    } finally {
      setState(() {
        isAuthenticating = false;
      });
    }
  }

  // 修改 _loadCurrentWanSettings 方法，添加 debug 輸出
  Future<void> _loadCurrentWanSettings() async {

    try {
      setState(() {
        _updateStatus("正在獲取網絡設置...");
      });

      // 調用API獲取當前網絡設置
      final wanSettings = await WifiApiService.getWanEth();

      String apiConnectionType = wanSettings['connection_type'] ?? 'dhcp';
      // 轉換為UI使用的格式
      if (apiConnectionType == 'dhcp') {
        connectionType = 'DHCP';
      } else if (apiConnectionType == 'static_ip') {
        connectionType = 'Static IP';
      } else if (apiConnectionType == 'pppoe') {
        connectionType = 'PPPoE';
      } else {
        connectionType = 'DHCP'; // 預設值
      }

      // 添加詳細的 debug 輸出
      print('獲取到的網絡設置: ${json.encode(wanSettings)}');

      setState(() {
        _currentWanSettings = wanSettings;
        _updateStatus("網絡設置已獲取");

        // 設置初始連接類型和相關數據
        connectionType = wanSettings['connection_type'] ?? 'DHCP';

        print('設置連接類型為: $connectionType');

        // 如果是靜態IP，則設置相關參數
        if (connectionType == 'static_ip') {
          staticIpConfig.ipAddress = wanSettings['static_ip_addr'] ?? '';
          staticIpConfig.subnetMask = wanSettings['static_ip_mask'] ?? '';
          staticIpConfig.gateway = wanSettings['static_ip_gateway'] ?? '';
          staticIpConfig.primaryDns = wanSettings['dns_1'] ?? '';
          staticIpConfig.secondaryDns = wanSettings['dns_2'] ?? '';

          print('靜態IP配置: IP=${staticIpConfig.ipAddress}, 子網掩碼=${staticIpConfig.subnetMask}, 網關=${staticIpConfig.gateway}, DNS1=${staticIpConfig.primaryDns}, DNS2=${staticIpConfig.secondaryDns}');
        }
        // 如果是PPPoE，則設置相關參數
        else if (connectionType == 'pppoe' && wanSettings.containsKey('pppoe')) {
          pppoeUsername = wanSettings['pppoe']['username'] ?? '';
          pppoePassword = wanSettings['pppoe']['password'] ?? '';

          print('PPPoE配置: 用戶名=$pppoeUsername, 密碼=${pppoePassword.isEmpty ? "空" : "已設置"}');
        }
      });
    } catch (e) {
      print('獲取WAN設置時出錯: $e');
      setState(() {
        _updateStatus("獲取網絡設置失敗: $e");
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

  // 修改處理精靈完成的方法
  void _handleWizardCompleted() async {
    try {

      // 步驟 2: 提交網絡設置
      print('步驟 1: 正在提交網絡設置...');
      await _submitWanSettings();
      await Future.delayed(const Duration(seconds: 2)); // 給系統一些處理時間

      // 步驟 3: 提交無線設置
      print('步驟 2: 正在提交無線設置...');
      await _submitWirelessSettings();
      await Future.delayed(const Duration(seconds: 2)); // 給系統一些處理時間

      if (password.isNotEmpty && confirmPassword.isNotEmpty && password == confirmPassword) {
        print('步驟 3: 變更用戶密碼...');
        await _changePassword();

      }
      // 步驟 4: 完成配置
      print('步驟 4: 正在完成配置...');
      await WifiApiService.configFinish();
      // await Future.delayed(const Duration(seconds: 2)); // 給系統一些處理時間
      print('配置已完成');

      // 步驟 5: 應用設置變更
      print('步驟 5: 正在應用設置變更...');
      try {
        await Future.delayed(const Duration(seconds: 2)); // 給設備一些應用配置的時間
        print('設置已應用');
      } catch (e) {
        print('應用設置時出錯: $e');
      }

      // 導航到初始化頁面
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const InitializationPage()),
            (route) => false,
      );
    } catch (e) {
      print('設置過程中出錯: $e');

      // 顯示錯誤對話框
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('設置失敗'),
              content: Text('無法完成設置: $e'),
              actions: <Widget>[
                TextButton(
                  child: const Text('確定'),
                  onPressed: () {
                    Navigator.of(context).pop();

                    // 仍然導航到初始化頁面
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

    // 根據連接類型設置不同的參數
    if (connectionType == 'DHCP') {
      wanSettings['connection_type'] = 'dhcp';
    } else if (connectionType == 'Static IP') {
      wanSettings['connection_type'] = 'static_ip';
      wanSettings['static_ip_addr'] = staticIpConfig.ipAddress;
      wanSettings['static_ip_mask'] = staticIpConfig.subnetMask;
      wanSettings['static_ip_gateway'] = staticIpConfig.gateway;
      wanSettings['dns_1'] = staticIpConfig.primaryDns;
      wanSettings['dns_2'] = staticIpConfig.secondaryDns;
    } else if (connectionType == 'PPPoE') {
      wanSettings['connection_type'] = 'pppoe';
      wanSettings['pppoe'] = {
        'username': pppoeUsername,
        'password': pppoePassword
      };
    }

    // 保存設置以便後續提交
    _currentWanSettings = wanSettings;
  }

  // 在 _handleConnectionTypeChanged 方法中添加重置邏輯
  void _handleConnectionTypeChanged(String type, bool isComplete, StaticIpConfig? config, PPPoEConfig? pppoeConfig) {
    setState(() {
      // 如果從特定類型切換到其他類型，重置相關字段
      bool isTypeChanged = connectionType != type;
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

      // 將設置轉換為API所需格式，以便後續提交
      _prepareWanSettingsForSubmission();
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


  // 處理 SSID 表單變更
  void _handleSSIDFormChanged(String newSsid, String newSecurityOption, String newPassword, bool isValid) {
    setState(() {
      ssid = newSsid;
      securityOption = newSecurityOption;
      ssidPassword = newPassword;
      isCurrentStepComplete = isValid;
    });
  }

  // 處理下一步操作
  void _handleNext() {
    final steps = _getCurrentModelSteps();
    if (steps.isEmpty) return;
    final currentComponents = _getCurrentStepComponents();

    // 只對非最後一步進行表單驗證
    if (currentStepIndex < steps.length - 1) {
      if (!_validateCurrentStep(currentComponents)) {
        return;
      }

      _isUpdatingStep = true;
      setState(() {
        currentStepIndex++;
        isCurrentStepComplete = false;
      });
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

  // 處理返回操作
  void _handleBack() {
    if (currentStepIndex > 0) {
      // 如果不是第一步，則回到上一步
      _isUpdatingStep = true;
      setState(() {
        currentStepIndex--;
        isCurrentStepComplete = false;
        isLastStepCompleted = false; // 重置最後一步完成狀態
      });
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

// 根據名稱創建組件
  Widget? _createComponentByName(String componentName) {
    List<String> detailOptions = _getStepDetailOptions();

    switch (componentName) {
      case 'AccountPasswordComponent':
        return AccountPasswordComponent(
          displayOptions: detailOptions.isNotEmpty ? detailOptions : const ['User', 'Password', 'Confirm Password'],
          onFormChanged: _handleFormChanged,
          onNextPressed: _handleNext,
          onBackPressed: _handleBack,
        );
      case 'ConnectionTypeComponent':
      // 在創建組件前，確保已調用獲取網絡設置的方法
        if (_currentWanSettings.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadCurrentWanSettings();
          });
        }

        return ConnectionTypeComponent(
          displayOptions: detailOptions.isNotEmpty ? detailOptions : const ['DHCP', 'Static IP', 'PPPoE'],
          initialConnectionType: connectionType,
          initialStaticIpConfig: connectionType == 'Static IP' ? staticIpConfig : null,
          initialPppoeUsername: pppoeUsername,
          initialPppoePassword: pppoePassword,
          onSelectionChanged: _handleConnectionTypeChanged,
          onNextPressed: _handleNext,
          onBackPressed: _handleBack,
        );
      case 'SetSSIDComponent':
      // 在創建組件前，確保已調用獲取無線設置的方法
        if (_currentWirelessSettings.isEmpty && !_isLoadingWirelessSettings) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadWirelessSettings();
          });
        }

        return SetSSIDComponent(
          displayOptions: detailOptions.isNotEmpty ? detailOptions : const ['no authentication', 'Enhanced Open (OWE)', 'WPA2 Personal', 'WPA3 Personal', 'WPA2/WPA3 Personal', 'WPA2 Enterprise'],
          initialSsid: ssid,
          initialSecurityOption: securityOption,
          initialPassword: ssidPassword,
          onFormChanged: _handleSSIDFormChanged,
          onNextPressed: _handleNext,
          onBackPressed: _handleBack,
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
        );
      default:
        print('不支援的組件名稱: $componentName');
        return null;
    }
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: Column(
          children: [
            // Stepper 區域 - 使用螢幕比例
            Container(
              height: stepperAreaHeight,
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: StepperComponent(
                configPath: 'lib/shared/config/flows/initialization/wifi.json',
                modelType: currentModel,
                onStepChanged: _updateCurrentStep,
                controller: _stepperController,
                isLastStepCompleted: isLastStepCompleted,
              ),
            ),

            // 主內容區域 - 使用螢幕比例
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
                    child: _buildPageView(
                      horizontalPadding: horizontalPadding,
                      verticalPadding: verticalPadding,
                      itemSpacing: itemSpacing,
                      subtitleFontSize: subtitleFontSize,
                      bodyTextFontSize: bodyTextFontSize,
                    ),
                  ),
                ],
              ),
            ),

            // 導航按鈕區域 - 使用螢幕比例
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
    );
  }

// 完成精靈介面 - 使用比例尺寸
  Widget _buildFinishingWizard({
    required double titleHeight,
    required double contentHeight,
    required double titleFontSize,
    required double horizontalPadding,
    required double verticalPadding,
  }) {
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
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: FinishingWizardComponent(
                  processNames: _processNames,
                  totalDurationSeconds: 10,
                  onCompleted: _handleWizardCompleted,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

// 構建頁面視圖 - 確保內容可滾動
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

    return PageView.builder(
      controller: _pageController,
      physics: const ClampingScrollPhysics(),
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
    );
  }

// 構建步驟內容 - 確保內容可滾動
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
      return SingleChildScrollView(
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
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          width: double.infinity,
          padding: contentPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: components,
          ),
        ),
      );
    }

    // 沒有定義組件的步驟
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        width: double.infinity,
        padding: contentPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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

// Back Next 按鈕實現 - 使用比例尺寸
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
          // 返回按鈕使用新的紫色邊框樣式
          Expanded(
            child: GestureDetector(
              onTap: _handleBack,
              child: Container(
                width: double.infinity,
                height: buttonHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(buttonBorderRadius),
                  color: const Color(0xFF9747FF).withOpacity(0.2), // 紫色填充顏色帶透明度
                  border: Border.all(
                    color: const Color(0xFF9747FF), // 紫色邊框
                    width: 1.0,
                  ),
                ),
                child: Center(
                  child: Text(
                    'Back',
                    style: TextStyle(
                      fontSize: buttonTextFontSize,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: buttonSpacing),
          // 下一步按鈕保持不變
          Expanded(
            child: GestureDetector(
              onTap: _handleNext,
              child: _appTheme.whiteBoxTheme.buildSimpleColorButton(
                width: double.infinity,
                height: buttonHeight,
                borderRadius: BorderRadius.circular(buttonBorderRadius),
                child: Center(
                  child: Text(
                    'Next',
                    style: TextStyle(
                      fontSize: buttonTextFontSize,
                      color: Colors.white,
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