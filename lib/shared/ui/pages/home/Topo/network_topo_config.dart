// lib/shared/ui/pages/home/Topo/network_topo_config.dart - 修正版本
// 🎯 統一所有API更新頻率為10秒

import 'package:flutter/material.dart';

/// 網路拓樸頁面配置 - 修正版本
class NetworkTopoConfig {
  // ==================== 資料源控制 ====================

  /// 🎯 是否使用真實資料（false = 假資料，true = 真實 Mesh API 資料）
  /// 切換這個值來控制整個系統的資料來源
  static bool useRealData = true;

  /// 是否顯示 Extender 之間的連接線
  static const bool showExtenderConnections = true;

  // ==================== 🎯 統一API更新頻率控制（全部改為10秒） ====================

  /// 🎯 主要更新頻率：統一為10秒
  static const int unifiedApiUpdateSeconds = 13;

  /// Mesh API 資料快取時間（秒）
  static const int meshApiCacheSeconds = 11;

  /// Dashboard API 快取時間（秒）
  static const int dashboardApiCacheSeconds = 13;

  /// Throughput API 快取時間（秒）
  static const int throughputApiCacheSeconds = 14;

  /// 速度圖表更新頻率（秒）
  static const int speedChartUpdateSeconds = 5;

  /// 🎯 自動重新載入控制
  static const bool enableAutoReload = true; // 是否啟用自動重新載入
  static const int autoReloadIntervalSeconds = 36; // 自動重新載入間隔（30秒，比API更新慢）

  /// 🎯 轉換為 Duration 格式
  static Duration get meshApiCacheDuration => Duration(seconds: meshApiCacheSeconds);
  static Duration get dashboardApiCacheDuration => Duration(seconds: dashboardApiCacheSeconds);
  static Duration get throughputApiCacheDuration => Duration(seconds: throughputApiCacheSeconds);
  static Duration get speedChartUpdateDuration => Duration(seconds: speedChartUpdateSeconds);

  /// 🎯 統一的實際快取時間（所有服務都使用這個）
  static Duration get actualCacheDuration => Duration(seconds: unifiedApiUpdateSeconds);

  /// 🎯 開發/測試快速模式（開發時可啟用）
  static const bool enableFastUpdateMode = false; // 設為 true 啟用快速測試
  static const int fastUpdateSeconds = 3; // 快速更新：每 3 秒

  /// 動態獲取實際使用的快取時間
  static Duration get developmentCacheDuration {
    return enableFastUpdateMode
        ? Duration(seconds: fastUpdateSeconds)
        : actualCacheDuration;
  }


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

  /// 🎯 修正：動畫配置 - 統一更新頻率
  static const Duration animationDuration = Duration(milliseconds: 300);
  static Duration speedUpdateInterval = Duration(seconds: unifiedApiUpdateSeconds); // 🎯 改為10秒
  static Duration meshApiUpdateInterval = Duration(seconds: unifiedApiUpdateSeconds); // 🎯 改為10秒
  static const Curve animationCurve = Curves.easeInOut;

  /// 設備配置
  static const int maxDeviceCount = 10;
  static const double iconSize = 35.0;

  /// 顏色配置
  static const Color primaryColor = Color(0xFF9747FF);
  static const Color secondaryColor = Color(0xFF7B2CBF);

  // ==================== 🎯 新增：統一的調試和日誌控制 ====================

  /// 是否啟用詳細日誌
  static const bool enableDetailedLogging = true;

  /// 是否顯示數據源指示器（開發用）
  static const bool showDataSourceIndicator = false; // 設為 true 來顯示調試資訊

  /// 🎯 取得當前配置摘要（用於調試）
  static String getConfigSummary() {
    return '''
網路拓樸配置摘要:
├─ 資料來源: ${useRealData ? "真實API" : "假資料"}
├─ API更新頻率: ${unifiedApiUpdateSeconds}秒
├─ 快速模式: ${enableFastUpdateMode ? "啟用 (${fastUpdateSeconds}秒)" : "停用"}
├─ 自動重新載入: ${enableAutoReload ? "啟用 (${autoReloadIntervalSeconds}秒)" : "停用"}
├─ Extender連線: ${showExtenderConnections ? "顯示" : "隱藏"}
└─ 詳細日誌: ${enableDetailedLogging ? "啟用" : "停用"}
''';
  }

  /// 🎯 打印當前配置（調試用）
  static void printCurrentConfig() {
    if (enableDetailedLogging) {
      print('🔧 ${getConfigSummary()}');
    }
  }
}