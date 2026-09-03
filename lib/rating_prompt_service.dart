import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service to politely prompt satisfied users to rate the app on Cafe Bazaar / Myket
class RatingPromptService {
  static const int promptThreshold = 4;
  static const String _fileName = 'rating_state.json';
  static const String packageName = 'com.fardissoft.metrun';

  static File? _cachedFile;

  static Future<File> _getFile() async {
    if (_cachedFile != null) return _cachedFile!;
    final dir = await getApplicationDocumentsDirectory();
    _cachedFile = File('${dir.path}/$_fileName');
    return _cachedFile!;
  }

  /// Records a successful search and triggers rating prompt when threshold is reached
  static Future<void> recordSearchAndCheck(BuildContext context) async {
    try {
      final file = await _getFile();
      Map<String, dynamic> state = {};
      if (await file.exists()) {
        final contents = await file.readAsString();
        state = jsonDecode(contents) as Map<String, dynamic>;
      }

      final bool hasRated = state['has_rated'] == true;
      if (hasRated) return;

      int searchCount = (state['search_count'] as int? ?? 0) + 1;
      state['search_count'] = searchCount;
      await file.writeAsString(jsonEncode(state));

      if (searchCount == promptThreshold && context.mounted) {
        _showRatingDialog(context, file, state);
      }
    } catch (_) {}
  }

  /// Opens Cafe Bazaar app page (or web fallback) and marks has_rated = true
  static Future<void> openCafeBazaar([BuildContext? context]) async {
    try {
      final file = await _getFile();
      Map<String, dynamic> state = {};
      if (await file.exists()) {
        state = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      }
      state['has_rated'] = true;
      await file.writeAsString(jsonEncode(state));
    } catch (_) {}

    final uri = Uri.parse('bazaar://details?id=$packageName');
    final webUri = Uri.parse('https://cafebazaar.ir/app/$packageName');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  /// Opens Myket app page (or web fallback) and marks has_rated = true
  static Future<void> openMyket([BuildContext? context]) async {
    try {
      final file = await _getFile();
      Map<String, dynamic> state = {};
      if (await file.exists()) {
        state = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      }
      state['has_rated'] = true;
      await file.writeAsString(jsonEncode(state));
    } catch (_) {}

    final uri = Uri.parse('myket://details?id=$packageName');
    final webUri = Uri.parse('https://myket.ir/app/$packageName');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  static void _showRatingDialog(
      BuildContext context, File file, Map<String, dynamic> state) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Icon(Icons.star_rounded, color: Colors.amber.shade600, size: 48),
                const SizedBox(height: 8),
                const Text(
                  'آیا از متران راضی هستید؟',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'نظر و امتیاز شما به توسعه و به‌روزرسانی مداوم خطوط و امکانات برنامه کمک می‌کند.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.star, size: 18),
                        label: const Text('امتیاز در کافه بازار'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          openCafeBazaar(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('امتیاز در مایکت'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          openMyket(context);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('بعداً یادآوری کن',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
