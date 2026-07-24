import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/theme_provider.dart';
import '../widgets/auth_fields.dart';
import '../widgets/district/brand_card.dart';
import '../widgets/district/motion.dart';
import 'login_screen.dart';
import 'register_screen.dart';

// Neobank landing: light canvas, bold typography, a code-drawn lime debit
// card as the hero, black pill CTA.
class FirstPageScreen extends StatelessWidget {
  static const route = '/first';
  const FirstPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              EntranceFade(
                child: BrandCard(colors: colors),
              ),
              const Spacer(flex: 2),
              EntranceFade(
                delay: const Duration(milliseconds: 90),
                child: Text(
                  'Your money,\nbeautifully managed.',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 34,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              EntranceFade(
                delay: const Duration(milliseconds: 160),
                child: Text(
                  'Track spending, visualize stats, and manage your money '
                  'with an AI assistant that speaks your language.',
                  style: TextStyle(
                    color: colors.secondaryText,
                    fontSize: 15.5,
                    height: 1.5,
                  ),
                ),
              ),
              const Spacer(flex: 2),
              EntranceFade(
                delay: const Duration(milliseconds: 230),
                child: PrimaryButton(
                  label: 'Get Started',
                  loading: false,
                  colors: colors,
                  onTap: () =>
                      Navigator.pushNamed(context, RegisterScreen.route),
                ),
              ),
              const SizedBox(height: 12),
              EntranceFade(
                delay: const Duration(milliseconds: 290),
                child: PressableScaleButton(
                  onTap: () => Navigator.pushReplacementNamed(
                      context, LoginScreen.route),
                  child: Container(
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      'I already have an account',
                      style: TextStyle(
                          color: colors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

