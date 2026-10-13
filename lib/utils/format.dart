/// Formats an integer as Indian rupees with Indian digit grouping, e.g. 1234567 -> ₹12,34,567
String formatInr(int n) {
  final s = n.abs().toString();
  final sign = n < 0 ? '-' : '';
  if (s.length <= 3) return '$sign₹$s';
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '$sign₹${parts.join(',')},$last3';
}

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// e.g. 5 Mar 2026
String formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// e.g. 5 - 9 Mar 2026, or 28 Feb - 3 Mar 2026
String formatDateRange(DateTime a, DateTime b) {
  if (a.year == b.year && a.month == b.month) {
    return a.day == b.day ? formatDate(a) : '${a.day} - ${formatDate(b)}';
  }
  if (a.year == b.year) {
    return '${a.day} ${_months[a.month - 1]} - ${formatDate(b)}';
  }
  return '${formatDate(a)} - ${formatDate(b)}';
}

/// Good morning / afternoon / evening.
String greetingFor(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 17) return 'Good afternoon';
  return 'Good evening';
}

final RegExp _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

String? validateEmail(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'Email is required';
  if (!_emailRe.hasMatch(s)) return 'Enter a valid email address';
  return null;
}

String? validatePassword(String? v) {
  final s = v ?? '';
  if (s.isEmpty) return 'Password is required';
  if (s.length < 6) return 'Use at least 6 characters';
  return null;
}
