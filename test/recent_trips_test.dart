import 'package:flutter_test/flutter_test.dart';
import 'package:masiryab_metro/recent_trips_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecentTripsService Tests', () {
    setUp(() {
      RecentTripsService.tripsNotifier.value = [];
    });

    test('TripRecord equality and json serialization', () {
      const trip1 = TripRecord(from: 'تجریش', to: 'قیطریه');
      const trip2 = TripRecord(from: 'تجریش', to: 'قیطریه');
      const trip3 = TripRecord(from: 'قیطریه', to: 'تجریش');

      expect(trip1, equals(trip2));
      expect(trip1 == trip3, isFalse);

      final json = trip1.toJson();
      expect(json['from'], 'تجریش');
      expect(json['to'], 'قیطریه');

      final fromJson = TripRecord.fromJson(json);
      expect(fromJson, equals(trip1));
    });

    test('addTrip prevents empty or identical stations', () async {
      await RecentTripsService.addTrip('', 'قیطریه');
      expect(RecentTripsService.tripsNotifier.value, isEmpty);

      await RecentTripsService.addTrip('تجریش', '');
      expect(RecentTripsService.tripsNotifier.value, isEmpty);

      await RecentTripsService.addTrip('تجریش', 'تجریش');
      expect(RecentTripsService.tripsNotifier.value, isEmpty);
    });
  });
}
