import 'dart:convert';

import '../connection/abs_api_request.dart';
import 'package:synchronized/synchronized.dart';

import '../utils/utility.dart';
import 'connection_utils.dart';

class ApiService extends ApiRequestBase {
  static const String PATH_WIZ_DATA = 'lua/db/wizard_data.plua';
  static const String HANDLER_WIZ_WAN_SETUP = 'wizWanSetup';
  static const String HANDLER_WIZ_WIFI2 = 'wizWifi2g';
  static const String HANDLER_WIZ_WIFI5 = 'wizWifi5g';
  static const String HANDLER_WIZ_EASY_MESH = 'wizWifiEasyMesh';
  static const String HANDLER_WIZ_SET_PWD = 'setPassword';
  static const String HANDLER_WIZ_APPLY = 'wizDone';

  //--------------------------WIRELESS NETWORK-----------------------------//
  static const String PATH_WIRELESS_BASIC_SETTINGS_DATA = 'lua/db/wirelessBasicSetting_data.plua';
  static const String HANDLER_WIRELESS_BASIC_SETTINGS = 'wirelessBasicSetting';

  static const String PATH_WIRELESS_MLO_DATA = 'lua/db/wirelessMLOSetting_data.plua';
  static const String HANDLER_WIRELESS_MLO_SETTING = 'wirelessMLOSetting';

  static const String PATH_WIRELESS_WPS_DATA = 'lua/db/wps_data.plua';
  static const String HEADER_WIRELESS_WPS_Client = 'wpsClient';

  //--------------------------MANAGEMENT-----------------------------//
  static const String HANDLER_CHANGE_PASSWORD = 'setAccount';

  //--------------------------Device Settings-----------------------------//
  static const String PATH_REBOOT_SCHEDULE_DATA = 'lua/db/rebootSchedule_data.plua';
  static const String HANDLER_REBOOT_SCHEDULE = 'rebootSchedule';
  static const String HANDLER_REBOOT_ACTION = 'reboot';

  static const String PATH_DATE_TIME_DATA = 'lua/db/NTP_Settings_data.plua';
  static const String HANDLER_NTP = 'ntp';

  //--------------------------ATTACHED DEVICES-----------------------------//
  static const String PATH_ATTACHED_SCHEDULE_TABLE_DATA = 'lua/db/scheduleTable_data.plua';
  static const String PATH_ATTACHED_DEVICES_DATA = 'lua/db/attachedDevTable_data.plua';
  static const String HANDLER_ATTACHED_DEVICE = 'setAttachDevice';


  //---------------------------NETWORK--------------------------------//
  static const String PATH_WAN_OPMODE = 'lua/db/wan_opmode_data.plua';
  static const String PATH_WAN_VPN_CLIENT = 'lua/db/wan_VpnClient_data.plua';
  static const String PATH_NETWORK_BASIC = 'lua/db/internet_basic_data.plua';
  static const String PATH_NETWORK_ETH = 'lua/db/internet_eth_data.plua';
  static const String PATH_NETWORK_PPPOE = 'lua/db/internet_pppoe_data.plua';
  static const String PATH_NETWORK_LAN = 'lua/db/LAN_lan_data.plua';
  static const String PATH_NETWORK_RELOAD = 'lua/db/reloadStatus_data.plua';
  static const String PATH_NETWORK_RESERVED = 'lua/db/reservedTable_data.plua';
  static const String HANDLER_NETWORK_LAN_SETUP = 'lanSetup';
  static const String HANDLER_WAN_ETH_SETUP = 'wanEtherSetup';
  static const String HANDLER_WAN_PPPOE_SETUP = 'wanPPPoE';
  static const String HANDLER_WAN_VPN_SETUP = 'wanVpnClientSetup';
  static const String HANDLER_WAN_OP_SETUP = 'wanOpmodeSetup';
  static const String HANDLER_WAN_DISABLE = 'wanDisable';

  static final ApiService _instance = ApiService._internal();

  factory ApiService() => _instance;

  ApiService._internal();

  final _lock = Lock();

  Future<String> fetchData(String target) async {
    try {
      final response = await get(target, {});
      print('get $target \ncode:${response.statusCode}\nresponse -> ${response.body}');
      return response.body;
    } catch (e) {
      print('fetchData query error: $e');
      return '';
    }
  }

  @override
  Future<PostResult> postData(String handler, data, {String? target, Map<String, String>? headers}) async {
    try {
      print('handler = $handler\ndata -> ${json.encode(data)}');
    } catch (e) {
      print('handler = $handler\ndata -> $data');
    }
    PostResult res = await _lock.synchronized(() async {
      final result = await post(handler, data, headers: headers, target: target);
      PrintUtil.printMap('HEADER', result.headers);
      print(result.body);
      return PostResult(response: result);
    });
    return res;
  }

  void updateBlankState(bool state) {
    isBlankState = state;
  }
}
