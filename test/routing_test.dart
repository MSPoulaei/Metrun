import 'package:flutter_test/flutter_test.dart';
import 'package:masiryab_metro/dijkstra.dart';
import 'package:masiryab_metro/istgah_reader.dart';
import 'package:masiryab_metro/masiryab.dart';
import 'package:masiryab_metro/route_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Station & Routing Tests', () {
    test('IstgahReader reads station list from metrofa.txt asset', () async {
      final reader = IstgahReader();
      final pair = await reader.readStates();
      final stations = pair.first;
      expect(stations, isNotEmpty);
      expect(stations.contains('تجریش'), isTrue);
      expect(stations.contains('کهریزک'), isTrue);
    });

    test('Dijkstra finds path between adjacent stations on Line 1', () async {
      final dijkstra = Dijkstra();
      await dijkstra.init();
      final result = dijkstra.getPath('تجریش', 'قیطریه');
      expect(result.first, greaterThan(0));
      expect(result.second.isNotEmpty, isTrue);
    });

    test('Masiryab returns calculated route steps', () async {
      final masiryab = Masiryab();
      final steps = await masiryab.getPath('تجریش', 'شهدای هفتم تیر');
      expect(steps, isNotEmpty);
      // First step has total duration
      expect(steps.first.min, greaterThan(0));
    });

    test('convertOfflineStepsToOnlineRoute converts Dijkstra steps to an OnlineRoute without fake hours', () async {
      final masiryab = Masiryab();
      final steps = await masiryab.getPath('تجریش', 'چیتگر');
      final route = convertOfflineStepsToOnlineRoute(steps);

      expect(route.title, contains('آفلاین'));
      expect(route.isOffline, isTrue);
      expect(route.totalMinutes, greaterThan(0));
      expect(route.steps, isNotEmpty);
      expect(route.steps.first.station, 'تجریش');
      expect(route.steps.last.station, 'چیتگر');
      expect(route.departTime, isNull); // Offline route has NO clock hours
      expect(route.arriveTime, isNull);
      expect(route.instructions, isNotEmpty);
    });

    test('IstgahReader contains Maryam Moghaddas and canonical names without duplicates', () async {
      final reader = IstgahReader();
      final pair = await reader.readStates();
      final stations = pair.first;

      // Maryam Moghaddas present
      expect(stations.contains('مریم مقدس(س)'), isTrue);

      // Canonical Sadeghiyeh and Imam Hossein
      expect(stations.contains('تهران (صادقیه)'), isTrue);
      expect(stations.contains('تهران صادقیه'), isFalse);
      expect(stations.contains('امام حسین (ع)'), isTrue);
      expect(stations.contains('امام حسین'), isFalse);
    });

    test('Dijkstra finds path through newly added Maryam Moghaddas on Line 6', () async {
      final dijkstra = Dijkstra();
      await dijkstra.init();
      final result = dijkstra.getPath('میدان حضرت ولیعصر (عج)', 'مریم مقدس(س)');
      expect(result.first, greaterThan(0));
      expect(result.second.isNotEmpty, isTrue);
    });

    test('Rule 1 & Rule 2: Broken transfer routes can be replaced with offline Dijkstra route without fake hours', () async {
      final masiryab = Masiryab();
      final offlineSteps = await masiryab.getPath('تجریش', 'چیتگر');
      final offlineRoute = convertOfflineStepsToOnlineRoute(offlineSteps);

      expect(offlineRoute.steps.first.station, 'تجریش');
      expect(offlineRoute.steps.last.station, 'چیتگر');
      expect(offlineRoute.title, contains('آفلاین'));
      expect(offlineRoute.isOffline, isTrue);
      expect(offlineRoute.departTime, isNull);
    });
  });
}
