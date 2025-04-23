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

class WifiSettingFlowPage extends StatefulWidget {
  const WifiSettingFlowPage({super.key});

  @override
  State<WifiSettingFlowPage> createState() => _WifiSettingFlowPageState();
}

class _WifiSettingFlowPageState extends State<WifiSettingFlowPage> {
  String currentModel = 'Micky';
  int currentStepIndex = 0;
  bool isLastStepCompleted = false;
  bool isShowingFinishingWizard = false;

  // 新增省略號動畫相關變數
  String _ellipsis = '';
  late Timer _ellipsisTimer;

  Map<String, dynamic> stepsConfig = {};
  bool isLoading = true;
  StaticIpConfig staticIpConfig = StaticIpConfig();
  String userName = '';
  String password = '';
  String confirmPassword = '';
  String connectionType = 'DHCP';
  String ssid = '';
  String securityOption = 'WPA3 Personal';
  String ssidPassword = '';
  String pppoeUsername = '';
  String pppoePassword = '';

  bool isCurrentStepComplete = false;

  late PageController _pageController;
  final StepperController _stepperController = StepperController();
  bool _isUpdatingStep = false;

  final List<String> _processNames = [
    'Process 01',
    'Process 02',
    'Process 03',
    'Process 04',
    'Process 05',
  ];

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _pageController = PageController(initialPage: currentStepIndex);
    _stepperController.addListener(_onStepperControllerChanged);

    // 初始化省略號動畫計時器
    _startEllipsisAnimation();
  }
  // 新增省略號動畫方法
  void _startEllipsisAnimation() {
    _ellipsisTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        switch (_ellipsis) {
          case '':
            _ellipsis = '.';
            break;
          case '.':
            _ellipsis = '..';
            break;
          case '..':
            _ellipsis = '...';
            break;
          case '...':
            _ellipsis = '';
            break;
          default:
            _ellipsis = '';
        }
      });
    });
  }
  @override
  void dispose() {
    _pageController.dispose();
    _stepperController.removeListener(_onStepperControllerChanged);
    _stepperController.dispose();

    // 取消省略號動畫計時器
    _ellipsisTimer.cancel();

    super.dispose();
  }

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

  Future<void> _loadConfig() async {
    try {
      setState(() {
        isLoading = true;
      });

      final String configPath = 'lib/shared/config/flows/initialization/wifi.json';
      final String jsonContent = await rootBundle.loadString(configPath);

      setState(() {
        stepsConfig = json.decode(jsonContent);
        isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncStepperState();
      });
    } catch (e) {
      print('載入配置出錯: $e');
      setState(() {
        isLoading = false;
        stepsConfig = {};
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showErrorDialog();
      });
    }
  }

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
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _syncStepperState() {
    _isUpdatingStep = true;
    _stepperController.jumpToStep(currentStepIndex);
    _isUpdatingStep = false;
  }

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

  void _handleFormChanged(String user, String pwd, String confirmPwd, bool isValid) {
    setState(() {
      userName = user;
      password = pwd;
      confirmPassword = confirmPwd;
      isCurrentStepComplete = isValid;
    });
  }

  bool _validateForm() {
    List<String> detailOptions = [];
    final steps = _getCurrentModelSteps();

    if (steps.isNotEmpty && currentStepIndex < steps.length) {
      var currentStep = steps[currentStepIndex];
      if (currentStep.containsKey('detail')) {
        detailOptions = List<String>.from(currentStep['detail']);
      }
    }

    if (detailOptions.isEmpty) {
      detailOptions = ['User', 'Password', 'Confirm Password'];
    }

    if (detailOptions.contains('User') && userName.isEmpty) {
      return false;
    }

    if (detailOptions.contains('Password')) {
      if (password.isEmpty || password.length < 8 || password.length > 32) {
        return false;
      }

      final RegExp validChars = RegExp(r'^[\x21\x23-\x2F\x30-\x39\x3A-\x3B\x3D\x3F-\x40\x41-\x5A\x5B\x5D-\x60\x61-\x7A\x7B-\x7E]+$');
      if (!validChars.hasMatch(password)) {
        return false;
      }
    }

    if (detailOptions.contains('Confirm Password') &&
        (confirmPassword.isEmpty || confirmPassword != password)) {
      return false;
    }

    return true;
  }

  void _handleConnectionTypeChanged(String type, bool isComplete, StaticIpConfig? config, PPPoEConfig? pppoeConfig) {
    setState(() {
      connectionType = type;
      isCurrentStepComplete = isComplete;

      if (config != null) {
        staticIpConfig = config;
      }

      if (pppoeConfig != null) {
        pppoeUsername = pppoeConfig.username;
        pppoePassword = pppoeConfig.password;
      }
    });
  }

  void _handleSSIDFormChanged(String newSsid, String newSecurityOption, String newPassword, bool isValid) {
    setState(() {
      ssid = newSsid;
      securityOption = newSecurityOption;
      ssidPassword = newPassword;
      isCurrentStepComplete = isValid;
    });
  }

  void _handleNext() {
    final steps = _getCurrentModelSteps();
    if (steps.isEmpty) return;
    final currentComponents = _getCurrentStepComponents();

    if (currentComponents.contains('AccountPasswordComponent')) {
      if (!_validateForm()) {
        List<String> detailOptions = [];
        if (steps.isNotEmpty && currentStepIndex < steps.length) {
          var currentStep = steps[currentStepIndex];
          if (currentStep.containsKey('detail')) {
            detailOptions = List<String>.from(currentStep['detail']);
          }
        }

        if (detailOptions.isEmpty) {
          detailOptions = ['User', 'Password', 'Confirm Password'];
        }

        String errorMessage = '';
        if (detailOptions.contains('User') && userName.isEmpty) {
          errorMessage = '請輸入用戶名';
        } else if (detailOptions.contains('Password')) {
          if (password.isEmpty) {
            errorMessage = '請輸入密碼';
          } else if (password.length < 8) {
            errorMessage = '密碼必須至少8個字元';
          } else if (password.length > 32) {
            errorMessage = '密碼長度不能超過32個字元';
          } else {
            final RegExp validChars = RegExp(r'^[\x21\x23-\x2F\x30-\x39\x3A-\x3B\x3D\x3F-\x40\x41-\x5A\x5B\x5D-\x60\x61-\x7A\x7B-\x7E]+$');
            if (!validChars.hasMatch(password)) {
              errorMessage = '密碼包含不允許的字元';
            }
          }
        }

        if (errorMessage.isEmpty && detailOptions.contains('Confirm Password')) {
          if (confirmPassword.isEmpty) {
            errorMessage = '請輸入確認密碼';
          } else if (confirmPassword != password) {
            errorMessage = '兩次輸入的密碼不一致';
          }
        }

        if (errorMessage.isEmpty) {
          errorMessage = '請完成當前步驟的設定';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
        return;
      }
      setState(() {
        isCurrentStepComplete = true;
      });
    }

    if (currentStepIndex < steps.length - 1) {
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
    } else if (currentStepIndex == steps.length - 1 && !isLastStepCompleted) {
      if (currentComponents.contains('AccountPasswordComponent') && !isCurrentStepComplete) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請完成當前步驟的設定')),
        );
        return;
      }

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

  void _handleBack() {
    if (currentStepIndex > 0) {
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
    }
  }

  void _handleWizardCompleted() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const InitializationPage()),
          (route) => false,
    );
  }

  List<dynamic> _getCurrentModelSteps() {
    if (stepsConfig.isEmpty ||
        !stepsConfig.containsKey('models') ||
        !stepsConfig['models'].containsKey(currentModel) ||
        !stepsConfig['models'][currentModel].containsKey('steps')) {
      return [];
    }
    return stepsConfig['models'][currentModel]['steps'];
  }

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 30,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: StepperComponent(
                  configPath: 'lib/shared/config/flows/initialization/wifi.json',
                  modelType: currentModel,
                  onStepChanged: _updateCurrentStep,
                  controller: _stepperController,
                  isLastStepCompleted: isLastStepCompleted, // 傳遞狀態
                ),
              ),
            ),
            Expanded(
              flex: 108,
              child: isShowingFinishingWizard
                  ? _buildFinishingWizard()
                  : Column(
                children: [
                  Expanded(
                    flex: 10,
                    child: Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Text(
                        _getCurrentStepName(),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 95,
                    child: _buildPageView(),
                  ),
                ],
              ),
            ),
            if (!isShowingFinishingWizard)
              Expanded(
                flex: 38,
                child: _buildNavigationButtons(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinishingWizard() {
    return Column(
      children: [
        // 將標題修改為「Finishing Wizard...」，並加入動態省略號
        Expanded(
          flex: 10,
          child: Container(
            width: double.infinity,
            alignment: Alignment.center,
            child: Text(
              'Finishing Wizard$_ellipsis',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Expanded(
          flex: 95,
          child: Center(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
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

  String _getCurrentStepName() {
    final steps = _getCurrentModelSteps();
    if (steps.isNotEmpty && currentStepIndex < steps.length) {
      return steps[currentStepIndex]['name'] ?? 'Step ${currentStepIndex + 1}';
    }
    return 'Step ${currentStepIndex + 1}';
  }

  Widget _buildPageView() {
    final steps = _getCurrentModelSteps();
    if (steps.isEmpty) {
      return const Center(child: Text('沒有可用的步驟'));
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
        return SizedBox.expand(
          child: _buildStepContent(index),
        );
      },
    );
  }

  Widget _buildStepContent(int index) {
    final componentNames = _getCurrentStepComponents(stepIndex: index);

    if (index == _getCurrentModelSteps().length - 1) {
      return SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
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

    List<Widget> components = [];
    for (String componentName in componentNames) {
      Widget? component = _createComponentByName(componentName);
      if (component != null) {
        components.add(component);
      }
    }

    if (components.isNotEmpty) {
      return SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: components,
          ),
        ),
      );
    }

    return Container(
      color: Colors.grey[200],
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step ${index + 1} Content',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          const Text('This step has no defined components. Please use the buttons below to continue.'),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final steps = _getCurrentModelSteps();
    final isLastStep = steps.isNotEmpty && currentStepIndex == steps.length - 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: TextButton(
                onPressed: currentStepIndex > 0 ? _handleBack : null,
                child: const Text(
                  'Back',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: TextButton(
                onPressed: _handleNext,
                child: const Text(
                  'Next',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _createComponentByName(String componentName) {
    List<String> detailOptions = [];
    final steps = _getCurrentModelSteps();

    if (steps.isNotEmpty && currentStepIndex < steps.length) {
      var currentStep = steps[currentStepIndex];
      if (currentStep.containsKey('detail')) {
        detailOptions = List<String>.from(currentStep['detail']);
      }
    }

    switch (componentName) {
      case 'AccountPasswordComponent':
        return AccountPasswordComponent(
          displayOptions: detailOptions.isNotEmpty ? detailOptions : const ['User', 'Password', 'Confirm Password'],
          onFormChanged: _handleFormChanged,
          onNextPressed: _handleNext,
          onBackPressed: _handleBack,
        );
      case 'ConnectionTypeComponent':
        return ConnectionTypeComponent(
          displayOptions: detailOptions.isNotEmpty ? detailOptions : const ['DHCP', 'Static IP', 'PPPoE'],
          onSelectionChanged: _handleConnectionTypeChanged,
          onNextPressed: _handleNext,
          onBackPressed: _handleBack,
        );
      case 'SetSSIDComponent':
        return SetSSIDComponent(
          displayOptions: detailOptions.isNotEmpty ? detailOptions : const ['no authentication', 'Enhanced Open (OWE)', 'WPA2 Personal', 'WPA3 Personal', 'WPA2/WPA3 Personal', 'WPA2 Enterprise'],
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
}