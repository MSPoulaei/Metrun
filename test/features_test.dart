import 'package:flutter_test/flutter_test.dart';
import 'package:masiryab_metro/favorites_service.dart';
import 'package:masiryab_metro/persian_number_utility.dart';
import 'package:masiryab_metro/update_checker_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Persian Number Utility', () {
    test('Converts English digits to Persian correctly', () {
      expect('1234567890'.toPersianDigits(), '۱۲۳۴۵۶۷۸۹۰');
      expect('14:35'.toPersianDigits(), '۱۴:۳۵');
      expect('خط 4 (ایستگاه 12)'.toPersianDigits(), 'خط ۴ (ایستگاه ۱۲)');
    });
  });

  group('UpdateCheckerService', () {
    test('Detects newer semver versions correctly', () {
      expect(UpdateCheckerService.isNewerVersion('2.1.0', '2.0.0'), isTrue);
      expect(UpdateCheckerService.isNewerVersion('2.0.1', '2.0.0'), isTrue);
      expect(UpdateCheckerService.isNewerVersion('3.0.0', '2.5.0'), isTrue);
      expect(UpdateCheckerService.isNewerVersion('2.0.0', '2.0.0'), isFalse);
      expect(UpdateCheckerService.isNewerVersion('1.9.0', '2.0.0'), isFalse);
    });
  });

  group('FavoritesService', () {
    setUp(() {
      FavoritesService.favoritesNotifier.value = [];
    });

    test('FavoriteTrip json serialization and equality', () {
      const fav1 = FavoriteTrip(from: 'تجریش', to: 'دروازه دولت');
      const fav2 = FavoriteTrip(from: 'تجریش', to: 'دروازه دولت');
      expect(fav1, equals(fav2));

      final json = fav1.toJson();
      final fromJson = FavoriteTrip.fromJson(json);
      expect(fromJson, equals(fav1));
    });
  });
}
