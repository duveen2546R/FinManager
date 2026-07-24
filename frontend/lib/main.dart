import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'services/api.dart';
import 'services/storage.dart';
import 'theme/theme_provider.dart';
import 'screens/first_page_screen.dart';
import 'screens/login_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/add_transaction_screen.dart';
import 'screens/ai_agent_screen.dart';
import 'screens/all_transactions_screen.dart';
import 'screens/account_screen.dart';
import 'screens/chat_history_screen.dart';
import 'screens/expense_setup_screen.dart';
import 'screens/import_review_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  // When a token can no longer be refreshed, drop the user back to the
  // landing screen from anywhere in the app.
  Api.onSessionExpired = () async {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      FirstPageScreen.route,
      (r) => false,
    );
  };
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const FinManagerApp(),
    ),
  );
}

class FinManagerApp extends StatelessWidget {
  const FinManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    // Keep the provider in sync with the platform brightness (mode == 'system').
    themeProvider.updateSystemBrightness(
      MediaQuery.platformBrightnessOf(context),
    );
    final colors = themeProvider.colors;

    // Status bar icons follow the theme (StatusBar style in App.jsx).
    SystemChrome.setSystemUIOverlayStyle(
      colors.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );

    return MaterialApp(
      title: 'FinManager',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: colors.isDark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: colors.background,
        primaryColor: colors.primary,
        colorScheme:
            (colors.isDark
                    ? const ColorScheme.dark()
                    : const ColorScheme.light())
                .copyWith(primary: colors.primary, secondary: colors.primary),
        appBarTheme: AppBarTheme(
          backgroundColor: colors.background,
          foregroundColor: colors.text,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: colors.text,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      home: const _RootDecider(),
      routes: {
        FirstPageScreen.route: (_) => const FirstPageScreen(),
        LoginScreen.route: (_) => const LoginScreen(),
        ForgotPasswordScreen.route: (_) => const ForgotPasswordScreen(),
        RegisterScreen.route: (_) => const RegisterScreen(),
        HomeScreen.route: (_) => const HomeScreen(),
        AddTransactionScreen.route: (_) => const AddTransactionScreen(),
        AiAgentScreen.route: (_) => const AiAgentScreen(),
        AllTransactionsScreen.route: (_) => const AllTransactionsScreen(),
        AccountScreen.route: (_) => const AccountScreen(),
        ChatHistoryScreen.route: (_) => const ChatHistoryScreen(),
        ExpenseSetupScreen.route: (_) => const ExpenseSetupScreen(),
        ImportReviewScreen.route: (_) => const ImportReviewScreen(),
      },
    );
  }
}

// Decides the initial screen based on stored login state (App.jsx useEffect).
class _RootDecider extends StatefulWidget {
  const _RootDecider();

  @override
  State<_RootDecider> createState() => _RootDeciderState();
}

class _RootDeciderState extends State<_RootDecider> {
  Widget? _initial;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final loggedIn = await Storage.isLoggedIn();
    if (!mounted) return;
    setState(() {
      _initial = loggedIn ? const HomeScreen() : const FirstPageScreen();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_initial == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5722)),
        ),
      );
    }
    return _initial!;
  }
}
