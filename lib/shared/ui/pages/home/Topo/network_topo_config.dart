// lib/shared/ui/pages/home/Topo/network_topo_config.dart

import 'package:flutter/material.dart';

/// 網路拓樸頁面配置
class NetworkTopoConfig {
  // ==================== 資料源控制 ====================

  /// 是否使用真實資料（false = 假資料，true = 真實 Mesh API 資料）
  static bool useRealData = true;

  /// 是否顯示 Extender 之間的連接線
  static const bool showExtenderConnections = true; // 設為 true 啟用功能
  // ==================== 🎯 新增：API 更新頻率控制 ====================

  /// Mesh API 資料快取時間（秒）
  /// 🎯 主要更新頻率控制：每 10 秒更新一次 Mesh API
  static const int meshApiCacheSeconds = 10;

  /// 轉換為 Duration 格式
  static Duration get meshApiCacheDuration => Duration(seconds: meshApiCacheSeconds);

  /// 🎯 測試用快速更新模式（開發/測試時使用）
  static const bool enableFastUpdateMode = false; // 設為 true 啟用快速測試
  static const int fastUpdateSeconds = 3; // 快速更新：每 3 秒

  /// 動態獲取實際使用的快取時間
  static Duration get actualCacheDuration {
    return enableFastUpdateMode
        ? Duration(seconds: fastUpdateSeconds)
        : meshApiCacheDuration;
  }

  /// 🎯 自動重新載入控制
  static const bool enableAutoReload = true; // 是否啟用自動重新載入
  static const int autoReloadIntervalSeconds = 30; // 自動重新載入間隔（秒）

  /// 獲取自動重新載入間隔
  static Duration get autoReloadInterval => Duration(seconds: autoReloadIntervalSeconds);

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
  static const Duration meshApiUpdateInterval = Duration(seconds: 30);
  static const Curve animationCurve = Curves.easeInOut;

  /// 設備配置
  static const int maxDeviceCount = 10;
  static const double iconSize = 35.0;

  /// 顏色配置
  static const Color primaryColor = Color(0xFF9747FF);
  static const Color secondaryColor = Color(0xFF7B2CBF);
}