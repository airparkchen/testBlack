import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async' show Future;
import 'package:flutter/services.dart' show rootBundle;

class StepperComponent extends StatefulWidget {
  final String configPath;
  final String modelType;
  // 简化回调定义，只传递当前索引
  final void Function(int)? onStepChanged;

  const StepperComponent({
    Key? key,
    this.configPath = 'lib/shared/config/flows/initialization/wifi.json',
    this.modelType = 'A',
    this.onStepChanged,  // 新增的回调参数
  }) : super(key: key);

  @override
  State<StepperComponent> createState() => _StepperComponentState();
}

class _StepperComponentState extends State<StepperComponent> {
  List<Map<String, dynamic>> steps = [];
  int currentStepIndex = 0;
  bool isLoading = true;
  bool isLastStepCompleted = false;

  // 添加标志以避免在组件已卸载时调用setState
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _loadStepsConfig();

    // 初始化时延迟一帧再通知，确保父组件已完全挂载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyStepChanged();
    });

    // 测试数据延迟加载
    Future.delayed(Duration(seconds: 3), () {
      if (!_mounted) return;

      if (steps.isEmpty) {
        print('使用硬编码的测试数据');
        setState(() {
          steps = [
            {"id": 1, "name": "帳戶", "next": 2},
            {"id": 2, "name": "網路", "next": 3},
            {"id": 3, "name": "無線", "next": 4},
            {"id": 4, "name": "摘要", "next": null}
          ];
          isLoading = false;
        });

        // 在下一帧通知以确保渲染完成
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _notifyStepChanged();
        });
      }
    });
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  // 通知父组件当前步骤的辅助方法
  void _notifyStepChanged() {
    if (!_mounted) return;

    if (widget.onStepChanged != null) {
      print('通知步骤变化: $currentStepIndex');
      widget.onStepChanged!(currentStepIndex);
    }
  }

  // Load the steps from the JSON configuration file
  Future<void> _loadStepsConfig() async {
    if (!_mounted) return;

    try {
      setState(() {
        isLoading = true;
        isLastStepCompleted = false;
      });

      print('尝试加载配置: ${widget.configPath}');
      print('当前模型类型: ${widget.modelType}');

      // 加载 JSON 文件
      final String jsonContent = await rootBundle.loadString(widget.configPath);
      if (!_mounted) return;

      print('成功加载 JSON 内容，长度: ${jsonContent.length}');

      final Map<String, dynamic> jsonData = json.decode(jsonContent);
      print('解析 JSON 数据，键值: ${jsonData.keys}');

      // 提取指定模型类型的步骤
      if (jsonData.containsKey('models') &&
          jsonData['models'].containsKey(widget.modelType) &&
          jsonData['models'][widget.modelType].containsKey('steps')) {

        final stepsData = jsonData['models'][widget.modelType]['steps'];
        print('找到步骤数据: $stepsData');

        if (!_mounted) return;
        setState(() {
          steps = List<Map<String, dynamic>>.from(stepsData);
          isLoading = false;
          currentStepIndex = 0; // 重置步骤索引
          print('成功设置 ${steps.length} 个步骤');
        });

        // 在下一帧通知以确保渲染完成
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _notifyStepChanged();
        });
      } else {
        print('未找到有效的步骤数据');
        if (!_mounted) return;
        setState(() {
          steps = [];
          isLoading = false;
          currentStepIndex = 0;
        });

        // 在下一帧通知以确保渲染完成
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _notifyStepChanged();
        });
      }
    } catch (e) {
      print('加载步骤配置时出错: $e');
      if (!_mounted) return;
      setState(() {
        steps = [];
        isLoading = false;
        currentStepIndex = 0;
      });

      // 在下一帧通知以确保渲染完成
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notifyStepChanged();
      });
    }
  }

  // Go to the next step if possible
  void _nextStep() {
    if (!_mounted) return;

    if (currentStepIndex < steps.length - 1) {
      // If not on the last step, advance to the next step
      setState(() {
        currentStepIndex++;
      });

      // 在状态更新后通知
      _notifyStepChanged();
    } else if (currentStepIndex == steps.length - 1 && !isLastStepCompleted) {
      // If on the last step and it's not completed yet, mark it as completed
      setState(() {
        isLastStepCompleted = true;
      });

      // 在状态更新后通知
      _notifyStepChanged();
    }
  }

  // Go to the previous step if possible
  void _previousStep() {
    if (!_mounted) return;

    if (currentStepIndex > 0) {
      setState(() {
        currentStepIndex--;
        // If going back from the completed last step, reset the completion flag
        if (currentStepIndex == steps.length - 2 && isLastStepCompleted) {
          isLastStepCompleted = false;
        }
      });

      // 在状态更新后通知
      _notifyStepChanged();
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

    // 如果回调函数变了，通知新的回调
    if (widget.onStepChanged != oldWidget.onStepChanged) {
      _notifyStepChanged();
    }
  }
}