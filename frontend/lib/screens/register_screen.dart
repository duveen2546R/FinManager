import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ionicons/ionicons.dart';

import '../services/api.dart';
import '../theme/theme_provider.dart';
import '../widgets/auth_fields.dart';
import '../widgets/district/auth_header.dart';
import '../widgets/district/motion.dart';
import '../widgets/toast.dart';
import 'home_screen.dart';

// Neobank register: bold headline, labelled fields, black pill CTA.
class RegisterScreen extends StatefulWidget {
  static const route = '/register';
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _passwordVisible = false;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_name.text.isEmpty) return 'Please enter your name';
    if (_email.text.isEmpty || !_email.text.contains('@')) {
      return 'Please enter a valid email address';
    }
    if (_password.text.isEmpty || _password.text.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  Future<void> _register() async {
    final error = _validate();
    if (error != null) {
      showToast(context, error);
      return;
    }
    setState(() => _loading = true);
    try {
      // Api.register persists the JWT tokens and user profile on success.
      final result = await Api.register({
        'name': _name.text,
        'phone_no': _phone.text,
        'email': _email.text,
        'password': _password.text,
      });
      if (!mounted) return;
      showToast(context, 'Registration successful! Logging you in...',
          variant: 'success');
      Navigator.pushNamedAndRemoveUntil(
        context,
        HomeScreen.route,
        (r) => false,
        arguments: HomeArgs(
          userId: result.userId,
          name: result.name,
          email: result.email,
        ),
      );
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) {
        showToast(context,
            'Could not connect to the server. Please check your network.');
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EntranceFade(
                child: AuthHeader(
                  colors: colors,
                  icon: Ionicons.person_add_outline,
                  titlePlain: 'Create',
                  titleHighlight: 'account',
                  subtitle: 'Start tracking your finances in minutes.',
                ),
              ),
              const SizedBox(height: 30),
              EntranceFade(
                delay: const Duration(milliseconds: 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Name', colors),
                    UnderlineField(
                        controller: _name,
                        hint: 'Your full name',
                        colors: colors),
                    const SizedBox(height: 16),
                    _label('Phone number', colors),
                    UnderlineField(
                      controller: _phone,
                      hint: '+91 …',
                      colors: colors,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _label('Email', colors),
                    UnderlineField(
                      controller: _email,
                      hint: 'you@example.com',
                      colors: colors,
                      keyboardType: TextInputType.emailAddress,
                      autoLowercase: true,
                    ),
                    const SizedBox(height: 16),
                    _label('Password', colors),
                    PasswordField(
                      controller: _password,
                      visible: _passwordVisible,
                      colors: colors,
                      onToggle: () => setState(
                          () => _passwordVisible = !_passwordVisible),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              EntranceFade(
                delay: const Duration(milliseconds: 150),
                child: PrimaryButton(
                  label: 'Register',
                  loading: _loading,
                  colors: colors,
                  onTap: _register,
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
        child: Text(text,
            style: TextStyle(
                color: colors.text,
                fontSize: 13.5,
                fontWeight: FontWeight.w600)),
      );
}
