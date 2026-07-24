import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../services/api.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../widgets/district/gradient_card.dart';
import '../widgets/district/motion.dart';
import '../widgets/toast.dart';
import 'first_page_screen.dart';

class AccountArgs {
  final String? userName;
  final String? userEmail;
  const AccountArgs({this.userName, this.userEmail});
}

// Neobank profile: centered lime avatar, "Personal info" card with labelled
// rows, settings + logout cards.
class AccountScreen extends StatelessWidget {
  static const route = '/account';
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final colors = theme.colors;
    final args = ModalRoute.of(context)!.settings.arguments as AccountArgs;
    final userName = args.userName ?? '';
    final userEmail = args.userEmail ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      backgroundColor: colors.background,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Avatar
          EntranceFade(
            child: Center(
              child: Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: colors.accent,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: colors.onAccent,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          EntranceFade(
            delay: const Duration(milliseconds: 60),
            child: Text(
              userName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: colors.text,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Personal info
          EntranceFade(
            delay: const Duration(milliseconds: 120),
            child: SurfaceCard(
              color: colors.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Personal info',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: Ionicons.person_outline,
                    label: 'Name',
                    value: userName,
                    colors: colors,
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: Ionicons.mail_outline,
                    label: 'E-mail',
                    value: userEmail,
                    colors: colors,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Settings
          EntranceFade(
            delay: const Duration(milliseconds: 180),
            child: SurfaceCard(
              color: colors.card,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                children: [
                  _MenuTile(
                    icon: Ionicons.color_palette_outline,
                    title: 'Theme',
                    colors: colors,
                    onTap: () => _showThemeDialog(context, theme, colors),
                  ),
                  Divider(
                    height: 1,
                    indent: 60,
                    endIndent: 12,
                    color: colors.border,
                  ),
                  _MenuTile(
                    icon: Ionicons.help_circle_outline,
                    title: 'Help & Support',
                    colors: colors,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Logout + danger zone
          EntranceFade(
            delay: const Duration(milliseconds: 240),
            child: SurfaceCard(
              color: colors.card,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                children: [
                  _MenuTile(
                    icon: Ionicons.log_out_outline,
                    title: 'Logout',
                    color: colors.expense,
                    colors: colors,
                    onTap: () => _confirmLogout(context),
                  ),
                  Divider(
                    height: 1,
                    indent: 60,
                    endIndent: 12,
                    color: colors.border,
                  ),
                  _MenuTile(
                    icon: Ionicons.download_outline,
                    title: 'Copy my data export',
                    colors: colors,
                    onTap: () => _copyExport(context),
                  ),
                  Divider(
                    height: 1,
                    indent: 60,
                    endIndent: 12,
                    color: colors.border,
                  ),
                  _MenuTile(
                    icon: Ionicons.trash_outline,
                    title: 'Delete account',
                    color: colors.expense,
                    colors: colors,
                    onTap: () => _confirmDeleteAccount(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    final colors = context.read<ThemeProvider>().colors;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Confirm Logout',
          style: TextStyle(color: colors.text, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: colors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.secondaryText),
            ),
          ),
          TextButton(
            onPressed: () async {
              // Revokes the token server-side and clears local state.
              await Api.logout();
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              Navigator.pushNamedAndRemoveUntil(
                context,
                FirstPageScreen.route,
                (r) => false,
              );
            },
            child: Text(
              'Logout',
              style: TextStyle(
                color: colors.expense,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyExport(BuildContext context) async {
    try {
      final data = await Api.exportData();
      await Clipboard.setData(
        ClipboardData(text: const JsonEncoder.withIndent('  ').convert(data)),
      );
      if (context.mounted) {
        showToast(
          context,
          'Your data export was copied to the clipboard.',
          variant: 'success',
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message);
    } catch (_) {
      if (context.mounted) showToast(context, 'Could not prepare data export.');
    }
  }

  // Password-confirmed, irreversible account deletion (DELETE /me).
  void _confirmDeleteAccount(BuildContext context) {
    final colors = context.read<ThemeProvider>().colors;
    final passwordController = TextEditingController();
    bool deleting = false;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Delete account?',
            style: TextStyle(color: colors.text, fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This permanently deletes your account and all expense data. '
                'Enter your password to confirm.',
                style: TextStyle(color: colors.secondaryText),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: TextStyle(color: colors.text),
                cursorColor: colors.text,
                decoration: InputDecoration(
                  hintText: 'Password',
                  hintStyle: TextStyle(color: colors.secondaryText),
                  filled: true,
                  fillColor: colors.elevated,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: deleting ? null : () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(color: colors.secondaryText),
              ),
            ),
            TextButton(
              onPressed: deleting
                  ? null
                  : () async {
                      setDialogState(() => deleting = true);
                      try {
                        await Api.deleteAccount(passwordController.text);
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          FirstPageScreen.route,
                          (r) => false,
                        );
                      } on ApiException catch (e) {
                        setDialogState(() => deleting = false);
                        if (dialogContext.mounted) {
                          showToast(dialogContext, e.message);
                        }
                      } catch (_) {
                        setDialogState(() => deleting = false);
                        if (dialogContext.mounted) {
                          showToast(
                            dialogContext,
                            'Could not delete the account.',
                          );
                        }
                      }
                    },
              child: Text(
                deleting ? 'Deleting…' : 'Delete',
                style: TextStyle(
                  color: colors.expense,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog(
    BuildContext context,
    ThemeProvider theme,
    AppColors colors,
  ) {
    const options = [
      ['system', 'System Default'],
      ['light', 'Light Mode'],
      ['dark', 'Dark Mode'],
    ];
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Theme',
          style: TextStyle(color: colors.text, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final opt in options)
              InkWell(
                onTap: () {
                  theme.setMode(opt[0]);
                  Navigator.pop(dialogContext);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        theme.mode == opt[0]
                            ? Ionicons.radio_button_on
                            : Ionicons.radio_button_off,
                        size: 22,
                        color: theme.mode == opt[0]
                            ? colors.text
                            : colors.secondaryText,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        opt[1],
                        style: TextStyle(color: colors.text, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Icon + label/value row (like the reference "Personal info" card).
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final AppColors colors;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colors.secondaryText),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: colors.secondaryText, fontSize: 12.5),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  final AppColors colors;
  final VoidCallback onTap;
  const _MenuTile({
    required this.icon,
    required this.title,
    this.color,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? colors.text;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.elevated,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: textColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            Icon(
              Ionicons.chevron_forward,
              size: 16,
              color: colors.secondaryText,
            ),
          ],
        ),
      ),
    );
  }
}
