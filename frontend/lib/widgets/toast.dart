import 'package:flutter/material.dart';

// Lightweight replacement for the RN <Toast> component (src/components/Toast.jsx),
// itself a stand-in for Flutter's ScaffoldMessenger.showSnackBar — so here we
// simply come full circle and use a themed SnackBar.
// variant: 'error' (red, default) or 'success' (green).
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
