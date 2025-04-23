import 'package:flutter/material.dart';
import 'dart:async';

class ProcessInfo {
  final String name;
  final double percentage;

  ProcessInfo(this.name, this.percentage);
}

class FinishingWizardComponent extends StatefulWidget {
  final List<String> processNames;
  final int totalDurationSeconds;
  final Function()? onCompleted;

  const FinishingWizardComponent({
    Key? key,
    required this.processNames,
    this.totalDurationSeconds = 10,
    this.onCompleted,
  }) : super(key: key);

  @override
  State<FinishingWizardComponent> createState() => _FinishingWizardComponentState();
}

class _FinishingWizardComponentState extends State<FinishingWizardComponent> {
  late List<ProcessInfo> _processes;
  late Timer _timer;
  int _currentProcessIndex = 0;
  double _currentProgress = 0.0;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();

    // 初始化進程列表
    _processes = widget.processNames.map((name) => ProcessInfo(name, 0.0)).toList();

    // 每個進程的目標完成時間（毫秒）
    final int msPerProcess = (widget.totalDurationSeconds * 1000) ~/ widget.processNames.length;

    // 每次更新的間隔（毫秒）
    const int updateInterval = 100;

    // 每次更新增加的百分比
    final double incrementPerUpdate = 100.0 / (msPerProcess / updateInterval);

    // 設置定時器，更新進度
    _timer = Timer.periodic(Duration(milliseconds: updateInterval), (timer) {
      if (_currentProcessIndex >= widget.processNames.length) {
        _timer.cancel();
        // 全部完成，延遲一小段時間後回調
        if (!_isCompleted) {
          _isCompleted = true;
          Future.delayed(const Duration(milliseconds: 500), () {
            if (widget.onCompleted != null) {
              widget.onCompleted!();
            }
          });
        }
        return;
      }

      setState(() {
        // 增加當前進程的進度
        _currentProgress += incrementPerUpdate;

        // 更新進程信息
        _processes[_currentProcessIndex] = ProcessInfo(
            widget.processNames[_currentProcessIndex],
            _currentProgress > 100.0 ? 100.0 : _currentProgress
        );

        // 如果當前進程完成，移到下一個進程
        if (_currentProgress >= 100.0) {
          _currentProcessIndex++;
          _currentProgress = 0.0;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Container(
      width: screenSize.width * 0.9,
      color: const Color(0xFFEFEFEF),
      padding: const EdgeInsets.all(25.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 進程列表
          ..._processes.map((process) => _buildProcessItem(process)),

          const SizedBox(height: 30),

          // 總進度指示器
          LinearProgressIndicator(
            value: _calculateTotalProgress(),
            minHeight: 10,
            backgroundColor: Colors.grey[300],
            color: Colors.black,
          ),

          const SizedBox(height: 15),

          // 總進度百分比
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${(_calculateTotalProgress() * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 計算總體進度（0.0 - 1.0）
  double _calculateTotalProgress() {
    if (_processes.isEmpty) return 0.0;

    double totalPercentage = 0.0;
    for (var process in _processes) {
      totalPercentage += process.percentage;
    }

    return totalPercentage / (_processes.length * 100.0);
  }

  // 構建單個進程項目
  Widget _buildProcessItem(ProcessInfo process) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              process.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${process.percentage.toInt()}%',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // 進度條
        ClipRRect(
          borderRadius: BorderRadius.circular(2.0),
          child: LinearProgressIndicator(
            value: process.percentage / 100.0,
            minHeight: 8,
            backgroundColor: Colors.grey[300],
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}