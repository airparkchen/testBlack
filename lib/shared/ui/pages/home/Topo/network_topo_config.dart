// lib/shared/ui/pages/home/Topo/network_topo_config.dart

import 'package:flutter/material.dart';

/// 網路拓樸頁面配置
class NetworkTopoConfig {
  // ==================== 資料源控制 ====================

  /// 是否使用真實資料（false = 假資料，true = 真實 Mesh API 資料）
  static bool useRealData = false;

  // ==================== 版面常數 ====================

  /// 螢幕比例
  static const double tabBarTopRatio = 0.085;
  static const double tabBarTopEmbeddedRatio = 0.07;
  static const double topologyHeightRatio = 0.50;
  static const double speedAreaHeight = 180.0;
  static const double bottomNavBottomRatio = 0.08;

  /// TabBar 配置
  static const EdgeInsets tabBarMargin = EdgeInsets.only(left: 60, right: 60);
  static const double tabBarHeight = 30.0;

  /// 底部導航配置
  static const double bottomNavHeight = 70.0;
  static const double bottomNavLeftRatio = 0.145;
  static const double bottomNavRightRatio = 0.151;

  /// 動畫配置
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration speedUpdateInterval = Duration(milliseconds: 500);
  static const Curve animationCurve = Curves.easeInOut;

  /// 設備配置
  static const int maxDeviceCount = 10;
  static const double iconSize = 35.0;

  /// 顏色配置
  static const Color primaryColor = Color(0xFF9747FF);
  static const Color secondaryColor = Color(0xFF7B2CBF);
}