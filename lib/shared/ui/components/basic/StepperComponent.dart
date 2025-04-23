import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async' show Future;
import 'package:flutter/services.dart' show rootBundle;

class StepperController extends ChangeNotifier {
  int _currentStep = 0;

  int get currentStep => _currentStep;

  void jumpToStep(int step) {
    _currentStep = step;
    notifyListeners();
  }

  void nextStep() {
    _currentStep++;
    notifyListeners();
  }

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
  final StepperController? controller;
  final bool isLastStepCompleted;

  const StepperComponent({
    Key? key,
    this.configPath = 'lib/shared/config/flows/initialization/wifi.json',
    this.modelType = 'Micky',
    this.onStepChanged,
    this.controller,
    this.isLastStepCompleted = false,
  }) : super(key: key);

  @override
  State<StepperComponent> createState() => _StepperComponentState();
}

class _StepperComponentState extends State<StepperComponent> {
  List<Map<String, dynamic>> steps = [];
  int currentStepIndex = 0;
  bool isLoading = true;
  bool _mounted = true;

  void _controllerListener() {
    if (!_mounted) return;

    setState(() {
      currentStepIndex = widget.controller!.currentStep;
    });

    if (widget.onStepChanged != null) {
      widget.onStepChanged!(currentStepIndex);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadStepsConfig();

    if (widget.controller != null) {
      widget.controller!.addListener(_controllerListener);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyStepChanged();
    });

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
    if (widget.controller != null) {
      widget.controller!.removeListener(_controllerListener);
    }
    _mounted = false;
    super.dispose();
  }

  @override
  void didUpdateWidget(StepperComponent oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      if (oldWidget.controller != null) {
        oldWidget.controller!.removeListener(_controllerListener);
      }
      if (widget.controller != null) {
        widget.controller!.addListener(_controllerListener);
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

  void _notifyStepChanged() {
    if (!_mounted) return;

    if (widget.onStepChanged != null) {
      widget.onStepChanged!(currentStepIndex);
    }

    if (widget.controller != null && widget.controller!.currentStep != currentStepIndex) {
      widget.controller!.removeListener(_controllerListener);
      widget.controller!.jumpToStep(currentStepIndex);
      widget.controller!.addListener(_controllerListener);
    }
  }

  Future<void> _loadStepsConfig() async {
    if (!_mounted) return;

    try {
      setState(() {
        isLoading = true;
      });

      print('嘗試載入配置: ${widget.configPath}');
      print('當前模型類型: ${widget.modelType}');

      final String jsonContent = await rootBundle.loadString(widget.configPath);
      if (!_mounted) return;

      print('成功載入 JSON 內容，長度: ${jsonContent.length}');

      final Map<String, dynamic> jsonData = json.decode(jsonContent);
      print('解析 JSON 數據，鍵值: ${jsonData.keys}');

      if (jsonData.containsKey('models') &&
          jsonData['models'].containsKey(widget.modelType) &&
          jsonData['models'][widget.modelType].containsKey('steps')) {
        final stepsData = jsonData['models'][widget.modelType]['steps'];
        print('找到步驟數據: $stepsData');

        if (!_mounted) return;
        setState(() {
          steps = List<Map<String, dynamic>>.from(stepsData);
          isLoading = false;
          if (widget.controller != null) {
            currentStepIndex = widget.controller!.currentStep;
          } else {
            currentStepIndex = 0;
          }
          print('成功設置 ${steps.length} 個步驟');
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _notifyStepChanged();
        });
      } else {
        print('未找到有效的步驟數據');
        if (!_mounted) return;
        setState(() {
          steps = [];
          isLoading = false;
          if (widget.controller != null) {
            currentStepIndex = widget.controller!.currentStep;
          } else {
            currentStepIndex = 0;
          }
        });

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
        if (widget.controller != null) {
          currentStepIndex = widget.controller!.currentStep;
        } else {
          currentStepIndex = 0;
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notifyStepChanged();
      });
    }
  }

  void _nextStep() {
    if (!_mounted) return;

    if (currentStepIndex < steps.length - 1) {
      setState(() {
        currentStepIndex++;
      });
      _notifyStepChanged();
    }
  }

  void _previousStep() {
    if (!_mounted) return;

    if (currentStepIndex > 0) {
      setState(() {
        currentStepIndex--;
      });
      _notifyStepChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 120,
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : steps.isEmpty
              ? const Center(child: Text('此模型沒有定義步驟'))
              : _buildStepperRow(),
        ),
      ],
    );
  }

  Widget _buildStepperRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: steps.asMap().entries.map((entry) {
        final int index = entry.key;
        final Map<String, dynamic> step = entry.value;

        final bool isCompleted = index < currentStepIndex ||
            (index == currentStepIndex &&
                index == steps.length - 1 &&
                widget.isLastStepCompleted);
        final bool isCurrent = index == currentStepIndex && !widget.isLastStepCompleted;

        return Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (index > 0)
                Positioned(
                  left: 0,
                  right: MediaQuery.of(context).size.width / (steps.length * 2),
                  top: 30,
                  child: Container(
                    height: 4,
                    color: index <= currentStepIndex ? Colors.black : const Color(0xFFEFEFEF),
                  ),
                ),
              if (index < steps.length - 1)
                Positioned(
                  left: MediaQuery.of(context).size.width / (steps.length * 2),
                  right: 0,
                  top: 30,
                  child: Container(
                    height: 4,
                    color: index < currentStepIndex ? Colors.black : const Color(0xFFEFEFEF),
                  ),
                ),
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