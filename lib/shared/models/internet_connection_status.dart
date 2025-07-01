// lib/shared/models/internet_connection_status.dart
//為了拓樸頁面internet狀態設計的，未來可能會有4種狀況 (connected_status, ping_status)
/// Internet 連接狀態類
class InternetConnectionStatus {
  final bool isConnected;
  final String status;
  final DateTime timestamp;

  InternetConnectionStatus({
    required this.isConnected,
    required this.status,
    required this.timestamp,
  });

  /// 判斷是否應該顯示紅色叉叉
  bool get shouldShowError => !isConnected;

  /// 工廠方法：創建未知狀態
  factory InternetConnectionStatus.unknown() {
    return InternetConnectionStatus(
      isConnected: false,
      status: 'unknown',
      timestamp: DateTime.now(),
    );
  }

  /// 工廠方法：從 ping_status 創建狀態
  factory InternetConnectionStatus.fromPingStatus(String pingStatus) {
    return InternetConnectionStatus(
      isConnected: pingStatus.toLowerCase() == 'connected',
      status: pingStatus,
      timestamp: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'InternetConnectionStatus(isConnected: $isConnected, status: $status, timestamp: $timestamp)';
  }

  /// 判斷兩個狀態是否相同
  bool isSameAs(InternetConnectionStatus? other) {
    if (other == null) return false;
    return isConnected == other.isConnected && status == other.status;
  }
}