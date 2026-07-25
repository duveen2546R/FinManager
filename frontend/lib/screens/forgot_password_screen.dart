import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../services/api.dart';
import '../theme/theme_provider.dart';
import '../widgets/auth_fields.dart';
import '../widgets/district/auth_header.dart';
import '../widgets/district/auth_shell.dart';
import '../widgets/district/motion.dart';
import '../widgets/toast.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  static const route = '/forgot-password';
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  bool get _hasValidEmail =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  Future<void> _sendCode() async {
    if (!_hasValidEmail) {
      showToast(context, 'Please enter a valid email');
      return;
    }
    setState(() => _loading = true);
    try {
      await Api.requestPasswordReset(_email.text.trim());
      if (!mounted) return;
      setState(() => _codeSent = true);
      showToast(
        context,
        'If that email is registered, a reset code is on its way.',
      );
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) showToast(context, 'Could not connect to the server.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_code.text.trim().length != 6) {
      showToast(context, 'Enter the six-digit code from your email');
      return;
    }
    if (_password.text.length < 8) {
      showToast(context, 'Password must be at least 8 characters');
      return;
    }
    if (_password.text != _confirmPassword.text) {
      showToast(context, 'Passwords do not match');
      return;
    }
    setState(() => _loading = true);
    try {
      await Api.resetPassword(
        email: _email.text.trim(),
        code: _code.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      showToast(context, 'Password reset. You can now log in.');
      Navigator.pushNamedAndRemoveUntil(
        context,
        LoginScreen.route,
        (route) => false,
      );
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) showToast(context, 'Could not connect to the server.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;
    final title = _codeSent ? 'Choose a new password' : 'Reset your password';
    final subtitle = _codeSent
        ? 'Enter the code from your email and your new password.'
        : 'We’ll send a six-digit code to your email address.';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(),
      body: SafeArea(
        child: AuthShell(
          colors: colors,
          headline: 'Back into\nyour account.',
          subline:
              'We’ll email you a six-digit code so you can set a new password.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EntranceFade(
                child: AuthHeader(
                  colors: colors,
                  icon: Ionicons.key_outline,
                  titlePlain: title,
                  titleHighlight: '',
                  subtitle: subtitle,
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
                    if (_codeSent) ...[
                      const SizedBox(height: 18),
                      _label('Reset code', colors),
                      UnderlineField(
                        controller: _code,
                        hint: '6-digit code',
                        colors: colors,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 18),
                      _label('New password', colors),
                      PasswordField(
                        controller: _password,
                        visible: _passwordVisible,
                        colors: colors,
                        onToggle: () => setState(
                          () => _passwordVisible = !_passwordVisible,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _label('Confirm new password', colors),
                      PasswordField(
                        controller: _confirmPassword,
                        visible: _confirmPasswordVisible,
                        colors: colors,
                        onToggle: () => setState(
                          () => _confirmPasswordVisible =
                              !_confirmPasswordVisible,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 30),
              EntranceFade(
                delay: const Duration(milliseconds: 150),
                child: PrimaryButton(
                  label: _codeSent ? 'Reset password' : 'Send reset code',
                  loading: _loading,
                  colors: colors,
                  onTap: _codeSent ? _resetPassword : _sendCode,
                ),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _loading ? null : _sendCode,
                  child: const Text('Resend code'),
                ),
              ],
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    LoginScreen.route,
                    (route) => false,
                  ),
                  child: const Text('Back to login'),
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
