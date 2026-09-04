/// Models for the official metro.tehran.ir scheduler (ported from Python).
library;

class Station {
  final int id;
  final String name;

  const Station({required this.id, required this.name});

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['id'] is int ? json['id'] as int : int.parse('${json['id']}'),
      name: (json['name'] as String).trim(),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class RouteStep {
  final int order;
  final int line;
  final String time;
  final String station;

  const RouteStep({
    required this.order,
    required this.line,
    required this.time,
    required this.station,
  });
}

class OnlineRoute {
  final String title;
  final List<RouteStep> steps;
  final List<String> instructions;
  final bool isOffline;
  final int? totalMinutes;

  const OnlineRoute({
    required this.title,
    this.steps = const [],
    this.instructions = const [],
    this.isOffline = false,
    this.totalMinutes,
  });

  String? get departTime =>
      steps.isEmpty || isOffline || steps.first.time.trim().isEmpty
          ? null
          : steps.first.time;
  String? get arriveTime =>
      steps.isEmpty || isOffline || steps.last.time.trim().isEmpty
          ? null
          : steps.last.time;
  int get stationCount => steps.length;

  List<int> get lines {
    final seen = <int>[];
    for (final step in steps) {
      if (seen.isEmpty || seen.last != step.line) {
        seen.add(step.line);
      }
    }
    return seen;
  }
}

/// schedule_type: 1 = depart origin, 2 = arrive destination
class RouteQuery {
  final int fromStationId;
  final int toStationId;
  final int dayType;
  final int hour;
  final int minute;
  final int scheduleType;

  const RouteQuery({
    required this.fromStationId,
    required this.toStationId,
    required this.dayType,
    required this.hour,
    required this.minute,
    this.scheduleType = scheduleDepart,
  });

  static const int scheduleDepart = 1;
  static const int scheduleArrive = 2;
}

class Catalog {
  final int version;
  final String updatedAt;
  final String sourceUrl;
  final List<Station> stations;
  final Map<int, String> dayTypes;
  final Map<int, String> scheduleTypes;
  final List<int> hours;
  final List<int> minutes;
  final Map<String, String> formFields;

  const Catalog({
    this.version = 1,
    this.updatedAt = '',
    this.sourceUrl = '',
    this.stations = const [],
    this.dayTypes = const {},
    this.scheduleTypes = const {},
    this.hours = const [],
    this.minutes = const [],
    this.formFields = const {},
  });

  factory Catalog.fromJson(Map<String, dynamic> data) {
    final stations = (data['stations'] as List? ?? [])
        .map((e) => Station.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    Map<int, String> parseIntMap(dynamic raw) {
      final out = <int, String>{};
      if (raw is Map) {
        raw.forEach((k, v) {
          out[int.parse('$k')] = '$v';
        });
      }
      return out;
    }

    List<int> parseIntList(dynamic raw) {
      if (raw is! List) return [];
      return raw.map((e) => int.parse('$e')).toList();
    }

    Map<String, String> parseStringMap(dynamic raw) {
      final out = <String, String>{};
      if (raw is Map) {
        raw.forEach((k, v) {
          out['$k'] = '$v';
        });
      }
      return out;
    }

    return Catalog(
      version: int.tryParse('${data['version'] ?? 1}') ?? 1,
      updatedAt: '${data['updated_at'] ?? ''}',
      sourceUrl: '${data['source_url'] ?? ''}',
      stations: stations,
      dayTypes: parseIntMap(data['day_types']),
      scheduleTypes: parseIntMap(data['schedule_types']),
      hours: parseIntList(data['hours']),
      minutes: parseIntList(data['minutes']),
      formFields: parseStringMap(data['form_fields']),
    );
  }

  int get hourMin => hours.isEmpty ? 4 : hours.reduce((a, b) => a < b ? a : b);
  int get hourMax => hours.isEmpty ? 23 : hours.reduce((a, b) => a > b ? a : b);
}

class MetroClientException implements Exception {
  final String message;
  MetroClientException(this.message);

  @override
  String toString() => message;
}
