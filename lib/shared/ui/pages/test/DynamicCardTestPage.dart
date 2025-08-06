import 'package:flutter/material.dart';
import 'dart:ui';

// ================================
// 配置層 - 動態卡片配置管理
// ================================
class DynamicCardConfig {
  // 卡片基礎配置
  static const double cardWidthRatio = 0.9;           // 卡片寬度比例
  static const double cardMinHeightRatio = 0.30;      // 最小高度比例
  static const double cardMaxHeightRatio = 0.75;      // 最大高度比例
  static const double cardPaddingRatio = 0.05;        // 內邊距比例
  static const double cardBorderRadius = 4.0;         // 圓角半徑

  // 標題相關配置
  static const double titleHeightRatio = 0.08;        // 標題區域高度比例
  static const double titleBottomSpaceRatio = 0.02;   // 標題底部間距比例

  // 分隔線配置
  static const double dividerThickness = 1.0;         // 分隔線厚度
  static const double dividerOpacity = 0.1;           // 分隔線透明度
  static const double dividerMarginRatio = 0.03;      // 分隔線上下邊距比例

  // 項目配置
  static const double itemHeightRatio = 0.06;         // 單個項目高度比例
  static const double itemSpacingRatio = 0.025;       // 項目間距比例
  static const double iconSizeRatio = 0.04;           // 圖標大小比例
  static const double iconTextSpacingRatio = 0.02;    // 圖標與文字間距比例

  // 顏色配置
  static const Color cardBackgroundStartColor = Color(0xFF121A3D);
  static const Color cardBackgroundEndColor = Color(0xFF66E9FF);
  static const Color textPrimaryColor = Colors.white;
  static const Color textSecondaryColor = Color(0xB3FFFFFF); // white with 70% opacity
  static const Color dividerColor = Colors.white;
  static const Color iconColor = Colors.white;
}

// ================================
// 主題系統 - 模擬您原有的主題
// ================================
class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 28.0,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.normal,
    color: Colors.white70,
  );
}

// ================================
// 數據層 - 動態卡片項目模型
// ================================
class CardItemModel {
  final String id;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? customIcon;
  final VoidCallback? onTap;
  final bool isEnabled;
  final Map<String, dynamic>? metadata;

  const CardItemModel({
    required this.id,
    required this.title,
    this.subtitle,
    this.icon,
    this.customIcon,
    this.onTap,
    this.isEnabled = true,
    this.metadata,
  });
}

class DynamicCardModel {
  final String title;
  final List<CardItemModel> items;
  final Widget? customIcon;
  final String? subtitle;

  const DynamicCardModel({
    required this.title,
    required this.items,
    this.customIcon,
    this.subtitle,
  });
}

// ================================
// 服務層 - 動態高度計算引擎
// ================================
class DynamicCardLayoutService {

  /// 計算卡片所需的總高度
  static double calculateCardHeight({
    required Size screenSize,
    required DynamicCardModel cardModel,
  }) {
    double totalHeight = 0.0;

    // 1. 卡片內邊距 (上下)
    totalHeight += screenSize.width * DynamicCardConfig.cardPaddingRatio * 2;

    // 2. 標題區域高度
    totalHeight += screenSize.height * DynamicCardConfig.titleHeightRatio;

    // 3. 標題底部間距
    totalHeight += screenSize.height * DynamicCardConfig.titleBottomSpaceRatio;

    // 4. 如果有項目，計算項目區域高度
    if (cardModel.items.isNotEmpty) {
      // 第一條分隔線 + 上下邊距
      totalHeight += DynamicCardConfig.dividerThickness;
      totalHeight += screenSize.height * DynamicCardConfig.dividerMarginRatio * 2;

      // 遍歷所有項目
      for (int i = 0; i < cardModel.items.length; i++) {
        // 項目高度
        totalHeight += screenSize.height * DynamicCardConfig.itemHeightRatio;

        // 如果不是最後一個項目，添加分隔線和間距
        if (i < cardModel.items.length - 1) {
          totalHeight += screenSize.height * DynamicCardConfig.itemSpacingRatio;
          totalHeight += DynamicCardConfig.dividerThickness;
          totalHeight += screenSize.height * DynamicCardConfig.dividerMarginRatio * 2;
        }
      }
    }

    return totalHeight;
  }

  /// 獲取卡片的最終高度 (帶最大最小值限制)
  static double getCardHeight({
    required Size screenSize,
    required DynamicCardModel cardModel,
  }) {
    final calculatedHeight = calculateCardHeight(
      screenSize: screenSize,
      cardModel: cardModel,
    );

    final minHeight = screenSize.height * DynamicCardConfig.cardMinHeightRatio;
    final maxHeight = screenSize.height * DynamicCardConfig.cardMaxHeightRatio;

    // 限制在最小和最大高度之間
    return calculatedHeight.clamp(minHeight, maxHeight);
  }
}

// ================================
// 工具層 - 漸變背景構建器
// ================================
class GradientBackgroundBuilder {

  /// 構建類似 SVG 的漸變背景
  static BoxDecoration buildCardDecoration({
    double borderRadius = 4.0,
    double opacity = 0.2,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      gradient: LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          DynamicCardConfig.cardBackgroundStartColor.withOpacity(opacity),
          DynamicCardConfig.cardBackgroundEndColor.withOpacity(opacity),
        ],
        stops: const [0.0, 1.0],
      ),
      // 添加陰影效果
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.25),
          offset: const Offset(-2, 2),
          blurRadius: 4.0,
          spreadRadius: 0.0,
        ),
      ],
    );
  }

  /// 構建模糊背景效果 (可選)
  static Widget buildBlurredBackground({
    required Widget child,
    double sigma = 5.0,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(DynamicCardConfig.cardBorderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: child,
      ),
    );
  }
}

// ================================
// 介面層 - 動態卡片構建器
// ================================
class DynamicCardBuilder {

  /// 構建動態卡片
  static Widget buildDynamicCard({
    required BuildContext context,
    required DynamicCardModel cardModel,
    bool enableBlur = true,
    ScrollController? scrollController,
  }) {
    final screenSize = MediaQuery.of(context).size;

    // 計算動態高度
    final cardHeight = DynamicCardLayoutService.getCardHeight(
      screenSize: screenSize,
      cardModel: cardModel,
    );

    final cardWidget = Container(
      width: screenSize.width * DynamicCardConfig.cardWidthRatio,
      height: cardHeight,
      decoration: GradientBackgroundBuilder.buildCardDecoration(
        borderRadius: DynamicCardConfig.cardBorderRadius,
        opacity: 0.2,
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        child: Padding(
          padding: EdgeInsets.all(screenSize.width * DynamicCardConfig.cardPaddingRatio),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 標題區域
              _buildTitleSection(context, cardModel),

              // 標題底部間距
              SizedBox(height: screenSize.height * DynamicCardConfig.titleBottomSpaceRatio),

              // 項目列表
              if (cardModel.items.isNotEmpty) ..._buildItemsList(context, cardModel.items),
            ],
          ),
        ),
      ),
    );

    // 根據需要添加模糊效果
    if (enableBlur) {
      return GradientBackgroundBuilder.buildBlurredBackground(
        child: cardWidget,
        sigma: 5.0,
      );
    }

    return cardWidget;
  }

  /// 構建標題區域
  static Widget _buildTitleSection(BuildContext context, DynamicCardModel cardModel) {
    final screenSize = MediaQuery.of(context).size;

    return Container(
      height: screenSize.height * DynamicCardConfig.titleHeightRatio,
      child: Row(
        children: [
          // 自定義圖標 (如果有)
          if (cardModel.customIcon != null) ...[
            SizedBox(
              width: screenSize.width * DynamicCardConfig.iconSizeRatio,
              height: screenSize.width * DynamicCardConfig.iconSizeRatio,
              child: cardModel.customIcon!,
            ),
            SizedBox(width: screenSize.width * DynamicCardConfig.iconTextSpacingRatio),
          ],

          // 標題文字
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  cardModel.title,
                  style: AppTextStyles.heading1.copyWith(
                    color: DynamicCardConfig.textPrimaryColor,
                    fontSize: 28.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                // 副標題 (如果有)
                if (cardModel.subtitle != null) ...[
                  SizedBox(height: 4),
                  Text(
                    cardModel.subtitle!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: DynamicCardConfig.textSecondaryColor,
                      fontSize: 14.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 構建項目列表
  static List<Widget> _buildItemsList(BuildContext context, List<CardItemModel> items) {
    final screenSize = MediaQuery.of(context).size;
    List<Widget> widgets = [];

    // 第一條分隔線
    widgets.add(_buildDivider(screenSize));

    for (int i = 0; i < items.length; i++) {
      final item = items[i];

      // 項目內容
      widgets.add(_buildItemRow(context, item));

      // 如果不是最後一個項目，添加分隔線
      if (i < items.length - 1) {
        widgets.add(SizedBox(height: screenSize.height * DynamicCardConfig.itemSpacingRatio));
        widgets.add(_buildDivider(screenSize));
      }
    }

    return widgets;
  }

  /// 構建分隔線
  static Widget _buildDivider(Size screenSize) {
    return Container(
      margin: EdgeInsets.symmetric(
        vertical: screenSize.height * DynamicCardConfig.dividerMarginRatio,
      ),
      child: Divider(
        color: DynamicCardConfig.dividerColor.withOpacity(DynamicCardConfig.dividerOpacity),
        thickness: DynamicCardConfig.dividerThickness,
        height: DynamicCardConfig.dividerThickness,
      ),
    );
  }

  /// 構建項目行
  static Widget _buildItemRow(BuildContext context, CardItemModel item) {
    final screenSize = MediaQuery.of(context).size;
    final isInteractive = item.onTap != null && item.isEnabled;

    Widget rowContent = Container(
      height: screenSize.height * DynamicCardConfig.itemHeightRatio,
      child: Row(
        children: [
          // 圖標區域
          if (item.customIcon != null || item.icon != null) ...[
            SizedBox(
              width: screenSize.width * DynamicCardConfig.iconSizeRatio,
              height: screenSize.width * DynamicCardConfig.iconSizeRatio,
              child: item.customIcon ?? Icon(
                item.icon!,
                color: item.isEnabled
                    ? DynamicCardConfig.iconColor
                    : DynamicCardConfig.iconColor.withOpacity(0.5),
                size: screenSize.width * DynamicCardConfig.iconSizeRatio,
              ),
            ),
            SizedBox(width: screenSize.width * DynamicCardConfig.iconTextSpacingRatio),
          ],

          // 文字區域
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.title,
                  style: AppTextStyles.heading3.copyWith(
                    color: item.isEnabled
                        ? DynamicCardConfig.textPrimaryColor
                        : DynamicCardConfig.textPrimaryColor.withOpacity(0.5),
                    fontSize: 18.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                // 副標題 (如果有)
                if (item.subtitle != null) ...[
                  SizedBox(height: 2),
                  Text(
                    item.subtitle!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: item.isEnabled
                          ? DynamicCardConfig.textSecondaryColor
                          : DynamicCardConfig.textSecondaryColor.withOpacity(0.5),
                      fontSize: 12.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // 交互指示器 (如果可點擊)
          if (isInteractive) ...[
            Icon(
              Icons.chevron_right,
              color: DynamicCardConfig.iconColor.withOpacity(0.7),
              size: screenSize.width * DynamicCardConfig.iconSizeRatio * 0.8,
            ),
          ],
        ],
      ),
    );

    // 如果可交互，包裝在 GestureDetector 中
    if (isInteractive) {
      return GestureDetector(
        onTap: item.onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: rowContent,
        ),
      );
    }

    return rowContent;
  }
}

// ================================
// 測試頁面 - 可直接在 main.dart 中使用
// ================================
class DynamicCardTestPage extends StatefulWidget {
  const DynamicCardTestPage({Key? key}) : super(key: key);

  @override
  State<DynamicCardTestPage> createState() => _DynamicCardTestPageState();
}

class _DynamicCardTestPageState extends State<DynamicCardTestPage> {

  /// 構建路由器圖標
  Widget _buildRouterIcon() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            offset: Offset(2, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Icon(
        Icons.router,
        color: Colors.black,
        size: 24,
      ),
    );
  }

  /// 創建 PEG-A 卡片範例
  DynamicCardModel _createPegACard() {
    return DynamicCardModel(
      title: "PEG-A",
      customIcon: _buildRouterIcon(),
      items: [
        CardItemModel(
          id: "peg5g",
          title: "PEG-5G",
          icon: Icons.router,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("PEG-5G clicked!")),
            );
          },
        ),
        CardItemModel(
          id: "pegacam",
          title: "PEG-A-CAM",
          icon: Icons.videocam,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("PEG-A-CAM clicked!")),
            );
          },
        ),
      ],
    );
  }

  /// 創建登入表單卡片範例
  DynamicCardModel _createLoginCard() {
    return DynamicCardModel(
      title: "Login",
      subtitle: "Enter your credentials",
      items: [
        CardItemModel(
          id: "account",
          title: "Account",
          subtitle: "admin",
          icon: Icons.person,
        ),
        CardItemModel(
          id: "password",
          title: "Password",
          subtitle: "Enter password",
          icon: Icons.lock,
        ),
      ],
    );
  }

  /// 創建設備列表卡片範例
  DynamicCardModel _createDeviceListCard() {
    return DynamicCardModel(
      title: "Router[s]",
      items: [
        CardItemModel(
          id: "router1",
          title: "Main Router",
          subtitle: "192.168.1.1",
          icon: Icons.router,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Main Router clicked!")),
            );
          },
        ),
        CardItemModel(
          id: "router2",
          title: "Secondary Router",
          subtitle: "192.168.1.2",
          icon: Icons.router,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Secondary Router clicked!")),
            );
          },
        ),
        CardItemModel(
          id: "router3",
          title: "Guest Router",
          subtitle: "192.168.1.3 (Offline)",
          icon: Icons.router,
          isEnabled: false, // 禁用狀態
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1A1A1A), // 深色背景
      appBar: AppBar(
        title: Text(
          "Dynamic Card Test",
          style: AppTextStyles.heading2,
        ),
        backgroundColor: Color(0xFF2A2A2A),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              // PEG-A 卡片
              DynamicCardBuilder.buildDynamicCard(
                context: context,
                cardModel: _createPegACard(),
              ),

              SizedBox(height: 20),

              // 設備列表卡片
              DynamicCardBuilder.buildDynamicCard(
                context: context,
                cardModel: _createDeviceListCard(),
              ),

              SizedBox(height: 20),

              // 登入卡片
              DynamicCardBuilder.buildDynamicCard(
                context: context,
                cardModel: _createLoginCard(),
              ),

              SizedBox(height: 20),

              // 演示按鈕
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    // 觸發重繪以測試響應式
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF9747FF),
                  foregroundColor: Colors.white,
                ),
                child: Text("Refresh Cards"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}