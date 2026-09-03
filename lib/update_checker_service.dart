import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service to check for new app updates via remote config
class UpdateCheckerService {
  static const String currentVersion = '2.0.0';
  static const Duration cooldownDuration = Duration(days: 3);
  static const String _fileName = 'update_state.json';

  static bool _hasPromptedThisSession = false;
  static File? _cachedFile;

  static Future<File> _getFile() async {
    if (_cachedFile != null) return _cachedFile!;
    final dir = await getApplicationDocumentsDirectory();
    _cachedFile = File('${dir.path}/$_fileName');
    return _cachedFile!;
  }

  /// Compares two semver strings: '2.1.0' vs '2.0.0'
  static bool isNewerVersion(String latest, String current) {
    try {
      final lParts =
          latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final cParts =
          current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (var i = 0; i < 3; i++) {
        final l = i < lParts.length ? lParts[i] : 0;
        final c = i < cParts.length ? cParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (_) {}
    return false;
  }

  /// Displays update dialog if remote config provides a higher version.
  /// Optional updates respect a 3-day cooldown and 1 prompt per session.
  /// Forced updates (min_version > currentVersion) bypass cooldown.
  static Future<void> checkAndPrompt(
    BuildContext context, {
    required String? latestVersion,
    String? minVersion,
    required String? updateUrl,
    String? updateMessage,
  }) async {
    if (latestVersion == null || latestVersion.isEmpty) return;

    // Check if current version is below minimum required version (Forced update)
    final bool isForce = minVersion != null &&
        minVersion.isNotEmpty &&
        isNewerVersion(minVersion, currentVersion);

    // Check if a newer version is available
    final bool hasNewer = isNewerVersion(latestVersion, currentVersion);
    if (!hasNewer && !isForce) return;

    // For optional updates, enforce 1 prompt per app session and 3-day cooldown
    if (!isForce) {
      if (_hasPromptedThisSession) return;

      try {
        final file = await _getFile();
        if (await file.exists()) {
          final content = await file.readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;
          final lastPromptMillis = data['last_prompt_millis'] as int?;
          if (lastPromptMillis != null) {
            final lastPrompt =
                DateTime.fromMillisecondsSinceEpoch(lastPromptMillis);
            if (DateTime.now().difference(lastPrompt) < cooldownDuration) {
              return; // Still in 3-day cooldown
            }
          }
        }
      } catch (_) {}
    }

    _hasPromptedThisSession = true;
    if (!context.mounted) return;

    // Record prompt timestamp for cooldown
    try {
      final file = await _getFile();
      await file.writeAsString(jsonEncode({
        'last_prompt_millis': DateTime.now().millisecondsSinceEpoch,
      }));
    } catch (_) {}

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: !isForce,
      builder: (ctx) {
        return PopScope(
          canPop: !isForce,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    isForce
                        ? Icons.warning_amber_rounded
                        : Icons.system_update_rounded,
                    color: isForce ? Colors.red.shade700 : Colors.orange.shade800,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isForce ? 'به‌روزرسانی ضروری متران' : 'به‌روزرسانی متران',
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'نسخه جدید $latestVersion در دسترس است (نسخه فعلی شما: $currentVersion).',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    updateMessage ??
                        (isForce
                            ? 'برای ادامه استفاده از متران و دریافت تغییرات جدید خطوط، باید برنامه را به‌روزرسانی کنید.'
                            : 'برای دسترسی به جدیدترین خطوط و ایستگاه‌های مترو و بهبود سرعت مسیریابی، لطفاً برنامه را به‌روزرسانی کنید.'),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
              ),
              actions: [
                if (!isForce)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('بعداً'),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isForce ? Colors.red.shade700 : Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    if (!isForce) Navigator.pop(ctx);
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
          ),
        );
      },
    );
  }
}
