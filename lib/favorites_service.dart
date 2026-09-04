import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Represents a bookmarked favorite route
class FavoriteTrip {
  final String from;
  final String to;
  final String? label;

  const FavoriteTrip({required this.from, required this.to, this.label});

  Map<String, dynamic> toJson() => {'from': from, 'to': to, 'label': label};

  factory FavoriteTrip.fromJson(Map<String, dynamic> json) {
    return FavoriteTrip(
      from: json['from'] as String? ?? '',
      to: json['to'] as String? ?? '',
      label: json['label'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoriteTrip &&
          runtimeType == other.runtimeType &&
          from == other.from &&
          to == other.to;

  @override
  int get hashCode => from.hashCode ^ to.hashCode;
}

/// Service to persist and manage the user's favorite routes
class FavoritesService {
  static const String _fileName = 'favorite_trips.json';
  static final ValueNotifier<List<FavoriteTrip>> favoritesNotifier =
      ValueNotifier<List<FavoriteTrip>>([]);

  static File? _cachedFile;

  static Future<File> _getFile() async {
    if (_cachedFile != null) return _cachedFile!;
    final dir = await getApplicationDocumentsDirectory();
    _cachedFile = File('${dir.path}/$_fileName');
    return _cachedFile!;
  }

  /// Loads stored favorites from disk
  static Future<List<FavoriteTrip>> loadFavorites() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        favoritesNotifier.value = [];
        return [];
      }
      final contents = await file.readAsString();
      if (contents.trim().isEmpty) {
        favoritesNotifier.value = [];
        return [];
      }
      final List<dynamic> list = jsonDecode(contents);
      final favs = list
          .map((e) => FavoriteTrip.fromJson(e as Map<String, dynamic>))
          .where((t) => t.from.isNotEmpty && t.to.isNotEmpty)
          .toList();
      favoritesNotifier.value = favs;
      return favs;
    } catch (_) {
      favoritesNotifier.value = [];
      return [];
    }
  }

  /// Checks if a route is favorited
  static bool isFavorite(String from, String to) {
    final cleanFrom = from.trim();
    final cleanTo = to.trim();
    return favoritesNotifier.value.any(
      (f) => f.from == cleanFrom && f.to == cleanTo,
    );
  }

  /// Toggles favorite status for a station pair
  static Future<bool> toggleFavorite(String from, String to,
      {String? label}) async {
    final cleanFrom = from.trim();
    final cleanTo = to.trim();
    if (cleanFrom.isEmpty || cleanTo.isEmpty || cleanFrom == cleanTo) {
      return false;
    }

    final current = List<FavoriteTrip>.from(favoritesNotifier.value);
    final index =
        current.indexWhere((f) => f.from == cleanFrom && f.to == cleanTo);

    bool nowFavorited;
    if (index >= 0) {
      current.removeAt(index);
      nowFavorited = false;
    } else {
      current.insert(0, FavoriteTrip(from: cleanFrom, to: cleanTo, label: label));
      nowFavorited = true;
    }

    favoritesNotifier.value = current;

    try {
      final file = await _getFile();
      final jsonStr = jsonEncode(current.map((e) => e.toJson()).toList());
      await file.writeAsString(jsonStr);
    } catch (_) {}

    return nowFavorited;
  }
}
