import 'package:flutter/material.dart';

// Themed SnackBar helper.
// variant: 'error' (red, default) or 'success' (lime).
void showToast(BuildContext context, String message, {String variant = 'error'}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(
          color: variant == 'success'
              ? const Color(0xFF171717)
              : Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor:
          variant == 'success' ? const Color(0xFFC8E84E) : const Color(0xFFD32F2F),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      duration: const Duration(seconds: 3),
    ),
  );
}
