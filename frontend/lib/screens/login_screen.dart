import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ionicons/ionicons.dart';

import '../services/api.dart';
import '../theme/theme_provider.dart';
import '../widgets/auth_fields.dart';
import '../widgets/district/auth_header.dart';
import '../widgets/district/auth_shell.dart';
import '../widgets/district/motion.dart';
import '../widgets/toast.dart';
import 'home_screen.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

// Neobank login: light canvas, bold headline, soft-filled fields, black pill.
class LoginScreen extends StatefulWidget {
  static const route = '/login';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _passwordVisible = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validate() {
    final email = _email.text;
    if (email.isEmpty || !email.contains('@')) {
      return 'Please enter a valid email';
    }
    if (_password.text.isEmpty) {
      return 'Please enter your password';
    }
    return null;
  }

  Future<void> _login() async {
    final error = _validate();
    if (error != null) {
      showToast(context, error);
      return;
    }
    setState(() => _loading = true);
    try {
      // Api.login persists the JWT tokens and user profile on success.
      final result = await Api.login(_email.text, _password.text);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        HomeScreen.route,
        (r) => false,
        arguments: HomeArgs(
          userId: result.userId,
          name: result.name,
          email: result.email,
          phoneNo: result.phoneNo,
        ),
      );
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) {
        showToast(
          context,
          'Could not connect to the server. Please check your network.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(),
      body: SafeArea(
        child: AuthShell(
          colors: colors,
          headline: 'Your money,\nbeautifully managed.',
          subline:
              'Pick up where you left off — your spending, stats and assistant '
              'are waiting.',
          points: const [
            'Every transaction in one place',
            'Charts that explain your month',
            'An AI assistant that speaks your language',
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EntranceFade(
                child: AuthHeader(
                  colors: colors,
                  icon: Ionicons.log_in_outline,
                  titlePlain: 'Welcome',
                  titleHighlight: 'back',
                  subtitle: 'Log in to continue managing your money.',
                ),
              ),
              const SizedBox(height: 32),
              EntranceFade(
                delay: const Duration(milliseconds: 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Email', colors),
                    UnderlineField(
                      controller: _email,
                      hint: 'you@example.com',
                      colors: colors,
                      keyboardType: TextInputType.emailAddress,
                      autoLowercase: true,
                    ),
                    const SizedBox(height: 18),
                    _label('Password', colors),
                    PasswordField(
                      controller: _password,
                      visible: _passwordVisible,
                      colors: colors,
                      onToggle: () =>
                          setState(() => _passwordVisible = !_passwordVisible),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          ForgotPasswordScreen.route,
                        ),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              EntranceFade(
                delay: const Duration(milliseconds: 150),
                child: PrimaryButton(
                  label: 'Login',
                  loading: _loading,
                  colors: colors,
                  onTap: _login,
                ),
              ),
              const SizedBox(height: 20),
              EntranceFade(
                delay: const Duration(milliseconds: 210),
                child: Center(
                  child: GestureDetector(
                    onTap: () =>
                        Navigator.pushNamed(context, RegisterScreen.route),
                    child: Text.rich(
                      TextSpan(
                        text: "Don't have an account?  ",
                        style: TextStyle(color: colors.secondaryText),
                        children: [
                          TextSpan(
                            text: 'Register',
                            style: TextStyle(
                              color: colors.text,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text, dynamic colors) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        color: colors.text,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
