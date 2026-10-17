/// App-wide date formatting: display as DD-MM-YYYY, API as yyyy-MM-dd.
class AppDateFormat {
  static const String displayPattern = 'dd-MM-yyyy';
  static const List<String> _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  /// Format a [DateTime] for UI (e.g. 25-07-2026).
  static String formatDisplay(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d-$m-$y';
  }

  /// Format a [DateTime] as DD-MMM-YYYY (e.g. 15-AUG-2026).
  static String formatLong(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final mon = _months[date.month - 1];
    return '$d-$mon-${date.year}';
  }

  /// Format for API / storage (e.g. 2026-07-25).
  static String formatApi(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$y-$m-$d';
  }

  /// Parse common date strings (yyyy-MM-dd, dd-MM-yyyy, dd/MM/yyyy, ISO).
  static DateTime? tryParse(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;

    // dd-MM-yyyy or dd/MM/yyyy
    final dmy = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$');
    final dmyMatch = dmy.firstMatch(value);
    if (dmyMatch != null) {
      final day = int.tryParse(dmyMatch.group(1)!);
      final month = int.tryParse(dmyMatch.group(2)!);
      final year = int.tryParse(dmyMatch.group(3)!);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }

    // yyyy-MM-dd or yyyy/MM/dd
    final ymd = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})');
    final ymdMatch = ymd.firstMatch(value);
    if (ymdMatch != null) {
      final year = int.tryParse(ymdMatch.group(1)!);
      final month = int.tryParse(ymdMatch.group(2)!);
      final day = int.tryParse(ymdMatch.group(3)!);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }

    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  /// Any stored/API date → DD-MM-YYYY for display (empty if unparseable).
  static String toDisplay(String? raw) {
    final parsed = tryParse(raw);
    if (parsed == null) return (raw ?? '').trim();
    return formatDisplay(parsed);
  }

  /// Any stored/API date → DD-MMM-YYYY (e.g. 15-AUG-2026).
  static String toLongDisplay(String? raw) {
    final parsed = tryParse(raw);
    if (parsed == null) return (raw ?? '').trim();
    return formatLong(parsed);
  }

  /// UI or mixed date → yyyy-MM-dd for API (empty if unparseable).
  static String toApi(String? raw) {
    final parsed = tryParse(raw);
    if (parsed == null) return '';
    return formatApi(parsed);
  }

  /// Age in full years from a DOB string or DateTime.
  static int? ageFromDob(String? raw) {
    final dob = tryParse(raw);
    if (dob == null) return null;
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (DateTime(now.year, dob.month, dob.day).isAfter(now)) {
      age--;
    }
    return age >= 0 ? age : null;
  }
}
