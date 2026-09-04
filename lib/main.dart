import 'package:flutter/material.dart';
import 'package:adivery/adivery.dart';
import 'package:masiryab_metro/ad_config.dart';
import 'package:masiryab_metro/istgah_reader.dart';
import 'package:masiryab_metro/masiryab.dart';
import 'package:masiryab_metro/online/line_mapper.dart';
import 'package:masiryab_metro/online/models.dart';
import 'package:masiryab_metro/online/timeutil.dart';
import 'package:masiryab_metro/pair.dart';
import 'package:masiryab_metro/favorites_service.dart';
import 'package:masiryab_metro/persian_number_utility.dart';
import 'package:masiryab_metro/rating_prompt_service.dart';
import 'package:masiryab_metro/recent_trips_service.dart';
import 'package:masiryab_metro/route_service.dart';
import 'package:masiryab_metro/update_checker_service.dart';
import 'package:masiryab_metro/widget/auto_complete.dart';
import 'package:masiryab_metro/widget/banner_ad_widget.dart';
import 'package:masiryab_metro/widget/favorites_bar.dart';
import 'package:masiryab_metro/widget/native_ad_card.dart';
import 'package:masiryab_metro/app_theme.dart';
import 'package:masiryab_metro/widget/recent_trips_bar.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'متران',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const MyHomePage(title: 'متران'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final RouteService _routeService = RouteService(mode: RouteMode.auto);

  Set<String> _offlineOptions = {};
  Set<String> _onlineOptions = {};
  List<Pair<String, String>> _firstLastIstgah = [];

  TextEditingController mabda = TextEditingController();
  TextEditingController maghsad = TextEditingController();

  bool selected1 = false;
  bool selected2 = false;
  bool _loading = false;
  bool _serviceReady = false;

  RouteResult? _result;

  // Online query params (Tehran defaults)
  late int _dayType;
  late int _hour;
  late int _minute;
  int _scheduleType = RouteQuery.scheduleDepart;

  @override
  void initState() {
    super.initState();
    final now = nowTehran();
    _dayType = dayTypeForDateTime(now);
    final clamped = clampServiceHour(now.hour, now.minute);
    _hour = clamped[0];
    _minute = clamped[1];
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await AdConfig.init();
    if (AdConfig.isSupported && AdConfig.appKey.isNotEmpty) {
      AdiveryPlugin.initialize(AdConfig.appKey);
      AdConfig.fetchRemoteConfig();
    }
    final offlineReader = IstgahReader();
    final offline = await offlineReader.readStates();
    await RecentTripsService.loadTrips();
    await FavoritesService.loadFavorites();
    AdConfig.updateNotifier.addListener(_onRemoteUpdate);
    await _routeService.init();
    if (!mounted) return;
    setState(() {
      _offlineOptions = offline.first;
      _firstLastIstgah = offline.second;
      _onlineOptions = _routeService.onlineStationNames();
      _serviceReady = true;
    });
  }

  Set<String> get _activeOptions {
    if (_routeService.mode == RouteMode.offline) return _offlineOptions;
    if (_routeService.mode == RouteMode.online) {
      return _onlineOptions.isNotEmpty ? _onlineOptions : _offlineOptions;
    }
    // Auto: prefer online catalog if available
    if (_onlineOptions.isNotEmpty) {
      return {..._onlineOptions, ..._offlineOptions};
    }
    return _offlineOptions;
  }

  void assign1(TextEditingController c) => mabda = c;
  void assign2(TextEditingController c) => maghsad = c;

  void _onRemoteUpdate() {
    if (!mounted) return;
    UpdateCheckerService.checkAndPrompt(
      context,
      latestVersion: AdConfig.latestVersion,
      minVersion: AdConfig.minVersion,
      updateUrl: AdConfig.updateUrl,
      updateMessage: AdConfig.updateMessage,
    );
  }

  void _swapStations() {
    final temp = mabda.text;
    mabda.text = maghsad.text;
    maghsad.text = temp;
    if (mabda.text.isNotEmpty && maghsad.text.isNotEmpty) {
      selected1 = true;
      selected2 = true;
      getPath();
    }
  }

  void _selectRecentTrip(String from, String to) {
    mabda.text = from;
    maghsad.text = to;
    selected1 = true;
    selected2 = true;
    getPath();
  }

  void select1() {
    setState(() => selected1 = true);
    getPath();
  }

  void select2() {
    setState(() => selected2 = true);
    getPath();
  }

  Future<void> getPath() async {
    if (!selected1 || !selected2) return;
    if (mabda.text.isEmpty || maghsad.text.isEmpty) return;
    if (mabda.text == maghsad.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مبدا و مقصد یکسان است')),
      );
      return;
    }

    AdConfig.updateActiveFormat();
    setState(() {
      _loading = true;
      _result = null;
    });

    final result = await _routeService.findRoute(
      fromName: mabda.text,
      toName: maghsad.text,
      dayType: _dayType,
      hour: _hour,
      minute: _minute,
      scheduleType: _scheduleType,
    );

    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });

    if (result.hasData) {
      RecentTripsService.addTrip(mabda.text, maghsad.text);
      if (mounted) {
        RatingPromptService.recordSearchAndCheck(context);
      }
    }

    if (result.notice != null && result.fellBack) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.notice!)),
      );
    } else if (result.error != null && !result.hasData) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error!)),
      );
    }
  }

  Future<void> _showAboutDialog() async {
    final version = await UpdateCheckerService.getCurrentVersion();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_subway_rounded,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'متران (Metrun)',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'نسخه ${version.toPersianDigits()}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'مسیریاب هوشمند با در نظر گرفتن زمان‌بندی خطوط متروی تهران',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const Divider(height: 28),
                // Developer & Company Info
                const Row(
                  children: [
                    Icon(Icons.person_rounded, size: 20, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('توسعه‌دهنده: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                    Text('محمد صادق پولائی', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.business_rounded, size: 20, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('شرکت: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                    Text('فردیس سافت (FardisSoft)', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 16),
                // Telegram Account Link
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF229ED9),
                      side: const BorderSide(color: Color(0xFF229ED9)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text(
                      'ارتباط در تلگرام (@MSPoulaei)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      final uri = Uri.parse('https://t.me/MSPoulaei');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 14),
                // Rating buttons
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'حمایت و ثبت نظر:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: const Color(0x35E65100),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.star_rate_rounded, size: 20),
                    label: const Text('ثبت نظر و امتیاز به برنامه',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    onPressed: () => RatingPromptService.openStoreRating(context),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _useNow() {
    final now = nowTehran();
    final clamped = clampServiceHour(now.hour, now.minute);
    setState(() {
      _dayType = dayTypeForDateTime(now);
      _hour = clamped[0];
      _minute = clamped[1];
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) {
      setState(() {
        _hour = picked.hour;
        _minute = picked.minute;
      });
    }
  }

  Color getColorByKhat(int khat) => AppColors.getMetroLineColor(khat);

  void _openMap() {
    const photourl = 'assets/images/metro_map.jpg';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
              ),
              title: const Text('نقشه خطوط متروی تهران'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  tooltip: 'بستن',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            backgroundColor: Colors.white,
            body: SafeArea(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: Center(
                  child: Hero(
                    tag: photourl,
                    child: Image.asset(photourl),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    AdConfig.updateNotifier.removeListener(_onRemoteUpdate);
    _routeService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dayLabels = _routeService.dayTypes;
    final showOnlineControls = _routeService.mode != RouteMode.offline;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
          ),
        ),
        elevation: 2,
        shadowColor: const Color(0x25000000),
        titleSpacing: 12,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.directions_subway_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'متران',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  'مسیریاب هوشمند متروی تهران',
                  style: TextStyle(
                    color: Color(0xEEFFFFFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openMap,
            icon: const Icon(Icons.map_rounded, color: Colors.white),
            tooltip: 'نقشه مترو',
          ),
          IconButton(
            onPressed: _showAboutDialog,
            icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
            tooltip: 'درباره متران',
          ),
        ],
      ),
      body: !_serviceReady
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              AutocompleteBasic(
                                options: _activeOptions,
                                assign: assign1,
                                label: 'ایستگاه مبدا',
                                prefixIcon: const Icon(
                                  Icons.radio_button_checked_rounded,
                                  size: 20,
                                  color: AppColors.originStation,
                                ),
                                select: select1,
                              ),
                              const SizedBox(height: 10),
                              AutocompleteBasic(
                                options: _activeOptions,
                                assign: assign2,
                                label: 'ایستگاه مقصد',
                                prefixIcon: const Icon(
                                  Icons.location_on_rounded,
                                  size: 22,
                                  color: AppColors.destStation,
                                ),
                                select: select2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: AppColors.primaryContainer,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: _swapStations,
                            child: const Padding(
                              padding: EdgeInsets.all(10.0),
                              child: Icon(
                                Icons.swap_vert_rounded,
                                size: 26,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FavoritesBar(onSelectTrip: _selectRecentTrip),
                  RecentTripsBar(onSelectTrip: _selectRecentTrip),
                  if (showOnlineControls) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Day Type Dropdown
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.cardBorder),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: dayLabels.containsKey(_dayType)
                                        ? _dayType
                                        : dayLabels.keys.first,
                                    isDense: true,
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                                    items: dayLabels.entries
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e.key,
                                            child: Text(e.value,
                                                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) {
                                      if (v != null) setState(() => _dayType = v);
                                    },
                                  ),
                                ),
                              ),
                              const Spacer(),
                              // Time Picker Button
                              InkWell(
                                onTap: _pickTime,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryContainer,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.primaryBorder),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.access_time_filled_rounded,
                                          size: 16, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}'
                                            .toPersianDigits(),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // "الان" quick button
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  foregroundColor: AppColors.primary,
                                ),
                                onPressed: _useNow,
                                icon: const Icon(Icons.replay_rounded, size: 14),
                                label: const Text('الان',
                                    style: TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Departure vs Arrival Segmented Button
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<int>(
                              segments: const [
                                ButtonSegment<int>(
                                  value: RouteQuery.scheduleDepart,
                                  label: Text('زمان حرکت',
                                      style: TextStyle(fontSize: 12)),
                                  icon: Icon(Icons.directions_walk_rounded, size: 16),
                                  tooltip: 'ساعت حرکت از ایستگاه مبدا',
                                ),
                                ButtonSegment<int>(
                                  value: RouteQuery.scheduleArrive,
                                  label: Text('زمان رسیدن',
                                      style: TextStyle(fontSize: 12)),
                                  icon: Icon(Icons.flag_rounded, size: 16),
                                  tooltip: 'رسیدن به ایستگاه مقصد قبل از این ساعت',
                                ),
                              ],
                              selected: {_scheduleType},
                              onSelectionChanged: (newSelection) {
                                setState(() => _scheduleType = newSelection.first);
                              },
                              style: ButtonStyle(
                                visualDensity: VisualDensity.compact,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return AppColors.primary;
                                  }
                                  return AppColors.background;
                                }),
                                foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return Colors.white;
                                  }
                                  return AppColors.textSecondary;
                                }),
                                side: WidgetStateProperty.all(
                                  const BorderSide(color: AppColors.cardBorder),
                                ),
                                shape: WidgetStateProperty.all(
                                  RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x35E65100),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _loading
                          ? null
                          : () {
                              selected1 = true;
                              selected2 = true;
                              getPath();
                            },
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.search_rounded, color: Colors.white),
                      label: Text(
                        _loading ? 'در حال جستجو…' : 'جستجوی مسیر',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (_result?.notice != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _result!.notice!,
                        style: TextStyle(
                          color: _result!.fellBack
                              ? AppColors.primaryLight
                              : AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Expanded(child: _buildResultBody()),
                  ValueListenableBuilder<AdFormat>(
                    valueListenable: AdConfig.formatNotifier,
                    builder: (context, format, _) {
                      switch (format) {
                        case AdFormat.native:
                          return const NativeAdCard();
                        case AdFormat.banner:
                          return const AdiveryBannerWidget();
                        case AdFormat.none:
                          return const SizedBox.shrink();
                      }
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildResultBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final result = _result;
    if (result == null) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryBorder, width: 2),
                ),
                child: const Icon(
                  Icons.directions_subway_rounded,
                  size: 44,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'مبدا و مقصد را انتخاب کنید',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'ایستگاه مبدا و مقصد را انتخاب کنید تا کوتاه‌ترین و سریع‌ترین مسیر به همراه زمان‌بندی حرکت قطارها نمایش داده شود.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (!result.hasData) {
      return Center(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(result.error ?? 'مسیری یافت نشد'),
        ),
      );
    }

    if (result.source == RouteSource.online &&
        result.onlineRoutes != null &&
        result.onlineRoutes!.isNotEmpty) {
      return _buildOnlineResults(result);
    }

    if (result.offlineSteps != null && result.offlineSteps!.isNotEmpty) {
      return _buildOfflineResults(result.offlineSteps!);
    }

    return const SizedBox.shrink();
  }

  List<Color> _buildGradientColors(List<int> lines) {
    if (lines.isEmpty) {
      return const [AppColors.primary, AppColors.primaryLight];
    }
    final colors = lines.map(getColorByKhat).toList();
    if (colors.length == 1) {
      return [colors.first, colors.first];
    }
    return colors;
  }

  Widget _buildOnlineResults(RouteResult result) {
    final routes = result.onlineRoutes!;
    return ListView.builder(
      itemCount: routes.length,
      itemBuilder: (context, routeIndex) {
        final route = routes[routeIndex];
        // Resolve real metro lines from station names (CSS class ≠ metro line)
        final realLines = <int>[];
        for (final step in route.steps) {
          final rl = cssLineToMetroLine(step.line);
          if (realLines.isEmpty || realLines.last != rl) realLines.add(rl);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: _buildGradientColors(realLines),
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x18000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          route.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(blurRadius: 6, color: Colors.black54),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        ValueListenableBuilder<List<FavoriteTrip>>(
                          valueListenable: FavoritesService.favoritesNotifier,
                          builder: (context, _, __) {
                            final isFav = FavoritesService.isFavorite(
                                mabda.text, maghsad.text);
                            return IconButton(
                              icon: Icon(
                                isFav
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: isFav ? AppColors.favoriteStar : Colors.white,
                                size: 24,
                              ),
                              tooltip: isFav
                                  ? 'حذف از برگزیده‌ها'
                                  : 'افزودن به برگزیده‌ها',
                              onPressed: () {
                                FavoritesService.toggleFavorite(
                                    mabda.text, maghsad.text);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isFav
                                        ? 'از مسیرهای برگزیده حذف شد'
                                        : 'به مسیرهای برگزیده افزوده شد'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (route.departTime != null && route.arriveTime != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                route.departTime!.toPersianDigits(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              Text(
                                route.arriveTime!.toPersianDigits(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        else if (route.totalMinutes != null && route.totalMinutes! > 0)
                          Text(
                            'مدت تقریبی: ${route.totalMinutes} دقیقه'.toPersianDigits(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            ('(${route.stationCount} ایستگاه'
                                    '${realLines.isEmpty ? '' : '، خطوط ${realLines.join('، ')}'})')
                                .toPersianDigits(),
                            style: const TextStyle(
                              color: Color(0xEEFFFFFF),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ...List.generate(route.steps.length, (i) {
              final step = route.steps[i];
              final realLine = cssLineToMetroLine(step.line);
              final prevLine = i > 0
                  ? cssLineToMetroLine(route.steps[i - 1].line)
                  : null;
              final transfer = prevLine != null && prevLine != realLine;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  leading: CircleAvatar(
                    backgroundColor: getColorByKhat(realLine),
                    child: Text(
                      '$realLine',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    step.station,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
                  ),
                  subtitle: transfer
                      ? Row(
                          children: [
                            Text(
                              step.time.isNotEmpty
                                  ? '${step.time}  •  خط $realLine'
                                  : 'خط $realLine',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.transferBadgeBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.primaryBorder),
                              ),
                              child: const Text('تعویض خط', style: TextStyle(color: AppColors.transferBadgeText, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        )
                      : Text(
                          step.time.isNotEmpty
                              ? '${step.time}  •  خط $realLine'
                              : 'خط $realLine',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${step.order}'.toPersianDigits(),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              );
            }),
            if (route.instructions.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: route.instructions
                      .map((i) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('• $i', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ))
                      .toList(),
                ),
              ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildOfflineResults(List<Stepp> steps) {
    final head = steps[0];
    final min = head.min % 60;
    final hour = head.min ~/ 60;
    final khats = steps.sublist(1).map((e) => e.khat2!).toList();
    var text = 'مدت سفر: $min دقیقه';
    if (hour > 0) {
      text = 'مدت سفر: $hour ساعت و  $min دقیقه';
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: _buildGradientColors(khats),
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                text.toPersianDigits(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<List<FavoriteTrip>>(
                valueListenable: FavoritesService.favoritesNotifier,
                builder: (context, _, __) {
                  final isFav = FavoritesService.isFavorite(
                      mabda.text, maghsad.text);
                  return IconButton(
                    icon: Icon(
                      isFav
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: isFav ? AppColors.favoriteStar : Colors.white,
                      size: 26,
                    ),
                    tooltip: isFav
                        ? 'حذف از مسیرهای برگزیده'
                        : 'افزودن به مسیرهای برگزیده',
                    onPressed: () {
                      FavoritesService.toggleFavorite(
                          mabda.text, maghsad.text);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isFav
                              ? 'از مسیرهای برگزیده حذف شد'
                              : 'به مسیرهای برگزیده افزوده شد'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: steps.length,
            itemBuilder: (context, index) {
              final step = steps[index];
              if (index == 0) return const SizedBox.shrink();
              var lineText = '';

              if (step.to == null) {
                final nextStep = steps[index + 1];
                final nextindex =
                    nextStep.tavizkhat ? nextStep.index1! : nextStep.index2!;
                final diff = nextindex - step.index2!;
                final samt = diff > 0
                    ? _firstLastIstgah[step.khat2! - 1].second
                    : _firstLastIstgah[step.khat2! - 1].first;
                lineText =
                    'سوار مترو ایستگاه ${step.from!.name} شوید. (به سمت $samt)';
              } else if (step.from == null) {
                lineText = 'از مترو ایستگاه ${step.to!.name} پیاده شوید!';
              } else if (step.tavizkhat) {
                final nextStep = steps[index + 1];
                final nextindex =
                    nextStep.tavizkhat ? nextStep.index1! : nextStep.index2!;
                final diff = nextindex - step.index2!;
                final samt = diff > 0
                    ? _firstLastIstgah[step.khat2! - 1].second
                    : _firstLastIstgah[step.khat2! - 1].first;
                lineText =
                    'در ایستگاه ${step.from!.name}  از خط ${step.khat1} به ${step.khat2} تعویض خط انجام دهید. (به سمت $samt)';
              } else {
                lineText = '${step.from!.name} ← ${step.to!.name}';
              }

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: ListTile(
                    leading: !step.tavizkhat
                        ? CircleAvatar(
                            backgroundColor: getColorByKhat(step.khat2!),
                            child: Text(
                              step.min.toString(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  getColorByKhat(step.khat1!),
                                  getColorByKhat(step.khat1!),
                                  getColorByKhat(step.khat2!),
                                ],
                                begin: Alignment.centerRight,
                                end: Alignment.centerLeft,
                                stops: const [0.0, 0.5, 0.5],
                              ),
                            ),
                            child: CircleAvatar(
                              backgroundColor: Colors.transparent,
                              child: Text(
                                step.min.toString(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                    title: Text(lineText, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
