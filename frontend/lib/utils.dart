import 'package:flutter/widgets.dart';
import 'package:ionicons/ionicons.dart';

// Shared helpers used across screens. Mirrors src/utils.js.

// Maps a transaction category to an Ionicons glyph.
const Map<String, IconData> categoryIcons = {
  'Food': Ionicons.fast_food,
  'Travel': Ionicons.train,
  'Shopping': Ionicons.bag_handle,
  'Bills': Ionicons.receipt,
  'Rent': Ionicons.home,
  'Income': Ionicons.cash,
  'Salary': Ionicons.briefcase,
  'Bonus': Ionicons.gift,
  'Gift': Ionicons.gift,
  'Investment': Ionicons.trending_up,
  'Others': Ionicons.ellipsis_horizontal,
};

IconData iconForCategory(String category) {
  return categoryIcons[category] ?? Ionicons.pricetag;
}

// ₹1234.50 style formatting (2 decimals).
String formatRupee(double amount) {
  return '₹${amount.toStringAsFixed(2)}';
}

const List<String> _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const List<String> _fullMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

// "Jul 24, 2026"
String formatShortDate(DateTime d) {
  return '${_monthNames[d.month - 1]} ${d.day}, ${d.year}';
}

// "July 24, 2026"
String formatLongDate(DateTime d) {
  return '${_fullMonthNames[d.month - 1]} ${d.day}, ${d.year}';
}

String monthLabel(DateTime d) {
  return _monthNames[d.month - 1];
}
