import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:whitebox/shared/ui/components/basic/StepperComponent.dart';
import 'package:whitebox/shared/ui/components/basic/AccountPasswordComponent.dart';
import 'package:whitebox/shared/ui/components/basic/ConnectionTypeComponent.dart';
import 'package:whitebox/shared/ui/components/basic/SetSSIDComponent.dart';

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  String currentModel = 'A';
  int currentStepIndex = 0;
  bool isLastStepCompleted = false;

  Map<String, dynamic> stepsConfig = {};
  bool isLoading = true;

  String userName = '';
  String password = '';
  String confirmPassword = '';
  bool isCurrentStepComplete = false;

  late PageController _pageController;
  final StepperController _stepperController = StepperController();
  bool _isUpdatingStep = false;

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

  void _handleFormChanged(String user, String pwd, String confirmPwd, bool isComplete) {
    setState(() {
      userName = user;
      password = pwd;
      confirmPassword = confirmPwd;
      // 不再直接設置 isCurrentStepComplete，改由 _handleNext 控制
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
      });
      _isUpdatingStep = false;

      _showCompletionDialog();
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

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('完成設置'),
          content: const Text('恭喜！您已完成所有步驟。'),
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
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0), // 添加垂直內邊距
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start, // 從頂部開始排列
            crossAxisAlignment: CrossAxisAlignment.center, // 水平居中
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
          onSelectionChanged: (connectionType, isComplete) {
            // 避免在 build 期間調用 setState
            Future.microtask(() {
              if (mounted) {
                setState(() {
                  isCurrentStepComplete = isComplete;
                });
              }
            });
          },
          onNextPressed: _handleNext,
          onBackPressed: _handleBack,
        );
      case 'SetSSIDComponent':
        return SetSSIDComponent(
          onFormChanged: (ssid, securityOption, password, isValid) {
            // 避免在 build 期間調用 setState
            Future.microtask(() {
              if (mounted) {
                setState(() {
                  // 可以在這裡存儲 SSID、安全選項和密碼
                  isCurrentStepComplete = isValid;
                });
              }
            });
          },
          onNextPressed: _handleNext,
          onBackPressed: _handleBack,
        );
      default:
        print('不支援的組件名稱: $componentName');
        return null;
    }
  }
}