import 'package:flutter/material.dart';
import 'package:adivery/adivery.dart';
import 'package:masiryab_metro/ad_config.dart';
import 'package:masiryab_metro/istgah_reader.dart';
import 'package:masiryab_metro/masiryab.dart';
import 'package:masiryab_metro/online/line_mapper.dart';
import 'package:masiryab_metro/online/models.dart';
import 'package:masiryab_metro/online/timeutil.dart';
import 'package:masiryab_metro/pair.dart';
import 'package:masiryab_metro/route_service.dart';
import 'package:masiryab_metro/widget/auto_complete.dart';
import 'package:masiryab_metro/widget/banner_ad_widget.dart';
import 'package:masiryab_metro/widget/native_ad_card.dart';

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

  void _setMode(RouteMode mode) {
    setState(() {
      _routeService.mode = mode;
      _result = null;
    });
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
          PopupMenuButton<RouteMode>(
            tooltip: 'حالت مسیر',
            icon: Icon(
              _routeService.mode == RouteMode.offline
                  ? Icons.cloud_off
                  : _routeService.mode == RouteMode.online
                      ? Icons.cloud_done
                      : Icons.cloud_sync,
              color: Colors.white,
            ),
            onSelected: _setMode,
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: RouteMode.auto,
                checked: _routeService.mode == RouteMode.auto,
                child: const Text('خودکار (آنلاین در صورت امکان)'),
              ),
              CheckedPopupMenuItem(
                value: RouteMode.online,
                checked: _routeService.mode == RouteMode.online,
                child: const Text('فقط آنلاین (رسمی)'),
              ),
              CheckedPopupMenuItem(
                value: RouteMode.offline,
                checked: _routeService.mode == RouteMode.offline,
                child: const Text('فقط آفلاین (تقریبی)'),
              ),
            ],
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
                  AutocompleteBasic(
                    options: _activeOptions,
                    assign: assign1,
                    lable: 'مبدا',
                    select: select1,
                  ),
                  AutocompleteBasic(
                    options: _activeOptions,
                    assign: assign2,
                    lable: 'مقصد',
                    select: select2,
                  ),
                  if (showOnlineControls) ...[
                    const SizedBox(height: 8),
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          DropdownButton<int>(
                            value: dayLabels.containsKey(_dayType)
                                ? _dayType
                                : dayLabels.keys.first,
                            items: dayLabels.entries
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(e.value, style: const TextStyle(fontSize: 13)),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _dayType = v);
                            },
                          ),
                          DropdownButton<int>(
                            value: _minute.clamp(0, 59),
                            items: List.generate(60, (i) => i)
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m,
                                    child: Text('$m'.padLeft(2, '0')),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _minute = v);
                            },
                          ),
                          const Text(':'),
                          DropdownButton<int>(
                            value: _hour,
                            items: List.generate(20, (i) => i + 4)
                                .map(
                                  (h) => DropdownMenuItem(
                                    value: h,
                                    child: Text('$h'.padLeft(2, '0')),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _hour = v);
                            },
                          ),
                          ChoiceChip(
                            label: const Text('حرکت از مبدا'),
                            selected: _scheduleType == RouteQuery.scheduleDepart,
                            onSelected: (_) {
                              setState(
                                  () => _scheduleType = RouteQuery.scheduleDepart);
                            },
                          ),
                          ChoiceChip(
                            label: const Text('رسیدن به مقصد'),
                            selected: _scheduleType == RouteQuery.scheduleArrive,
                            onSelected: (_) {
                              setState(
                                  () => _scheduleType = RouteQuery.scheduleArrive);
                            },
                          ),
                          TextButton.icon(
                            onPressed: _useNow,
                            icon: const Icon(Icons.access_time, size: 18),
                            label: const Text('الان'),
                          ),
                        ],
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
      return const Center(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Text('مبدا و مقصد را انتخاب کنید'),
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
                        const SizedBox(height: 4),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    route.departTime!,
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
                                      Icons.arrow_forward,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  Text(
                                    route.arriveTime!,
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
                              '(${route.stationCount} ایستگاه'
                              '${realLines.isEmpty ? '' : '، خطوط ${realLines.join('، ')}'})',
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
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
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
