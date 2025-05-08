import 'dart:developer';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:srp/client.dart' as client;

import 'connection_utils.dart';
import '../utils/utility.dart';

class ChangePwdProcess {
  final String baseUrl;
  String _username = '';
  String _password = '';
  String _newPwd = '';
  String _token = '';
  late SessionInfo _currSessionInfo;
  SessionInfo emptySession = SessionInfo(sessionId: "", csrfToken: "");
  ChangePwdProcess(this.baseUrl, String username, String pwd, String newPwd, SessionInfo sessionInfo) {
    this._username = username;
    this._password = pwd;
    this._newPwd = newPwd;
    this._currSessionInfo = sessionInfo;
    _token = _currSessionInfo.csrfToken;
  }

  bool isSessionFull(Map<String, String> headers) {
    String? sessionFull = headers['retry-after'];
    return sessionFull != null;
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

  //send new pwd verifier to server
  Future<LoginResult> loginStep4(Map<String, String> headers, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/cgi-bin/webPost.plua?csrftoken=$_token'),
      headers: headers,
      body: json.encode(data),
    );
    var result = preCheck(response);
    try {
      print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!'+result.response!.body);
      var tmp = json.decode(result.response!.body);

      if (tmp['error'] != null) {
        return LoginResult(response: result.response, returnStatus: false, session: emptySession, msg: tmp['error']['msg']);
      }
    } catch (e) {
      print("step4 response paresing error!");
    }
    return result;
  }


  Future<LoginResult> startChangePwdProcess() async {
    try {
      String sessionId = _currSessionInfo.sessionId;

      //2. gen salt and keys
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
        'Referer': 'http://192.168.1.1/change_password.html',
        'Cookie': 'sessionID=$sessionId',
      };

      //3. send public key to server;
      var result = await loginStep2(step2Header , step2PostData);
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
        'Referer': 'http://192.168.1.1/change_password.html',
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
      //login pwd check done;

      //4. send post to "setAccount" function
      //gen new salt and keys
      final newSalt = client.generateSalt();
      final newPrivateKey = client.derivePrivateKey(newSalt, _username, _newPwd);   //x = H(salt, 'ac:pwd')
      final newVerifier = client.deriveVerifier(newPrivateKey);                               //g^x mod N
      print('generate newSalt : $newSalt \nVerifier: $newVerifier');

      final step4Header = {
        'Content-Type': 'application/json',
        'Origin': 'http://192.168.1.1',
        'Referer': 'http://192.168.1.1/change_password.html',
        'Cookie': 'sessionID=$sessionId',
      };
      final step4PostData = {
        'function': 'setAccount',
        'data': {
          'CSRFtoken': _token,
          'old_name': _username,
          'user_name': _username,
          'srp_salt' : newSalt,
          'srp_verifier' : newVerifier,
          'action' : 'change',
        }
      };

      result = await loginStep4(step4Header , step4PostData);
      var serverRes = json.decode(result.response!.body);

      //return should be
      //{"message":"Set user account successfully!","csrfToken":"a05249cd938b79c16b0437b01575412a","status":"success"}GET / HTTP/1.1
      // return LoginResult(response: null, returnStatus: true, session: SessionInfo(sessionId: sessionId, csrfToken: _token), msg: "login success");
      return LoginResult(response: result.response, returnStatus: serverRes['status'] == "success", session: SessionInfo(sessionId: sessionId, csrfToken: serverRes['csrfToken']), msg: "Change Pwd Success ${serverRes['message']}");

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