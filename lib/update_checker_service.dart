import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service to check for new app updates via remote config
class UpdateCheckerService {
  static const String currentVersion = '2.0.0';
  static bool _hasPromptedThisSession = false;

  /// Compares two semver strings: '2.1.0' vs '2.0.0'
  static bool isNewerVersion(String latest, String current) {
    try {
      final lParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final cParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (var i = 0; i < 3; i++) {
        final l = i < lParts.length ? lParts[i] : 0;
        final c = i < cParts.length ? cParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (_) {}
    return false;
  }

  /// Displays update dialog if remote config provides a higher version
  static void checkAndPrompt(
    BuildContext context, {
    required String? latestVersion,
    required String? updateUrl,
    String? updateMessage,
    bool force = false,
  }) {
    if (_hasPromptedThisSession && !force) return;
    if (latestVersion == null || latestVersion.isEmpty) return;

    if (isNewerVersion(latestVersion, currentVersion)) {
      _hasPromptedThisSession = true;
      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: !force,
        builder: (ctx) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.system_update_rounded,
                      color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  const Text('به‌روزرسانی متران', style: TextStyle(fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'نسخه جدید $latestVersion در دسترس است (نسخه فعلی: $currentVersion).',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    updateMessage ??
                        'برای دسترسی به جدیدترین خطوط و ایستگاه‌های مترو و بهبود سرعت مسیریابی، لطفا برنامه را به‌روزرسانی کنید.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
              ),
              actions: [
                if (!force)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('بعداً'),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final url = updateUrl ??
                        'https://cafebazaar.ir/app/com.mspco.metrun';
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: const Text('به‌روزرسانی اکنون'),
                ),
              ],
            ),
          );
        },
      );
    }
  }
}
