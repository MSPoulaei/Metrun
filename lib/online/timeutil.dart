/// Tehran local time helpers and metro day-type mapping.

const int daySatToWed = 1; // شنبه تا چهارشنبه
const int dayThursday = 2; // پنجشنبه
const int dayFriday = 3; // جمعه
const int dayHoliday = 4; // تعطیل

/// Official form day labels (fallback if catalog missing).
const Map<int, String> defaultDayTypes = {
  daySatToWed: 'روزهای شنبه تا چهارشنبه',
  dayThursday: 'روزهای پنجشنبه',
  dayFriday: 'روزهای جمعه',
  dayHoliday: 'روزهای تعطیل',
};

/// Approximate Asia/Tehran offset (IRDT UTC+3:30 / IRST UTC+3:30 historically;
/// Iran has been permanently on UTC+3:30 since 2022).
const Duration tehranOffset = Duration(hours: 3, minutes: 30);

DateTime nowTehran() {
  return DateTime.now().toUtc().add(tehranOffset);
}

/// Map a datetime to the official scheduler day type.
/// Dart weekday: Mon=1 ... Sun=7
/// Iran metro form: 1=Sat–Wed, 2=Thursday, 3=Friday, 4=holiday
int dayTypeForDateTime(DateTime dt, {bool holiday = false}) {
  if (holiday) return dayHoliday;
  // Convert to Tehran local if needed (assume already local wall time for simple use)
  final wd = dt.weekday; // 1=Mon ... 7=Sun
  if (wd == DateTime.thursday) return dayThursday; // 4
  if (wd == DateTime.friday) return dayFriday; // 5
  // Sat(6), Sun(7), Mon(1), Tue(2), Wed(3)
  return daySatToWed;
}

/// Official form hours default 4–23.
/// If current time is before service, snap to hourMin:00.
/// If after hourMax, keep hourMax:59.
List<int> clampServiceHour(
  int hour,
  int minute, {
  int hourMin = 4,
  int hourMax = 23,
}) {
  if (hour < hourMin) return [hourMin, 0];
  if (hour > hourMax) return [hourMax, 59];
  return [hour, minute];
}

List<int> parseTime(String value) {
  var v = value.trim().replaceAll('.', ':').replaceAll(' ', '');
  if (!v.contains(':')) {
    if (RegExp(r'^\d{1,2}$').hasMatch(v)) {
      return [int.parse(v), 0];
    }
    throw FormatException('Invalid time: $value (use HH:MM)');
  }
  final parts = v.split(':');
  final hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    throw FormatException('Invalid time: $value');
  }
  return [hour, minute];
}
