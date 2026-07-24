// Central place for the backend API configuration (v2 expense-intelligence API).
class AppConfig {
  static const String baseUrl = 'http://127.0.0.1:5001';

  // Auth
  static String get register => '$baseUrl/auth/register';
  static String get login => '$baseUrl/auth/login';
  static String get forgotPassword => '$baseUrl/auth/forgot-password';
  static String get resetPassword => '$baseUrl/auth/reset-password';
  static String get refresh => '$baseUrl/auth/refresh';
  static String get logout => '$baseUrl/auth/logout';

  // Transactions (ownership derived from the bearer token)
  static String get transactions => '$baseUrl/transactions';
  static String transactionDetail(String id) => '$baseUrl/transactions/$id';

  // AI chat (multi-turn sessions)
  static String get aiAgent => '$baseUrl/ai/agent/invoke';
  static String get chatSessions => '$baseUrl/chat/sessions';
  static String chatSession(String id) => '$chatSessions/$id';
  static String chatMessages(String id) => '${chatSession(id)}/messages';

  // Expense intelligence
  static String get expenseInsights => '$baseUrl/expense-insights';
  static String insightFeedback(String id) =>
      '$baseUrl/expense-insights/$id/feedback';
  static String get expenseGuidance => '$baseUrl/expense-guidance';
  static String get imports => '$baseUrl/imports';
  static String importDetail(String id) => '$imports/$id';
  static String confirmImport(String id) => '${importDetail(id)}/confirm';
  static String get merchantRules => '$baseUrl/merchant-rules';
  static String merchantRule(String id) => '$merchantRules/$id';
  static String get commitments => '$baseUrl/commitments';
  static String commitment(String id) => '$commitments/$id';

  // Account
  static String get me => '$baseUrl/me';
  static String get dataExport => '$me/export';
}
