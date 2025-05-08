import 'dart:ui';

import 'package:flutter/cupertino.dart';

class AppColors {
  static const primary = Color(0xFF346b7d);
  static const primaryAccent = Color(0xFF245b6d);
  static const secondary = Color(0x42000000);
}

class AppString {
  static List<DayType> get dayList => DayType.values;

  static List<NTPType> get ntpList => NTPType.values;

  static const wanList = [
    WanType.dhcp,
    WanType.staticIp,
    WanType.pppoe,
  ];

  static const vpnTypeList = [
    VPNType.none,
    VPNType.pptp,
    VPNType.l2tp,
  ];

  static const connectionList = [
    ConnectionType.alwaysOn,
    ConnectionType.dod,
  ];
}

enum DeviceModeType {
  router(label: 'Router', value: 'router'),
  meshGateway(label: 'Mesh Gateway', value: 'mesh_gateway'),
  meshExtender(label: 'Mesh Extender', value: 'mesh_extender');

  final String label;
  final String value;

  const DeviceModeType({
    required this.label,
    required this.value,
  });

  static DeviceModeType? fromValue(String value) {
    return DeviceModeType.values.firstWhere(
      (mode) => mode.value == value,
      orElse: () => throw ArgumentError('No DeviceModeType found for value: $value'),
    );
  }
}

/// !!!注意!!! 每個頁面的value可能不一樣
enum WanType {
  dhcp(label: 'DHCP', value: 'DHCP'),
  staticIp(label: 'Static IP', value: 'Static'),
  pppoe(label: 'PPPoE', value: 'PPPoE');

  final String label;
  final String value;

  const WanType({
    required this.label,
    required this.value,
  });
}

enum VPNType {
  none(label: 'None', value: 'None'),
  pptp(label: 'PPTP', value: 'PPTP'),
  l2tp(label: 'L2TP', value: 'L2TP');

  final String label;
  final String value;

  const VPNType({
    required this.label,
    required this.value,
  });
}

enum ConnectionType {
  alwaysOn(label: 'Always On', value: 'always'),
  dod(label: 'Dial on Demand', value: 'onDemand');

  final String label;
  final String value;

  const ConnectionType({
    required this.label,
    required this.value,
  });
}

enum DayType {
  sun(label: 'Sun', value: '0'),
  mon(label: 'Mon', value: '1'),
  tue(label: 'Tue', value: '2'),
  wed(label: 'Sun', value: '3'),
  thu(label: 'Thu', value: '4'),
  fri(label: 'Fri', value: '5'),
  sta(label: 'Sta', value: '6');

  final String label;
  final String value;

  const DayType({
    required this.label,
    required this.value,
  });
}

enum NTPType {
  automatic(label: 'Automatically', value: 'true'),
  manual(label: 'Manually NTP Server', value: 'false');

  final String label;
  final String value;

  const NTPType({
    required this.label,
    required this.value,
  });
}

enum BlockPeriodType {
  never(label: 'Never', value: 'never'),
  always(label: 'Always', value: 'always'),
  schedule(label: 'Schedule', value: 'schedule');

  final String label;
  final String value;

  const BlockPeriodType({
    required this.label,
    required this.value,
  });
}
