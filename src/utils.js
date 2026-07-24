// Shared helpers used across screens.

// Maps a transaction category to an Ionicons name (from @expo/vector-icons).
export const categoryIcons = {
  Food: 'fast-food',
  Travel: 'train',
  Shopping: 'bag-handle',
  Bills: 'receipt',
  Rent: 'home',
  Income: 'cash',
  Salary: 'briefcase',
  Bonus: 'gift',
  Gift: 'gift',
  Investment: 'trending-up',
  Others: 'ellipsis-horizontal',
};

export function iconForCategory(category) {
  return categoryIcons[category] ?? 'pricetag';
}

// ₹1234.50 style formatting (2 decimals), matching Flutter's toStringAsFixed(2).
export function formatRupee(amount) {
  return `₹${amount.toFixed(2)}`;
}

const monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

// "Jul 24, 2026" — replaces intl DateFormat.yMMMd()
export function formatShortDate(d) {
  return `${monthNames[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`;
}

// "July 24, 2026" — replaces intl DateFormat.yMMMMd()
const fullMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
export function formatLongDate(d) {
  return `${fullMonthNames[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`;
}

export function monthLabel(d) {
  return monthNames[d.getMonth()];
}
