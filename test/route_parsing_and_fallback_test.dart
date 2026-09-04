import 'package:flutter_test/flutter_test.dart';
import 'package:masiryab_metro/online/client.dart';
import 'package:masiryab_metro/online/models.dart';
import 'package:masiryab_metro/route_service.dart';

void main() {
  group('MetroClient parseRoutes & step parsing', () {
    test('Correctly parses steps even when time is a hyphen "-"', () {
      const html = '''
<div class="PathTitle">بهترین مسیر بر اساس تعویض خطوط</div>
<a class='line_4'><div class='stepNumberText'>1</div><span class='stepDesc'>14:36<br><small>دانشگاه علم و صنعت</small></span></a>
<a class='line_4'><div class='stepNumberText'>7</div><span class='stepDesc'>14:50<br><small>امام حسین (ع)</small></span></a>
<a class='line_5'><div class='stepNumberText'>8</div><span class='stepDesc'>-<br><small>اقدسیه</small></span></a>
<a class='line_7'><div class='stepNumberText'>9</div><span class='stepDesc'>--<br><small>ارم سبز</small></span></a>
<a class='line_7'><div class='stepNumberText'>10</div><span class='stepDesc'>15:06<br><small>ورزشگاه آزادی</small></span></a>
<a class='line_7'><div class='stepNumberText'>11</div><span class='stepDesc'>15:13<br><small>چیتگر</small></span></a>
''';

      final routes = parseRoutes(html);
      expect(routes.length, equals(1));
      final route = routes.first;
      expect(route.steps.length, equals(6));

      expect(route.steps[0].order, equals(1));
      expect(route.steps[0].station, equals('دانشگاه علم و صنعت'));
      expect(route.steps[0].time, equals('14:36'));

      expect(route.steps[1].order, equals(7));
      expect(route.steps[1].station, equals('امام حسین (ع)'));
      expect(route.steps[1].time, equals('14:50'));

      expect(route.steps[2].order, equals(8));
      expect(route.steps[2].station, equals('اقدسیه'));
      expect(route.steps[2].time, equals('-')); // Successfully captured '-'

      expect(route.steps[3].order, equals(9));
      expect(route.steps[3].station, equals('ارم سبز'));
      expect(route.steps[3].time, equals('--')); // Successfully captured '--'

      expect(route.steps[4].order, equals(10));
      expect(route.steps[4].station, equals('ورزشگاه آزادی'));
      expect(route.steps[4].time, equals('15:06'));

      expect(route.steps[5].order, equals(11));
      expect(route.steps[5].station, equals('چیتگر'));
      expect(route.steps[5].time, equals('15:13'));
    });

    test('getRouteTransferCount correctly calculates number of line changes', () {
      // 1 line change (Line 2 to Line 5: css 4 -> 7)
      const route1Transfer = OnlineRoute(
        title: 'مسیر ۱',
        steps: [
          RouteStep(order: 1, line: 4, time: '14:00', station: 'دانشگاه علم و صنعت'),
          RouteStep(order: 2, line: 4, time: '14:20', station: 'تهران (صادقیه)'),
          RouteStep(order: 3, line: 7, time: '14:25', station: 'تهران (صادقیه)'),
          RouteStep(order: 4, line: 7, time: '14:35', station: 'چیتگر'),
        ],
      );

      // 2 line changes (Line 2 to Line 4 to Line 5: css 4 -> 6 -> 7)
      const route2Transfers = OnlineRoute(
        title: 'مسیر ۲',
        steps: [
          RouteStep(order: 1, line: 4, time: '14:00', station: 'دانشگاه علم و صنعت'),
          RouteStep(order: 2, line: 4, time: '14:15', station: 'دروازه شمیران'),
          RouteStep(order: 3, line: 6, time: '14:18', station: 'دروازه شمیران'),
          RouteStep(order: 4, line: 6, time: '14:30', station: 'ارم سبز'),
          RouteStep(order: 5, line: 7, time: '14:35', station: 'ارم سبز'),
          RouteStep(order: 6, line: 7, time: '14:45', station: 'چیتگر'),
        ],
      );

      expect(getRouteTransferCount(route1Transfer), equals(1));
      expect(getRouteTransferCount(route2Transfers), equals(2));

      // Sorting test: route with lower transfer count must be first!
      final list = [route2Transfers, route1Transfer];
      list.sort((a, b) {
        final countA = getRouteTransferCount(a);
        final countB = getRouteTransferCount(b);
        if (countA != countB) return countA.compareTo(countB);
        return a.stationCount.compareTo(b.stationCount);
      });

      expect(list.first.title, equals('مسیر ۱'));
      expect(list.last.title, equals('مسیر ۲'));
    });
  });
}
