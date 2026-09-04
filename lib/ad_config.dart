import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

/// Possible ad formats to display
enum AdFormat { none, native, banner }

/// Configuration and Dynamic Remote Control for Adivery Ad Network
class AdConfig {
  /// App Key from Adivery panel (loaded from assets/config/ads.json, --dart-define, or remote config)
  static String appKey =
      const String.fromEnvironment('ADIVERY_APP_KEY', defaultValue: '');

  /// Native Ad Placement ID
  static String nativePlacementId =
      const String.fromEnvironment('ADIVERY_NATIVE_ID', defaultValue: '');

  /// Banner Ad Placement ID
  static String bannerPlacementId =
      const String.fromEnvironment('ADIVERY_BANNER_ID', defaultValue: '');

  /// In-memory ad flags (defaults take effect instantly with 0ms startup delay)
  static bool nativeEnabled = true;
  static bool bannerEnabled = true;

  /// Reactive notifiers so UI components update live if remote config changes
  static final ValueNotifier<bool> bannerNotifier = ValueNotifier(true);
  static final ValueNotifier<bool> nativeNotifier = ValueNotifier(true);

  /// Current chosen ad format (dice roll if both are active)
  static AdFormat currentFormat = AdFormat.native;
  static final ValueNotifier<AdFormat> formatNotifier =
      ValueNotifier(AdFormat.native);

  /// Optional remote config endpoint (e.g., GitHub raw / Gist JSON).
  /// Set this in assets/config/ads.json or via remoteConfigUrl.
  static String? remoteConfigUrl;

  /// Optional app version update metadata from remote config
  static String? latestVersion;
  static String? minVersion;
  static String? updateUrl;
  static String? updateMessage;
  static final ValueNotifier<String?> updateNotifier = ValueNotifier(null);

  /// Only Android and iOS are supported by the Adivery mobile SDK
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Updates which ad format is shown.
  /// If BOTH native and banner are enabled, rolls a 50/50 dice to pick only ONE.
  static void updateActiveFormat() {
    if (!isSupported) {
      currentFormat = AdFormat.none;
    } else if (nativeEnabled && bannerEnabled) {
      // Both active: roll a 50/50 random dice
      currentFormat = Random().nextBool() ? AdFormat.native : AdFormat.banner;
    } else if (nativeEnabled) {
      currentFormat = AdFormat.native;
    } else if (bannerEnabled) {
      currentFormat = AdFormat.banner;
    } else {
      currentFormat = AdFormat.none;
    }
    formatNotifier.value = currentFormat;
    bannerNotifier.value = currentFormat == AdFormat.banner;
    nativeNotifier.value = currentFormat == AdFormat.native;
  }

  /// Loads local ad configuration from assets/config/ads.json if present.
  /// This file is ignored by git to keep your IDs private.
  static Future<void> init() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/config/ads.json');
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      if (data['app_key'] is String && (data['app_key'] as String).isNotEmpty) {
        appKey = data['app_key'];
      }
      if (data['native_placement_id'] is String &&
          (data['native_placement_id'] as String).isNotEmpty) {
        nativePlacementId = data['native_placement_id'];
      }
      if (data['banner_placement_id'] is String &&
          (data['banner_placement_id'] as String).isNotEmpty) {
        bannerPlacementId = data['banner_placement_id'];
      }
      if (data['native_enabled'] is bool) {
        nativeEnabled = data['native_enabled'];
      }
      if (data['banner_enabled'] is bool) {
        bannerEnabled = data['banner_enabled'];
      }
      if (data['remote_config_url'] is String &&
          (data['remote_config_url'] as String).isNotEmpty) {
        remoteConfigUrl = data['remote_config_url'];
      }
    } catch (_) {
      // Local config file is optional; falls back to defaults or dart-define
    }
    updateActiveFormat();
  }

  /// Non-blocking, simultaneous background fetch.
  ///
  /// - Runs completely in parallel without delaying the UI.
  /// - Times out quickly (3 seconds) to prevent hanging.
  /// - If successful, updates flags and placements live.
  /// - If offline, error, or timed out, silently falls back to defaults.
  static Future<void> fetchRemoteConfig({String? url}) async {
    final targetUrl = url ?? remoteConfigUrl;
    if (targetUrl == null || targetUrl.isEmpty) return;

    try {
      final response = await http
          .get(Uri.parse(targetUrl))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['app_key'] is String &&
            (data['app_key'] as String).isNotEmpty) {
          appKey = data['app_key'];
        }
        if (data['native_placement_id'] is String &&
            (data['native_placement_id'] as String).isNotEmpty) {
          nativePlacementId = data['native_placement_id'];
        }
        if (data['banner_placement_id'] is String &&
            (data['banner_placement_id'] as String).isNotEmpty) {
          bannerPlacementId = data['banner_placement_id'];
        }
        if (data.containsKey('banner_enabled')) {
          bannerEnabled = data['banner_enabled'] == true;
        }
        if (data.containsKey('native_enabled')) {
          nativeEnabled = data['native_enabled'] == true;
        }
        if (data['latest_version'] is String) {
          latestVersion = data['latest_version'];
        }
        if (data['min_version'] is String) {
          minVersion = data['min_version'];
        }
        if (data['update_url'] is String) {
          updateUrl = data['update_url'];
        }
        if (data['update_message'] is String) {
          updateMessage = data['update_message'];
        }
        if (latestVersion != null) {
          updateNotifier.value = latestVersion;
        }
        updateActiveFormat();
      }
    } catch (_) {
      // Silently ignore network failures and keep instant local defaults
    }
  }
}
