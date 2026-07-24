import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import '../theme/app_colors.dart';

// Neobank form widgets: soft-filled rounded inputs and the black pill button.

InputDecoration _fieldDecoration(
  AppColors colors, {
  required String hint,
  Widget? suffix,
}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: colors.secondaryText),
    filled: true,
    fillColor: colors.elevated,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: border(Colors.transparent),
    focusedBorder: border(colors.text, 1.4),
    suffixIcon: suffix,
  );
}

class UnderlineField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final AppColors colors;
  final TextInputType? keyboardType;
  final bool autoLowercase;
  const UnderlineField({
    super.key,
    required this.controller,
    required this.hint,
    required this.colors,
    this.keyboardType,
    this.autoLowercase = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      autocorrect: !autoLowercase,
      textCapitalization: autoLowercase
          ? TextCapitalization.none
          : TextCapitalization.sentences,
      style: TextStyle(color: colors.text, fontSize: 16),
      cursorColor: colors.text,
      decoration: _fieldDecoration(colors, hint: hint),
    );
  }
}

class PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool visible;
  final AppColors colors;
  final VoidCallback onToggle;
  const PasswordField({
    super.key,
    required this.controller,
    required this.visible,
    required this.colors,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: !visible,
      style: TextStyle(color: colors.text, fontSize: 16),
      cursorColor: colors.text,
      decoration: _fieldDecoration(
        colors,
        hint: 'Password',
        suffix: IconButton(
          icon: Icon(visible ? Ionicons.eye_off : Ionicons.eye,
              size: 22, color: colors.secondaryText),
          onPressed: onToggle,
        ),
      ),
    );
  }
}

// Solid pill button (black in light mode, white in dark) with loading state.
class PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  final AppColors colors;
  const PrimaryButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScaleButton(
      onTap: loading ? null : onTap,
      child: Container(
        height: 56,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: loading ? 0.75 : 1),
          borderRadius: BorderRadius.circular(100),
        ),
        child: loading
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                    color: colors.onPrimary, strokeWidth: 2.5),
              )
            : Text(
                label,
                style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}

class PressableScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const PressableScaleButton({super.key, required this.child, this.onTap});

  @override
  State<PressableScaleButton> createState() => _PressableScaleButtonState();
}

class _PressableScaleButtonState extends State<PressableScaleButton> {
  bool _down = false;
  void _set(bool v) {
    if (widget.onTap == null) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}
