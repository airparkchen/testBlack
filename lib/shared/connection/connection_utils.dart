import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;

class PostData {
  String function;
  Map<String, dynamic> data;

  PostData({
    required this.function,
    required this.data,
  });

  String toJson() {
    return json.encode({
      'function': function,
      'data': data,
    });
  }
}

class PostResult {
  final String STATUS_SUCCESS = "success";
  final String STATUS_ERROR = "error";
  final String ERROR_MSG = "response not found!!";
  http.Response? response;
  Map<String, dynamic> data = {};

  PostResult({required this.response}) {
    try {
      data = json.decode(this.response!.body);
    } catch (e) {
      print('http.response parser failed !');
    }
  }

  bool isSuccess() {
    return getStatus() == STATUS_SUCCESS;
  }

  String getStatus() {
    return data['status'] ?? ERROR_MSG;
  }

  String getMessage() {
    return data['message'] ?? ERROR_MSG;
  }
}

class SessionInfo {
  final String sessionId;
  String csrfToken;

  SessionInfo({
    required this.sessionId,
    required this.csrfToken,
  });

  String attachCsrfToken(String url) {
    return '$url?csrftoken=$csrfToken';
  }

  bool updateCSRFFromGet(http.Response response) {
    final csrfTokenRegex = RegExp(r'CSRF_TOKEN\s*=\s*"([a-f0-9]{32})"');
    final match = csrfTokenRegex.firstMatch(response.body);

    if (match != null && match.groupCount >= 1) {
      print('updateCSRFviaGet >> CSRF token = ${match.group(1)}');
      String newToken = match.group(1)!;
      if (newToken != null && newToken != "" && csrfToken != newToken) {
        csrfToken = newToken;
        log("##############csrfToken updated from html src: $csrfToken");
      }
    }
    return false;
  }

  bool updateCSRFToken(http.Response response) {
    try {
      var json = jsonDecode(response.body);
      var oldToken = this.csrfToken;
      var newToken = json['csrfToken'] ?? csrfToken;
      if (newToken != "" && oldToken != newToken) {
        csrfToken = newToken;
        log("##############csrfToken updated from response json: $csrfToken");
        return true;
      }
    } catch (exception) {
      log('parse csrf from json failed: body : ${response.body}');
    }
    return false;
  }

  bool isEmpty() {
    return sessionId.isEmpty || csrfToken.isEmpty;
  }

  bool isNotEmpty() {
    return !isEmpty();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true; // check objects are same instance;
    if (other is! SessionInfo) return false; // make sure they are same object type.
    return csrfToken == other.csrfToken && sessionId == other.sessionId; //compare data
  }

  @override
  String toString() {
    // TODO: implement toString
    return 'SessionId = $sessionId, CSRF token = $csrfToken';
  }
}
