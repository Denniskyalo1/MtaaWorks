import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';


class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8001/api';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static bool _googleInitialized = false;

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phoneNumber,
    required String nationalId,
    required String password,
    required String passwordConfirmation,
  }) async {
    final uri = Uri.parse('$baseUrl/register');

    final response = await http.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'email': email,
        'phone_number': phoneNumber.trim().isEmpty
            ? null
            : phoneNumber.trim(),
        'national_id': nationalId.trim(),
        'password': password,
        'password_confirmation': passwordConfirmation,
      }),
    );

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response from the server.');
    }

    if (response.statusCode == 201) {
      return decoded;
    }

    if (response.statusCode == 422) {
      final errors = decoded['errors'];

      if (errors is Map<String, dynamic> && errors.isNotEmpty) {
        final firstError = errors.values.first;

        if (firstError is List && firstError.isNotEmpty) {
          throw Exception(firstError.first.toString());
        }
      }

      throw Exception(
        decoded['message']?.toString() ?? 'Please check your details.',
      );
    }

    throw Exception(
      decoded['message']?.toString() ??
          'Registration failed. Please try again.',
    );
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
      }),
    );

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response from the server.');
    }

    if (response.statusCode == 200) {
      final token = decoded['access_token'];

      if (token is! String || token.isEmpty) {
        throw Exception('The server did not return an access token.');
      }

      await _storage.write(key: 'auth_token', value: token);
      return decoded;
    }

    final errors = decoded['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final firstError = errors.values.first;
      if (firstError is List && firstError.isNotEmpty) {
        throw Exception(firstError.first.toString());
      }
    }

    throw Exception(
      decoded['message']?.toString() ?? 'Login failed.',
    );
  }

  static Future<String?> getToken() {
    return _storage.read(key: 'auth_token');
  }

  static Future<void> clearToken() {
    return _storage.delete(key: 'auth_token');
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in. Please log in again.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/show'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response from the server.');
    }

    if (response.statusCode == 200) {
      return decoded;
    }

    if (response.statusCode == 401) {
      throw Exception('Your session has expired. Please log in again.');
    }

    throw Exception(
      decoded['message']?.toString() ?? 'Failed to load your profile.',
    );
  }


  static Future<Map<String, dynamic>> getLatestScore() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in. Please log in again.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/scores/latest'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print('Latest score status: ${response.statusCode}');
    print('Latest score body: ${response.body}');

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response from the server.');
    }

    if (response.statusCode == 200) {
      return decoded;
    }

    if (response.statusCode == 404) {
      return decoded;
    }

    if (response.statusCode == 401) {
      throw Exception('Your session has expired. Please log in again.');
    }

    throw Exception(
      decoded['message']?.toString() ?? 'Failed to load your credit score.',
    );
  }


  static Future<Map<String, dynamic>> scoreStatement({
    required String statementPath,
    required String password,
  }) async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Please log in again.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/scores'),
    );

    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });

    request.fields['password'] = password;
    request.files.add(
      await http.MultipartFile.fromPath(
        'statement',
        statementPath,
      ),
    );

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 130),
      onTimeout: () {
        throw Exception(
          'Scoring timed out. Please try again.',
        );
      },
    );

    final response = await http.Response.fromStream(streamedResponse);

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response from the server.');
    }

    if (response.statusCode == 201) {
      return decoded;
    }

    if (response.statusCode == 401) {
      throw Exception('Your session has expired. Please log in again.');
    }

    if (response.statusCode == 403) {
      throw Exception(
        decoded['message']?.toString() ??
            'Please grant consent before scoring your statement.',
      );
    }

    if (response.statusCode == 422) {
      final errors = decoded['errors'];

      if (errors is Map && errors.isNotEmpty) {
        final firstError = errors.values.first;
        if (firstError is List && firstError.isNotEmpty) {
          throw Exception(firstError.first.toString());
        }
      }
    }

    throw Exception(
      decoded['message']?.toString() ??
          'Statement scoring failed. Please try again.',
    );
  }

  static Future<Map<String, dynamic>> grantStatementConsent() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Please log in again.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/consents'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'purpose': 'statement_analysis',
        'policy_version': '1.0',
      }),
    );

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response from the server.');
    }

    if (response.statusCode == 201) {
      return decoded;
    }

    // Consent may already exist for this purpose.
    if (response.statusCode == 409) {
      return {
        'message': 'Consent already granted.',
        'already_granted': true,
      };
    }

    if (response.statusCode == 401) {
      throw Exception('Your session has expired. Please log in again.');
    }

    if (response.statusCode == 422) {
      final errors = decoded['errors'];

      if (errors is Map && errors.isNotEmpty) {
        final firstError = errors.values.first;

        if (firstError is List && firstError.isNotEmpty) {
          throw Exception(firstError.first.toString());
        }
      }
    }

    throw Exception(
      decoded['message']?.toString() ?? 'Failed to record consent.',
    );
  }

  static Future<Map<String, dynamic>> getConsents() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Please log in again.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/consents'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response from the server.');
    }

    if (response.statusCode == 200) {
      return decoded;
    }

    if (response.statusCode == 401) {
      throw Exception('Your session has expired. Please log in again.');
    }

    throw Exception(
      decoded['message']?.toString() ?? 'Failed to load consent status.',
    );
  }

  static Future<Map<String, dynamic>> revokeStatementConsent() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Please log in again.');
    }

    final response = await http.delete(
      Uri.parse('$baseUrl/consents/statement_analysis'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response from the server.');
    }

    if (response.statusCode == 200) {
      return decoded;
    }

    if (response.statusCode == 401) {
      throw Exception('Your session has expired. Please log in again.');
    }

    if (response.statusCode == 404) {
      throw Exception('No active statement-analysis consent was found.');
    }

    throw Exception(
      decoded['message']?.toString() ?? 'Failed to revoke consent.',
    );
  }



  static Future<bool> hasSavedSession() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/show'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return true;
      }

      if (response.statusCode == 401) {
        // The server confirms that this token is no longer valid.
        await clearToken();
        return false;
      }

      // Do not log the user out because of a temporary server error.
      return true;
    } catch (_) {
      // The server may be temporarily unreachable.
      // Keep the saved session and let HomePage handle API errors.
      return true;
    }
  }

  static Future<Map<String, dynamic>> loginWithGoogle() async {
    // Initialize Google Sign-In only once.
    if (!_googleInitialized) {
      await _googleSignIn.initialize(
        serverClientId: dotenv.env['GOOGLE_CLIENT_ID'],
      );
      _googleInitialized = true;
    }

    final account = await _googleSignIn.authenticate();

    // Obtain the Google ID token for Laravel to verify.
    final idToken = account.authentication.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw Exception('Google did not provide an ID token. Please try again.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/auth/google'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'id_token': idToken,
      }),
    );

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response from the server.');
    }

    if (response.statusCode == 200) {
      // Your GoogleAuthController returns "token", not "access_token".
      final token = decoded['token'];

      if (token is! String || token.isEmpty) {
        throw Exception('The server did not return an access token.');
      }

      await _storage.write(
        key: 'auth_token',
        value: token,
      );

      return decoded;
    }

    if (response.statusCode == 401) {
      throw Exception(
        decoded['message']?.toString() ?? 'Google authentication failed.',
      );
    }

    if (response.statusCode == 422) {
      throw Exception(
        decoded['message']?.toString() ?? 'Invalid Google sign-in request.',
      );
    }

    throw Exception(
      decoded['message']?.toString() ??
          'Google sign-in failed. Please try again.',
    );
  }


  static Future<Map<String, dynamic>> getAccessRequests() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Please log in again.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/access-requests'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response from the server.');
    }

    if (response.statusCode == 200) {
      return decoded;
    }

    if (response.statusCode == 401) {
      throw Exception('Your session has expired. Please log in again.');
    }

    throw Exception(
      decoded['message']?.toString() ??
          'Failed to load lender requests.',
    );
  }

  static Future<Map<String, dynamic>> respondToAccessRequest({
    required int grantId,
    required String action,
  }) async {
    const allowedActions = ['approve', 'decline', 'revoke'];

    if (!allowedActions.contains(action)) {
      throw ArgumentError('Invalid access request action.');
    }

    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Please log in again.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/access-requests/$grantId/$action'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response from the server.');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    if (response.statusCode == 401) {
      throw Exception('Your session has expired. Please log in again.');
    }

    if (response.statusCode == 404) {
      throw Exception('This lender request could not be found.');
    }

    if (response.statusCode == 409) {
      throw Exception(
        decoded['message']?.toString() ??
            'This request has already been handled.',
      );
    }

    if (response.statusCode == 422) {
      throw Exception(
        decoded['message']?.toString() ??
            'The request could not be processed.',
      );
    }

    throw Exception(
      decoded['message']?.toString() ??
          'Failed to $action lender access.',
    );
  }


  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    String? email,
    String? phoneNumber,
  }) async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Please log in again.');
    }

    final body = <String, dynamic>{
      'name': name.trim(),
    };

    if (email != null) {
      body['email'] = email.trim();
    }

    if (phoneNumber != null) {
      body['phone_number'] = phoneNumber.trim();
    }

    final response = await http.patch(
      Uri.parse('$baseUrl/update'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response from the server.');
    }

    if (response.statusCode == 200) {
      final user = decoded['user'];

      if (user is Map<String, dynamic>) {
        return user;
      }

      throw Exception('The server did not return the updated user.');
    }

    if (response.statusCode == 401) {
      throw Exception('Your session has expired. Please log in again.');
    }

    if (response.statusCode == 422) {
      final errors = decoded['errors'];

      if (errors is Map && errors.isNotEmpty) {
        final firstError = errors.values.first;

        if (firstError is List && firstError.isNotEmpty) {
          throw Exception(firstError.first.toString());
        }
      }
    }

    throw Exception(
      decoded['message']?.toString() ?? 'Failed to update your profile.',
    );


  }




  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String passwordConfirmation,
  }) async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Please log in again.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/change-password'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': passwordConfirmation,
      }),
    );

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response from the server.');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    if (response.statusCode == 401) {
      throw Exception('Your session has expired. Please log in again.');
    }

    if (response.statusCode == 422) {
      final errors = decoded['errors'];

      if (errors is Map) {
        // Prioritize the current-password error if present.
        for (final key in ['current_password', 'password']) {
          final messages = errors[key];

          if (messages is List && messages.isNotEmpty) {
            throw Exception(messages.first.toString());
          }
        }

        if (errors.isNotEmpty) {
          final messages = errors.values.first;
          if (messages is List && messages.isNotEmpty) {
            throw Exception(messages.first.toString());
          }
        }
      }
    }

    throw Exception(
      decoded['message']?.toString() ?? 'Failed to change your password.',
    );
  }

  static Future<Map<String, dynamic>> requestAccountDeletion() async {
    return _accountDeletionRequest(
      method: 'POST',
      endpoint: '/account/delete/request',
    );
  }

  static Future<Map<String, dynamic>> deleteAccount({
    required String code,
  }) async {
    return _accountDeletionRequest(
      method: 'DELETE',
      endpoint: '/account',
      body: {'code': code},
    );
  }

  static Future<Map<String, dynamic>> _accountDeletionRequest({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
  }) async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Please log in again.');
    }

    final uri = Uri.parse('$baseUrl$endpoint');

    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final response = method == 'DELETE'
        ? await http.delete(
      uri,
      headers: headers,
      body: jsonEncode(body ?? {}),
    )
        : await http.post(
      uri,
      headers: headers,
      body: jsonEncode(body ?? {}),
    );

    Map<String, dynamic> decoded;

    try {
      final dynamic result = jsonDecode(response.body);

      if (result is! Map<String, dynamic>) {
        throw Exception('Unexpected response from the server.');
      }

      decoded = result;
    } catch (_) {
      throw Exception('Could not read the server response.');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final errors = decoded['errors'];

    if (errors is Map && errors.isNotEmpty) {
      final firstError = errors.values.first;

      if (firstError is List && firstError.isNotEmpty) {
        throw Exception(firstError.first.toString());
      }
    }

    throw Exception(
      decoded['message']?.toString() ??
          'Account deletion request failed.',
    );
  }



  static Future<Map<String, dynamic>> completeGoogleProfile({
    required String nationalId,
    String? phoneNumber,
  }) async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception(
        'Your session has expired. Please sign in again.',
      );
    }

    final response = await http
        .post(
      Uri.parse('$baseUrl/profile/complete'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'national_id': nationalId.trim(),
        if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
          'phone_number': phoneNumber.trim(),
      }),
    )
        .timeout(const Duration(seconds: 30));

    Map<String, dynamic> data;

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }

      data = decoded;
    } on FormatException {
      throw Exception(
        'The server returned an unexpected response. '
            'Please try again.',
      );
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return data;
    }

    if (response.statusCode == 401) {
      throw Exception(
        'Your session has expired. Please sign in again.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        data['message']?.toString() ??
            'You are not permitted to complete this profile.',
      );
    }

    if (response.statusCode == 409) {
      throw Exception(
        data['message']?.toString() ??
            'Your profile is already complete.',
      );
    }

    final errors = data['errors'];

    if (errors is Map && errors.isNotEmpty) {
      final firstError = errors.values.first;

      if (firstError is List && firstError.isNotEmpty) {
        throw Exception(firstError.first.toString());
      }
    }

    throw Exception(
      data['message']?.toString() ??
          'Could not complete your profile.',
    );
  }





}