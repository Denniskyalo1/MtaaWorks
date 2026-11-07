import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8001/api',
  );

  static String? _token;
  static String? _role;
  static String? _userName;
  static int? _userId;

  static bool get isLoggedIn => _token != null;
  static String? get role => _role;
  static String? get userName => _userName;
  static int? get userId => _userId;
  static bool get isAdmin => _role == 'admin';

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
        (response.statusCode >= 500
            ? 'The server had a problem. Please try again in a moment.'
            : 'Something went wrong (error ${response.statusCode}). Please try again.');

    throw Exception(message);
  }
  /// Reads a JSON reply. If the server sent something else (an HTML error
  /// page, an empty body or a cut-off reply), throws a readable message
  /// instead of a FormatException.
  static dynamic _decodeBody(http.Response response) {
    try {
      return jsonDecode(response.body);
    } on FormatException {
      if (response.statusCode >= 500 || response.body.trim().isEmpty) {
        throw Exception(
            'The server had a problem. Please try again in a moment.');
      }
      throw Exception('Unexpected reply from the server. Please try again.');
    }
  }

  /// Shared request helper for the admin calls.
  static Future<Map<String, dynamic>> _send(
      String method,
      String path, {
        Map<String, dynamic>? body,
        Map<String, String>? query,
      }) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );

    final Future<http.Response> request;

    switch (method) {
      case 'POST':
        request = http.post(uri, headers: _headers, body: jsonEncode(body ?? {}));
        break;
      case 'PATCH':
        request = http.patch(uri, headers: _headers, body: jsonEncode(body ?? {}));
        break;
      default:
        request = http.get(uri, headers: _headers);
    }

    final response = await request.timeout(const Duration(seconds: 20));
    return _decodeResponse(response);
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

    final user = data['user'];
    final role = user is Map ? user['role']?.toString() : null;

    _token = token;
    _role = role;
    _userName = user is Map ? user['name']?.toString() : null;
    _userId = user is Map ? int.tryParse(user['id'].toString()) : null;

    if (role == 'admin') return;

    if (role != null && role != 'lender') {
      // Borrowers have the mobile app; this portal is for lenders and admins.
      await logout();
      throw Exception(
        'This portal is for lender and admin accounts. '
            'Borrowers should use the MtaaWorks mobile app.',
      );
    }

    try {
      // Verify that this account can access the lender API.
      await getGrants();
      _role = 'lender';
    } catch (_) {
      _token = null;
      _role = null;
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
    _role = null;
    _userName = null;
    _userId = null;
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
      final decoded = _decodeBody(response);
      if (decoded is Map<String, dynamic>) return decoded;
    }

    throw Exception('The report could not be checked. Try again later.');
  }

  // ---------------------------------------------------------------- admin

  static Future<Map<String, dynamic>> getAdminDashboard() =>
      _send('GET', '/admin/dashboard');

  static Future<List<Map<String, dynamic>>> getAdminLenders() async {
    final list = (await _send('GET', '/admin/lenders'))['lenders'];

    if (list is! List) {
      throw Exception('The server returned an invalid lenders response.');
    }

    return list.whereType<Map<String, dynamic>>().toList();
  }

  static Future<String> createLender({
    required String name,
    required String type,
    required String licenceNumber,
    required String contactName,
    required String contactEmail,
  }) async {
    final data = await _send('POST', '/admin/lenders', body: {
      'name': name.trim(),
      'type': type,
      'licence_number': licenceNumber.trim(),
      'contact_name': contactName.trim(),
      'contact_email': contactEmail.trim(),
    });

    return data['message']?.toString() ?? 'Lender created.';
  }

  /// [status] is 'active' or 'suspended'.
  static Future<String> setLenderStatus({
    required int lenderId,
    required String status,
    String? reason,
  }) async {
    final data = await _send('PATCH', '/admin/lenders/$lenderId/status', body: {
      'status': status,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });

    return data['message']?.toString() ?? 'Lender updated.';
  }

  /// Paginated: the result has 'data', 'current_page' and 'last_page'.
  static Future<Map<String, dynamic>> getAdminUsers({
    String? role,
    String? search,
    int page = 1,
  }) =>
      _send('GET', '/admin/users', query: {
        if (role != null) 'role': role,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'page': '$page',
      });

  /// [role] is 'borrower' or 'admin'.
  static Future<String> changeUserRole({
    required int userId,
    required String role,
  }) async {
    final data = await _send('PATCH', '/admin/users/$userId/role', body: {'role': role});
    return data['message']?.toString() ?? 'Role updated.';
  }

  static Future<Map<String, dynamic>> getAuditLogs({int page = 1}) =>
      _send('GET', '/admin/audit-logs', query: {'page': '$page'});

  static Future<Map<String, dynamic>> getAccessEvents({int page = 1}) =>
      _send('GET', '/admin/access-events', query: {'page': '$page'});
}

/// Turns any error into a message a user can act on.
String friendlyError(Object e) {
  if (e is TimeoutException) {
    return 'The server is taking too long to reply. Check your connection and try again.';
  }
  // In the browser every connection failure arrives as a ClientException.
  if (e is http.ClientException) {
    return 'Could not reach MtaaWorks. Check your internet connection and try again.';
  }
  final text = e.toString().replaceFirst('Exception: ', '');
  if (text.contains('Exception') || text.contains('errno') || text.contains('uri=')) {
    return 'Something went wrong. Please try again.';
  }
  return text;
}