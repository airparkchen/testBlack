import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async' show Future;
import 'package:flutter/services.dart' show rootBundle;

class StepperComponent extends StatefulWidget {
  final String configPath;
  final String modelType;

  const StepperComponent({
    Key? key,
    this.configPath = 'lib/shared/config/flows/initialization/wifi.json',
    this.modelType = 'A',
  }) : super(key: key);

  @override
  State<StepperComponent> createState() => _StepperComponentState();
}

class _StepperComponentState extends State<StepperComponent> {
  List<Map<String, dynamic>> steps = [];
  int currentStepIndex = 0; // Track the current step index
  bool isLoading = true; // 添加載入狀態標誌
  bool isLastStepCompleted = false; // Add a flag to track if the last step is completed

  @override
  void initState() {
    super.initState();
    _loadStepsConfig();

    // 測試用：如果 30 秒後仍然沒有數據，則使用硬編碼的測試資料
    Future.delayed(Duration(seconds: 3), () {
      if (steps.isEmpty) {
        print('使用硬編碼的測試資料');
        setState(() {
          steps = [
            {"id": 1, "name": "帳戶", "next": 2},
            {"id": 2, "name": "網路", "next": 3},
            {"id": 3, "name": "無線", "next": 4},
            {"id": 4, "name": "摘要", "next": null}
          ];
          isLoading = false;
        });
      }
    });
  }

  // Load the steps from the JSON configuration file
  Future<void> _loadStepsConfig() async {
    try {
      setState(() {
        isLoading = true;
        isLastStepCompleted = false; // Reset completion state when loading new config
      });

      print('嘗試載入設定檔: ${widget.configPath}');
      print('目前模型類型: ${widget.modelType}');

      // 載入 JSON 檔案
      final String jsonContent = await rootBundle.loadString(widget.configPath);
      print('成功載入 JSON 內容，長度: ${jsonContent.length}');

      final Map<String, dynamic> jsonData = json.decode(jsonContent);
      print('解析 JSON 資料，鍵值: ${jsonData.keys}');

      // 提取指定模型類型的步驟
      if (jsonData.containsKey('models') &&
          jsonData['models'].containsKey(widget.modelType) &&
          jsonData['models'][widget.modelType].containsKey('steps')) {

        final stepsData = jsonData['models'][widget.modelType]['steps'];
        print('找到步驟資料: $stepsData');

        setState(() {
          steps = List<Map<String, dynamic>>.from(stepsData);
          isLoading = false;
          print('成功設置 ${steps.length} 個步驟');
        });
      } else {
        print('未找到有效的步驟資料');
        setState(() {
          steps = [];
          isLoading = false;
        });
      }
    } catch (e) {
      print('載入步驟設定時出錯: $e');
      setState(() {
        steps = [];
        isLoading = false;
      });
    }
  }

  // Go to the next step if possible
  void _nextStep() {
    if (currentStepIndex < steps.length - 1) {
      // If not on the last step, advance to the next step
      setState(() {
        currentStepIndex++;
      });
    } else if (currentStepIndex == steps.length - 1 && !isLastStepCompleted) {
      // If on the last step and it's not completed yet, mark it as completed
      setState(() {
        isLastStepCompleted = true;
      });
    }
  }

  // Go to the previous step if possible
  void _previousStep() {
    if (currentStepIndex > 0) {
      setState(() {
        currentStepIndex--;
        // If going back from the completed last step, reset the completion flag
        if (currentStepIndex == steps.length - 2 && isLastStepCompleted) {
          isLastStepCompleted = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stepper UI
        Container(
          height: 120, // 增加高度以容納連接線
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : steps.isEmpty
              ? const Center(child: Text('此模型沒有定義步驟'))
              : _buildStepperRow(),
        ),

        // 只有在有步驟時才顯示導航按鈕
        if (steps.isNotEmpty && !isLoading) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: currentStepIndex > 0 ? _previousStep : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(0),
                    side: BorderSide(color: Colors.grey[400]!),
                  ),
                ),
                child: const Text('上一步'),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                // Enable next button if not on the last step OR if on the last step but not completed yet
                onPressed: (currentStepIndex < steps.length - 1 ||
                    (currentStepIndex == steps.length - 1 && !isLastStepCompleted))
                    ? _nextStep : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(0),
                    side: BorderSide(color: Colors.grey[400]!),
                  ),
                ),
                child: const Text('下一步'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // 建立步驟列，包含連接線
  Widget _buildStepperRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: steps.asMap().entries.map((entry) {
        final int index = entry.key;
        final Map<String, dynamic> step = entry.value;

        // 確定步驟狀態 - check if completed based on current index and last step completion status
        final bool isCompleted = index < currentStepIndex ||
            (index == currentStepIndex &&
                index == steps.length - 1 &&
                isLastStepCompleted);
        final bool isCurrent = index == currentStepIndex && !isLastStepCompleted;

        // 構建一個包含步驟和前後連接線的組件
        return Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 左連接線 (如果不是第一個步驟)
              if (index > 0)
                Positioned(
                  left: 0,
                  right: MediaQuery.of(context).size.width / (steps.length * 2), // 動態計算位置
                  top: 30, // 與圓圈垂直居中
                  child: Container(
                    height: 4,
                    color: index <= currentStepIndex ? Colors.black : const Color(0xFFEFEFEF),
                  ),
                ),

              // 右連接線 (如果不是最後一個步驟)
              if (index < steps.length - 1)
                Positioned(
                  left: MediaQuery.of(context).size.width / (steps.length * 2), // 動態計算位置
                  right: 0,
                  top: 30, // 與圓圈垂直居中
                  child: Container(
                    height: 4,
                    color: index < currentStepIndex ? Colors.black : const Color(0xFFEFEFEF),
                  ),
                ),

              // 步驟圓圈和文字
              _buildStep(
                id: step['id'].toString(),
                name: step['name'].toString(),
                isCompleted: isCompleted,
                isCurrent: isCurrent,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStep({
    required String id,
    required String name,
    required bool isCompleted,
    required bool isCurrent,
  }) {
    // 根據步驟狀態設定樣式
    final Color circleColor = isCompleted
        ? Colors.black
        : (isCurrent ? Colors.white : Colors.grey[200]!);
    final Color textColor = isCompleted || !isCurrent
        ? Colors.black
        : Colors.white;
    final Color borderColor = isCurrent ? Colors.black : Colors.grey;
    final double borderWidth = isCurrent ? 2.0 : 1.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 圓圈，包含步驟編號或勾號
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 30)
                : Text(
              id,
              style: TextStyle(
                color: isCurrent ? Colors.black : Colors.grey,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 步驟名稱
        Text(
          name,
          style: TextStyle(
            color: Colors.black,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  @override
  void didUpdateWidget(StepperComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.modelType != oldWidget.modelType ||
        widget.configPath != oldWidget.configPath) {
      // 如果模型類型發生變化，重新載入設定
      _loadStepsConfig();
    }
  }
}