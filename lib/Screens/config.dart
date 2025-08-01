// lib/config.dart

class AppConfig {
  static const String ipAddress = '44.216.169.125';

  static const String baseUrl = 'http://$ipAddress:5000';

  static const String registerEndpoint = '$baseUrl/register';
  static const String loginEndpoint = '$baseUrl/login';
  static const String addTransactionEndpoint = '$baseUrl/transaction';
  static const String getTransactionsEndpoint = '$baseUrl/transactions'; 
  static const String aiAgentEndpoint = '$baseUrl/ai/agent/invoke';
}