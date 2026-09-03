import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Represents a previously searched station pair
class TripRecord {
  final String from;
  final String to;

  const TripRecord({required this.from, required this.to});

  Map<String, dynamic> toJson() => {'from': from, 'to': to};

  factory TripRecord.fromJson(Map<String, dynamic> json) {
    return TripRecord(
      from: json['from'] as String? ?? '',
      to: json['to'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripRecord &&
          runtimeType == other.runtimeType &&
          from == other.from &&
          to == other.to;

  @override
  int get hashCode => from.hashCode ^ to.hashCode;
}

/// Service to persist and retrieve the user's recent trips
class RecentTripsService {
  static const int maxRecentTrips = 8;
  static const String _fileName = 'recent_trips.json';

  static final ValueNotifier<List<TripRecord>> tripsNotifier =
      ValueNotifier<List<TripRecord>>([]);

  static File? _cachedFile;

  static Future<File> _getFile() async {
    if (_cachedFile != null) return _cachedFile!;
    final dir = await getApplicationDocumentsDirectory();
    _cachedFile = File('${dir.path}/$_fileName');
    return _cachedFile!;
  }

  /// Loads stored trips from disk
  static Future<List<TripRecord>> loadTrips() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        tripsNotifier.value = [];
        return [];
      }
      final contents = await file.readAsString();
      final List<dynamic> list = jsonDecode(contents);
      final trips = list
          .map((e) => TripRecord.fromJson(e as Map<String, dynamic>))
          .where((t) => t.from.isNotEmpty && t.to.isNotEmpty)
          .toList();
      tripsNotifier.value = trips;
      return trips;
    } catch (_) {
      tripsNotifier.value = [];
      return [];
    }
  }

  /// Adds a new trip to history (moves to front, deduplicates, caps at max limit)
  static Future<void> addTrip(String from, String to) async {
    final cleanFrom = from.trim();
    final cleanTo = to.trim();
    if (cleanFrom.isEmpty || cleanTo.isEmpty || cleanFrom == cleanTo) return;

    final newTrip = TripRecord(from: cleanFrom, to: cleanTo);
    final current = List<TripRecord>.from(tripsNotifier.value);

    // Remove if already exists to push to front
    current.removeWhere((t) => t.from == cleanFrom && t.to == cleanTo);
    current.insert(0, newTrip);

    if (current.length > maxRecentTrips) {
      current.removeRange(maxRecentTrips, current.length);
    }

    tripsNotifier.value = current;

    try {
      final file = await _getFile();
      final jsonStr = jsonEncode(current.map((e) => e.toJson()).toList());
      await file.writeAsString(jsonStr);
    } catch (_) {}
  }

  /// Clears recent trips
  static Future<void> clearTrips() async {
    tripsNotifier.value = [];
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
