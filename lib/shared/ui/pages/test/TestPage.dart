import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:whitebox/shared/ui/components/basic/StepperComponent.dart';
import 'package:whitebox/shared/ui/components/basic/AccountPasswordComponent.dart';

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  // Toggle between different models for testing
  String currentModel = 'A';
  // 新增當前步驟索引的狀態變數
  int currentStepIndex = 0;

  // 儲存步驟配置
  Map<String, dynamic> stepsConfig = {};
  bool isLoading = true;

  // 新增表單數據狀態
  String userName = '';
  String password = '';
  String confirmPassword = '';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  // 載入配置檔案
  Future<void> _loadConfig() async {
    try {
      setState(() {
        isLoading = true;
      });

      // 假設配置檔案在assets目錄下
      // 這裡可以替換為您實際的配置檔案路徑
      final String configPath = 'lib/shared/config/flows/initialization/wifi.json';
      final String jsonContent = await rootBundle.loadString(configPath);

      setState(() {
        stepsConfig = json.decode(jsonContent);
        isLoading = false;
      });

      print('成功載入配置：${stepsConfig.keys}');
    } catch (e) {
      print('載入配置出錯: $e');
      // 使用硬編碼的配置作為備用
      final hardcodedConfig = {
        "models": {
          "A": {
            "steps": [
              {
                "id": 1,
                "name": "Account",
                "next": 2,
                "components": ["AccountPasswordComponent"]
              },
              {
                "id": 2,
                "name": "Internet",
                "next": 3,
                "components": []
              },
              {
                "id": 3,
                "name": "Wireless",
                "next": 4,
                "components": []
              },
              {
                "id": 4,
                "name": "Summery",
                "next": null,
                "components": []
              }
            ],
            "type": "JSON",
            "API": "WifiAPI"
          },
          "B": {
            "steps": [
              {
                "id": 1,
                "name": "選擇模式",
                "next": 2,
                "components": []
              },
              {
                "id": 2,
                "name": "連線",
                "next": 3,
                "components": []
              },
              {
                "id": 3,
                "name": "完成",
                "next": null,
                "components": []
              }
            ],
            "type": "JSON",
            "API": "WifiAPI"
          }
        }
      };

      setState(() {
        stepsConfig = hardcodedConfig;
        isLoading = false;
      });
      print('使用硬編碼配置：${stepsConfig.keys}');
    }
  }

  void _changeModel(String newModel) {
    setState(() {
      currentModel = newModel;
      currentStepIndex = 0; // 切換模型時重置步驟
    });
  }

  // 新增更新當前步驟的回調方法
  void _updateCurrentStep(int stepIndex) {
    setState(() {
      currentStepIndex = stepIndex;
    });
  }

  // 處理表單數據變化
  void _handleFormChanged(String user, String pwd, String confirmPwd) {
    setState(() {
      userName = user;
      password = pwd;
      confirmPassword = confirmPwd;
    });
  }

  // 處理下一步
  void _handleNext() {
    // 從配置中獲取當前步驟的"next"值
    List<dynamic> steps = _getCurrentModelSteps();
    if (steps.isNotEmpty && currentStepIndex < steps.length - 1) {
      setState(() {
        currentStepIndex++;
      });
    }
  }

  // 處理上一步
  void _handleBack() {
    if (currentStepIndex > 0) {
      setState(() {
        currentStepIndex--;
      });
    }
  }

  // 獲取當前模型的步驟配置
  List<dynamic> _getCurrentModelSteps() {
    if (stepsConfig.isEmpty ||
        !stepsConfig.containsKey('models') ||
        !stepsConfig['models'].containsKey(currentModel) ||
        !stepsConfig['models'][currentModel].containsKey('steps')) {
      return [];
    }

    return stepsConfig['models'][currentModel]['steps'];
  }

  // 獲取當前步驟的組件列表
  List<String> _getCurrentStepComponents() {
    List<dynamic> steps = _getCurrentModelSteps();

    if (steps.isEmpty || currentStepIndex >= steps.length) {
      return [];
    }

    var currentStep = steps[currentStepIndex];
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
            // Model selection buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Select Model: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => _changeModel('A'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: currentModel == 'A' ? Colors.grey[400] : Colors.grey[300],
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0),
                        side: BorderSide(color: Colors.grey[400]!),
                      ),
                    ),
                    child: const Text('Model A'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => _changeModel('B'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: currentModel == 'B' ? Colors.grey[400] : Colors.grey[300],
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0),
                        side: BorderSide(color: Colors.grey[400]!),
                      ),
                    ),
                    child: const Text('Model B'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Display the current model being used
            Text(
              'Current Model: $currentModel',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            // 新增顯示當前步驟的文字
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Current Step: ${currentStepIndex + 1}',  // 加1以便從1開始計數
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ),

            const SizedBox(height: 20),

            // StepperComponent 放在頂部
            Container(
              height: 120,
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: StepperComponent(
                configPath: 'lib/shared/config/flows/initialization/wifi.json',
                modelType: currentModel,
                onStepChanged: _updateCurrentStep,
              ),
            ),

            // 顯示當前步驟的組件列表（除錯用）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Text(
                '當前步驟組件: ${_getCurrentStepComponents().join(", ")}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ),

            // 主內容區域 - 根據當前步驟的組件配置顯示不同內容
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildDynamicContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 根據當前步驟的組件配置動態構建內容
  Widget _buildDynamicContent() {
    List<String> componentNames = _getCurrentStepComponents();

    // 如果當前步驟沒有定義組件，顯示預設內容
    if (componentNames.isEmpty) {
      return Center(
        child: Text(
          '步驟 ${currentStepIndex + 1} - 無組件定義',
          style: const TextStyle(fontSize: 20),
        ),
      );
    }

    // 創建組件列表
    List<Widget> components = [];

    for (String componentName in componentNames) {
      Widget? component = _createComponentByName(componentName);
      if (component != null) {
        components.add(component);
      }
    }

    // 如果沒有成功創建任何組件，顯示預設內容
    if (components.isEmpty) {
      return Center(
        child: Text(
          '步驟 ${currentStepIndex + 1} - 無法創建組件',
          style: const TextStyle(fontSize: 20),
        ),
      );
    }

    // 如果只有一個組件，直接返回它
    if (components.length == 1) {
      return components.first;
    }

    // 如果有多個組件，將它們放在Column中
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: components,
      ),
    );
  }

  // 根據組件名稱創建對應的組件
  Widget? _createComponentByName(String componentName) {
    // 可以根據需要擴展支援更多組件
    switch (componentName) {
      case 'AccountPasswordComponent':
        return AccountPasswordComponent(
          onFormChanged: _handleFormChanged,
          onNextPressed: _handleNext,
          onBackPressed: _handleBack,
        );
      default:
        print('不支援的組件名稱: $componentName');
        return null;
    }
  }
}