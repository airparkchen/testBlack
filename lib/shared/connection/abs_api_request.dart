import 'dart:developer';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'login_process.dart';
import 'connection_utils.dart';

abstract class ApiRequestBase {
  final ApiRequestConfig _config = ApiRequestConfig();
  late final String _defaultPostUrl = _config.defaultPost;
  late final String baseUrl = '${_config.protocol}://${_config.host}';
  bool isBlankState = false;
  LoginProcess? _actionLogin;

  Map<String, String> appendHeader(Map<String, String>? headers, String target) {
    headers ??= {};
    headers['Content-Type'] = 'application/json';
    headers['Cookie'] = 'sessionID=${_config.session.sessionId}';
    headers['Referer'] = '$baseUrl/$target';
    return headers;
  }

  //check login first;
  Future<bool> hasBeenLoggedIn() async {
    String target = "lua/db/deviceName_data.plua";
    Map<String, String>? headers = appendHeader({}, target);
    final response = await http.get(Uri.parse(_config.session.attachCsrfToken('$baseUrl/$target')), headers: headers);
    print(response.body);
    try {
      return json.decode(response.body)["name"]["value"].length != 0;
    } catch (e) {
      return false;
    }
  }

  //auto login
  Future<void> autoLogin() async {
    //if session if empty or get device name failed;
    // if (/*_config.session.isEmpty() ||*/ !await hasBeenLoggedIn()) {
    //   print("@@@@@@@@@@@@@@@@@@@@@@@@@auto re-login@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    //   _actionLogin = ActionLogin('http://${_config.host}');
    //   await _actionLogin?.executeApiCalls().then((result) {
    //     if (result != null) {
    //       _config.session = result;
    //     }
    //     print('login result : $result');
    //   });
    // } else {
    //   print('user has been login already !');
    // }
  }

  Future<http.Response> post(String handler, Map<String, dynamic> data,
      {String? target, Map<String, String>? headers}) async {
    return _post(target ?? _defaultPostUrl, headers, PostData(function: handler, data: data));
  }

  Future<http.Response> _post(String target, Map<String, String>? headers, PostData data) async {
    //if (!isBlankState) await autoLogin();
    headers = appendHeader(headers, target);
    final response = await http.post(Uri.parse(_config.session.attachCsrfToken('$baseUrl/$target')),
        headers: headers, body: data.toJson());
    handleResponseError(response, target);
    if (_config.session.updateCSRFToken(response)) {
      //try to update token;
      await _config.syncToDev();
    }
    return response;
  }

  Future<http.Response> get(String target, Map<String, String>? headers) async {
    //if (!isBlankState) await autoLogin();
    headers = appendHeader(headers, target);
    final response = await http.get(Uri.parse(_config.session.attachCsrfToken('$baseUrl/$target')), headers: headers);
    handleResponseError(response, target);
    try {
      _config.session.updateCSRFFromGet(response);
    } catch (e) {}
    return response;
  }

  void handleResponseError(http.Response response, String target) {
    if (response.statusCode != 200) {
      if (response.statusCode == 302) {
        if (response.body.toLowerCase().contains("Unknow Session".toLowerCase())) {
          print("need to relogin");
          return;
        }
      }
      print(
        'Error: Failed to fetch $target, Status: ${response.statusCode}, Response: ${response.body}',
      );
    } else {
      if (target.toLowerCase().contains('post')) {
        log('$target result: success : Response: ${response.body}');
      } else {
        log('$target result: success');
      }
    }
  }

  bool checkPostSuccess(http.Response response) {
    final result = json.decode(response.body);
    log(result.toString());
    return true;
  }

  Future<PostResult> postData(String handler, data, {Map<String, String>? headers});
}

class ApiRequestConfig {
  static final ApiRequestConfig _instance = ApiRequestConfig._internal();

  factory ApiRequestConfig() => _instance;

  ApiRequestConfig._internal() {
    _init();
  }

  final FlutterSecureStorage _storage = FlutterSecureStorage();

  final String _protocol = "http";
  String _host = "192.168.1.1";
  String _userAccount = "";
  final String _defaultPost = "cgi-bin/webPost.plua";
  SessionInfo _sessionInfo = SessionInfo(sessionId: "", csrfToken: "");

  // Getter
  String get protocol => _protocol;

  String get host => _host;

  String get defaultPost => _defaultPost;

  SessionInfo get session => _sessionInfo;

  String get user => _userAccount;

  // Setter
  set host(String value) {
    _host = value;
  }

  set session(SessionInfo value) {
    _sessionInfo = value;
  }

  set user(String value) {
    _userAccount = value;
  }

  Future<void> _init() async {
    print(
        "=====================================API Request Config init()======================================================");
    await _syncDataFromDev();
  }

  Future<void> _syncDataFromDev() async {
    String sessionId = await _storage.read(key: "sessionId") ?? "";
    String sessionCsrf = await _storage.read(key: "csrfToken") ?? "";
    _sessionInfo = SessionInfo(sessionId: sessionId, csrfToken: sessionCsrf);
    _userAccount = await _storage.read(key: "user") ?? "";
    print("@@@@sharedpreference [load] session: ${_sessionInfo.toString()} , user = ${_userAccount}");
    host = await _storage.read(key: 'host') ?? host;
  }

  Future<void> syncToDev() async {
    // 存入資料（加密）
    await _storage.write(key: "user", value: _userAccount.toString());
    await _storage.write(key: "sessionId", value: _sessionInfo.sessionId);
    await _storage.write(key: "csrfToken", value: _sessionInfo.csrfToken);
    print("@@@@sharedpreference [saved] session: ${_sessionInfo.toString()}, user = $_userAccount");
  }
}
