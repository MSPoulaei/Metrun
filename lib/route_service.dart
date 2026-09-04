import 'istgah_reader.dart';
import 'masiryab.dart';
import 'online/client.dart';
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
    return RouteResult(
      source: RouteSource.online,
      originName: fromMatch.station!.name,
      destinationName: toMatch.station!.name,
      onlineRoutes: routes,
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
