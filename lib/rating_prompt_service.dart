import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_theme.dart';

/// Service to politely prompt satisfied users to rate the app on the installed store
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
        if (contents.trim().isNotEmpty) {
          state = jsonDecode(contents) as Map<String, dynamic>;
        }
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

  /// Opens the market store app page using the standard Android market:// intent
  static Future<void> openStoreRating([BuildContext? context]) async {
    try {
      final file = await _getFile();
      Map<String, dynamic> state = {};
      if (await file.exists()) {
        final str = await file.readAsString();
        if (str.trim().isNotEmpty) {
          state = jsonDecode(str) as Map<String, dynamic>;
        }
      }
      state['has_rated'] = true;
      await file.writeAsString(jsonEncode(state));
    } catch (_) {}

    final uri = Uri.parse('market://details?id=$packageName');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
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
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Icon(Icons.star_rounded, color: AppColors.favoriteStar, size: 48),
                const SizedBox(height: 8),
                const Text(
                  'آیا از متران راضی هستید؟',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'نظر و امتیاز شما به توسعه و به‌روزرسانی مداوم خطوط و امکانات برنامه کمک می‌کند.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: const Color(0x35E65100),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.star_rounded, size: 20),
                    label: const Text(
                      'ثبت نظر و امتیاز به برنامه',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      openStoreRating(context);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('بعداً یادآوری کن',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
