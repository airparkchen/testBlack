import 'dart:developer';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:srp/client.dart' as client;

import 'connection_utils.dart';
import '../utils/utility.dart';

class LoginProcess {
  final String baseUrl;
  // final _username = 'engineer';
  // final _password = 'g4GhCqLhzzxYZnETTaxa';
  String _username = '';
  String _password = '';
  String _token = '';
  SessionInfo emptySession = SessionInfo(sessionId: "", csrfToken: "");
  LoginProcess(this.baseUrl, String username, String pwd) {
    this._username = username;
    this._password = pwd;
  }

  bool isSessionFull(Map<String, String> headers) {
    String? sessionFull = headers['retry-after'];
    return sessionFull != null;
  }

  String? getSessionIDFromHeaders(Map<String, String> headers) {
    String? cookie = headers['set-cookie'];
    if (cookie == null) {
      return null;
    }
    String? sessionId = getSessionID(cookie);
    return sessionId;
  }

  String getCSRFToken(String responseBody) {
    final csrfTokenRegex = RegExp(r'CSRF_TOKEN\s*=\s*"([a-f0-9]{32})"');
    final match = csrfTokenRegex.firstMatch(responseBody);

    if (match != null && match.groupCount >= 1) {
      print('CSRF token = ${match.group(1)}');
      return match.group(1)!;
    } else {
      //blank state, we need to get csrf from wizard;
      print('CSRF_TOKEN not found in response body, could be a blank state?');
      return "";
    }
  }

  String? getSessionID(String cookieHeader) {
    if (cookieHeader == null) return null;
    final RegExp regExp = RegExp(r'sessionID=([^;]+)');
    final match = regExp.firstMatch(cookieHeader);
    return match?.group(1);
  }

  //get login.html to retrieve header including sessionID;
  Future<void> getCsrfFromWizard() async {
    final String wizPage = '$baseUrl/wizard.html';
    print("print get from : ${Uri.parse(wizPage)}");
    final response = await http.get(Uri.parse(wizPage));
    if (response.statusCode == 200) {
      PrintUtil.printMap('HEADER', response.headers);
      print("_token is getting from wizard.html");
      _token = getCSRFToken(response.body);
    }
  }

  LoginResult preCheck(http.Response res) {
    //check status code first;
    if (res.statusCode == 200) {
      return LoginResult(response: res, returnStatus: true, session: emptySession, msg: "access success");
    } else if (res.statusCode == 302) {
      return LoginResult(response: res, returnStatus: false, session: emptySession, msg: "redirect to somewhere");
    } else if (res.statusCode == 503) {
      return LoginResult(response: res, returnStatus: false, session: emptySession, msg: isSessionFull(res.headers) ? "The connection limit has been reached!" : "Unknown 503");
    } else {
      return LoginResult(response: res, returnStatus: false, session: emptySession, msg: "unknown ${res.statusCode}");
    }
  }

  static int rCount = 1;
  //get login.html to retrieve header including sessionID;
  Future<LoginResult> loginStep1() async {
    final String loginPath = '$baseUrl/login.html';
    print("print get : ${Uri.parse(loginPath)}");
    final response = await http.get(Uri.parse(loginPath));
    PrintUtil.printMap(' [STEP1] HEADER', response.headers);
    return preCheck(response);
  }

  //send public key to server;
  Future<LoginResult> loginStep2(Map<String, String> headers, Map<String, dynamic> data) async {
      final response = await http.post(
        Uri.parse('$baseUrl/cgi-bin/webPost.plua?csrftoken=$_token'),
        headers: headers,
        body: json.encode(data),
      );
      PrintUtil.printMap(' [STEP2] HEADER', response.headers);
      return preCheck(response);
      // if (response.statusCode == 200) {
      //   rCount = 1;
      //   return json.decode(response.body);
      // } else if (response.statusCode == 503) {
      //   PrintUtil.printMap(' [STEP2] 503 HEADER', response.headers);
      //   return response.headers;
      // } else {
      //   rCount = 1;
      //   print("Code : " + response.statusCode.toString());
      //   throw Exception('Failed to send data to login STEP2.');
      // }
  }

  //send M to server;
  Future<LoginResult> loginStep3(Map<String, String> headers, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/cgi-bin/webPost.plua?csrftoken=$_token'),
      headers: headers,
      body: json.encode(data),
    );
    var result = preCheck(response);
    try {
      var tmp = json.decode(result.response!.body);
      //json.decode("{\"error\": {\"waitTime\": 0, \"msg\": \"M didn't match\", \"wrongCount\": 1}}")
      if (tmp['error'] != null) {
        return LoginResult(response: result.response, returnStatus: false, session: emptySession, msg: tmp['error']['msg']);
      }
    } catch (e) {
      print("step3 response paresing error!");
    }
    return result;
  }

  //get dashboard
  Future<dynamic> getDashboard(Map<String, String> headers) async {
    final response = await http.post(
      Uri.parse('$baseUrl/dashboard.html?csrftoken=$_token'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      print(response.body);
      return response.body;
    } else {
      print("Code : " + response.statusCode.toString() );
      throw Exception('Failed to send data to login get Dashboard');
    }
  }


  Future<LoginResult> startSRPLoginProcess() async {
    try {
      //1. get login.html to retrieve header including sessionID;
      var result = await loginStep1();
      if (!result.returnStatus) return result;
      _token = getCSRFToken(result.response!.body);
      String sessionId = getSessionIDFromHeaders(result.response!.headers) ?? "";
      print("get session = ${sessionId} , token = ${_token}");

      if (_token == "") {
        //maybe in blank state, so login is not require;
        //but we need to get csrf from wizard page in blank state;
        //return SessionInfo(sessionId: sessionId, csrfToken: _token);
        await getCsrfFromWizard();
        return LoginResult(response: result.response, session: SessionInfo(sessionId: sessionId, csrfToken: _token), msg: "get csrf from Wizard", returnStatus: true);
      }

      //2. gen salt andk keys
      final salt = client.generateSalt();
      print('generateSalt : $salt');

      final clientEphemeral = client.generateEphemeral();
      print('clientEphemeral : public : ${clientEphemeral.public} \n secret : ${clientEphemeral.secret}');

      final step2PostData = {
        'function': 'authenticate',
        'data': {
          'CSRFtoken': _token,
          'I': _username,
          'A': clientEphemeral.public,
        }
      };

      final step2Header = {
        'Content-Type': 'application/json',
        'Referer': 'http://192.168.1.1/login.html',
        'Cookie': 'sessionID=$sessionId',
      };

      //3. send public key to server;
      result = await loginStep2(step2Header , step2PostData);
      if (!result.returnStatus) return result;
      var dataFromStep2 = result.getJson();
      print('salt and B received from server : ${dataFromStep2}');

      //the salt and B received from server;
      String saltFromHost = dataFromStep2['s'];
      String BFromHost = dataFromStep2['B'];

      final privateKey = client.derivePrivateKey(saltFromHost, _username, _password);   //x = H(salt, 'ac:pwd')
      final verifier = client.deriveVerifier(privateKey);                               //g^x mod N
      final clientSession = client.deriveSession(clientEphemeral.secret, BFromHost,
           saltFromHost, _username, privateKey);
      print('clientSession : M1: ${clientSession.proof} ');

      final step3Header = {
        'Content-Type': 'application/json',
        'Origin': 'http://192.168.1.1',
        'Referer': 'http://192.168.1.1/login.html',
        'Cookie': 'sessionID=$sessionId',
      };

      final step3PostData = {
        'function': 'authenticate',
        'data': {
          'CSRFtoken': '',
          'M': clientSession.proof,
        }
      };

      //3. send M to server;
      result = await loginStep3(step3Header , step3PostData);
      if (!result.returnStatus) return result;
      var dataFromStep3 = result.getJson();
      print('Received M2 from server : $dataFromStep3');

      String M2 = dataFromStep3['M'];
      //verification H(A,M,K) should be equaling with (M2)
      client.verifySession(clientEphemeral.public, clientSession, M2);

      return LoginResult(response: null, returnStatus: true, session: SessionInfo(sessionId: sessionId, csrfToken: _token), msg: "login success");

    } catch (e) {
      print('Error: ');
      return LoginResult(response: null, returnStatus: false, session: SessionInfo(sessionId: "", csrfToken: ""), msg: "login error $e");
    }
  }
}

class LoginResult {
  http.Response? response;
  bool returnStatus;
  String msg;
  SessionInfo session;
  LoginResult({required this.response, required this.returnStatus, required this.session, required this.msg});

  Map<String, dynamic> getJson() {
    try {
      return json.decode(response!.body);
    } catch (e) {
      print("error body is :  ${response?.body}");
      return {};
    }
  }
}