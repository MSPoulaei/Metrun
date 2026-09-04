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
      title: 'Metrun',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        useMaterial3: false,
      ),
      home: const MyHomePage(title: 'Metro Tehran Navigator'),
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
              color: Colors.white,
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
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_subway_rounded,
                    size: 48,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'متران (Metrun)',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'نسخه ${version.toPersianDigits()}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  'مسیریاب هوشمند با در نظر گرفتن زمان‌بندی خطوط متروی تهران',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const Divider(height: 28),
                // Developer & Company Info
                Row(
                  children: [
                    Icon(Icons.person_rounded, size: 20, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    const Text('توسعه‌دهنده: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const Text('محمد صادق پولائی', style: TextStyle(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.business_rounded, size: 20, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    const Text('شرکت: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const Text('فردیس سافت (FardisSoft)', style: TextStyle(fontSize: 13)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
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

  Color getColorByKhat(int khat) {
    switch (khat) {
      case 1:
        return const Color(0xffef2e25);
      case 2:
        return const Color(0xff04509f);
      case 3:
        return const Color(0xff18C0F5);
      case 4:
        return const Color(0xffFAD103);
      case 5:
        return const Color(0xff06885c);
      case 6:
        return const Color(0xfff670ab);
      case 7:
        return const Color(0xff85317a);
      default:
        return const Color(0xff9E9E9E);
    }
  }

  void _openMap() {
    const photourl = 'assets/images/metro_map.jpg';
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        barrierDismissible: false,
        pageBuilder: (BuildContext context, _, __) {
          return Scaffold(
            body: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.cancel_sharp),
                    ),
                  ),
                  Expanded(
                    child: InteractiveViewer(
                      scaleEnabled: true,
                      panEnabled: true,
                      child: Hero(
                        tag: photourl,
                        child: Center(child: Image.asset(photourl)),
                      ),
                    ),
                  ),
                ],
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
        title: Text(widget.title),
        backgroundColor: Colors.orange.shade600,
        actions: [
          IconButton(
            onPressed: _showAboutDialog,
            icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
            tooltip: 'درباره متران',
          ),
          IconButton(
            onPressed: _openMap,
            icon: const Icon(Icons.map, color: Colors.white),
            tooltip: 'نقشه مترو',
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
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                AutocompleteBasic(
                                  options: _activeOptions,
                                  assign: assign1,
                                  label: 'ایستگاه مبدا',
                                  prefixIcon: Icon(
                                    Icons.circle,
                                    size: 14,
                                    color: Colors.green.shade600,
                                  ),
                                  select: select1,
                                ),
                                const SizedBox(height: 8),
                                AutocompleteBasic(
                                  options: _activeOptions,
                                  assign: assign2,
                                  label: 'ایستگاه مقصد',
                                  prefixIcon: Icon(
                                    Icons.location_on,
                                    size: 18,
                                    color: Colors.red.shade600,
                                  ),
                                  select: select2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: Icon(
                              Icons.swap_vert_rounded,
                              size: 28,
                              color: Colors.orange.shade800,
                            ),
                            tooltip: 'جابجایی مبدا و مقصد',
                            onPressed: _swapStations,
                          ),
                        ],
                      ),
                    ),
                  ),
                  FavoritesBar(onSelectTrip: _selectRecentTrip),
                  RecentTripsBar(onSelectTrip: _selectRecentTrip),
                  if (showOnlineControls) ...[
                    const SizedBox(height: 6),
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x08000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                // Day Type Dropdown
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
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
                                                  style: const TextStyle(fontSize: 12)),
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
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange.shade300),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.access_time_filled_rounded,
                                            size: 16, color: Colors.orange.shade800),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}'
                                              .toPersianDigits(),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange.shade900,
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
                                    foregroundColor: Colors.orange.shade800,
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
                                  shape: WidgetStateProperty.all(
                                    RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _loading
                        ? null
                        : () {
                            selected1 = true;
                            selected2 = true;
                            getPath();
                          },
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(_loading ? 'در حال جستجو…' : 'جستجوی مسیر'),
                  ),
                  if (_result?.notice != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text(
                          _result!.notice!,
                          style: TextStyle(
                            color: _result!.fellBack
                                ? Colors.deepOrange
                                : Colors.grey.shade700,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
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
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.directions_subway_rounded,
                size: 64,
                color: Colors.orange.shade300,
              ),
              const SizedBox(height: 12),
              Text(
                'مبدا و مقصد را انتخاب کنید',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'می‌توانید نام ایستگاه را جستجو کرده یا از مسیرهای اخیر انتخاب کنید',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
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
      return const [Colors.orange, Colors.orange];
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
            if (route.departTime != null && route.arriveTime != null)
              Card(
                elevation: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    gradient: LinearGradient(
                      colors: _buildGradientColors(realLines),
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                    ),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
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
                                  Shadow(blurRadius: 4, color: Colors.black54),
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
                                    color: isFav ? Colors.amber : Colors.white,
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
                        const SizedBox(height: 4),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Directionality(
                              textDirection: TextDirection.rtl,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    route.departTime!.toPersianDigits(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(blurRadius: 4, color: Colors.black54),
                                      ],
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Icon(
                                      Icons.arrow_back_rounded,
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
                                      shadows: [
                                        Shadow(blurRadius: 4, color: Colors.black54),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              ('(${route.stationCount} ایستگاه'
                                      '${realLines.isEmpty ? '' : '، خطوط ${realLines.join('، ')}'})')
                                  .toPersianDigits(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                shadows: [
                                  Shadow(blurRadius: 4, color: Colors.black54),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ...List.generate(route.steps.length, (i) {
                      final step = route.steps[i];
                      final realLine = cssLineToMetroLine(step.line);
                      final prevLine = i > 0
                          ? cssLineToMetroLine(route.steps[i - 1].line)
                          : null;
                      final transfer = prevLine != null && prevLine != realLine;
                      return Card(
                        elevation: 4,
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: getColorByKhat(realLine),
                              child: Text(
                                '$realLine',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                            title: Text(step.station),
                            subtitle: Text(
                              transfer
                                  ? '${step.time}  •  خط $realLine  (تعویض خط)'
                                  : '${step.time}  •  خط $realLine',
                            ),
                            trailing: Text('${step.order}'),
                          ),
                        ),
                      );
                    }),
            if (route.instructions.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: route.instructions
                          .map((i) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('• $i'),
                              ))
                          .toList(),
                    ),
                  ),
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
        Card(
          elevation: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              gradient: LinearGradient(
                colors: _buildGradientColors(khats),
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    text.toPersianDigits(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
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
                          color: isFav ? Colors.amber : Colors.white,
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

              return Card(
                elevation: 6,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 1),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: ListTile(
                      leading: !step.tavizkhat
                          ? CircleAvatar(
                              backgroundColor: getColorByKhat(step.khat2!),
                              child: Text(
                                step.min.toString(),
                                style: const TextStyle(color: Colors.white),
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
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                      title: Text(lineText),
                    ),
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
