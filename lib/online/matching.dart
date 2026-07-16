import 'models.dart';

/// Persian/Arabic character normalization map (ported from Python).
final Map<String, String> _normalizeMap = {
  'ك': 'ک',
  'ي': 'ی',
  'ى': 'ی',
  'ة': 'ه',
  'ؤ': 'و',
  'إ': 'ا',
  'أ': 'ا',
  'آ': 'ا',
  '\u200c': '', // ZWNJ
  '\u200d': '',
  '\u200e': '',
  '\u200f': '',
  ' ': '',
  '\t': '',
  '\n': '',
  '\r': '',
  'ـ': '',
  '(': '',
  ')': '',
  '،': '',
  ',': '',
  '٫': '',
  '.': '',
  '·': '',
  '-': '',
  '–': '',
  '—': '',
  '_': '',
  'ء': '',
  'ٔ': '',
  'ّ': '',
  'ً': '',
  'ٌ': '',
  'ٍ': '',
  'َ': '',
  'ُ': '',
  'ِ': '',
  'ْ': '',
};

final RegExp _noise = RegExp(
  r'(ایستگاه|ايستگاه|metro|station|شهید|شهيد|آیت\s*الله|آيت\s*الله|'
  r'امام|حضرت|میدان|ميدان|فلکه|فلكه)',
  caseSensitive: false,
);

String normalizeName(String name) {
  var text = name.trim();
  final buf = StringBuffer();
  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    buf.write(_normalizeMap[ch] ?? ch);
  }
  return buf.toString().toLowerCase();
}

String softNormalize(String name) {
  var text = normalizeName(name);
  text = text.replaceAll(_noise, '');
  return text;
}

/// Simple sequence similarity ratio (like difflib.SequenceMatcher.ratio).
double sequenceRatio(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1.0;
  if (a.isEmpty || b.isEmpty) return 0.0;
  final m = a.length;
  final n = b.length;
  // DP LCS length
  final prev = List<int>.filled(n + 1, 0);
  final curr = List<int>.filled(n + 1, 0);
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      if (a[i - 1] == b[j - 1]) {
        curr[j] = prev[j - 1] + 1;
      } else {
        curr[j] = prev[j] > curr[j - 1] ? prev[j] : curr[j - 1];
      }
    }
    for (var j = 0; j <= n; j++) {
      prev[j] = curr[j];
      curr[j] = 0;
    }
  }
  final lcs = prev[n];
  return (2.0 * lcs) / (m + n);
}

/// Best station match + suggestions.
class MatchResult {
  final Station? station;
  final List<StationScore> suggestions;
  MatchResult(this.station, this.suggestions);
}

class StationScore {
  final Station station;
  final double score;
  StationScore(this.station, this.score);
}

MatchResult matchStation(
  String query,
  List<Station> stations, {
  int limit = 5,
  double cutoff = 0.55,
}) {
  final q = query.trim();
  if (q.isEmpty) return MatchResult(null, []);

  final qn = normalizeName(q);
  final qs = softNormalize(q);

  final byNorm = <String, Station>{};
  for (final s in stations) {
    byNorm[normalizeName(s.name)] = s;
  }
  if (byNorm.containsKey(qn)) {
    final s = byNorm[qn]!;
    return MatchResult(s, [StationScore(s, 1.0)]);
  }

  final bySoft = <String, Station>{};
  for (final s in stations) {
    bySoft.putIfAbsent(softNormalize(s.name), () => s);
  }
  if (qs.isNotEmpty && bySoft.containsKey(qs)) {
    final s = bySoft[qs]!;
    return MatchResult(s, [StationScore(s, 0.98)]);
  }

  final contains = <StationScore>[];
  for (final s in stations) {
    final sn = normalizeName(s.name);
    final ss = softNormalize(s.name);
    if (qn.isNotEmpty && (sn.contains(qn) || qn.contains(sn))) {
      final score = 0.9 *
          (qn.length < sn.length ? qn.length : sn.length) /
          (qn.length > sn.length ? qn.length : sn.length).clamp(1, 9999);
      contains.add(StationScore(s, score < 0.75 ? 0.75 : score));
    } else if (qs.isNotEmpty && (ss.contains(qs) || qs.contains(ss))) {
      final score = 0.85 *
          (qs.length < ss.length ? qs.length : ss.length) /
          (qs.length > ss.length ? qs.length : ss.length).clamp(1, 9999);
      contains.add(StationScore(s, score < 0.7 ? 0.7 : score));
    }
  }
  if (contains.isNotEmpty) {
    contains.sort((a, b) {
      final c = b.score.compareTo(a.score);
      if (c != 0) return c;
      return a.station.name.length.compareTo(b.station.name.length);
    });
    return MatchResult(
      contains.first.station,
      contains.take(limit).toList(),
    );
  }

  final scored = <StationScore>[];
  for (final s in stations) {
    final sn = normalizeName(s.name);
    final ss = softNormalize(s.name);
    final r1 = sequenceRatio(qn, sn);
    final r2 = (qs.isNotEmpty && ss.isNotEmpty) ? sequenceRatio(qs, ss) : 0.0;
    final score = r1 > r2 ? r1 : r2;
    if (score >= cutoff) {
      scored.add(StationScore(s, score));
    }
  }
  scored.sort((a, b) {
    final c = b.score.compareTo(a.score);
    if (c != 0) return c;
    return a.station.name.compareTo(b.station.name);
  });
  if (scored.isEmpty) {
    final loose = <StationScore>[];
    for (final s in stations) {
      final sn = normalizeName(s.name);
      loose.add(StationScore(s, sequenceRatio(qn, sn)));
    }
    loose.sort((a, b) => b.score.compareTo(a.score));
    return MatchResult(null, loose.take(limit).toList());
  }
  return MatchResult(scored.first.station, scored.take(limit).toList());
}

/// Ranked suggestions for autocomplete.
List<Station> suggestStations(
  String query,
  List<Station> stations, {
  int limit = 12,
}) {
  final q = query.trim();
  if (q.isEmpty) {
    final sorted = List<Station>.from(stations)
      ..sort((a, b) => a.name.compareTo(b.name));
    return sorted.take(limit).toList();
  }

  final qn = normalizeName(q);
  final qs = softNormalize(q);
  final scored = <StationScore>[];

  for (final s in stations) {
    final sn = normalizeName(s.name);
    final ss = softNormalize(s.name);
    double score;
    if (sn == qn || (qs.isNotEmpty && ss == qs)) {
      score = 1.0;
    } else if (sn.startsWith(qn) || (qs.isNotEmpty && ss.startsWith(qs))) {
      score = 0.95;
    } else if (sn.contains(qn) || (qs.isNotEmpty && ss.contains(qs))) {
      score = 0.85;
    } else {
      final r1 = sequenceRatio(qn, sn);
      final r2 = (qs.isNotEmpty && ss.isNotEmpty) ? sequenceRatio(qs, ss) : 0.0;
      score = r1 > r2 ? r1 : r2;
      if (score < 0.4) continue;
    }
    scored.add(StationScore(s, score));
  }
  scored.sort((a, b) {
    final c = b.score.compareTo(a.score);
    if (c != 0) return c;
    return a.station.name.compareTo(b.station.name);
  });

  final out = <Station>[];
  final seen = <int>{};
  for (final item in scored) {
    if (seen.contains(item.station.id)) continue;
    seen.add(item.station.id);
    out.add(item.station);
    if (out.length >= limit) break;
  }
  return out;
}
