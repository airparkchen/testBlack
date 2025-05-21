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
    // 獲取螢幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    // 計算每個步驟的平均寬度
    final stepWidth = screenWidth / steps.length;

    // ===== 可調整參數開始 =====
    final double circleDiameter = 50.0; // 圓圈直徑
    final double circleRadius = circleDiameter / 2; // 圓圈半徑 = 30.0
    final double lineHeight = 3.0; // 連接線的粗細
    final double lineVerticalPosition = 30.0; // 連接線的垂直位置
    final Color completedLineColor = Colors.white; // 已完成連接線的顏色
    // ===== 可調整參數結束 =====

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: steps.asMap().entries.map((entry) {
        final int index = entry.key;
        final Map<String, dynamic> step = entry.value;

        // 計算當前步驟的圓心 X 座標 (相對於步驟區域)
        final double centerX = stepWidth / 2;

        // 計算圓的左邊緣 X 座標 (相對於步驟區域)
        final double leftEdgeX = centerX - circleRadius;

        // 計算圓的右邊緣 X 座標 (相對於步驟區域)
        final double rightEdgeX = centerX + circleRadius;

        // 計算左連接線終點 X 座標 (圓的左邊緣)
        final double leftLineEndX = leftEdgeX;

        // 計算右連接線起點 X 座標 (圓的右邊緣)
        final double rightLineStartX = rightEdgeX;

        // 計算左連接線在 Positioned 中的 right 值
        // right = 步驟寬度 - 左連接線終點 X 座標
        final double leftLineRight = stepWidth - leftLineEndX;

        // 計算右連接線在 Positioned 中的 left 值
        // left = 右連接線起點 X 座標
        final double rightLineLeft = rightLineStartX;

        final bool isCompleted = index < currentStepIndex ||
            (index == currentStepIndex &&
                index == steps.length - 1 &&
                widget.isLastStepCompleted);
        final bool isCurrent =
            index == currentStepIndex && !widget.isLastStepCompleted;

        return Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 左側連接線 - 從前一個步驟連接到當前步驟
              if (index > 0)
                Positioned(
                  left: 0, // 連接線從步驟區域左邊界開始
                  right: leftLineRight, // 連接線結束於圓的左邊緣
                  top: lineVerticalPosition,
                  child: index <= currentStepIndex
                      ? Container(
                    height: lineHeight,
                    color: completedLineColor,
                  )
                      : _buildDashedLine(lineHeight),
                ),

              // 右側連接線 - 從當前步驟連接到下一個步驟
              if (index < steps.length - 1)
                Positioned(
                  left: rightLineLeft, // 連接線從圓的右邊緣開始
                  right: 0, // 連接線延伸到步驟區域右邊界
                  top: lineVerticalPosition,
                  child: index < currentStepIndex
                      ? Container(
                    height: lineHeight,
                    color: completedLineColor,
                  )
                      : _buildDashedLine(lineHeight),
                ),

              // 繪製步驟圓形
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

  Widget _buildDashedLine(double height) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double totalWidth = constraints.maxWidth;
        final double dashWidth = 2.5; // 虛線段的寬度
        final double dashSpace = 1.5; // 虛線段之間的間隔
        final dashCycle = dashWidth + dashSpace; // 一個虛線周期的總寬度

        // 計算可以放入的虛線數量
        final int dashCount = (totalWidth / dashCycle).floor();
        // 計算虛線之間的實際間距，以確保它們均勻分布
        final double adjustedSpace = (totalWidth - dashCount * dashWidth) / (dashCount - 1);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (index) {
            // 創建單個虛線段
            return Container(
              width: dashWidth,
              height: height,
              color: Colors.white, // 使用純白色
            );
          }),
        );
      },
    );
  }
  Widget _buildStep({
    required String id,
    required String name,
    required bool isCompleted,
    required bool isCurrent,
  }) {
    // ===== 可調整參數開始 =====
    // 圓圈參數
    final double circleWidth = 60.0; // 圓圈寬度
    final double circleHeight = 60.0; // 圓圈高度

    // 顏色參數
    final Color currentCircleColor = Colors.white; // 當前步驟的圓圈填充顏色
    final Color otherCircleColor = Colors.transparent; // 其他步驟的圓圈填充顏色
    final Color borderColor = Colors.white; // 圓圈邊框顏色

    // 文字顏色
    final Color currentTextColor = Colors.black; // 當前步驟的文字顏色
    final Color otherTextColor = Colors.white; // 其他步驟的文字顏色
    final Color nameTextColor = Colors.white; // 步驟名稱的文字顏色

    // 邊框粗細
    final double currentBorderWidth = 3.0; // 當前步驟的邊框粗細
    final double otherBorderWidth = 3.0; // 其他步驟的邊框粗細

    // 圖標參數
    final double checkIconSize = 30.0; // 完成步驟的勾號大小
    final Color checkIconColor = Colors.white; // 完成步驟的勾號顏色

    // 文字參數
    final double idFontSize = 24.0; // 步驟ID的字體大小
    final FontWeight idFontWeight = FontWeight.bold; // 步驟ID的字體粗細
    final FontWeight currentNameFontWeight = FontWeight.bold; // 當前步驟名稱的字體粗細
    final FontWeight otherNameFontWeight = FontWeight.normal; // 其他步驟名稱的字體粗細

    // 間距參數
    final double spaceBetweenCircleAndName = 8.0; // 圓圈和名稱之間的間距
    // ===== 可調整參數結束 =====

    // 根據狀態選擇樣式
    final Color circleColor = isCurrent ? currentCircleColor : otherCircleColor;
    final Color idTextColor = isCurrent ? currentTextColor : otherTextColor;
    final double borderWidth =
    isCurrent ? currentBorderWidth : otherBorderWidth;
    final FontWeight nameFontWeight =
    isCurrent ? currentNameFontWeight : otherNameFontWeight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: circleWidth,
          height: circleHeight,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Center(
            child: isCompleted
                ? Icon(
              Icons.check,
              color: checkIconColor,
              size: checkIconSize,
            )
                : Text(
              id,
              style: TextStyle(
                color: idTextColor,
                fontSize: idFontSize,
                fontWeight: idFontWeight,
              ),
            ),
          ),
        ),
        SizedBox(height: spaceBetweenCircleAndName),
        Text(
          name,
          style: TextStyle(
            color: nameTextColor,
            fontWeight: nameFontWeight,
          ),
        ),
      ],
    );
  }
}
