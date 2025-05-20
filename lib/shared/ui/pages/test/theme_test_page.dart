// lib/shared/ui/pages/test/theme_test_page.dart

import 'package:flutter/material.dart';
import 'package:whitebox/shared/theme/app_theme.dart';
import 'dart:ui';

class ThemeTestPage extends StatefulWidget {
  const ThemeTestPage({Key? key}) : super(key: key);

  @override
  State<ThemeTestPage> createState() => _ThemeTestPageState();
}

class _ThemeTestPageState extends State<ThemeTestPage> {
  // 當前選擇的背景圖片
  String _currentBackground = AppBackgrounds.mainBackground;
  // 模糊程度
  double _blurRadius = 0.0;
  // 當前背景顯示模式
  BackgroundMode _backgroundMode = BackgroundMode.normal;
  // 是否顯示背景
  bool _showBackground = true;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final appTheme = AppTheme();

    // 根據選擇的模式創建不同的背景
    Widget backgroundWidget;
    if (!_showBackground) {
      // 純色背景
      backgroundWidget = Container(
        color: const Color(0xFFD9D9D9),
        child: _buildContent(screenSize, appTheme),
      );
    } else {
      // 普通背景
      backgroundWidget = Container(
        decoration: BackgroundDecorator.imageBackground(
          imagePath: _currentBackground,
        ),
        child: _buildContent(screenSize, appTheme),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('主題與背景測試'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          // 添加設置按鈕
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: backgroundWidget,
    );
  }

  // 構建主要內容
  Widget _buildContent(Size screenSize, AppTheme appTheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 標題
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '漸層卡片 + 背景圖片測試',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 標準漸層卡片
          Center(
            child: appTheme.whiteBoxTheme.buildStandardCard(
              width: screenSize.width * 0.9,
              height: 180,
              child: const Center(
                child: Text(
                  '標準漸層卡片',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 自定義漸層卡片
          Center(
            child: appTheme.whiteBoxTheme.buildCustomCard(
              width: screenSize.width * 0.9,
              height: 180,
              borderRadius: BorderRadius.circular(12.0),
              gradientColors: const [
                Colors.deepPurple,
                Colors.teal,
                Colors.indigo,
              ],
              opacity: 0.7,
              borderColor: Colors.teal,
              borderWidth: 2.0,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.brush,
                      color: Colors.white,
                      size: 40,
                    ),
                    SizedBox(height: 16),
                    Text(
                      '自定義漸層卡片',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '您可以完全自定義卡片的漸層顏色、邊框和其他屬性',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 加入一些背景描述
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '當前背景設置',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '背景圖片: ${_currentBackground.split('/').last}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '顯示模式: ${_backgroundMode.displayName}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (_backgroundMode == BackgroundMode.blur)
                  Text(
                    '模糊程度: ${_blurRadius.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 響應式背景信息
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '響應式背景信息',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '螢幕寬度: ${screenSize.width.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '螢幕高度: ${screenSize.height.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '推薦背景: ${BackgroundDecorator.getResponsiveBackground(context).split('/').last}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _currentBackground = BackgroundDecorator.getResponsiveBackground(context);
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('使用推薦背景'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // 顯示設置對話框
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('背景設置'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 背景開關
                  SwitchListTile(
                    title: const Text('顯示背景圖片'),
                    value: _showBackground,
                    onChanged: (value) {
                      setState(() {
                        _showBackground = value;
                      });
                    },
                  ),

                  const Divider(),

                  // 背景選擇
                  const Text('選擇背景圖片:'),
                  const SizedBox(height: 8),
                  _buildBackgroundSelector(setState),

                  const Divider(),

                  // 顯示模式選擇
                  const Text('背景顯示模式:'),
                  const SizedBox(height: 8),
                  _buildModeSelector(setState),

                  // 模糊程度調整（僅在模糊模式下顯示）
                  if (_backgroundMode == BackgroundMode.blur) ...[
                    const SizedBox(height: 16),
                    const Text('模糊程度:'),
                    Slider(
                      value: _blurRadius,
                      min: 0,
                      max: 20,
                      divisions: 40,
                      label: _blurRadius.toStringAsFixed(1),
                      onChanged: (value) {
                        setState(() {
                          _blurRadius = value;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // 更新主頁面狀態
                  this.setState(() {});
                },
                child: const Text('確定'),
              ),
            ],
          );
        },
      ),
    );
  }

  // 構建背景選擇器
  Widget _buildBackgroundSelector(StateSetter setState) {
    final backgrounds = [
      AppBackgrounds.mainBackground,
      AppBackgrounds.background2x,
      AppBackgrounds.background3x,
      AppBackgrounds.background4x,
      AppBackgrounds.background5x,
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: backgrounds.map((bg) {
        final isSelected = bg == _currentBackground;
        final name = bg.split('/').last.split('.').first;

        return GestureDetector(
          onTap: () {
            setState(() {
              _currentBackground = bg;
            });
          },
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey,
                width: isSelected ? 3 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: AssetImage(bg),
                fit: BoxFit.cover,
              ),
            ),
            child: isSelected
                ? Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            )
                : Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 8,
                ),
                color: Colors.black.withOpacity(0.5),
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // 構建模式選擇器
  Widget _buildModeSelector(StateSetter setState) {
    return Wrap(
      spacing: 10,
      children: BackgroundMode.values.map((mode) {
        return ChoiceChip(
          label: Text(mode.displayName),
          selected: _backgroundMode == mode,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _backgroundMode = mode;
              });
            }
          },
        );
      }).toList(),
    );
  }
}

// 背景顯示模式
enum BackgroundMode {
  normal(displayName: '普通'),
  blur(displayName: '模糊'),
  gradient(displayName: '漸層覆蓋');

  final String displayName;

  const BackgroundMode({required this.displayName});
}