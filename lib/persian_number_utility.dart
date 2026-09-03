/// Utility for formatting numbers to Persian digits (۰-۹)
class PersianNumberUtility {
  static const List<String> _englishDigits = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'
  ];
  static const List<String> _persianDigits = [
    '۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'
  ];

  /// Converts all English digits in [input] to Persian digits
  static String toPersianDigits(dynamic input) {
    if (input == null) return '';
    var str = input.toString();
    for (var i = 0; i < 10; i++) {
      str = str.replaceAll(_englishDigits[i], _persianDigits[i]);
    }
    return str;
  }
}

extension PersianStringExtension on String {
  /// Converts string containing English digits to Persian digits
  String toPersianDigits() => PersianNumberUtility.toPersianDigits(this);
}
