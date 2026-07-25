import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/chat.dart';
import '../models/expense_setup.dart';
import '../models/insight.dart';
import '../models/transaction.dart';
import 'storage.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  final String? code;
  ApiException(this.message, {this.status, this.code});

  @override
  String toString() => message;
}

// Result of a successful login/registration.
class LoginResult {
  final String userId;
  final String? name;
  final String email;
  final String? phoneNo;
  LoginResult({
    required this.userId,
    this.name,
    required this.email,
    this.phoneNo,
  });
}

// Reply from the multi-turn chat endpoint.
class ChatReply {
  final String answer;
  final String sessionId;
  ChatReply({required this.answer, required this.sessionId});
}

// v2 API client: every private call carries `Authorization: Bearer <access>`,
// with a one-shot refresh-and-retry on 401. Ownership is derived server-side
// from the token — no user_id is ever sent.
class Api {
  static const Duration _timeout = Duration(seconds: 30);

  // Set by main.dart: called when the session cannot be refreshed.
  static Future<void> Function()? onSessionExpired;

  static Map<String, dynamic> _decode(http.Response res) {
    if (res.body.isEmpty) return {};
    try {
      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  static Never _fail(http.Response res, String fallback) {
    final data = _decode(res);
    throw ApiException(
      (data['message'] as String?) ?? fallback,
      status: res.statusCode,
      code: data['code'] as String?,
    );
  }

  // ---- Core request plumbing ----

  static Future<http.Response> _send(
    String method,
    String url, {
    Map<String, dynamic>? body,
    bool auth = true,
    bool retried = false,
  }) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await Storage.getAccessToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    final uri = Uri.parse(url);
    final encoded = body == null ? null : jsonEncode(body);

    late http.Response res;
    switch (method) {
      case 'GET':
        res = await http.get(uri, headers: headers).timeout(_timeout);
        break;
      case 'POST':
        res = await http
            .post(uri, headers: headers, body: encoded)
            .timeout(_timeout);
        break;
      case 'PATCH':
        res = await http
            .patch(uri, headers: headers, body: encoded)
            .timeout(_timeout);
        break;
      case 'DELETE':
        res = await http
            .delete(uri, headers: headers, body: encoded)
            .timeout(_timeout);
        break;
    }

    if (auth && res.statusCode == 401 && !retried) {
      if (await _refreshAccessToken()) {
        return _send(method, url, body: body, auth: auth, retried: true);
      }
      await Storage.clearUser();
      await onSessionExpired?.call();
      throw ApiException(
        'Your session has expired. Please log in again.',
        status: 401,
        code: 'session_expired',
      );
    }
    return res;
  }

  static Future<bool> _refreshAccessToken() async {
    final refresh = await Storage.getRefreshToken();
    if (refresh == null) return false;
    try {
      final res = await http
          .post(
            Uri.parse(AppConfig.refresh),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $refresh',
            },
          )
          .timeout(_timeout);
      final data = _decode(res);
      if (res.statusCode == 200 && data['access_token'] is String) {
        await Storage.setAccessToken(data['access_token'] as String);
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<LoginResult> _storeAuth(Map<String, dynamic> data) async {
    final user = (data['user'] as Map<String, dynamic>?) ?? data;
    final result = LoginResult(
      userId: user['user_id'] as String,
      name: user['name'] as String?,
      email: user['email'] as String,
      phoneNo: user['phone_no'] as String?,
    );
    await Storage.setTokens(
      access: data['access_token'] as String,
      refresh: data['refresh_token'] as String,
    );
    await Storage.setLoggedIn(true);
    await Storage.setUser(
      userId: result.userId,
      name: result.name,
      email: result.email,
    );
    return result;
  }

  // ---- Auth ----

  static Future<LoginResult> register(Map<String, dynamic> body) async {
    final res = await _send(
      'POST',
      AppConfig.register,
      body: body,
      auth: false,
    );
    final data = _decode(res);
    if (res.statusCode == 201 && data['status'] == 'success') {
      return _storeAuth(data);
    }
    _fail(res, 'Registration failed.');
  }

  static Future<LoginResult> login(String email, String password) async {
    final res = await _send(
      'POST',
      AppConfig.login,
      body: {'email': email, 'password': password},
      auth: false,
    );
    final data = _decode(res);
    if (res.statusCode == 200 && data['status'] == 'success') {
      return _storeAuth(data);
    }
    _fail(res, 'Invalid email or password');
  }

  static Future<void> requestPasswordReset(String email) async {
    final res = await _send(
      'POST',
      AppConfig.forgotPassword,
      body: {'email': email},
      auth: false,
    );
    if (res.statusCode != 200) {
      _fail(res, 'Unable to send a password reset email.');
    }
  }

  static Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    final res = await _send(
      'POST',
      AppConfig.resetPassword,
      body: {'email': email, 'code': code, 'password': password},
      auth: false,
    );
    if (res.statusCode != 200) {
      _fail(res, 'Unable to reset your password.');
    }
  }

  // Revokes the access token server-side; local state is cleared regardless.
  static Future<void> logout() async {
    try {
      await _send('POST', AppConfig.logout, body: {});
    } catch (_) {}
    await Storage.clearUser();
  }

  // ---- Transactions ----

  static Future<List<Txn>> getTransactions() async {
    final res = await _send('GET', '${AppConfig.transactions}?page_size=100');
    final data = _decode(res);
    if (res.statusCode == 200 && data['status'] == 'success') {
      final list = (data['transactions'] as List?) ?? [];
      return list.map((e) => Txn.fromJson(e as Map<String, dynamic>)).toList();
    }
    _fail(res, 'Failed to load data.');
  }

  static Future<Txn> addTransaction(Map<String, dynamic> body) async {
    final res = await _send('POST', AppConfig.transactions, body: body);
    final data = _decode(res);
    if (res.statusCode == 201 && data['transaction'] is Map<String, dynamic>) {
      return Txn.fromJson(data['transaction'] as Map<String, dynamic>);
    }
    _fail(res, 'Failed to add transaction.');
  }

  static Future<Txn> updateTransaction(
    String id,
    Map<String, dynamic> body,
  ) async {
    final res = await _send(
      'PATCH',
      AppConfig.transactionDetail(id),
      body: body,
    );
    final data = _decode(res);
    if (res.statusCode == 200 && data['transaction'] is Map<String, dynamic>) {
      return Txn.fromJson(data['transaction'] as Map<String, dynamic>);
    }
    _fail(res, 'Failed to update transaction.');
  }

  static Future<void> deleteTransaction(String id) async {
    final res = await _send('DELETE', AppConfig.transactionDetail(id));
    if (res.statusCode != 200) _fail(res, 'Failed to delete transaction.');
  }

  // ---- AI chat (multi-turn) ----

  static Future<ChatReply> askAgent(String message, {String? sessionId}) async {
    final res = await _send(
      'POST',
      AppConfig.aiAgent,
      body: {'message': message, 'session_id': ?sessionId},
    );
    final data = _decode(res);
    if (res.statusCode == 200 && data['status'] == 'success') {
      final session = data['session'] as Map<String, dynamic>?;
      return ChatReply(
        answer: (data['answer'] as String?) ?? '…',
        sessionId: (session?['session_id'] as String?) ?? sessionId ?? '',
      );
    }
    _fail(res, 'Sorry, I encountered an error.');
  }

  static Future<List<ChatSession>> getChatSessions() async {
    final res = await _send('GET', AppConfig.chatSessions);
    final data = _decode(res);
    if (res.statusCode == 200 && data['status'] == 'success') {
      return ((data['sessions'] as List?) ?? [])
          .map((item) => ChatSession.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    _fail(res, 'Failed to load chat history.');
  }

  static Future<List<ChatMessage>> getChatHistory(String sessionId) async {
    final res = await _send('GET', AppConfig.chatMessages(sessionId));
    final data = _decode(res);
    if (res.statusCode == 200 && data['status'] == 'success') {
      return ((data['messages'] as List?) ?? [])
          .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    _fail(res, 'Failed to load this conversation.');
  }

  static Future<void> deleteChatSession(String sessionId) async {
    final res = await _send('DELETE', AppConfig.chatSession(sessionId));
    if (res.statusCode != 200) _fail(res, 'Failed to delete conversation.');
  }

  static Future<void> archiveChatSession(
    String sessionId,
    bool archived,
  ) async {
    final res = await _send(
      'PATCH',
      AppConfig.chatSession(sessionId),
      body: {'is_archived': archived},
    );
    if (res.statusCode != 200) _fail(res, 'Failed to update conversation.');
  }

  // ---- Expense intelligence ----

  static Future<List<Insight>> getInsights() async {
    final res = await _send('GET', AppConfig.expenseInsights);
    final data = _decode(res);
    if (res.statusCode == 200 && data['status'] == 'success') {
      final list = (data['insights'] as List?) ?? [];
      return list
          .map((e) => Insight.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    _fail(res, 'Failed to load insights.');
  }

  // feedback: helpful | incorrect | expected | ignored
  static Future<void> sendInsightFeedback(String id, String feedback) async {
    final res = await _send(
      'POST',
      AppConfig.insightFeedback(id),
      body: {'feedback': feedback},
    );
    if (res.statusCode != 200) _fail(res, 'Failed to send feedback.');
  }

  static Future<Guidance?> getGuidance() async {
    final res = await _send('GET', AppConfig.expenseGuidance);
    final data = _decode(res);
    if (res.statusCode == 200 && data['status'] == 'success') {
      return Guidance.fromJson(data);
    }
    return null;
  }

  // ---- Import review ----

  static Future<ImportBatch> createImport({
    required String source,
    String? filename,
    required List<Map<String, dynamic>> items,
  }) async {
    final res = await _send(
      'POST',
      AppConfig.imports,
      body: {'source': source, 'filename': filename, 'items': items},
    );
    final data = _decode(res);
    if (res.statusCode == 201 && data['status'] == 'success') {
      return ImportBatch.fromResponse(data);
    }
    _fail(res, 'Failed to prepare import.');
  }

  static Future<bool> validateCsvHeaders(List<String> headers) async {
    final res = await _send(
      'POST',
      '${AppConfig.imports}/validate_csv_headers',
      body: {'headers': headers},
    );
    final data = _decode(res);
    if (res.statusCode == 200 && data['status'] == 'success') {
      return data['valid'] == true;
    }
    return true; // Fallback to allow if API fails
  }

  static Future<ImportBatch> getImport(String id) async {
    final res = await _send('GET', AppConfig.importDetail(id));
    final data = _decode(res);
    if (res.statusCode == 200 && data['status'] == 'success') {
      return ImportBatch.fromResponse(data);
    }
    _fail(res, 'Failed to load import.');
  }

  static Future<void> confirmImport(
    String id,
    List<Map<String, dynamic>> items,
  ) async {
    final res = await _send(
      'POST',
      AppConfig.confirmImport(id),
      body: {'items': items},
    );
    if (res.statusCode != 200) _fail(res, 'Failed to confirm import.');
  }

  // ---- Expense setup ----

  static Future<List<Commitment>> getCommitments() async {
    final res = await _send('GET', AppConfig.commitments);
    final data = _decode(res);
    if (res.statusCode == 200 && data['status'] == 'success') {
      return ((data['commitments'] as List?) ?? [])
          .map((item) => Commitment.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    _fail(res, 'Failed to load commitments.');
  }

  static Future<Commitment> saveCommitment(
    Map<String, dynamic> body, {
    String? id,
  }) async {
    final res = await _send(
      id == null ? 'POST' : 'PATCH',
      id == null ? AppConfig.commitments : AppConfig.commitment(id),
      body: body,
    );
    final data = _decode(res);
    final commitment = data['commitment'];
    if ((res.statusCode == 200 || res.statusCode == 201) &&
        commitment is Map<String, dynamic>) {
      return Commitment.fromJson(commitment);
    }
    _fail(res, 'Failed to save commitment.');
  }

  static Future<void> deleteCommitment(String id) async {
    final res = await _send('DELETE', AppConfig.commitment(id));
    if (res.statusCode != 200) _fail(res, 'Failed to delete commitment.');
  }

  static Future<List<MerchantRule>> getMerchantRules() async {
    final res = await _send('GET', AppConfig.merchantRules);
    final data = _decode(res);
    if (res.statusCode == 200 && data['status'] == 'success') {
      return ((data['merchant_rules'] as List?) ?? [])
          .map((item) => MerchantRule.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    _fail(res, 'Failed to load merchant rules.');
  }

  static Future<MerchantRule> saveMerchantRule(
    Map<String, dynamic> body,
  ) async {
    final res = await _send('POST', AppConfig.merchantRules, body: body);
    final data = _decode(res);
    if ((res.statusCode == 200 || res.statusCode == 201) &&
        data['merchant_rule'] is Map<String, dynamic>) {
      return MerchantRule.fromJson(
        data['merchant_rule'] as Map<String, dynamic>,
      );
    }
    _fail(res, 'Failed to save merchant rule.');
  }

  static Future<void> deleteMerchantRule(String id) async {
    final res = await _send('DELETE', AppConfig.merchantRule(id));
    if (res.statusCode != 200) _fail(res, 'Failed to delete merchant rule.');
  }

  // ---- Account ----

  static Future<void> deleteAccount(String password) async {
    final res = await _send(
      'DELETE',
      AppConfig.me,
      body: {'password': password},
    );
    if (res.statusCode != 200) _fail(res, 'Failed to delete account.');
    await Storage.clearUser();
  }

  static Future<Map<String, dynamic>> exportData() async {
    final res = await _send('GET', AppConfig.dataExport);
    final data = _decode(res);
    if (res.statusCode == 200 && data['export'] is Map<String, dynamic>) {
      return data['export'] as Map<String, dynamic>;
    }
    _fail(res, 'Failed to prepare data export.');
  }
}
