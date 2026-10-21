
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  // Change this if your Laravel server uses a different port.
  static const String baseUrl = 'http://127.0.0.1:8001/api';

  static String? _token;

  static bool get isLoggedIn => _token != null;

  static Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Map<String, dynamic> _decodeResponse(
      http.Response response,
      ) {
    Map<String, dynamic> body;

    try {
      final decoded = jsonDecode(response.body);
      body = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
    } catch (_) {
      body = <String, dynamic>{};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    final message = body['message']?.toString() ??
        'Request failed with status ${response.statusCode}.';

    throw Exception(message);
  }

  static Future<void> login({
    required String email,
    required String password,
  }) async {
    final response = await http
        .post(
      Uri.parse('$baseUrl/login'),
      headers: _headers,
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
      }),
    )
        .timeout(const Duration(seconds: 20));

    final data = _decodeResponse(response);
    final token = data['access_token']?.toString();

    if (token == null || token.isEmpty) {
      throw Exception('The server did not return an access token.');
    }

    _token = token;

    try {
      // Verify that this account can access the lender API.
      await getGrants();
    } catch (_) {
      _token = null;
      rethrow;
    }
  }

  static Future<void> logout() async {
    // Clear the portal's local session.
    // Your current routes do not expose a lender-specific logout endpoint.
    _token = null;
  }

  static Future<List<Map<String, dynamic>>> getGrants() async {
    final response = await http
        .get(
      Uri.parse('$baseUrl/lender/access-requests'),
      headers: _headers,
    )
        .timeout(const Duration(seconds: 20));

    final data = _decodeResponse(response);
    final grants = data['grants'];

    if (grants is! List) {
      throw Exception('The server returned an invalid grants response.');
    }

    return grants
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  static Future<String> requestAccess({
    required String borrowerEmail,
    required String scope,
  }) async {
    final response = await http
        .post(
      Uri.parse('$baseUrl/lender/access-requests'),
      headers: _headers,
      body: jsonEncode({
        'borrower_email': borrowerEmail.trim(),
        'scope': scope,
      }),
    )
        .timeout(const Duration(seconds: 20));

    final data = _decodeResponse(response);

    return data['message']?.toString() ??
        'Your access request has been submitted.';
  }

  static Future<Map<String, dynamic>> getGrantScore(
      int grantId,
      ) async {
    final response = await http
        .get(
      Uri.parse('$baseUrl/lender/grants/$grantId/score'),
      headers: _headers,
    )
        .timeout(const Duration(seconds: 20));

    final data = _decodeResponse(response);
    final score = data['score'];

    if (score is! Map<String, dynamic>) {
      throw Exception('The server returned an invalid score response.');
    }

    return score;
  }
}
