// ── 12-hour time formatting ───────────────────────────────────────────────────
//
// Direction strategy
// ------------------
// Both locales use "digits then period marker" as the LOGICAL string:
//   English (LTR) → "8:00 AM"   visual = "8:00 AM"  ✓
//   Arabic  (RTL) → "8:00 ص"   visual = "ص 8:00"   ✓
//
// Why "8:00 ص" works in RTL:
//   Unicode BiDi sees two runs: digits "8:00" at embedding level 2 (LTR
//   sub-run) and "ص" at level 1 (RTL).  The reversal pass swaps them, so
//   the digit group moves to the right and "ص" to the left — exactly the
//   Arabic reading order "8:00 then ص".  No Directionality widget needed.
//
// Why "ص 8:00" would be WRONG:
//   The same reversal pass produces visual "8:00 ص" — ص ends up on the
//   right, which is backwards for the Arabic reader.

/// Converts an "HH:mm" string (24-hour) to a locale-aware 12-hour label.
///
/// * English → "8:00 AM"  / "1:30 PM"
/// * Arabic  → "8:00 ص"  / "1:30 م"  (BiDi renders visually as "ص 8:00")
String format12h(String hhmm, {bool isArabic = false}) {
  final parts = hhmm.split(':');
  final h = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  final isAm = h < 12;
  final period = isArabic ? (isAm ? 'ص' : 'م') : (isAm ? 'AM' : 'PM');
  final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  final mm = m.toString().padLeft(2, '0');
  return '$h12:$mm $period'; // digits first in both locales; BiDi handles display
}

/// Formats a time range from two "HH:mm" strings.
///
/// * English → "8:00 AM – 12:00 PM"
/// * Arabic  → "8:00 ص – 12:00 م"  (renders as "م 12:00 – ص 8:00" in RTL)
String format12hRange(String from, String to, {bool isArabic = false}) {
  return '${format12h(from, isArabic: isArabic)} – ${format12h(to, isArabic: isArabic)}';
}
