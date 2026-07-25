import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../widgets/auth_fields.dart';
import '../widgets/district/brand_card.dart';
import '../widgets/responsive.dart';
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
      // On a laptop the landing page is a full-bleed split: lime brand panel
      // on the left, the card art and CTAs on the right.
      body: context.isWide
          ? _wide(colors, context)
          : SafeArea(child: _narrow(colors, context)),
    );
  }

  Widget _wide(AppColors colors, BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: BrandPanel(
            colors: colors,
            headline: 'Your money,\nbeautifully managed.',
            subline:
                'Track spending, visualize stats, and manage your money with '
                'an AI assistant that speaks your language.',
            points: const [
              'Every transaction in one place',
              'Charts that explain your month',
              'Import statements from a CSV file',
            ],
          ),
        ),
        Expanded(
          flex: 5,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: context.screenWidth > 1400 ? 96 : 64,
                  vertical: 48,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      EntranceFade(child: BrandCard(colors: colors)),
                      const SizedBox(height: 40),
                      EntranceFade(
                        delay: const Duration(milliseconds: 90),
                        child: Text(
                          'Ready when you are.',
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 28,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      EntranceFade(
                        delay: const Duration(milliseconds: 140),
                        child: Text(
                          'Create an account in a minute, or pick up where you '
                          'left off.',
                          style: TextStyle(
                            color: colors.secondaryText,
                            fontSize: 15.5,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      EntranceFade(
                        delay: const Duration(milliseconds: 200),
                        child: PrimaryButton(
                          label: 'Get Started',
                          loading: false,
                          colors: colors,
                          onTap: () => Navigator.pushNamed(
                            context,
                            RegisterScreen.route,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      EntranceFade(
                        delay: const Duration(milliseconds: 260),
                        child: _secondaryCta(colors, context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _narrow(AppColors colors, BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Tall desktop windows would otherwise stretch the flexible gaps
        // into empty bands, so cap the column and centre it; short windows
        // fall back to a fixed height and scroll.
        const idealHeight = 720.0;
        const minHeight = 620.0;
        final height = constraints.maxHeight
            .clamp(minHeight, idealHeight)
            .toDouble();
        return Center(
          child: SingleChildScrollView(
            child: SizedBox(height: height, child: _content(colors, context)),
          ),
        );
      },
    );
  }

  Widget _secondaryCta(AppColors colors, BuildContext context) {
    return PressableScaleButton(
      onTap: () => Navigator.pushReplacementNamed(context, LoginScreen.route),
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
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _content(AppColors colors, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(flex: 2),
          EntranceFade(child: BrandCard(colors: colors)),
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
              onTap: () => Navigator.pushNamed(context, RegisterScreen.route),
            ),
          ),
          const SizedBox(height: 12),
          EntranceFade(
            delay: const Duration(milliseconds: 290),
            child: _secondaryCta(colors, context),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
