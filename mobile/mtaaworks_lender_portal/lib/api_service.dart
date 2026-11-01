
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
    // Ask the server to revoke the token, then clear the portal's local session.
    try {
      if (_token != null) {
        await http
            .post(Uri.parse('$baseUrl/logout'), headers: _headers)
            .timeout(const Duration(seconds: 10));
      }
    } catch (_) {
      // the local session is cleared even when the server cannot be reached
    }
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

  static Future<List<Map<String, dynamic>>> getLoanRequests() async {
    final response = await http
        .get(Uri.parse('$baseUrl/lender/loan-requests'), headers: _headers)
        .timeout(const Duration(seconds: 20));

    final list = _decodeResponse(response)['loan_requests'];

    if (list is! List) {
      throw Exception('The server returned an invalid loan requests response.');
    }

    return list.whereType<Map<String, dynamic>>().toList();
  }

  /// Opens one loan request together with the borrower's score. Counts as a view.
  static Future<Map<String, dynamic>> getLoanRequest(int id) async {
    final response = await http
        .get(Uri.parse('$baseUrl/lender/loan-requests/$id'), headers: _headers)
        .timeout(const Duration(seconds: 20));

    return _decodeResponse(response);
  }

  static Future<String> decideLoanRequest({
    required int id,
    required bool approve,
    String? note,
  }) async {
    final response = await http
        .post(
      Uri.parse('$baseUrl/lender/loan-requests/$id/${approve ? 'approve' : 'decline'}'),
      headers: _headers,
      body: jsonEncode({if (note != null && note.trim().isNotEmpty) 'note': note.trim()}),
    )
        .timeout(const Duration(seconds: 20));

    return _decodeResponse(response)['message']?.toString() ?? 'Done.';
  }
  /// Sets a lender's password from the token in the emailed link.
  static Future<String> setPassword({
    required String token,
    required String email,
    required String password,
    required String confirmation,
  }) async {
    final response = await http
        .post(
      Uri.parse('$baseUrl/reset-password'),
      headers: const {'Accept': 'application/json', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'email': email,
        'password': password,
        'password_confirmation': confirmation,
      }),
    )
        .timeout(const Duration(seconds: 20));

    return _decodeResponse(response)['message']?.toString() ?? 'Password saved.';
  }
  /// Summary figures for the borrowers whose scores the lender may currently see.
  static Future<Map<String, dynamic>> getPortfolio() async {
    final response = await http
        .get(Uri.parse('$baseUrl/lender/portfolio'), headers: _headers)
        .timeout(const Duration(seconds: 20));

    return _decodeResponse(response);
  }
  /// Checks a credit report code. This route needs no sign-in, and an unknown code returns a result, not an error.
  static Future<Map<String, dynamic>> verifyReport(String code) async {
    final response = await http
        .get(
      Uri.parse('$baseUrl/reports/verify/${Uri.encodeComponent(code.trim())}'),
      headers: const {'Accept': 'application/json'},
    )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 200 || response.statusCode == 404) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    }

    throw Exception('The report could not be checked. Try again later.');
  }
}
