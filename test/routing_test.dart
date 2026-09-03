import 'package:flutter_test/flutter_test.dart';
import 'package:masiryab_metro/dijkstra.dart';
import 'package:masiryab_metro/istgah_reader.dart';
import 'package:masiryab_metro/masiryab.dart';

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
      final result = dijkstra.GetPath('تجریش', 'قیطریه');
      expect(result.first, greaterThan(0));
      expect(result.second.isNotEmpty, isTrue);
    });

    test('Masiryab returns calculated route steps', () async {
      final masiryab = Masiryab();
      final steps = await masiryab.GetPath('تجریش', 'شهدای هفتم تیر');
      expect(steps, isNotEmpty);
      // First step has total duration
      expect(steps.first.min, greaterThan(0));
    });
  });
}
