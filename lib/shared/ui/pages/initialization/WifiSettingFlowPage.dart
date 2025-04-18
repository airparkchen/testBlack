import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:whitebox/shared/ui/components/basic/StepperComponent.dart';
import 'package:whitebox/shared/ui/components/basic/AccountPasswordComponent.dart';
import 'package:whitebox/shared/ui/components/basic/ConnectionTypeComponent.dart';
import 'package:whitebox/shared/ui/components/basic/SetSSIDComponent.dart';
import 'package:whitebox/shared/ui/components/basic/SummaryComponent.dart';
import 'package:whitebox/shared/ui/components/basic/FinishingWizardComponent.dart'; // 引入新的嚮導完成元件
import 'package:whitebox/shared/ui/pages/initialization/InitializationPage.dart'; // 引入初始頁面

class WifiSettingFlowPage extends StatefulWidget {
  const WifiSettingFlowPage({super.key});

  @override
  State<WifiSettingFlowPage> createState() => _WifiSettingFlowPageState();
}

class _WifiSettingFlowPageState extends State<WifiSettingFlowPage> {
  String currentModel = 'A';
  int currentStepIndex = 0;
  bool isLastStepCompleted = false;
  bool isShowingFinishingWizard = false; // 是否顯示完成嚮導

  Map<String, dynamic> stepsConfig = {};
  bool isLoading = true;

  // 儲存所有設定資料的變數
  String userName = '';
  String password = '';
  String confirmPassword = '';
  String connectionType = 'DHCP'; // 預設連線類型
  String ssid = '';
  String securityOption = 'WPA3 Personal'; // 預設安全選項
  String ssidPassword = '';

  bool isCurrentStepComplete = false;

  late PageController _pageController;
  final StepperController _stepperController = StepperController();
  bool _isUpdatingStep = false;

  // 定義嚮導完成的進程名稱
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
  }

  @override
  void dispose() {
    _pageController.dispose();
    _stepperController.removeListener(_onStepperControllerChanged);
    _stepperController.dispose();
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

  // 帳號密碼表單變更處理函數
  void _handleFormChanged(String user, String pwd, String confirmPwd, bool isComplete) {
    setState(() {
      userName = user;
      password = pwd;
      confirmPassword = confirmPwd;
      // 表單完成狀態由 _handleNext 控制
    });
  }

  // 連線類型變更處理函數
  void _handleConnectionTypeChanged(String type, bool isComplete) {
    setState(() {
      connectionType = type;
      isCurrentStepComplete = isComplete;
    });
  }

  // SSID設定變更處理函數
  void _handleSSIDFormChanged(String newSsid, String newSecurityOption, String newPassword, bool isValid) {
    setState(() {
      ssid = newSsid;
      securityOption = newSecurityOption;
      ssidPassword = newPassword;
      isCurrentStepComplete = isValid;
    });
  }

  bool _validateForm() {
    if (userName.isEmpty) {
      return false;
    }
    if (password.isEmpty || password.length < 6) {
      return false;
    }
    if (confirmPassword.isEmpty || confirmPassword != password) {
      return false;
    }
    return true;
  }

  void _handleNext() {
    final steps = _getCurrentModelSteps();

    if (steps.isEmpty) return;

    final currentComponents = _getCurrentStepComponents();

    // 帳號密碼元件的驗證
    if (currentComponents.contains('AccountPasswordComponent')) {
      if (!_validateForm()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userName.isEmpty
                  ? '請輸入用戶名'
                  : password.isEmpty
                  ? '請輸入密碼'
                  : password.length < 6
                  ? '密碼必須至少6個字符'
                  : '密碼不匹配',
            ),
          ),
        );
        return;
      }
      setState(() {
        isCurrentStepComplete = true;
      });
    }

    // 如果當前不是最後一步，則前進到下一步
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
    }
    // 如果是最後一步但尚未完成
    else if (currentStepIndex == steps.length - 1 && !isLastStepCompleted) {
      // 檢查當前步驟是否需要驗證
      if (currentComponents.contains('AccountPasswordComponent') && !isCurrentStepComplete) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請完成當前步驟的設定')),
        );
        return;
      }

      _isUpdatingStep = true;
      setState(() {
        isLastStepCompleted = true;
        isShowingFinishingWizard = true; // 顯示完成嚮導
      });
      _isUpdatingStep = false;

      // 不再顯示對話框，而是在頁面上直接顯示完成嚮導
    }
  }

  void _handleBack() {
    if (currentStepIndex > 0) {
      _isUpdatingStep = true;
      setState(() {
        currentStepIndex--;
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
  }

  // 處理嚮導完成後的操作
  void _handleWizardCompleted() {
    // 導航回初始頁面
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const InitializationPage()),
          (route) => false, // 清除所有路由堆疊
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
        child: isShowingFinishingWizard
            ? _buildFinishingWizard() // 顯示完成嚮導頁面
            : Column(
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
                ),
              ),
            ),
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
            Expanded(
              flex: 38,
              child: _buildNavigationButtons(),
            ),
          ],
        ),
      ),
    );
  }

  // 構建完成嚮導視圖
  Widget _buildFinishingWizard() {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: FinishingWizardComponent(
            processNames: _processNames,
            totalDurationSeconds: 10, // 10秒完成
            onCompleted: _handleWizardCompleted,
          ),
        ),
      ),
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

    // 最後一步顯示摘要元件
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
                child: Text(
                  isLastStep && !isLastStepCompleted ? 'Finish' : 'Next',
                  style: const TextStyle(
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
    switch (componentName) {
      case 'AccountPasswordComponent':
        return AccountPasswordComponent(
          onFormChanged: _handleFormChanged,
          onNextPressed: _handleNext,
          onBackPressed: _handleBack,
        );
      case 'ConnectionTypeComponent':
        return ConnectionTypeComponent(
          onSelectionChanged: _handleConnectionTypeChanged,
          onNextPressed: _handleNext,
          onBackPressed: _handleBack,
        );
      case 'SetSSIDComponent':
        return SetSSIDComponent(
          onFormChanged: _handleSSIDFormChanged,
          onNextPressed: _handleNext,
          onBackPressed: _handleBack,
        );
      default:
        print('不支援的組件名稱: $componentName');
        return null;
    }
  }
}