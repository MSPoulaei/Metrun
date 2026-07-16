import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import 'models.dart';

const String _defaultUa =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

// Fallback form field names (DNN module IranDnn Metro Station)
const String fieldFrom = 'dnn\$ctr2558\$Main\$frmRcbBaseStation';
const String fieldTo = 'dnn\$ctr2558\$Main\$frmRcbDestinationStation';
const String fieldDay = 'dnn\$ctr2558\$Main\$frmDdlDaysTypeLU';
const String fieldSchedule = 'dnn\$ctr2558\$Main\$frmRblSchedulingType';
const String fieldMinute = 'dnn\$ctr2558\$Main\$frmDdlMinute';
const String fieldHour = 'dnn\$ctr2558\$Main\$frmDdlHour';
const String fieldSearch = 'dnn\$ctr2558\$Main\$frmBtnSearch';
const String fieldSearchValue = 'جستجو';

const Map<int, String> dayTypesFallback = {
  1: 'روزهای شنبه تا چهارشنبه',
  2: 'روزهای پنجشنبه',
  3: 'روزهای جمعه',
  4: 'روزهای تعطیل',
};

final RegExp _stepRe = RegExp(
  r"<a class='line_(\d+)'>.*?"
  r"<div class='stepNumberText'>(\d+)</div>.*?"
  r"<span class='stepDesc'[^>]*>\s*([\d:]+)<br><small>([^<]+)</small>",
  dotAll: true,
);

final RegExp _pathTitleRe = RegExp(
  r'class="PathTitle"[^>]*>([^<]+)',
  caseSensitive: false,
);

final RegExp _routeHelpRe = RegExp(
  r'class="route-help"[^>]*>(.*?)</div>',
  caseSensitive: false,
  dotAll: true,
);

final RegExp _optionRe = RegExp(r'<option value="(\d+)">([^<]+)</option>');

/// HTTP client for the official Tehran Metro route scheduler form.
class MetroClient {
  final String pageUrl;
  final Duration timeout;
  Catalog? _catalog;
  List<Station>? _stations;
  final http.Client _http;
  String? _cookieHeader;

  MetroClient({
    required this.pageUrl,
    this.timeout = const Duration(seconds: 45),
    Catalog? catalog,
    http.Client? httpClient,
  })  : _catalog = catalog,
        _http = httpClient ?? http.Client();

  Catalog? get catalog => _catalog;

  Map<int, String> dayTypes() {
    if (_catalog != null && _catalog!.dayTypes.isNotEmpty) {
      return Map<int, String>.from(_catalog!.dayTypes);
    }
    return Map<int, String>.from(dayTypesFallback);
  }

  Map<int, String> scheduleTypes() {
    if (_catalog != null && _catalog!.scheduleTypes.isNotEmpty) {
      return Map<int, String>.from(_catalog!.scheduleTypes);
    }
    return {
      RouteQuery.scheduleDepart: 'حرکت از مبدا',
      RouteQuery.scheduleArrive: 'ایستگاه مقصد',
    };
  }

  List<int> serviceHours() {
    final hours = (_catalog != null && _catalog!.hours.isNotEmpty)
        ? _catalog!.hours
        : List<int>.generate(20, (i) => i + 4); // 4..23
    return [hours.reduce((a, b) => a < b ? a : b), hours.reduce((a, b) => a > b ? a : b)];
  }

  String _field(String key, String defaultValue) {
    final v = _catalog?.formFields[key];
    if (v != null && v.isNotEmpty) return v;
    return defaultValue;
  }

  Map<String, String> _headers({bool post = false}) {
    final h = <String, String>{
      'User-Agent': _defaultUa,
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'fa-IR,fa;q=0.9,en;q=0.8',
    };
    if (_cookieHeader != null && _cookieHeader!.isNotEmpty) {
      h['Cookie'] = _cookieHeader!;
    }
    if (post) {
      h['Content-Type'] = 'application/x-www-form-urlencoded';
      h['Origin'] = 'https://metro.tehran.ir';
      h['Referer'] = pageUrl;
    }
    return h;
  }

  void _captureCookies(http.Response resp) {
    final setCookies = resp.headers['set-cookie'];
    if (setCookies == null || setCookies.isEmpty) return;
    // http package may join multiple set-cookie with comma; take name=value pairs
    final parts = setCookies.split(RegExp(r',(?=[^;]+?=)'));
    final jar = <String, String>{};
    if (_cookieHeader != null) {
      for (final c in _cookieHeader!.split(';')) {
        final kv = c.trim().split('=');
        if (kv.length >= 2) jar[kv.first.trim()] = kv.sublist(1).join('=');
      }
    }
    for (final part in parts) {
      final first = part.split(';').first.trim();
      final eq = first.indexOf('=');
      if (eq > 0) {
        jar[first.substring(0, eq)] = first.substring(eq + 1);
      }
    }
    _cookieHeader = jar.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  Future<String> _request(String url, {Map<String, String>? data}) async {
    try {
      final uri = Uri.parse(url);
      final http.Response resp;
      if (data != null) {
        resp = await _http
            .post(uri, headers: _headers(post: true), body: data)
            .timeout(timeout);
      } else {
        resp = await _http.get(uri, headers: _headers()).timeout(timeout);
      }
      _captureCookies(resp);
      if (resp.statusCode >= 400) {
        throw MetroClientException(
            'HTTP ${resp.statusCode} from metro.tehran.ir');
      }
      return utf8.decode(resp.bodyBytes, allowMalformed: true);
    } on MetroClientException {
      rethrow;
    } catch (e) {
      throw MetroClientException('Network error: $e');
    }
  }

  static String _hidden(String html, String name) {
    final patterns = [
      RegExp('name="${RegExp.escape(name)}"[^>]*value="([^"]*)"',
          caseSensitive: false),
      RegExp('id="${RegExp.escape(name)}"[^>]*value="([^"]*)"',
          caseSensitive: false),
      RegExp('value="([^"]*)"[^>]*name="${RegExp.escape(name)}"',
          caseSensitive: false),
      RegExp('value="([^"]*)"[^>]*id="${RegExp.escape(name)}"',
          caseSensitive: false),
    ];
    for (final pat in patterns) {
      final m = pat.firstMatch(html);
      if (m != null) {
        return _htmlUnescape(m.group(1) ?? '');
      }
    }
    return '';
  }

  static String _htmlUnescape(String s) {
    return s
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
  }

  Future<String> fetchPage() => _request(pageUrl);

  Future<List<Station>> listStations({bool force = false}) async {
    if (_stations != null && !force) return _stations!;

    if (!force && _catalog != null && _catalog!.stations.isNotEmpty) {
      _stations = List<Station>.from(_catalog!.stations);
      return _stations!;
    }

    final page = await fetchPage();
    final fieldFromName = _field('from', fieldFrom);
    final blockRe = RegExp(
      '<select[^>]*name="${RegExp.escape(fieldFromName)}"[^>]*>(.*?)</select>',
      caseSensitive: false,
      dotAll: true,
    );
    final block = blockRe.firstMatch(page);
    if (block == null) {
      throw MetroClientException(
          'Could not find station list on the official page');
    }
    final stations = <Station>[];
    for (final m in _optionRe.allMatches(block.group(0)!)) {
      stations.add(Station(
        id: int.parse(m.group(1)!),
        name: _htmlUnescape(m.group(2)!).trim(),
      ));
    }
    if (stations.isEmpty) {
      throw MetroClientException('Station list is empty');
    }
    _stations = stations;
    return stations;
  }

  /// Always hits the official site — routes/schedules are live.
  Future<List<OnlineRoute>> findRoute(RouteQuery query) async {
    final page = await fetchPage();
    final viewstate = _hidden(page, '__VIEWSTATE');
    final eventValidation = _hidden(page, '__EVENTVALIDATION');
    final viewstateGen = _hidden(page, '__VIEWSTATEGENERATOR');
    final token = _hidden(page, '__RequestVerificationToken');
    if (viewstate.isEmpty || eventValidation.isEmpty) {
      throw MetroClientException(
          'Missing ASP.NET form tokens from official page');
    }

    final days = dayTypes();
    final schedules = scheduleTypes();
    final hours = serviceHours();
    final hMin = hours[0];
    final hMax = hours[1];

    if (!days.containsKey(query.dayType)) {
      throw MetroClientException('Invalid day_type: ${query.dayType}');
    }
    if (!schedules.containsKey(query.scheduleType)) {
      throw MetroClientException(
          'Invalid schedule_type: ${query.scheduleType}');
    }
    if (query.minute < 0 || query.minute > 59) {
      throw MetroClientException('Invalid minute: ${query.minute}');
    }
    if (query.hour < hMin || query.hour > hMax) {
      throw MetroClientException(
        'Hour ${query.hour} is outside metro form range ($hMin–$hMax). '
        'Use a time during service hours.',
      );
    }

    final fFrom = _field('from', fieldFrom);
    final fTo = _field('to', fieldTo);
    final fDay = _field('day', fieldDay);
    final fSched = _field('schedule', fieldSchedule);
    final fMin = _field('minute', fieldMinute);
    final fHour = _field('hour', fieldHour);
    final fSearch = _field('search', fieldSearch);
    final fSearchVal = _field('search_value', fieldSearchValue);

    final data = <String, String>{
      '__EVENTTARGET': '',
      '__EVENTARGUMENT': '',
      '__VIEWSTATE': viewstate,
      '__VIEWSTATEGENERATOR': viewstateGen,
      '__VIEWSTATEENCRYPTED': '',
      '__EVENTVALIDATION': eventValidation,
      fFrom: '${query.fromStationId}',
      fTo: '${query.toStationId}',
      fDay: '${query.dayType}',
      fSched: '${query.scheduleType}',
      fMin: '${query.minute}',
      fHour: '${query.hour}',
      fSearch: fSearchVal,
    };
    if (token.isNotEmpty) {
      data['__RequestVerificationToken'] = token;
    }

    final resultHtml = await _request(pageUrl, data: data);
    final routes = parseRoutes(resultHtml);
    if (routes.isEmpty) {
      throw MetroClientException(
        'No route returned. Check stations, day type, and service hours.',
      );
    }
    return routes;
  }

  void dispose() {
    _http.close();
  }
}

List<OnlineRoute> parseRoutes(String resultHtml) {
  final titles = _pathTitleRe
      .allMatches(resultHtml)
      .map((m) => MetroClient._htmlUnescape(m.group(1)!).trim())
      .toList();

  final helps = <List<String>>[];
  for (final m in _routeHelpRe.allMatches(resultHtml)) {
    var text = m.group(1)!;
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
    text = MetroClient._htmlUnescape(text);
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final parts = text
        .split(RegExp(r'[•\u2022]'))
        .map((p) => p.replaceAll(RegExp(r'^[ \t•\u2022]+|[ \t]+$'), ''))
        .where((p) => p.isNotEmpty)
        .toList();
    helps.add(parts);
  }

  final allSteps = <RouteStep>[];
  for (final m in _stepRe.allMatches(resultHtml)) {
    allSteps.add(RouteStep(
      order: int.parse(m.group(2)!),
      line: int.parse(m.group(1)!),
      time: m.group(3)!.trim(),
      station: MetroClient._htmlUnescape(m.group(4)!).trim(),
    ));
  }

  if (titles.isEmpty && allSteps.isEmpty) return [];

  final useTitles = titles.isEmpty ? <String>['مسیر'] : titles;

  final groups = <List<RouteStep>>[];
  var current = <RouteStep>[];
  for (final step in allSteps) {
    if (current.isNotEmpty && step.order == 1) {
      groups.add(current);
      current = [step];
    } else {
      current.add(step);
    }
  }
  if (current.isNotEmpty) groups.add(current);

  while (groups.length < useTitles.length) {
    groups.add([]);
  }

  final routes = <OnlineRoute>[];
  for (var i = 0; i < useTitles.length; i++) {
    routes.add(OnlineRoute(
      title: useTitles[i],
      steps: i < groups.length ? groups[i] : const [],
      instructions: i < helps.length ? helps[i] : const [],
    ));
  }
  return routes;
}

/// Load catalog + page URL from Flutter assets.
Future<MetroClient> createMetroClientFromAssets({
  String catalogAsset = 'assets/data/catalog.json',
  String linkAsset = 'assets/data/link.txt',
}) async {
  String pageUrl;
  try {
    final linkText = (await rootBundle.loadString(linkAsset)).trim();
    pageUrl = linkText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .firstWhere((l) => l.startsWith('http'), orElse: () => '');
  } catch (_) {
    pageUrl = '';
  }

  Catalog? catalog;
  try {
    final raw = await rootBundle.loadString(catalogAsset);
    catalog = Catalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    if (pageUrl.isEmpty && catalog.sourceUrl.isNotEmpty) {
      pageUrl = catalog.sourceUrl;
    }
  } catch (_) {
    catalog = null;
  }

  if (pageUrl.isEmpty) {
    throw MetroClientException(
      'No metro.tehran.ir URL found in assets (link.txt / catalog.json)',
    );
  }

  return MetroClient(pageUrl: pageUrl, catalog: catalog);
}
