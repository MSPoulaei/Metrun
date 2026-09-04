import 'istgah_reader.dart';
import 'masiryab.dart';
import 'online/client.dart';
import 'online/line_mapper.dart';
import 'online/matching.dart';
import 'online/models.dart';
import 'online/timeutil.dart';

enum RouteMode { auto, online, offline }

enum RouteSource { online, offline }

/// Unified search result for the UI.
class RouteResult {
  final RouteSource source;
  final bool fellBack;
  final String? notice;
  final String? error;

  /// Offline Dijkstra steps (null if online-only success).
  final List<Stepp>? offlineSteps;

  /// Online official routes.
  final List<OnlineRoute>? onlineRoutes;

  final String originName;
  final String destinationName;
  final int? dayType;
  final int? hour;
  final int? minute;
  final int? scheduleType;

  const RouteResult({
    required this.source,
    required this.originName,
    required this.destinationName,
    this.fellBack = false,
    this.notice,
    this.error,
    this.offlineSteps,
    this.onlineRoutes,
    this.dayType,
    this.hour,
    this.minute,
    this.scheduleType,
  });

  bool get hasData =>
      (offlineSteps != null && offlineSteps!.isNotEmpty) ||
      (onlineRoutes != null && onlineRoutes!.isNotEmpty);
}

class RouteService {
  RouteMode mode;
  MetroClient? _client;
  List<Station> _onlineStations = [];
  bool _ready = false;
  List<String>? _offlineNameCache;

  RouteService({this.mode = RouteMode.auto});

  bool get isReady => _ready;
  List<Station> get onlineStations => List.unmodifiable(_onlineStations);
  Catalog? get catalog => _client?.catalog;
  Map<int, String> get dayTypes =>
      _client?.dayTypes() ?? Map<int, String>.from(dayTypesFallback);

  Future<void> init() async {
    try {
      _client = await createMetroClientFromAssets();
      _onlineStations = await _client!.listStations();
    } catch (_) {
      // Online catalog optional at startup; offline still works.
      _client = null;
      _onlineStations = [];
    }
    _ready = true;
  }

  Set<String> onlineStationNames() =>
      _onlineStations.map((s) => s.name).toSet();

  /// Auto: try online when client is ready (network probed by actual request).
  /// Online: force online. Offline: force offline graph.
  bool _shouldTryOnline() {
    if (mode == RouteMode.offline) return false;
    if (mode == RouteMode.online) return true;
    return _client != null;
  }

  Future<RouteResult> findRoute({
    required String fromName,
    required String toName,
    int? dayType,
    int? hour,
    int? minute,
    int scheduleType = RouteQuery.scheduleDepart,
    bool holiday = false,
  }) async {
    final useOnline = _shouldTryOnline();

    if (useOnline && _client != null) {
      try {
        return await _findOnline(
          fromName: fromName,
          toName: toName,
          dayType: dayType,
          hour: hour,
          minute: minute,
          scheduleType: scheduleType,
          holiday: holiday,
        );
      } catch (e) {
        if (mode == RouteMode.online) {
          return RouteResult(
            source: RouteSource.online,
            originName: fromName,
            destinationName: toName,
            error: e.toString(),
            dayType: dayType,
            hour: hour,
            minute: minute,
            scheduleType: scheduleType,
          );
        }
        // Auto: fallback to offline
        try {
          final offline = await _findOffline(fromName, toName);
          return RouteResult(
            source: RouteSource.offline,
            originName: fromName,
            destinationName: toName,
            offlineSteps: offline,
            fellBack: true,
            notice: 'اینترنت در دسترس نیست — مسیر تقریبی آفلاین',
            error: e.toString(),
          );
        } catch (offlineErr) {
          return RouteResult(
            source: RouteSource.offline,
            originName: fromName,
            destinationName: toName,
            fellBack: true,
            error: 'آنلاین: $e\nآفلاین: $offlineErr',
          );
        }
      }
    }

    // Offline path
    try {
      final steps = await _findOffline(fromName, toName);
      return RouteResult(
        source: RouteSource.offline,
        originName: fromName,
        destinationName: toName,
        offlineSteps: steps,
        notice: mode == RouteMode.auto
            ? 'حالت آفلاین (بدون کاتالوگ آنلاین)'
            : null,
      );
    } catch (e) {
      return RouteResult(
        source: RouteSource.offline,
        originName: fromName,
        destinationName: toName,
        error: e.toString(),
      );
    }
  }

  Future<RouteResult> _findOnline({
    required String fromName,
    required String toName,
    int? dayType,
    int? hour,
    int? minute,
    int scheduleType = RouteQuery.scheduleDepart,
    bool holiday = false,
  }) async {
    final client = _client!;
    final stations = _onlineStations.isNotEmpty
        ? _onlineStations
        : await client.listStations();

    final fromMatch = matchStation(fromName, stations);
    final toMatch = matchStation(toName, stations);

    if (fromMatch.station == null) {
      throw MetroClientException('ایستگاه مبدا پیدا نشد: $fromName');
    }
    if (toMatch.station == null) {
      throw MetroClientException('ایستگاه مقصد پیدا نشد: $toName');
    }
    if (fromMatch.station!.id == toMatch.station!.id) {
      throw MetroClientException('مبدا و مقصد یکسان است');
    }

    final now = nowTehran();
    var h = hour ?? now.hour;
    var m = minute ?? now.minute;
    final hours = client.serviceHours();
    final clamped =
        clampServiceHour(h, m, hourMin: hours[0], hourMax: hours[1]);
    h = clamped[0];
    m = clamped[1];

    final day = dayType ?? dayTypeForDateTime(now, holiday: holiday);

    final query = RouteQuery(
      fromStationId: fromMatch.station!.id,
      toStationId: toMatch.station!.id,
      dayType: day,
      hour: h,
      minute: m,
      scheduleType: scheduleType,
    );

    final routes = await client.findRoute(query);

    final validRoutes = <OnlineRoute>[];
    bool hadBrokenRoute = false;

    for (final r in routes) {
      if (_isRouteValid(r, toMatch.station!.name)) {
        validRoutes.add(r);
      } else {
        hadBrokenRoute = true;
      }
    }

    List<OnlineRoute> finalOnlineRoutes = [];
    List<Stepp>? offlineSteps;

    if (hadBrokenRoute) {
      // One of the online routes was broken -> discard it,
      // keep valid online route(s) (such as مسافت) 1st,
      // and place offline result as 2nd!
      try {
        offlineSteps = await _findOffline(fromName, toName);
        if (offlineSteps.isNotEmpty) {
          final offlineRoute = convertOfflineStepsToOnlineRoute(offlineSteps);
          finalOnlineRoutes = [...validRoutes, offlineRoute];
        } else {
          finalOnlineRoutes = validRoutes;
        }
      } catch (_) {
        finalOnlineRoutes = validRoutes;
      }
    } else {
      // Both routes are healthy (or single route returned).
      // Sort so that the route with the LOWER count of line transfers (تعویض خط) is 1st!
      validRoutes.sort((a, b) {
        final countA = getRouteTransferCount(a);
        final countB = getRouteTransferCount(b);
        if (countA != countB) {
          return countA.compareTo(countB); // Lower count of transfers first!
        }
        return a.stationCount.compareTo(b.stationCount);
      });
      finalOnlineRoutes = validRoutes;
    }

    // Rule D: None of the online results exist/valid -> show offline result
    if (finalOnlineRoutes.isEmpty) {
      final offline = offlineSteps ?? await _findOffline(fromName, toName);
      return RouteResult(
        source: RouteSource.offline,
        originName: fromMatch.station!.name,
        destinationName: toMatch.station!.name,
        offlineSteps: offline,
        fellBack: true,
        notice: 'مسیر آنلاین معتبر یافت نشد — مسیر آفلاین',
        dayType: day,
        hour: h,
        minute: m,
        scheduleType: scheduleType,
      );
    }

    return RouteResult(
      source: RouteSource.online,
      originName: fromMatch.station!.name,
      destinationName: toMatch.station!.name,
      onlineRoutes: finalOnlineRoutes,
      offlineSteps: offlineSteps,
      dayType: day,
      hour: h,
      minute: m,
      scheduleType: scheduleType,
    );
  }

  Future<List<Stepp>> _findOffline(String from, String to) async {
    // Offline graph uses metrofa.txt names; resolve via fuzzy match when
    // the user picked an official-catalog name that differs slightly.
    final offlineNames = await _offlineStationList();
    final fromResolved = _resolveOfflineName(from, offlineNames);
    final toResolved = _resolveOfflineName(to, offlineNames);
    return Masiryab().getPath(fromResolved, toResolved);
  }

  Future<List<String>> _offlineStationList() async {
    if (_offlineNameCache != null) return _offlineNameCache!;
    final reader = await _loadOfflineNames();
    _offlineNameCache = reader;
    return reader;
  }

  Future<List<String>> _loadOfflineNames() async {
    try {
      final pair = await IstgahReader().readStates();
      return pair.first.toList();
    } catch (_) {
      return [];
    }
  }

  String _resolveOfflineName(String query, List<String> offlineNames) {
    if (offlineNames.contains(query)) return query;
    if (offlineNames.isEmpty) return query;
    final stations = offlineNames
        .asMap()
        .entries
        .map((e) => Station(id: e.key, name: e.value))
        .toList();
    final match = matchStation(query, stations);
    return match.station?.name ?? query;
  }

  void dispose() {
    _client?.dispose();
  }
}

bool _isDestinationMatch(String lastStation, String destination) {
  String norm(String s) {
    return s
        .replaceAll(RegExp(r'[آأإٱ]'), 'ا')
        .replaceAll(RegExp(r'[يىئ]'), 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'[\u200c\u200d\(\)\[\]\-–—،,._]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'(ایستگاه|مترو)'), '')
        .trim();
  }
  final s1 = norm(lastStation);
  final s2 = norm(destination);
  return s1 == s2 || s1.contains(s2) || s2.contains(s1);
}

bool _isRouteValid(OnlineRoute r, String expectedDest) {
  if (r.steps.length < 2) return false;
  if (!_isDestinationMatch(r.steps.last.station, expectedDest)) return false;
  if (!_hasValidTimes(r)) return false;
  if (!_hasContinuousOrders(r)) return false;
  return true;
}

bool _hasContinuousOrders(OnlineRoute r) {
  if (r.steps.isEmpty) return false;
  for (var i = 0; i < r.steps.length; i++) {
    if (r.steps[i].order != i + 1) {
      return false;
    }
  }
  return true;
}

bool _hasValidTimes(OnlineRoute r) {
  if (r.steps.isEmpty) return false;
  for (final step in r.steps) {
    final t = step.time.trim();
    if (t.isEmpty || t == '-' || t == '--' || t == '---' || !RegExp(r'\d').hasMatch(t)) {
      return false;
    }
  }
  return true;
}

int getRouteTransferCount(OnlineRoute r) {
  if (r.steps.isEmpty) return 0;
  final lines = <int>[];
  for (final step in r.steps) {
    final rl = cssLineToMetroLine(step.line);
    if (lines.isEmpty || lines.last != rl) {
      lines.add(rl);
    }
  }
  return (lines.length - 1).clamp(0, 999);
}

OnlineRoute convertOfflineStepsToOnlineRoute(List<Stepp> steps) {
  if (steps.isEmpty) {
    return const OnlineRoute(
      title: 'بهترین مسیر بر اساس تعویض خطوط (آفلاین)',
      isOffline: true,
      totalMinutes: 0,
    );
  }

  final routeSteps = <RouteStep>[];
  final instructions = <String>[];
  var accumulatedMinutes = 0;
  var order = 1;

  int metroLineToCss(int line) {
    switch (line) {
      case 1:
        return 1;
      case 2:
        return 4;
      case 3:
        return 5;
      case 4:
        return 6;
      case 5:
        return 7;
      case 6:
        return 8;
      case 7:
        return 9;
      case 8:
        return 10;
      default:
        return line;
    }
  }

  if (steps.length > 1 && steps[1].from != null) {
    final first = steps[1];
    final line = first.khat2 ?? 1;
    routeSteps.add(RouteStep(
      order: order++,
      line: metroLineToCss(line),
      time: '',
      station: first.from!.name,
    ));
    instructions.add('سوار قطار خط $line در ایستگاه ${first.from!.name} شوید.');
  }

  for (var i = 1; i < steps.length; i++) {
    final step = steps[i];
    accumulatedMinutes += step.min;

    if (step.tavizkhat) {
      final k1 = step.khat1 ?? 1;
      final k2 = step.khat2 ?? 1;
      instructions.add('در ایستگاه ${step.from!.name} از خط $k1 به خط $k2 تعویض خط انجام دهید.');
    } else if (step.to != null) {
      final line = step.khat2 ?? 1;
      routeSteps.add(RouteStep(
        order: order++,
        line: metroLineToCss(line),
        time: '',
        station: step.to!.name,
      ));
    }
  }

  if (routeSteps.isNotEmpty) {
    instructions.add('در ایستگاه ${routeSteps.last.station} از قطار پیاده شوید.');
  }

  return OnlineRoute(
    title: 'بهترین مسیر بر اساس تعویض خطوط (آفلاین)',
    steps: routeSteps,
    instructions: instructions,
    isOffline: true,
    totalMinutes: accumulatedMinutes,
  );
}
