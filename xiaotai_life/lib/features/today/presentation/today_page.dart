import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/daily/xx_api_service.dart';
import '../../../core/data/app_data_store.dart';
import '../../../core/theme/app_theme_tokens.dart';
import '../../../core/weather/qweather_service.dart';
import '../../../shared/widgets/prototype_ui.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({this.weatherFuture, super.key});

  final Future<AppWeatherNow?>? weatherFuture;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> with WidgetsBindingObserver {
  late Future<AppWeatherNow?> _weatherFuture;
  late Future<AppLocalStore> _storeFuture;
  StreamSubscription<void>? _storeSubscription;
  List<AppWeeklyGoal>? _homeGoalsOverride;

  @override
  void initState() {
    super.initState();
    _weatherFuture =
        widget.weatherFuture ?? QWeatherService.instance.fetchNow();
    _storeFuture = AppLocalStore.create();
    WidgetsBinding.instance.addObserver(this);
    _storeSubscription = AppLocalStore.changes.listen((_) {
      if (mounted) {
        _refreshHomeData();
      }
    });
  }

  @override
  void dispose() {
    _storeSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshHomeData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: TextScaler.noScaling),
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const Positioned.fill(child: _HomeBackground()),
            SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding = constraints.maxWidth < 380
                      ? 12.0
                      : 14.0;
                  final bottomInset = MediaQuery.paddingOf(context).bottom;
                  final availableWidth = math.max(
                    0.0,
                    constraints.maxWidth - horizontalPadding * 2,
                  );
                  final contentWidth = math.min(availableWidth, 430.0);
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      0,
                      horizontalPadding,
                      bottomInset + 112,
                    ),
                    child: Center(
                      child: SizedBox(
                        width: contentWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _HomeHero(),
                            const SizedBox(height: 10),
                            _TopInfoCards(
                              storeFuture: _storeFuture,
                              onDiaryTap: () => context.push(AppRoutes.entries),
                              onReminderTap: () {
                                _refreshHomeData();
                                context.go(AppRoutes.reminder);
                              },
                              onAnniversaryTap: () =>
                                  context.push(AppRoutes.anniversary),
                            ),
                            const SizedBox(height: 12),
                            _WeatherGoalRow(
                              weatherFuture: _weatherFuture,
                              storeFuture: _storeFuture,
                              goalsOverride: _homeGoalsOverride,
                              onWeatherRefresh: _refreshWeather,
                              onWeatherDetails: _showWeatherDetails,
                              onGoalsTap: () =>
                                  context.push(AppRoutes.weeklyGoals),
                              onGoalCheckIn: _checkInHomeGoal,
                            ),
                            const SizedBox(height: 12),
                            _QuickCalendarRow(
                              onHotSearchTap: _showHotSearchSheet,
                              onHoroscopeTap: _showHoroscopeSheet,
                              onMoneyTap: () => context.push(AppRoutes.money),
                              onComicTap: () =>
                                  context.push(AppRoutes.dailyComic),
                              onAnniversaryTap: () =>
                                  context.push(AppRoutes.anniversary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _refreshWeather() {
    setState(() {
      _weatherFuture = QWeatherService.instance.fetchNow(
        forceLocationRefresh: true,
      );
    });
  }

  void _refreshHomeData() {
    setState(() {
      _storeFuture = AppLocalStore.create();
    });
  }

  void _showWeatherDetails(AppWeatherNow weather) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _WeatherDetailSheetV2(weather: weather),
    );
  }

  void _showHotSearchSheet() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HotSearchSheet(
        future: XxApiService.instance.fetchWeiboHot(limit: 10),
      ),
    );
  }

  void _showHoroscopeSheet() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HoroscopeSheet(
        future: XxApiService.instance.fetchHoroscope(type: 'cancer'),
      ),
    );
  }

  Future<void> _checkInHomeGoal(AppWeeklyGoal goal) async {
    final store = await _storeFuture;
    final currentGoals = store.getWeeklyGoals();
    final storedIndex = currentGoals.indexWhere((item) => item.id == goal.id);
    final source = storedIndex == -1 ? goal : currentGoals[storedIndex];
    final now = DateTime.now();
    final todayValue = source.progressForDate(now);
    final nextTodayValue = (todayValue + 1)
        .clamp(0, source.targetValue)
        .toDouble();
    final nextCurrentValue = (source.currentValue + 1)
        .clamp(0, source.targetValue)
        .toDouble();
    final updated = source
        .copyWith(
          id: source.id,
          currentValue: nextCurrentValue,
          lastCheckInDateKey: AppWeeklyGoal.dateKey(now),
        )
        .recordProgressForDate(now, nextTodayValue);
    await store.upsertWeeklyGoal(updated);
    if (!mounted) {
      return;
    }
    final refreshedGoals = store.getWeeklyGoals();
    setState(() {
      _homeGoalsOverride = refreshedGoals;
      _storeFuture = Future.value(store);
    });
    _showCenteredSnack(
      '已打卡：${updated.title} ${_homeGoalPeriodLabel(updated.period)} ${_formatHomeGoalValue(_homeGoalPeriodValue(updated, now))}/${_formatHomeGoalValue(updated.targetValue)}',
    );
  }

  void _showCenteredSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message, textAlign: TextAlign.center),
        ),
      );
  }
}

class _HomePalette {
  const _HomePalette._();

  static const ink = Color(0xFF10152F);
  static const text = Color(0xFF1A1D2E);
  static const subText = Color(0xFF787A8A);
  static const purple = Color(0xFF9B70F1);
  static const purpleDeep = Color(0xFF7F55DA);
  static const pink = Color(0xFFFF5A93);
  static const orange = Color(0xFFE66B3A);
  static const green = Color(0xFF41B86B);
  static const blue = Color(0xFF5EA7FF);
  static const yellow = Color(0xFFFFC857);
  static const weatherBlue = Color(0xFFE9F4FF);
}

class _HomeBackground extends StatelessWidget {
  const _HomeBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x12FFFFFF),
            Color(0x0AFFF7FB),
            Color(0x08FFFFFF),
            Color(0x10F8F6FF),
          ],
          stops: [0, .18, .42, 1],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero();

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    return SizedBox(
      height: 116,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 24,
            left: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Hi， 小可爱',
                      style: TextStyle(
                        color: _HomePalette.ink,
                        fontSize: 24,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    CustomPaint(
                      size: const Size(20, 20),
                      painter: _PlusSparkPainter(
                        color: const Color(0xFFFFB5C9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '今天也要好好照顾自己呀~',
                  style: TextStyle(
                    color: _HomePalette.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 6,
            right: 48,
            width: 122,
            height: 108,
            child: Image.asset(
              tokens.assets.homeMascot,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              errorBuilder: (context, error, stackTrace) {
                return CustomPaint(painter: _HeroBearPainter());
              },
            ),
          ),
          Positioned(
            top: 50,
            right: 22,
            child: CustomPaint(
              size: const Size(18, 18),
              painter: _StarPainter(color: const Color(0xFFFF99BE)),
            ),
          ),
          Positioned(
            top: 82,
            right: 132,
            child: CustomPaint(
              size: const Size(18, 18),
              painter: _StarPainter(color: const Color(0xFFFF99BE)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopInfoCards extends StatelessWidget {
  const _TopInfoCards({
    required this.storeFuture,
    required this.onDiaryTap,
    required this.onReminderTap,
    required this.onAnniversaryTap,
  });

  final Future<AppLocalStore> storeFuture;
  final VoidCallback onDiaryTap;
  final VoidCallback onReminderTap;
  final VoidCallback onAnniversaryTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 370;
        return FutureBuilder<AppLocalStore>(
          future: storeFuture,
          builder: (context, snapshot) {
            final store = snapshot.data;
            final entries = [...(store?.getEntries() ?? const <AppEntry>[])]
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            final reminders = store?.getReminders() ?? const <AppReminder>[];
            final anniversaries =
                store?.getAnniversaries() ?? const <AppAnniversary>[];
            return SizedBox(
              height: narrow ? 264 : 256,
              child: Column(
                children: [
                  SizedBox(
                    height: narrow ? 130 : 122,
                    child: Row(
                      children: [
                        Expanded(
                          child: _ReminderMiniCard(
                            reminders: reminders,
                            onTap: onReminderTap,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _AnniversaryMiniCard(
                            anniversaries: anniversaries,
                            onTap: onAnniversaryTap,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _RecentDiaryCard(
                      entry: entries.isEmpty ? null : entries.first,
                      onTap: onDiaryTap,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _RecentDiaryCard extends StatelessWidget {
  const _RecentDiaryCard({required this.entry, required this.onTap});

  final AppEntry? entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 300;
        final current = entry;
        final preview = current == null
            ? null
            : (current.content.trim().isEmpty
                  ? current.title.trim()
                  : current.content.trim());
        return _HomeCard(
          onTap: onTap,
          padding: EdgeInsets.fromLTRB(14, 13, wide ? 13 : 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: _CardTitle('最近日记')),
                  _AllLink(onTap: onTap),
                ],
              ),
              const Spacer(),
              if (current == null)
                const _MiniEmptyText('还没有日记记录')
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preview!.isEmpty ? current.title : preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: wide ? 13 : 11.3,
                              height: wide ? 1.45 : 1.45,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ),
                          SizedBox(height: wide ? 11 : 10),
                          _DateMeta(
                            text: _formatHomeDateTime(current.createdAt),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: wide ? 12 : 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.asset(
                        'assets/mascot/source/place_default.webp',
                        width: wide ? 72 : 52,
                        height: wide ? 72 : 52,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniEmptyText extends StatelessWidget {
  const _MiniEmptyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _HomePalette.subText,
            fontSize: 12,
            height: 1.35,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _ReminderMiniCard extends StatelessWidget {
  const _ReminderMiniCard({required this.reminders, required this.onTap});

  final List<AppReminder> reminders;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final todayReminders = _homeTodayReminders(reminders, DateTime.now());
    final visible = todayReminders.take(2).toList(growable: false);
    return _HomeCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(9, 13, 7, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: _CardTitle('今日提醒', fontSize: 13.5),
                ),
              ),
              Text(
                '全部(${todayReminders.length})',
                style: const TextStyle(
                  color: _HomePalette.orange,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (visible.isEmpty)
            const _MiniEmptyText('今天暂无提醒')
          else
            for (var index = 0; index < visible.length; index++) ...[
              _ReminderLine(
                time: _formatHomeReminderTime(visible[index].scheduledAt),
                title: visible[index].title,
              ),
              if (index != visible.length - 1) const SizedBox(height: 13),
            ],
        ],
      ),
    );
  }
}

class _ReminderLine extends StatelessWidget {
  const _ReminderLine({required this.time, required this.title});

  final String time;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 20,
          padding: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1E9FF),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: _HomePalette.purple,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                time,
                style: const TextStyle(
                  color: _HomePalette.purpleDeep,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 3),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnniversaryMiniCard extends StatelessWidget {
  const _AnniversaryMiniCard({
    required this.anniversaries,
    required this.onTap,
  });

  final List<AppAnniversary> anniversaries;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final anniversary = _homePrimaryAnniversary(anniversaries, now);
    final countUp = anniversary?.showCountUp ?? false;
    final days = anniversary == null
        ? 0
        : (countUp ? anniversary.daysPassed(now) : anniversary.daysLeft(now));
    return _HomeCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(10, 13, 7, 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CardTitle('纪念日'),
              const SizedBox(height: 12),
              if (anniversary == null)
                const _MiniEmptyText('还没有纪念日')
              else ...[
                Text(
                  anniversary.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                _AnniversaryDays(days: days, suffix: countUp ? '天' : '天后'),
                const Spacer(),
                _DateMeta(
                  text: _formatHomeDate(anniversary.date),
                  dotColor: _HomePalette.pink,
                ),
              ],
            ],
          ),
          Positioned(
            right: -3,
            bottom: -5,
            width: 42,
            height: 40,
            child: CustomPaint(painter: _HeartPainter()),
          ),
        ],
      ),
    );
  }
}

class _AnniversaryDays extends StatelessWidget {
  const _AnniversaryDays({required this.days, required this.suffix});

  final int days;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            days.toString(),
            style: const TextStyle(
              color: _HomePalette.pink,
              fontSize: 30,
              height: .9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              suffix,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<AppReminder> _homeTodayReminders(
  List<AppReminder> reminders,
  DateTime now,
) {
  return reminders.where((reminder) {
    if (reminder.completed || reminder.isDoneForDate(now)) {
      return false;
    }
    if (_sameHomeDay(reminder.scheduledAt, now)) {
      return true;
    }
    return _repeatReminderOccursToday(reminder, now);
  }).toList()..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
}

AppAnniversary? _homePrimaryAnniversary(
  List<AppAnniversary> anniversaries,
  DateTime now,
) => selectHomeAnniversary(anniversaries, now);

bool _sameHomeDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

bool _repeatReminderOccursToday(AppReminder reminder, DateTime now) {
  if (reminder.repeatRule == 'none') {
    return false;
  }
  final today = DateTime(now.year, now.month, now.day);
  final startDay = DateTime(
    reminder.scheduledAt.year,
    reminder.scheduledAt.month,
    reminder.scheduledAt.day,
  );
  if (startDay.isAfter(today)) {
    return false;
  }
  return switch (reminder.repeatRule) {
    'daily' => true,
    'weekly' => reminder.scheduledAt.weekday == now.weekday,
    'monthly' => reminder.scheduledAt.day == now.day,
    _ => false,
  };
}

String _formatHomeTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatHomeReminderTime(DateTime value) {
  return '今天 ${_formatHomeTime(value)}';
}

String _formatHomeDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}.$month.$day';
}

String _formatHomeDateTime(DateTime value) {
  if (_sameHomeDay(value, DateTime.now())) {
    return '今天 ${_formatHomeTime(value)}';
  }
  return '${_formatHomeDate(value)} · ${_formatHomeTime(value)}';
}

class _WeatherGoalRow extends StatelessWidget {
  const _WeatherGoalRow({
    required this.weatherFuture,
    required this.storeFuture,
    required this.goalsOverride,
    required this.onWeatherRefresh,
    required this.onWeatherDetails,
    required this.onGoalsTap,
    required this.onGoalCheckIn,
  });

  final Future<AppWeatherNow?> weatherFuture;
  final Future<AppLocalStore> storeFuture;
  final List<AppWeeklyGoal>? goalsOverride;
  final VoidCallback onWeatherRefresh;
  final ValueChanged<AppWeatherNow> onWeatherDetails;
  final VoidCallback onGoalsTap;
  final ValueChanged<AppWeeklyGoal> onGoalCheckIn;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 156,
      child: Row(
        children: [
          Expanded(
            flex: 184,
            child: _WeatherCardGlass(
              weatherFuture: weatherFuture,
              onRefresh: onWeatherRefresh,
              onDetails: onWeatherDetails,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 196,
            child: _GoalCard(
              storeFuture: storeFuture,
              goalsOverride: goalsOverride,
              onTap: onGoalsTap,
              onCheckIn: onGoalCheckIn,
            ),
          ),
        ],
      ),
    );
  }
}

class WeatherCardV2Legacy extends StatelessWidget {
  const WeatherCardV2Legacy({
    required this.weatherFuture,
    required this.onRefresh,
    required this.onDetails,
    super.key,
  });

  final Future<AppWeatherNow?> weatherFuture;
  final VoidCallback onRefresh;
  final ValueChanged<AppWeatherNow> onDetails;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppWeatherNow?>(
      future: weatherFuture,
      builder: (context, snapshot) {
        final weather = snapshot.data;
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final temp = weather?.temp ?? '--';
        final weatherText = weather?.text ?? (loading ? '加载中' : '暂无天气');
        final city = weather?.cityName ?? '未定位';
        final feelsLike = weather?.feelsLike ?? '--';
        final humidity = weather?.humidity ?? '--';
        final advice = weather == null
            ? null
            : _WeatherLifeAdvice.from(weather);
        return InkWell(
          borderRadius: BorderRadius.circular(23),
          onTap: weather == null ? onRefresh : () => onDetails(weather),
          child: Container(
            padding: const EdgeInsets.fromLTRB(15, 12, 12, 10),
            decoration: BoxDecoration(
              color: _HomePalette.weatherBlue,
              borderRadius: BorderRadius.circular(23),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120C3F77),
                  blurRadius: 26,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: -10,
                  top: 35,
                  width: 78,
                  height: 60,
                  child: CustomPaint(painter: _WeatherCloudPainter()),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _CardTitle('今日天气'),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          temp,
                          style: const TextStyle(
                            color: Color(0xFF3F4653),
                            fontSize: 34,
                            height: .92,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text(
                            '°C',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$weatherText | 体感 $feelsLike°',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: Colors.black,
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (advice == null)
                      const _WeatherMiniChip(
                        icon: Icons.refresh_rounded,
                        label: '点我刷新天气',
                      )
                    else
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          _WeatherMiniChip(
                            icon: Icons.checkroom_outlined,
                            label: advice.clothing,
                          ),
                          _WeatherMiniChip(
                            icon: Icons.umbrella_outlined,
                            label: advice.outing,
                          ),
                          _WeatherMiniChip(
                            icon: Icons.water_drop_outlined,
                            label: '湿度 $humidity%',
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WeatherCardGlass extends StatelessWidget {
  const _WeatherCardGlass({
    required this.weatherFuture,
    required this.onRefresh,
    required this.onDetails,
  });

  final Future<AppWeatherNow?> weatherFuture;
  final VoidCallback onRefresh;
  final ValueChanged<AppWeatherNow> onDetails;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppWeatherNow?>(
      future: weatherFuture,
      builder: (context, snapshot) {
        final weather = snapshot.data;
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final temp = weather?.temp ?? '--';
        final weatherText = weather?.text ?? (loading ? '加载中' : '暂无天气');
        final city = weather?.cityName ?? '未定位';
        final feelsLike = weather?.feelsLike ?? '--';
        final humidity = weather?.humidity ?? '--';
        final advice = weather == null
            ? null
            : _WeatherLifeAdvice.from(weather);
        return InkWell(
          borderRadius: BorderRadius.circular(23),
          onTap: weather == null ? onRefresh : () => onDetails(weather),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 11, 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .22),
                  borderRadius: BorderRadius.circular(23),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .72),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: .34),
                      _HomePalette.weatherBlue.withValues(alpha: .18),
                      Colors.white.withValues(alpha: .12),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _HomePalette.blue.withValues(alpha: .10),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _CardTitle('今日天气'),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              temp,
                              style: const TextStyle(
                                color: Color(0xFF3F4653),
                                fontSize: 28,
                                height: .9,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Text(
                                '°C',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$weatherText | 体感 $feelsLike°',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: Colors.black,
                              size: 13,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                city,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (advice == null)
                          const _WeatherAdviceLine(
                            icon: Icons.refresh_rounded,
                            text: '点我刷新天气',
                          )
                        else ...[
                          _WeatherAdviceLine(
                            icon: Icons.checkroom_outlined,
                            text: '${advice.clothing} · ${advice.outing}',
                          ),
                          const SizedBox(height: 3),
                          _WeatherAdviceLine(
                            icon: Icons.water_drop_outlined,
                            text: '湿度 $humidity% · ${advice.wind}',
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WeatherAdviceLine extends StatelessWidget {
  const _WeatherAdviceLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .58),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .74)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _HomePalette.green, size: 12),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _HomePalette.text,
                fontSize: 10,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherMiniChip extends StatelessWidget {
  const _WeatherMiniChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 94),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .72)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _HomePalette.green, size: 12),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _HomePalette.text,
                fontSize: 10.5,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherLifeAdvice {
  const _WeatherLifeAdvice({
    required this.clothing,
    required this.outing,
    required this.wind,
    required this.comfort,
  });

  final String clothing;
  final String outing;
  final String wind;
  final String comfort;

  static _WeatherLifeAdvice from(AppWeatherNow weather) {
    final temp = _weatherInt(weather.temp);
    final feelsLike = _weatherInt(weather.feelsLike) ?? temp;
    final humidity = _weatherInt(weather.humidity);
    final windScale = _weatherInt(weather.windScale);
    final text = weather.text;
    final rainy = text.contains('雨') || text.contains('雪');
    final sunny = text.contains('晴');
    final clothing = switch (feelsLike) {
      null => '按体感穿',
      <= 8 => '厚外套',
      <= 15 => '薄毛衣',
      <= 22 => '长袖刚好',
      <= 28 => '短袖轻薄',
      _ => '清凉防晒',
    };
    final outing = rainy
        ? '记得带伞'
        : sunny
        ? '注意防晒'
        : '适合出门';
    final wind = windScale == null
        ? '${weather.windDir}风'
        : windScale >= 4
        ? '风大慢行'
        : '${weather.windScale}级微风';
    final comfort = humidity == null
        ? '体感留意'
        : humidity >= 75
        ? '偏潮湿'
        : humidity <= 35
        ? '多喝水'
        : '体感舒适';
    return _WeatherLifeAdvice(
      clothing: clothing,
      outing: outing,
      wind: wind,
      comfort: comfort,
    );
  }
}

int? _weatherInt(String value) {
  return int.tryParse(value.replaceAll(RegExp(r'[^0-9-]'), ''));
}

class WeatherCardLegacy extends StatelessWidget {
  const WeatherCardLegacy({
    required this.weatherFuture,
    required this.onRefresh,
    required this.onDetails,
    super.key,
  });

  final Future<AppWeatherNow?> weatherFuture;
  final VoidCallback onRefresh;
  final ValueChanged<AppWeatherNow> onDetails;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppWeatherNow?>(
      future: weatherFuture,
      builder: (context, snapshot) {
        final weather = snapshot.data;
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final temp = weather?.temp ?? '--';
        final weatherText = weather?.text ?? (loading ? '加载中' : '暂无天气');
        final city = weather?.cityName ?? '未定位';
        final feelsLike = weather?.feelsLike ?? '--';
        final humidity = weather?.humidity ?? '--';
        return InkWell(
          borderRadius: BorderRadius.circular(23),
          onTap: weather == null ? onRefresh : () => onDetails(weather),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 13, 14, 10),
            decoration: BoxDecoration(
              color: _HomePalette.weatherBlue,
              borderRadius: BorderRadius.circular(23),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120C3F77),
                  blurRadius: 26,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: 0,
                  top: 38,
                  width: 88,
                  height: 68,
                  child: CustomPaint(painter: _WeatherCloudPainter()),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _CardTitle('今日天气'),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          temp,
                          style: const TextStyle(
                            color: Color(0xFF3F4653),
                            fontSize: 36,
                            height: .95,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Text(
                            '°C',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$weatherText  |  体感 $feelsLike°',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '湿度 $humidity%',
                      style: const TextStyle(
                        color: Color(0xFF79C99B),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: Colors.black,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.storeFuture,
    required this.goalsOverride,
    required this.onTap,
    required this.onCheckIn,
  });

  final Future<AppLocalStore> storeFuture;
  final List<AppWeeklyGoal>? goalsOverride;
  final VoidCallback onTap;
  final ValueChanged<AppWeeklyGoal> onCheckIn;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppLocalStore>(
      future: storeFuture,
      builder: (context, snapshot) {
        final storedGoals =
            goalsOverride ??
            snapshot.data?.getWeeklyGoals() ??
            const <AppWeeklyGoal>[];
        final goals = _homeGoalItems(storedGoals);
        final now = DateTime.now();
        return _HomeCard(
          onTap: onTap,
          padding: const EdgeInsets.fromLTRB(12, 12, 11, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '小目标',
                      style: TextStyle(
                        color: _HomePalette.green,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  _AllLink(onTap: onTap),
                ],
              ),
              const SizedBox(height: 9),
              if (goals.isEmpty)
                const _GoalEmptyPrompt()
              else
                for (var index = 0; index < goals.length; index++) ...[
                  _GoalLine(
                    icon: _goalIcon(goals[index].iconName),
                    iconColor: _goalColor(goals[index].colorName),
                    iconBg: _goalColor(
                      goals[index].colorName,
                    ).withValues(alpha: .16),
                    title: goals[index].title,
                    trailing: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onCheckIn(goals[index]),
                      child: _GoalProgress(
                        value: _homeGoalPeriodProgress(goals[index], now),
                        color: _goalColor(goals[index].colorName),
                      ),
                    ),
                    value:
                        '${_homeGoalPeriodLabel(goals[index].period)} ${_formatHomeGoalValue(_homeGoalPeriodValue(goals[index], now))}/${_formatHomeGoalValue(goals[index].targetValue)}',
                  ),
                  if (index != goals.length - 1) const SizedBox(height: 8),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _GoalEmptyPrompt extends StatelessWidget {
  const _GoalEmptyPrompt();

  @override
  Widget build(BuildContext context) {
    return const Expanded(
      child: Center(
        child: Text(
          '还没有小目标',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _HomePalette.subText,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _GoalLine extends StatelessWidget {
  const _GoalLine({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.trailing,
    this.value,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final Widget trailing;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 14.5),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 4),
        trailing,
        if (value != null) ...[
          const SizedBox(width: 4),
          Text(
            value!,
            style: const TextStyle(
              color: _HomePalette.subText,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _GoalProgress extends StatelessWidget {
  const _GoalProgress({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          minHeight: 5,
          value: value,
          color: color,
          backgroundColor: color.withValues(alpha: .18),
        ),
      ),
    );
  }
}

List<AppWeeklyGoal> _homeGoalItems(List<AppWeeklyGoal> storedGoals) {
  final now = DateTime.now();
  final sorted = [...storedGoals]
    ..sort((a, b) {
      final aDone = _homeGoalPeriodProgress(a, now) >= 1;
      final bDone = _homeGoalPeriodProgress(b, now) >= 1;
      if (aDone != bDone) {
        return aDone ? 1 : -1;
      }
      return a.title.compareTo(b.title);
    });
  return sorted.take(3).toList(growable: false);
}

String _homeGoalPeriodLabel(String period) {
  return switch (period) {
    'day' => '今日',
    'month' => '本月',
    _ => '本周',
  };
}

double _homeGoalPeriodValue(AppWeeklyGoal goal, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  double sumWhere(bool Function(DateTime date) test) {
    var total = 0.0;
    for (final entry in goal.dailyProgress.entries) {
      final date = DateTime.tryParse(entry.key);
      if (date != null && test(date)) {
        total += entry.value;
      }
    }
    return total;
  }

  final value = switch (goal.period) {
    'day' => goal.progressForDate(today),
    'month' => sumWhere(
      (date) => date.year == today.year && date.month == today.month,
    ),
    _ => sumWhere((date) {
      final normalized = DateTime(date.year, date.month, date.day);
      final diff = today.difference(normalized).inDays;
      return diff >= 0 && diff < 7;
    }),
  };
  return value <= 0 && goal.dailyProgress.isEmpty ? goal.currentValue : value;
}

double _homeGoalPeriodProgress(AppWeeklyGoal goal, DateTime now) {
  if (goal.targetValue <= 0) {
    return 0;
  }
  return (_homeGoalPeriodValue(goal, now) / goal.targetValue)
      .clamp(0, 1)
      .toDouble();
}

IconData _goalIcon(String iconName) {
  return switch (iconName) {
    'water' => Icons.local_drink_rounded,
    'read' || 'book' => Icons.menu_book_rounded,
    'sport' || 'run' => Icons.fitness_center_rounded,
    'sleep' => Icons.dark_mode_rounded,
    'study' => Icons.school_rounded,
    'write' => Icons.edit_note_rounded,
    'food' => Icons.restaurant_rounded,
    'heart' => Icons.favorite_rounded,
    _ => Icons.track_changes_rounded,
  };
}

Color _goalColor(String colorName) {
  return switch (colorName) {
    'blue' => _HomePalette.blue,
    'orange' => _HomePalette.orange,
    'purple' => _HomePalette.purple,
    'green' => _HomePalette.green,
    'pink' => _HomePalette.pink,
    'yellow' => _HomePalette.yellow,
    _ => _HomePalette.purple,
  };
}

String _formatHomeGoalValue(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}

class _QuickCalendarRow extends StatelessWidget {
  const _QuickCalendarRow({
    required this.onHotSearchTap,
    required this.onHoroscopeTap,
    required this.onMoneyTap,
    required this.onComicTap,
    required this.onAnniversaryTap,
  });

  final VoidCallback onHotSearchTap;
  final VoidCallback onHoroscopeTap;
  final VoidCallback onMoneyTap;
  final VoidCallback onComicTap;
  final VoidCallback onAnniversaryTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 126,
      width: double.infinity,
      child: _QuickEntryCard(
        onHotSearchTap: onHotSearchTap,
        onHoroscopeTap: onHoroscopeTap,
        onMoneyTap: onMoneyTap,
        onComicTap: onComicTap,
        onAnniversaryTap: onAnniversaryTap,
      ),
    );
  }
}

class _QuickEntryCard extends StatelessWidget {
  const _QuickEntryCard({
    required this.onHotSearchTap,
    required this.onHoroscopeTap,
    required this.onMoneyTap,
    required this.onComicTap,
    required this.onAnniversaryTap,
  });

  final VoidCallback onHotSearchTap;
  final VoidCallback onHoroscopeTap;
  final VoidCallback onMoneyTap;
  final VoidCallback onComicTap;
  final VoidCallback onAnniversaryTap;

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('快捷入口'),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    label: '热搜',
                    icon: Icons.local_fire_department_rounded,
                    bg: const Color(0xFFFFF1EA),
                    fg: _HomePalette.orange,
                    onTap: onHotSearchTap,
                  ),
                ),
                Expanded(
                  child: _QuickAction(
                    label: '星座',
                    icon: Icons.auto_awesome_rounded,
                    bg: const Color(0xFFF4F0FF),
                    fg: _HomePalette.purple,
                    onTap: onHoroscopeTap,
                  ),
                ),
                Expanded(
                  child: _QuickAction(
                    label: '记账',
                    icon: Icons.wallet_rounded,
                    bg: const Color(0xFFFFF0F1),
                    fg: const Color(0xFFF38340),
                    onTap: onMoneyTap,
                  ),
                ),
                Expanded(
                  child: _QuickAction(
                    label: '漫画',
                    icon: Icons.auto_stories_rounded,
                    bg: const Color(0xFFEAF3FF),
                    fg: _HomePalette.blue,
                    onTap: onComicTap,
                  ),
                ),
                Expanded(
                  child: _QuickAction(
                    label: '纪念日',
                    icon: Icons.event_available_rounded,
                    bg: const Color(0xFFFFF0F5),
                    fg: _HomePalette.pink,
                    onTap: onAnniversaryTap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(13),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(icon, color: fg, size: 19),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HotSearchSheet extends StatelessWidget {
  const _HotSearchSheet({required this.future});

  final Future<List<WeiboHotItem>> future;

  @override
  Widget build(BuildContext context) {
    return _DailyApiSheet(
      title: '微博热搜',
      subtitle: '实时热门话题',
      icon: Icons.local_fire_department_rounded,
      color: _HomePalette.orange,
      child: FutureBuilder<List<WeiboHotItem>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _SheetLoadingText(text: '正在加载热搜');
          }
          if (snapshot.hasError) {
            return _SheetErrorText(message: '${snapshot.error}');
          }
          final items = snapshot.data ?? const <WeiboHotItem>[];
          if (items.isEmpty) {
            return const _SheetErrorText(message: '暂时没有热搜内容');
          }
          return Column(
            children: [
              for (final item in items)
                _HotSearchTile(
                  item: item,
                  onTap: () => _openExternalUrl(item.url),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HotSearchTile extends StatelessWidget {
  const _HotSearchTile({required this.item, required this.onTap});

  final WeiboHotItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _HomePalette.orange.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${item.index}',
                style: const TextStyle(
                  color: _HomePalette.orange,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _HomePalette.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              item.hot,
              style: TextStyle(
                color: _HomePalette.orange.withValues(alpha: .78),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoroscopeSheet extends StatelessWidget {
  const _HoroscopeSheet({required this.future});

  final Future<HoroscopeResult> future;

  @override
  Widget build(BuildContext context) {
    return _DailyApiSheet(
      title: '巨蟹座',
      subtitle: '今日星座运势',
      icon: Icons.auto_awesome_rounded,
      color: _HomePalette.purple,
      child: FutureBuilder<HoroscopeResult>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _SheetLoadingText(text: '正在加载星座运势');
          }
          if (snapshot.hasError) {
            return _SheetErrorText(message: '${snapshot.error}');
          }
          final result = snapshot.data;
          if (result == null) {
            return const _SheetErrorText(message: '暂时没有星座内容');
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _HoroscopeMetric(label: '综合', value: result.overallIndex),
                  const SizedBox(width: 8),
                  _HoroscopeMetric(
                    label: '事业',
                    value: result.index['work'] ?? '--',
                  ),
                  const SizedBox(width: 8),
                  _HoroscopeMetric(
                    label: '健康',
                    value: result.index['health'] ?? '--',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                result.shortComment.isEmpty ? result.type : result.shortComment,
                style: const TextStyle(
                  color: _HomePalette.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                result.overallText.replaceAll('星%座%屋', '').trim(),
                style: const TextStyle(
                  color: _HomePalette.subText,
                  fontSize: 13,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FortunePill('幸运色', result.luckyColor),
                  _FortunePill('幸运数', result.luckyNumber),
                  _FortunePill('速配', result.luckyConstellation),
                  _FortunePill('宜', result.todoYi),
                  _FortunePill('忌', result.todoJi),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DailyApiSheet extends StatelessWidget {
  const _DailyApiSheet({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: .64,
      minChildSize: .42,
      maxChildSize: .88,
      builder: (context, controller) {
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
          decoration: const BoxDecoration(
            color: Color(0xFFFFFBF8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: ListView(
            controller: controller,
            children: [
              const Center(child: _SheetGrip()),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: color, size: 23),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: _HomePalette.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: _HomePalette.subText,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        );
      },
    );
  }
}

class _SheetGrip extends StatelessWidget {
  const _SheetGrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 5,
      decoration: BoxDecoration(
        color: const Color(0xFFE7D7CF),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _SheetLoadingText extends StatelessWidget {
  const _SheetLoadingText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(strokeWidth: 2.4),
            const SizedBox(height: 12),
            Text(text),
          ],
        ),
      ),
    );
  }
}

class _SheetErrorText extends StatelessWidget {
  const _SheetErrorText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Text(
        message,
        style: const TextStyle(
          color: _HomePalette.subText,
          fontSize: 13,
          height: 1.45,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HoroscopeMetric extends StatelessWidget {
  const _HoroscopeMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _HomePalette.purple.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: _HomePalette.purple,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: _HomePalette.subText,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FortunePill extends StatelessWidget {
  const _FortunePill(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFFE0D0)),
      ),
      child: Text(
        '$label：$value',
        style: const TextStyle(
          color: _HomePalette.text,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

Future<void> _openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return;
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _WeatherDetailSheetV2 extends StatelessWidget {
  const _WeatherDetailSheetV2({required this.weather});

  final AppWeatherNow weather;

  @override
  Widget build(BuildContext context) {
    final advice = _WeatherLifeAdvice.from(weather);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .88),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: .82)),
            boxShadow: [
              BoxShadow(
                color: _HomePalette.purple.withValues(alpha: .12),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _HomePalette.weatherBlue,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.wb_cloudy_outlined,
                      color: _HomePalette.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${weather.cityName}天气详情',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${weather.text} · ${weather.temp}°C · 体感 ${weather.feelsLike}°C',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _HomePalette.text,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _WeatherAdviceTile(
                    icon: Icons.checkroom_outlined,
                    label: '穿衣建议',
                    value: advice.clothing,
                  ),
                  _WeatherAdviceTile(
                    icon: Icons.umbrella_outlined,
                    label: '出行提醒',
                    value: advice.outing,
                  ),
                  _WeatherAdviceTile(
                    icon: Icons.air_rounded,
                    label: '风力',
                    value: advice.wind,
                  ),
                  _WeatherAdviceTile(
                    icon: Icons.spa_outlined,
                    label: '舒适度',
                    value: advice.comfort,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '湿度 ${weather.humidity}% · ${weather.windDir}${weather.windScale}级',
                style: const TextStyle(
                  color: _HomePalette.subText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeatherAdviceTile extends StatelessWidget {
  const _WeatherAdviceTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 136,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _HomePalette.weatherBlue.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .84)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _HomePalette.green, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _HomePalette.subText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _HomePalette.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WeatherDetailSheetLegacy extends StatelessWidget {
  const WeatherDetailSheetLegacy({required this.weather, super.key});

  final AppWeatherNow weather;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .82),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: .78)),
            boxShadow: [
              BoxShadow(
                color: _HomePalette.purple.withValues(alpha: .10),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${weather.cityName}天气详情',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${weather.text} · ${weather.temp}°C · 体感 ${weather.feelsLike}°C',
                style: const TextStyle(
                  color: _HomePalette.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '湿度 ${weather.humidity}% · ${weather.windDir}${weather.windScale}级',
                style: const TextStyle(
                  color: _HomePalette.subText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = GlassCard(
      padding: padding,
      radius: 23,
      tintColor: _HomePalette.pink.withValues(alpha: .42),
      child: child,
    );
    if (onTap == null) {
      return card;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(23),
      onTap: onTap,
      child: card,
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text, {this.fontSize = 14.5});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.black,
        height: 1.15,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ).copyWith(fontSize: fontSize),
    );
  }
}

class _AllLink extends StatelessWidget {
  const _AllLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '全部',
              style: TextStyle(
                color: _HomePalette.orange,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: _HomePalette.orange,
              size: 15,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateMeta extends StatelessWidget {
  const _DateMeta({required this.text, this.dotColor = _HomePalette.yellow});

  final String text;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _HomePalette.subText,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlusSparkPainter extends CustomPainter {
  const _PlusSparkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    path
      ..moveTo(cx, 0)
      ..quadraticBezierTo(cx + 3, cy - 3, size.width, cy)
      ..quadraticBezierTo(cx + 3, cy + 3, cx, size.height)
      ..quadraticBezierTo(cx - 3, cy + 3, 0, cy)
      ..quadraticBezierTo(cx - 3, cy - 3, cx, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PlusSparkPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _StarPainter extends CustomPainter {
  const _StarPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? size.width * .5 : size.width * .22;
      final angle = -math.pi / 2 + i * math.pi / 5;
      final point = Offset(
        cx + math.cos(angle) * radius,
        cy + math.sin(angle) * radius,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _HeroBearPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 168;
    canvas.save();
    canvas.scale(s);
    final outline = Paint()
      ..color = const Color(0xFFA979E6)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final white = Paint()
      ..color = Colors.white.withValues(alpha: .97)
      ..style = PaintingStyle.fill;
    final lavender = Paint()
      ..color = const Color(0xFFE2D1FF)
      ..style = PaintingStyle.fill;
    final cheek = Paint()
      ..color = const Color(0xFFFFB8C9)
      ..style = PaintingStyle.fill;
    final ink = Paint()
      ..color = const Color(0xFF67446F)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(const Offset(46, 46), 23, white);
    canvas.drawCircle(const Offset(111, 45), 24, white);
    canvas.drawCircle(const Offset(84, 64), 53, white);
    canvas.drawCircle(const Offset(46, 46), 23, outline);
    canvas.drawCircle(const Offset(111, 45), 24, outline);
    canvas.drawCircle(const Offset(84, 64), 53, outline);
    canvas.drawCircle(const Offset(66, 78), 8, cheek);
    canvas.drawCircle(const Offset(108, 78), 8, cheek);
    canvas.drawCircle(const Offset(72, 62), 4, ink);
    canvas.drawCircle(const Offset(98, 62), 4, ink);
    canvas.drawCircle(const Offset(84, 70), 3, ink);
    final mouth = Path()
      ..moveTo(84, 75)
      ..quadraticBezierTo(79, 82, 73, 77)
      ..moveTo(84, 75)
      ..quadraticBezierTo(89, 82, 95, 77);
    canvas.drawPath(mouth, outline);

    final bowLeft = Path()
      ..moveTo(57, 111)
      ..cubicTo(35, 92, 30, 119, 53, 126)
      ..cubicTo(70, 133, 74, 117, 57, 111)
      ..close();
    final bowRight = Path()
      ..moveTo(91, 111)
      ..cubicTo(118, 92, 128, 122, 98, 128)
      ..cubicTo(80, 132, 77, 118, 91, 111)
      ..close();
    canvas.drawPath(bowLeft, lavender);
    canvas.drawPath(bowRight, lavender);
    canvas.drawCircle(const Offset(76, 118), 10, lavender);
    canvas.drawPath(bowLeft, outline);
    canvas.drawPath(bowRight, outline);
    canvas.drawCircle(const Offset(76, 118), 10, outline);

    canvas.drawOval(const Rect.fromLTWH(42, 124, 44, 28), white);
    canvas.drawOval(const Rect.fromLTWH(82, 124, 44, 28), white);
    canvas.drawOval(const Rect.fromLTWH(42, 124, 44, 28), outline);
    canvas.drawOval(const Rect.fromLTWH(82, 124, 44, 28), outline);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF8FB0), Color(0xFFFF5A93)],
      ).createShader(Offset.zero & size);
    _drawHeart(canvas, Offset(size.width * .5, size.height * .55), 24, paint);
    final shine = Paint()
      ..color = Colors.white.withValues(alpha: .7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawArc(
      Rect.fromLTWH(size.width * .48, size.height * .22, 14, 12),
      math.pi,
      math.pi / 1.5,
      false,
      shine,
    );
  }

  void _drawHeart(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (var i = 0; i < 120; i++) {
      final t = i / 120 * math.pi * 2;
      final x = 16 * math.pow(math.sin(t), 3);
      final y =
          -(13 * math.cos(t) -
              5 * math.cos(2 * t) -
              2 * math.cos(3 * t) -
              math.cos(4 * t));
      final point = Offset(
        center.dx + x * radius / 18,
        center.dy + y * radius / 18,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WeatherCloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sunPaint = Paint()
      ..color = const Color(0xFFFFC93D)
      ..style = PaintingStyle.fill;
    final rayPaint = Paint()
      ..color = const Color(0xFFFFC93D)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final sun = Offset(size.width * .66, size.height * .36);
    canvas.drawCircle(sun, 20, sunPaint);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final p1 = Offset(sun.dx + math.cos(a) * 27, sun.dy + math.sin(a) * 27);
      final p2 = Offset(sun.dx + math.cos(a) * 34, sun.dy + math.sin(a) * 34);
      canvas.drawLine(p1, p2, rayPaint);
    }
    final cloudPaint = Paint()
      ..color = Colors.white.withValues(alpha: .94)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * .32, size.height * .63),
      26,
      cloudPaint,
    );
    canvas.drawCircle(
      Offset(size.width * .54, size.height * .55),
      33,
      cloudPaint,
    );
    canvas.drawCircle(
      Offset(size.width * .74, size.height * .65),
      24,
      cloudPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .16,
          size.height * .55,
          size.width * .72,
          32,
        ),
        const Radius.circular(18),
      ),
      cloudPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
