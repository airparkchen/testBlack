import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async' show Future;
import 'package:flutter/services.dart' show rootBundle;

// 添加這個 controller 類，在已有的檔案中實作這部分
class StepperController extends ChangeNotifier {
  int _currentStep = 0;

  int get currentStep => _currentStep;

  // 跳轉至指定步驟
  void jumpToStep(int step) {
    _currentStep = step;
    notifyListeners();
  }

  // 移至下一步
  void nextStep() {
    _currentStep++;
    notifyListeners();
  }

  // 移至上一步
  void previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
    }
  }
}

class StepperComponent extends StatefulWidget {
  final String configPath;
  final String modelType;
  final void Function(int)? onStepChanged;
  // 新增控制器參數
  final StepperController? controller;

  const StepperComponent({
    Key? key,
    this.configPath = 'lib/shared/config/flows/initialization/wifi.json',
    this.modelType = 'Micky',
    this.onStepChanged,
    this.controller,
  }) : super(key: key);

  @override
  State<StepperComponent> createState() => _StepperComponentState();
}

class _StepperComponentState extends State<StepperComponent> {
  List<Map<String, dynamic>> steps = [];
  int currentStepIndex = 0;
  bool isLoading = true;
  bool isLastStepCompleted = false;
  bool _mounted = true;

  // 控制器監聽器
  void _controllerListener() {
    if (!_mounted) return;

    setState(() {
      currentStepIndex = widget.controller!.currentStep;
    });

    // 通知父組件
    if (widget.onStepChanged != null) {
      widget.onStepChanged!(currentStepIndex);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadStepsConfig();

    // 如果有提供控制器，設置監聽器
    if (widget.controller != null) {
      widget.controller!.addListener(_controllerListener);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyStepChanged();
    });

    // 測試數據延遲加載
    Future.delayed(Duration(seconds: 3), () {
      if (!_mounted) return;

      if (steps.isEmpty) {
        print('使用硬編碼的測試數據');
        setState(() {
          steps = [
            {"id": 1, "name": "帳戶", "next": 2},
            {"id": 2, "name": "網路", "next": 3},
            {"id": 3, "name": "無線", "next": 4},
            {"id": 4, "name": "摘要", "next": null}
          ];
          isLoading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _notifyStepChanged();
        });
      }
    });
  }

  @override
  void dispose() {
    // 移除控制器監聽器
    if (widget.controller != null) {
      widget.controller!.removeListener(_controllerListener);
    }
    _mounted = false;
    super.dispose();
  }

  @override
  void didUpdateWidget(StepperComponent oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 檢查控制器是否變更
    if (widget.controller != oldWidget.controller) {
      if (oldWidget.controller != null) {
        oldWidget.controller!.removeListener(_controllerListener);
      }
      if (widget.controller != null) {
        widget.controller!.addListener(_controllerListener);
        // 立即同步當前步驟
        setState(() {
          currentStepIndex = widget.controller!.currentStep;
        });
      }
    }

    if (widget.modelType != oldWidget.modelType ||
        widget.configPath != oldWidget.configPath) {
      _loadStepsConfig();
    }
  }

  // 通知父組件當前步驟的輔助方法
  void _notifyStepChanged() {
    if (!_mounted) return;

    if (widget.onStepChanged != null) {
      widget.onStepChanged!(currentStepIndex);
    }

    // 同步控制器
    if (widget.controller != null && widget.controller!.currentStep != currentStepIndex) {
      // 避免無限循環，暫時移除監聽器
      widget.controller!.removeListener(_controllerListener);
      widget.controller!.jumpToStep(currentStepIndex);
      widget.controller!.addListener(_controllerListener);
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

      print('嘗試載入配置: ${widget.configPath}');
      print('當前模型類型: ${widget.modelType}');

      // 加載 JSON 文件
      final String jsonContent = await rootBundle.loadString(widget.configPath);
      if (!_mounted) return;

      print('成功載入 JSON 內容，長度: ${jsonContent.length}');

      final Map<String, dynamic> jsonData = json.decode(jsonContent);
      print('解析 JSON 數據，鍵值: ${jsonData.keys}');

      // 提取指定模型類型的步驟
      if (jsonData.containsKey('models') &&
          jsonData['models'].containsKey(widget.modelType) &&
          jsonData['models'][widget.modelType].containsKey('steps')) {
        final stepsData = jsonData['models'][widget.modelType]['steps'];
        print('找到步驟數據: $stepsData');

        if (!_mounted) return;
        setState(() {
          steps = List<Map<String, dynamic>>.from(stepsData);
          isLoading = false;

          // 如果控制器存在，從控制器獲取當前步驟
          if (widget.controller != null) {
            currentStepIndex = widget.controller!.currentStep;
          } else {
            currentStepIndex = 0; // 重置步驟索引
          }

          print('成功設置 ${steps.length} 個步驟');
        });

        // 在下一幀通知以確保渲染完成
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _notifyStepChanged();
        });
      } else {
        print('未找到有效的步驟數據');
        if (!_mounted) return;
        setState(() {
          steps = [];
          isLoading = false;

          // 如果控制器存在，從控制器獲取當前步驟
          if (widget.controller != null) {
            currentStepIndex = widget.controller!.currentStep;
          } else {
            currentStepIndex = 0;
          }
        });

        // 在下一幀通知以確保渲染完成
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _notifyStepChanged();
        });
      }
    } catch (e) {
      print('載入步驟配置時出錯: $e');
      if (!_mounted) return;
      setState(() {
        steps = [];
        isLoading = false;

        // 如果控制器存在，從控制器獲取當前步驟
        if (widget.controller != null) {
          currentStepIndex = widget.controller!.currentStep;
        } else {
          currentStepIndex = 0;
        }
      });

      // 在下一幀通知以確保渲染完成
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

      // 在狀態更新後通知
      _notifyStepChanged();
    } else if (currentStepIndex == steps.length - 1 && !isLastStepCompleted) {
      // If on the last step and it's not completed yet, mark it as completed
      setState(() {
        isLastStepCompleted = true;
      });

      // 在狀態更新後通知
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

      // 在狀態更新後通知
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
}