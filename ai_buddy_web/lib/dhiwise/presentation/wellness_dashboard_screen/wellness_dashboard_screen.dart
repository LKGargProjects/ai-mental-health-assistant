import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../../core/app_export.dart';
import '../../widgets/custom_button.dart';
import './widgets/progress_card_widget.dart';
import './widgets/recommendation_card_widget.dart';
import '../../../theme/text_style_helper.dart' as CoreTextStyles;
import '../../../widgets/assessment_splash.dart';
import '../../../quests/quests_engine.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:provider/provider.dart';
import '../../../providers/progress_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../navigation/route_observer.dart';
import '../../../widgets/keyboard_dismissible_scaffold.dart';
import '../../../widgets/app_bottom_nav.dart';
import '../../../widgets/app_back_button.dart';
import '../../../screens/quest_screen/widgets/quest_card_widget.dart';
import '../../../services/analytics_service.dart';
import '../../../services/notification_service.dart';

// DEBUG ONLY: toggle to reset quest state on each app launch
const bool _debugResetQuestsOnLaunch = false;
// DEBUG ONLY: toggle verbose XP chip position logs
const bool _debugXpLogs = false;
// DEBUG ONLY: run selector determinism/variety checks on init
const bool _debugSelectorTest = false;
// DEBUG ONLY: auto-run reminder microinteraction self-test after init
// Turned off after verification to avoid noise
const bool _debugAutoTestReminder = false;

// Animation tuning constants (microinteractions)
const Duration kRippleDuration = Duration(milliseconds: 380);
const double kRippleEndRadius = 84.0;
const Curve kRippleCurve = Curves.easeOutCubic;

const Duration kRingDuration = Duration(milliseconds: 520);
const Curve kRingCurve = Curves.easeOutCubic;

class WellnessDashboardScreen extends StatefulWidget {
  final bool showBottomNav;
  final ValueNotifier<int>? reselect;
  WellnessDashboardScreen({Key? key, this.showBottomNav = true, this.reselect}) : super(key: key);

  @override
  State<WellnessDashboardScreen> createState() => _WellnessDashboardScreenState();
}

// Painter for progress ring
class _RingPainter extends CustomPainter {
  final Offset center;
  final double progress; // 0..1
  final Color color;

  _RingPainter({required this.center, required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = 46.0;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final bg = Paint()
      ..color = color.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    // background circle
    canvas.drawArc(rect, 0, 2 * 3.1415926535, false, bg);
    // progress arc from top (-pi/2)
    final sweep = (2 * 3.1415926535) * progress.clamp(0.0, 1.0);
    canvas.drawArc(rect, -3.1415926535 / 2, sweep, false, fg);
  }
  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.center != center ||
        oldDelegate.progress != progress ||
        oldDelegate.color != color;
  }
}

// Painter for subtle expanding ripple
class _RipplePainter extends CustomPainter {
  final Offset center;
  final double radius;
  final double opacity; // 0..1
  final Color color;

  _RipplePainter({
    required this.center,
    required this.radius,
    required this.opacity,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final effectiveOpacity = opacity.clamp(0.0, 1.0);
    final fill = Paint()
      ..color = color.withOpacity(0.10 * (1.0 - effectiveOpacity))
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color.withOpacity(0.35 * (1.0 - effectiveOpacity))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, radius, fill);
    canvas.drawCircle(center, radius, stroke);
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) {
    return oldDelegate.center != center ||
        oldDelegate.radius != radius ||
        oldDelegate.opacity != opacity ||
        oldDelegate.color != color;
  }
}

class _WellnessDashboardScreenState extends State<WellnessDashboardScreen>
    with TickerProviderStateMixin, RouteAware, WidgetsBindingObserver {
  // UI-only state for TASK completion and progress
  bool _task1Done = false; // Focus reset
  bool _task2Done = false; // Study sprint
  int _baseSteps = 2; // total tasks today
  int _baseXp = 20; // base example XP shown initially
  bool _reminderOn = true; // UI-only reminder toggle (default ON)
  TimeOfDay _reminderTime = const TimeOfDay(hour: 19, minute: 0);
  // Level-up UX state
  int _lastLevelShown = -1;
  double _prevLevelProgress = 0.0;
  int _prevLifetimeXpForAnim = -1;
  bool _levelUpFlash = false;
  Timer? _levelUpTimer;

  // Reminder UI anchors (safe even if not attached)
  final GlobalKey _reminderToggleKey = GlobalKey();
  final GlobalKey _reminderTimeKey = GlobalKey();

  // Reminder scheduler
  Timer? _reminderTimer;
  DateTime? _reminderTargetAt;

  // DEBUG QA hooks removed post-verification

  // Debug log throttling for reminder prints
  DateTime _lastReminderLogAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool? _lastReminderNear;

  // Optional microinteraction flags (must be explicitly enabled)
  bool _enableSoftXpPop = true; // enabled per user approval
  // Reminder microinteraction anchors
  // (duplicates removed; declared once above)

  // Timer pill overlay state
  OverlayEntry? _timerPillEntry;
  Timer? _timerPillTicker;
  DateTime? _timerPillEndAt;
  String? _timerPillQuestId;
  AnimationController? _timerPillAnim;
  // Auto-complete timer for the active quest (cancelable replacement for Future.delayed)
  Timer? _autoCompleteTimer;
  
  // Main scroll controller (for re-tap scroll-to-top)
  final ScrollController _scrollController = ScrollController();

  // Segmented tabs: 0 = Today, 1 = Discover
  int _tabIndex = 0;
  // Explore filter state
  String _exploreFilter = 'All';
  List<String> _exploreCats = ['Mindfulness', 'Activity', 'Social', 'Learning', 'Challenge']; // curated MECE categories
  final Map<String, GlobalKey> _exploreCardKeys = <String, GlobalKey>{};
  // Track which Explore quests we've logged an impression for (to avoid duplicates)
  final Set<String> _impressedExplore = <String>{};
  // Track Explore completions this session to drive 'Done' state only after Explore interaction
  final Set<String> _exploreCompletedToday = <String>{};

  // Telemetry helpers
  String _slug(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  // Handle completion of the Quick Check-in flow (explicit submission)
  Future<void> _onQuickCheckinSubmitted() async {
    final engine = _questsEngine;
    if (engine == null) return;

    // Determine the quick check-in quest id for today
    String? questId;
    try {
      final raw = (_todayData?['todayItems'] as List?) ?? const [];
      // Pass 1: prefer explicit CHECK-IN
      for (final e in raw) {
        try {
          if (e is Quest && e.tag == QuestTag.checkin) {
            questId = e.id;
            break;
          } else if (e is Map<String, dynamic>) {
            final t = (e['tag'] ?? '').toString().toUpperCase();
            if (t == 'CHECK-IN' || t == 'CHECKIN') {
              questId = (e['quest_id'] as String?) ?? (e['id'] as String?);
              break;
            }
          }
        } catch (_) {}
      }
      // Pass 2: allow PROGRESS only if no CHECK-IN was present
      if (questId == null) {
        for (final e in raw) {
          try {
            if (e is Quest && e.tag == QuestTag.progress) {
              questId = e.id;
              break;
            } else if (e is Map<String, dynamic>) {
              final t = (e['tag'] ?? '').toString().toUpperCase();
              if (t == 'PROGRESS') {
                questId = (e['quest_id'] as String?) ?? (e['id'] as String?);
                break;
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    // Fallback to known ids if not present in today's list
    questId ??= engine.listAll().any((q) => q.id == 'checkin_quick_v2')
        ? 'checkin_quick_v2'
        : 'checkin_quick_v1';

    bool alreadyDone = false;
    try {
      alreadyDone = engine.isCompletedToday(questId);
    } catch (_) {}

    try { await engine.markImpression(questId); } catch (_) {}
    try { await engine.markStart(questId); } catch (_) {}
    if (kDebugMode) { try { debugPrint('[QuickCheckin][Submitted] questId=$questId'); } catch (_) {} }
    try { await engine.markComplete(questId); } catch (_) {}
    // Determine if XP was newly awarded now (award occurs only if not already done today)
    bool awarded = false;
    try {
      awarded = !alreadyDone && engine.isCompletedToday(questId);
    } catch (_) {}

    if (!mounted) return;
    setState(() {});

    // Visual feedback
    try {
      if (_enableSoftXpPop && awarded) {
        _showXpChipPop(_startBtnKey, amount: QuestsEngine.xpOther);
      }
      _showCheckRipple(_startBtnKey);
    } catch (_) {}

    // Telemetry: only log on first completion to avoid duplicate events
    try {
      if (awarded) {
        logAnalyticsEvent('quest_complete', metadata: {
          'quest_id': questId,
          'surface': 'wellness_dashboard',
          'variant': 'today',
          'tag': 'xp_awarded',
          'ts': DateTime.now().millisecondsSinceEpoch,
          'success': true,
          'progress': 1.0,
          'ui': 'quick_checkin',
        });
      }
    } catch (_) {}

    // Sync providers: lifetime XP + today progress
    try {
      final lifetimeXp = engine.computeLifetimeXp();
      if (mounted) context.read<ProgressProvider>().updateLifetimeXp(lifetimeXp);
    } catch (_) {}
    await _refreshToday();
    // Also refresh Explore to sync Discover tab cards and categories immediately
    await _refreshExplore();
    // Force a lightweight rebuild so Explore list reflects "Done" state right away
    if (mounted) setState(() {});
  }

  // Compute global center of a widget by key
  Offset? _globalCenterOf(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    final center = topLeft + Offset(box.size.width / 2, box.size.height / 2);
    return center;
  }

  // Look up duration_min for a quest in today's selection
  int? _durationFor(String? questId) {
    if (questId == null) return null;
    // Datasets may provide 'todayItems' (preferred) which may be List<Quest> or List<Map>
    final raw = (_todayData?['todayItems'] as List?) ?? const [];
    for (final e in raw) {
      try {
        if (e is Quest && e.id == questId) {
          return e.durationMin;
        } else if (e is Map<String, dynamic> && e['quest_id'] == questId) {
          final d = e['duration_min'];
          if (d == null) return null;
          return (d as num).toInt();
        }
      } catch (_) {}
    }
    // Legacy 'today' support (List<Map>)
    final todayAlt = (_todayData?['today'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    for (final m in todayAlt) {
      if (m['quest_id'] == questId) {
        final d = m['duration_min'];
        if (d == null) return null;
        try { return (d as num).toInt(); } catch (_) { return null; }
      }
    }
    // No hardcoded fallbacks: single source of truth is engine/JSON
    return null;
  }

  // Keys to compute positions for XP chip animation
  final GlobalKey _task1CardKey = GlobalKey();
  final GlobalKey _task2CardKey = GlobalKey();
  final GlobalKey _resCardKey = GlobalKey();
  final GlobalKey _tipCardKey = GlobalKey();
  final GlobalKey _xpCardKey = GlobalKey();
  // Start button key for microinteraction pill
  final GlobalKey _startBtnKey = GlobalKey();

  // Guard to ensure chip pop occurs only once per task per session
  // (Removed) _task1Popped was used for a local chip-pop guard; no longer needed.

  // Habit formation microcopy (rotates while active)
  final List<String> _microcopy = const [
    "You've got this!",
    "Stay on track!",
    "Future you is proud",
    "Small steps, big wins",
    "Consistency is power"
  ];
  int _microIndex = 0;
  Timer? _microTimer;
  Timer? _midnightTimer;

  // Gentle pulse for near-time attention
  late AnimationController _pulseController;

  // Week 0 QuestsEngine (minimal glue, no UI changes)
  QuestsEngine? _questsEngine;
  Map<String, dynamic>? _todayData; // {'todayItems': List<Quest>, 'progress': {stepsLeft, xpEarned}}

  // RouteObserver subscription guard
  bool _routeSubscribed = false;
  // IDs for the 4 displayed cards (derived from todayItems; UI copy remains static)
  String? _qTask1Id; // preferred: Focus reset variant
  String? _qTask2Id; // preferred: Study sprint variant
  String? _qResId;   // a RESOURCE item
  String? _qTipId;   // a TIP item

  // Persist reminder prefs
  static const _prefsReminderOn = 'wellness.reminder_on_v1';
  static const _prefsReminderMinutes = 'wellness.reminder_minutes_v1';
  // Daily first-use keys
  static const _prefsTipPopDate = 'xp_pop_tip_date_v1';
  static const _prefsResPopDate = 'xp_pop_res_date_v1';

  Future<void> _loadReminderPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final on = prefs.getBool(_prefsReminderOn);
      final mins = prefs.getInt(_prefsReminderMinutes);
      if (on != null || mins != null) {
        if (mounted) {
          setState(() {
            if (on != null) _reminderOn = on;
            if (mins != null) {
              final h = (mins ~/ 60).clamp(0, 23);
              final m = (mins % 60).clamp(0, 59);
              _reminderTime = TimeOfDay(hour: h, minute: m);
            }
          });
        }
      }
    } catch (e) {
      // swallow
    }
  }

  // Subtle check ripple behind a card center
  void _showCheckRipple(GlobalKey sourceKey) {
    // Respect reduce-motion: skip decorative animation
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return;
    final startGlobal = _globalCenterOf(sourceKey);
    // Use screen-scoped overlay to avoid leaking into other tabs/screens
    final overlayState = Overlay.of(context);
    if (startGlobal == null) return;
    final overlayBox = overlayState.context.findRenderObject() as RenderBox?;
    if (overlayBox == null || !overlayBox.attached) return;
    final start = overlayBox.globalToLocal(startGlobal);
    final size = overlayBox.size;
    final controller = AnimationController(vsync: this, duration: kRippleDuration);
    final fade = CurvedAnimation(parent: controller, curve: kRippleCurve);
    final radius = Tween<double>(begin: 0, end: kRippleEndRadius)
        .animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));

    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) {
      final r = radius.value;
      return Positioned.fill(
        child: IgnorePointer(
          ignoring: true,
          child: CustomPaint(
            painter: _RipplePainter(
              center: Offset(
                start.dx.clamp(0.0, size.width),
                start.dy.clamp(0.0, size.height),
              ),
              radius: r,
              opacity: (1.0 - fade.value).clamp(0.0, 1.0),
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
    });
    overlayState.insert(entry);
    controller.addListener(() { entry.markNeedsBuild(); });
    controller.addStatusListener((s) { if (s == AnimationStatus.completed) { entry.remove(); controller.dispose(); } });
    controller.forward();
  }

  Future<void> _saveReminderPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsReminderOn, _reminderOn);
      final mins = _reminderTime.hour * 60 + _reminderTime.minute;
      await prefs.setInt(_prefsReminderMinutes, mins);
    } catch (e) {
      // swallow
    }
  }

  // --- Daily first-use (Tip/Resource) helpers ---
  String _todayStr() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return '${now.year}-$mm-$dd';
  }

  Future<bool> _isFirstUseToday(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getString(key);
      return last != _todayStr();
    } catch (_) {
      return true;
    }
  }

  Future<void> _markUsedToday(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, _todayStr());
    } catch (_) {}
  }

  Future<void> _initQuests() async {
    final engine = QuestsEngine();
    if (kDebugMode && _debugSelectorTest) {
      // Lightweight selector assertions (determinism and variety)
      // ignore: invalid_use_of_visible_for_testing_member
      assert(() { engine.debugRunSelectorChecks(); return true; }());
    }
    final data = await engine.getTodayData();
    if (!mounted) return;
    setState(() {
      _questsEngine = engine;
      _todayData = data;
      _computeDisplayedQuestIds();
      // Sync local completion flags from engine's persisted map
      final comp = (data['completedToday'] as Map?)?.cast<String, bool>() ?? const {};
      _task1Done = _qTask1Id != null ? (comp[_qTask1Id] ?? false) : false;
      _task2Done = _qTask2Id != null ? (comp[_qTask2Id] ?? false) : false;
      // Keep curated Explore categories (MECE); no dynamic override
    });
    if (kDebugMode) {
      try {
        final items = (data['todayItems'] as List?) ?? const [];
        final ids = items.map((e) => e is Quest ? e.id : (e is Map ? e['quest_id'] : '?')).toList();
        final comp = (data['completedToday'] as Map?)?.cast<String, bool>() ?? const {};
        final prog = (data['progress'] as Map?)?.cast<String, dynamic>() ?? const {};
        debugPrint('[Quests][INIT] todayItems=${ids.join(', ')} comp=${comp.toString()} progress=${prog.toString()}');
      } catch (_) {}
    }

    // Push progress summary to existing ProgressProvider (no widget changes)
    final progress = data['progress'] as Map<String, dynamic>?;
    if (progress != null && mounted) {
      final stepsLeft = (progress['stepsLeft'] ?? 0) as int;
      final xpEarned = (progress['xpEarned'] ?? 0) as int;
      context.read<ProgressProvider>().updateFromQuests(stepsLeft: stepsLeft, xpEarned: xpEarned);
      // Also push lifetime XP for Explore header (backward compatible)
      try {
        final lifetimeXp = _questsEngine?.computeLifetimeXp() ?? 0;
        context.read<ProgressProvider>().updateLifetimeXp(lifetimeXp);
      } catch (_) {}
    }
  }

  Future<void> _refreshToday() async {
    if (_questsEngine == null) return _initQuests();
    final data = await _questsEngine!.getTodayData();
    if (!mounted) return;
    setState(() {
      _todayData = data;
      _computeDisplayedQuestIds();
      // Sync local completion flags from engine's persisted map
      final comp = (data['completedToday'] as Map?)?.cast<String, bool>() ?? const {};
      _task1Done = _qTask1Id != null ? (comp[_qTask1Id] ?? false) : false;
      _task2Done = _qTask2Id != null ? (comp[_qTask2Id] ?? false) : false;
    });
    final progress = data['progress'] as Map<String, dynamic>?;
    if (progress != null) {
      final stepsLeft = (progress['stepsLeft'] ?? 0) as int;
      final xpEarned = (progress['xpEarned'] ?? 0) as int;
      context.read<ProgressProvider>().updateFromQuests(stepsLeft: stepsLeft, xpEarned: xpEarned);
      // Keep lifetime XP in sync
      try {
        final lifetimeXp = _questsEngine?.computeLifetimeXp() ?? 0;
        context.read<ProgressProvider>().updateLifetimeXp(lifetimeXp);
      } catch (_) {}
    }
    if (kDebugMode) {
      try {
        final comp = (data['completedToday'] as Map?)?.cast<String, bool>() ?? const {};
        final prog = (data['progress'] as Map?)?.cast<String, dynamic>() ?? const {};
        debugPrint('[Quests][REFRESH] comp=${comp.toString()} progress=${prog.toString()}');
      } catch (_) {}
    }
  }
  
  // Refresh Explore: reload catalog and update curated categories while preserving current filter
  Future<void> _refreshExplore() async {
    if (_questsEngine == null) {
      await _initQuests();
      return;
    }
    await _questsEngine!.loadCatalog();
    if (!mounted) return;
    setState(() {
      final current = _exploreFilter;
      if (current != 'All' && !_exploreCats.contains(current)) {
        _exploreFilter = 'All';
      } else {
        _exploreFilter = current;
      }
    });
    if (kDebugMode) {
      try { debugPrint('[Explore][REFRESH] curated_cats=${_exploreCats.join(', ')}'); } catch (_) {}
    }
  }

  // Choose IDs from today's items to back the 4 static cards.
  void _computeDisplayedQuestIds() {
    final items = (_todayData?['todayItems'] as List?)?.cast<dynamic>() ?? const [];
    // Helper to extract fields safely from either Quest or Map
    String? idOf(dynamic j) {
      if (j is Quest) return j.id;
      if (j is Map<String, dynamic>) return j['quest_id'] as String?;
      return null;
    }
    bool isTag(dynamic j, QuestTag tag) {
      if (j is Quest) return j.tag == tag;
      if (j is Map<String, dynamic>) {
        final t = (j['tag'] ?? '').toString().toUpperCase();
        switch (tag) {
          case QuestTag.task:
            return t == 'TASK';
          case QuestTag.tip:
            return t == 'TIP';
          case QuestTag.resource:
            return t == 'RESOURCE';
          case QuestTag.reminder:
            return t == 'REMINDER';
          case QuestTag.checkin:
            return t == 'CHECK-IN' || t == 'CHECKIN';
          case QuestTag.progress:
            return t == 'PROGRESS';
        }
      }
      return false;
    }
    String titleOf(dynamic j) {
      if (j is Quest) return j.title;
      if (j is Map<String, dynamic>) return (j['title']?.toString() ?? '');
      return '';
    }

    // Pick two TASKs: prefer ones resembling current UI labels
    final tasks = items.where((e) => isTag(e, QuestTag.task)).toList();
    dynamic focusCandidate = tasks.firstWhere(
      (e) => titleOf(e).toLowerCase().contains('focus'),
      orElse: () => tasks.isNotEmpty ? tasks.first : null,
    );
    dynamic sprintCandidate = tasks.firstWhere(
      (e) => titleOf(e).toLowerCase().contains('study'),
      orElse: () => tasks.length > 1 ? tasks[1] : (tasks.isNotEmpty ? tasks.first : null),
    );
    _qTask1Id = idOf(focusCandidate);
    // Ensure task2 is different from task1 when possible
    final t2 = (idOf(sprintCandidate) != null && idOf(sprintCandidate) != _qTask1Id)
        ? sprintCandidate
        : (tasks.firstWhere(
              (e) => idOf(e) != null && idOf(e) != _qTask1Id,
              orElse: () => null,
            ));
    _qTask2Id = idOf(t2);

    // Pools for non-task cards
    final resources = items.where((e) => isTag(e, QuestTag.resource)).toList();
    final tips = items.where((e) => isTag(e, QuestTag.tip)).toList();
    final checks = items.where((e) => isTag(e, QuestTag.checkin) || isTag(e, QuestTag.progress)).toList();

    // Pick one RESOURCE (preferred), else TIP, else CHECK/PROGRESS
    dynamic resPick;
    if (resources.isNotEmpty) {
      resPick = resources.first;
    } else if (tips.isNotEmpty) {
      resPick = tips.first;
    } else if (checks.isNotEmpty) {
      resPick = checks.first;
    }
    _qResId = idOf(resPick);

    // Pick one TIP distinct from resource (if possible); else CHECK/PROGRESS distinct; else null
    dynamic tipPick;
    if (tips.isNotEmpty) {
      tipPick = tips.firstWhere(
        (e) => idOf(e) != null && idOf(e) != _qResId,
        orElse: () => tips.first,
      );
      // If only one TIP and it's same as res, try checks
      if (idOf(tipPick) == _qResId && checks.isNotEmpty) {
        tipPick = checks.firstWhere(
          (e) => idOf(e) != null && idOf(e) != _qResId,
          orElse: () => checks.first,
        );
      }
    } else if (checks.isNotEmpty) {
      tipPick = checks.firstWhere(
        (e) => idOf(e) != null && idOf(e) != _qResId,
        orElse: () => checks.first,
      );
    }
    _qTipId = idOf(tipPick);

  // Debug: note when only one TASK is present today
  if (kDebugMode && (_qTask1Id != null && _qTask2Id == null)) {
    try {
      debugPrint('[QA][Quests] only_one_task=true task1=$_qTask1Id task2=null');
    } catch (_) {}
  }
}

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final ms = nextMidnight.difference(now).inMilliseconds;
    _midnightTimer = Timer(Duration(milliseconds: ms.clamp(1000, 86400000)), () async {
      await _refreshToday();
      _rescheduleReminder('midnight');
      _scheduleMidnightRefresh();
    });
  }

  @override
  void dispose() {
    // Unsubscribe from route observer
    try {
      final route = ModalRoute.of(context);
      if (route is PageRoute) {
        routeObserver.unsubscribe(this);
        _routeSubscribed = false;
      }
    } catch (_) {}
    _removeTimerPill();
    _microTimer?.cancel();
    _midnightTimer?.cancel();
    _reminderTimer?.cancel();
    // Cancel level-up flash timer
    try { _levelUpTimer?.cancel(); } catch (_) {}
    // Remove lifecycle observer
    try { WidgetsBinding.instance.removeObserver(this); } catch (_) {}
    widget.reselect?.removeListener(_onReselect);
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    // Clean up floating UI when navigating away/tab switching
    _removeTimerPill();
    super.deactivate();
  }

  String _formatReminderTime(TimeOfDay t) {
    final hour12 = (t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod).toString();
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }

  bool _isTomorrowLabel(TimeOfDay t) {
    final now = DateTime.now();
    final todayTarget = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    return todayTarget.isBefore(now); // if passed today, it's effectively tomorrow
  }

  bool _isReminderNear() {
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, _reminderTime.hour, _reminderTime.minute);
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }
    final minutes = target.difference(now).inMinutes;
    return minutes >= 0 && minutes < 10; // within next 10 minutes
  }

  // Reminder scheduler helpers
  void _cancelReminderTimer({String from = 'unspecified'}) {
    if (_reminderTimer != null) {
      if (kDebugMode) {
        try { debugPrint('[Reminder][cancel] from=$from'); } catch (_) {}
      }
    }
    _reminderTimer?.cancel();
    _reminderTimer = null;
    // Only cancel native OS notification when user has reminders turned OFF.
    // Do NOT cancel during lifecycle pauses or reschedules, to avoid losing the scheduled alert.
    try {
      if (!_reminderOn) {
        NotificationService.cancelReminder();
      }
    } catch (_) {}
  }

  void _scheduleNextReminder({String from = 'unspecified'}) {
    // Only schedule when toggle is ON
    if (!_reminderOn) {
      _cancelReminderTimer(from: from);
      return;
    }
    _cancelReminderTimer(from: from);
    final now = DateTime.now();
    DateTime target = DateTime(now.year, now.month, now.day, _reminderTime.hour, _reminderTime.minute);
    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }
    _reminderTargetAt = target;
    final delay = target.difference(now);
    // Clamp delay to reasonable bounds (>=1s, <= 2 days)
    final Duration clamped = Duration(milliseconds: delay.inMilliseconds.clamp(1000, 172800000));
    if (kDebugMode) {
      try {
        debugPrint('[Reminder][schedule] from=$from target=${target.toIso8601String()} delay=${clamped.inSeconds}s');
      } catch (_) {}
    }
    _reminderTimer = Timer(clamped, _onReminderFired);
    // Also schedule a native OS notification so the user is nudged even if the app is backgrounded.
    // The service defensively cancels any previous pending reminder to avoid duplicates.
    try {
      NotificationService.scheduleOneShot(
        target: target,
        title: 'Daily check‑in',
        body: 'Time for your quick check‑in. Take 2 minutes to reflect and log your mood.',
        debugTag: 'daily_reminder',
      );
    } catch (_) {}
  }

  void _rescheduleReminder(String from) {
    if (!_reminderOn) {
      _cancelReminderTimer(from: from);
      return;
    }
    _scheduleNextReminder(from: from);
  }

  void _onReminderFired() {
    // If widget disposed, skip
    if (!mounted) return;
    final now = DateTime.now();
    // Haptic + sound feedback
    HapticFeedback.mediumImpact();
    try { SystemSound.play(SystemSoundType.alert); } catch (_) { SystemSound.play(SystemSoundType.click); }
    // Microinteractions to draw attention
    _showCheckRipple(_reminderToggleKey);
    _showTimerRing(_reminderTimeKey);
    // In-app notification
    try {
      final msg = 'It\'s time for your daily reminder';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () {
              // Bring user focus to Today tab if not already
              if (_tabIndex != 0) {
                setState(() { _tabIndex = 0; });
              }
            },
          ),
        ),
      );
    } catch (_) {}
    // Telemetry
    try {
      final qid = _qTask1Id ?? _qTask2Id;
      logAnalyticsEvent('quest_reminder_fired', metadata: {
        if (qid != null) 'quest_id': qid,
        'surface': 'wellness_dashboard',
        'variant': 'today',
        'tag': 'fired',
        'ts': now.millisecondsSinceEpoch,
        'ui': 'in_app',
      });
    } catch (_) {}
    // Schedule next occurrence (tomorrow)
    _scheduleNextReminder(from: 'post_fire');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (kDebugMode) {
      try { debugPrint('[Lifecycle] state=$state'); } catch (_) {}
    }
    if (state == AppLifecycleState.resumed) {
      // If we missed the target while backgrounded, fire immediately within grace window
      final now = DateTime.now();
      DateTime target = DateTime(now.year, now.month, now.day, _reminderTime.hour, _reminderTime.minute);
      if (!target.isAfter(now)) {
        // Today target has passed
        final diff = now.difference(target).inMinutes;
        // Fire if within 15 minutes of target, else just schedule next
        if (_reminderOn && diff >= 0 && diff <= 15) {
          // Avoid double-fire if timer also triggers; cancel then fire
          _cancelReminderTimer(from: 'resume_fire');
          _onReminderFired();
          return;
        }
      }
      _rescheduleReminder('resume');
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Cancel active timer to avoid stale callback while backgrounded
      _cancelReminderTimer(from: 'pause');
    }
  }

  void _startMicrocopyRotation() {
    _microTimer?.cancel();
    if (_reminderOn) {
      _microTimer = Timer.periodic(const Duration(seconds: 6), (_) {
        setState(() {
          _microIndex = (_microIndex + 1) % _microcopy.length;
        });
      });
    }
  }

  // DEBUG ONLY: programmatically exercise reminder microinteractions once
  Future<void> _debugRunReminderSelfTestOnce() async {
    if (!kDebugMode || !_debugAutoTestReminder) return;
    // Only run once per day to avoid annoyance on hot restarts
    const key = 'debug.reminder_test_run_today_v1';
    final first = await _isFirstUseToday(key);
    if (!first) return;
    await _markUsedToday(key);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    if (kDebugMode) debugPrint('[Reminder][selftest] start');
    // 1) Toggle ripple: flip OFF then ON with ripple
    setState(() { _reminderOn = !_reminderOn; });
    if (kDebugMode) debugPrint('[Reminder][selftest] toggle -> ${_reminderOn ? 'ON' : 'OFF'}');
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
    _showCheckRipple(_reminderToggleKey);
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    setState(() { _reminderOn = true; });
    if (kDebugMode) debugPrint('[Reminder][selftest] toggle -> ON');
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
    _showCheckRipple(_reminderToggleKey);
    await _saveReminderPrefs();
    if (!mounted) return;
    // 2) Time change ring: move time by +1 min and show ring
    final nextMinute = (TimeOfDay(
      hour: _reminderTime.hour,
      minute: (_reminderTime.minute + 1) % 60,
    ));
    setState(() { _reminderTime = nextMinute; });
    if (kDebugMode) debugPrint('[Reminder][selftest] time -> ${_reminderTime.format(context)}');
    HapticFeedback.selectionClick();
    SystemSound.play(SystemSoundType.click);
    _showTimerRing(_reminderTimeKey);
    await _saveReminderPrefs();
    if (kDebugMode) debugPrint('[Reminder][selftest] done');
  }

  @override
  void initState() {
    super.initState();
    // Observe app lifecycle for reminder scheduling
    WidgetsBinding.instance.addObserver(this);
    // When embedded inside HomeShell (no bottom nav), start on Today tab by default
    if (!widget.showBottomNav) {
      _tabIndex = 0; // Default to Today (0) when embedded; 1 = Explore
    }
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _startMicrocopyRotation();
    // Initialize asynchronously: reminder prefs, quests data, and midnight refresh
    Future.microtask(() async {
      await _loadReminderPrefs();
      _rescheduleReminder('init');
      // DEBUG ONLY: reset quests state on each launch to test persistence/awards
      if (kDebugMode && _debugResetQuestsOnLaunch) {
        await QuestsEngine.debugResetAll();
      }
      await _initQuests();
      _scheduleMidnightRefresh();
      // DEBUG ONLY: run reminder microinteraction self-test once per day,
      // after first frame so keys are mounted
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _debugRunReminderSelfTestOnce();
      });
    });
    // Listen for bottom-tab re-tap events
    widget.reselect?.addListener(_onReselect);
  }

  @override
  void didUpdateWidget(covariant WellnessDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reselect != widget.reselect) {
      oldWidget.reselect?.removeListener(_onReselect);
      widget.reselect?.addListener(_onReselect);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes so we can clean up overlay when covered
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      try {
        // Avoid duplicate subscriptions across dependency changes
        if (_routeSubscribed) {
          routeObserver.unsubscribe(this);
          _routeSubscribed = false;
        }
        routeObserver.subscribe(this, route);
        _routeSubscribed = true;
      } catch (_) {}
    }
  }

  @override
  void didPushNext() {
    // Another route pushed on top (e.g., switching tabs or opening sheet)
    if (kDebugMode) {
      try { debugPrint('[Pill][ROUTE] didPushNext -> remove pill'); } catch (_) {}
    }
    _removeTimerPill();
  }

  @override
  void didPopNext() {
    // A subsequent route popped, revealing this one
    if (kDebugMode) {
      try { debugPrint('[Pill][ROUTE] didPopNext'); } catch (_) {}
    }
    // No-op: pill is only created explicitly while on this screen
  }

  // Handle bottom tab reselect: scroll to top if scrolled, otherwise refresh
  void _onReselect() {
    if (!mounted) return;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_scrollController.hasClients) {
      final offset = _scrollController.offset;
      const threshold = 64.0;
      if (offset > threshold) {
        if (reduceMotion) {
          _scrollController.jumpTo(0);
        } else {
          _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
        return;
      }
    }
    // Near top: trigger a lightweight refresh of active tab
    if (_tabIndex == 0) {
      _refreshToday();
    } else {
      _refreshExplore();
    }
  }

  @override
  void didPop() {
    // This route popped: ensure complete cleanup
    if (kDebugMode) {
      try { debugPrint('[Pill][ROUTE] didPop -> remove pill'); } catch (_) {}
    }
    _removeTimerPill();
  }

  // Start a floating timer pill anchored near the given card.
  void _startTimerPill({required GlobalKey cardKey, required String questId, required Duration total}) {
    _removeTimerPill();
    // Only show pill when this screen is visible.
    // If used standalone (showBottomNav=true), require route '/wellness-dashboard' and current.
    // If used inside HomeShell (showBottomNav=false), we are on '/home'; allow when current.
    final route = ModalRoute.of(context);
    final routeName = route?.settings.name;
    final isCurrent = route?.isCurrent ?? true;
    // Consider visible when current; do not strictly require a named route (can be null under builders)
    final bool allow = isCurrent && (!widget.showBottomNav || routeName == '/wellness-dashboard' || routeName == null);
    // Also require we're on the Today tab to avoid showing on Explore/programmatic switches
    if (!allow || _tabIndex != 0) {
      _removeTimerPill(forQuestId: questId);
      return;
    }
    if (kDebugMode) {
      try {
        debugPrint('[Pill][START] questId=$questId total=${total.inMinutes}m route=${routeName ?? 'null'} isCurrent=$isCurrent');
      } catch (_) {}
    }
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    // Use screen-scoped overlay so the pill is owned by this screen
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    final centerGlobal = _globalCenterOf(cardKey);
    if (overlayBox == null || !overlayBox.attached || centerGlobal == null) return;
    final centerLocal = overlayBox.globalToLocal(centerGlobal);
    _timerPillQuestId = questId;
    _timerPillEndAt = DateTime.now().add(total);
    // Prepare animation controller and scale tween
    _timerPillAnim?.dispose();
    _timerPillAnim = null;
    if (!reduceMotion) {
      _timerPillAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
        ..repeat(reverse: true);
    }
    final Animation<double> scaleAnim = _timerPillAnim == null
        ? const AlwaysStoppedAnimation<double>(1.0)
        : Tween<double>(begin: 0.98, end: 1.02).animate(CurvedAnimation(parent: _timerPillAnim!, curve: Curves.easeInOut));

    String _fmt(Duration d) {
      final s = d.inSeconds.clamp(0, 24 * 3600);
      final mm = (s ~/ 60).toString().padLeft(2, '0');
      final ss = (s % 60).toString().padLeft(2, '0');
      return '$mm:$ss';
    }

    _timerPillEntry = OverlayEntry(builder: (_) {
      final now = DateTime.now();
      final remaining = _timerPillEndAt != null ? _timerPillEndAt!.difference(now) : Duration.zero;
      final txt = _fmt(remaining);
      // Position slightly to the right of the card center
      final left = (centerLocal.dx + 64).clamp(8.0, (overlayBox.size.width - 140).toDouble());
      final top = (centerLocal.dy - 16).clamp(8.0, (overlayBox.size.height - 40).toDouble());
      return Positioned(
        left: left,
        top: top,
        child: IgnorePointer(
          ignoring: true,
          child: AnimatedBuilder(
            animation: scaleAnim,
            builder: (context, child) => Transform.scale(scale: scaleAnim.value, child: child),
            child: Builder(builder: (ctx) {
              final scheme = Theme.of(ctx).colorScheme;
              final scaffoldBg = Theme.of(ctx).scaffoldBackgroundColor;
              Color bg = scheme.primary;
              // If primary is too close to scaffold background, fall back
              bool similar(Color a, Color b) {
                double dr = (a.r - b.r).abs();
                double dg = (a.g - b.g).abs();
                double db = (a.b - b.b).abs();
                return (dr + dg + db) < 0.12; // ~30/255 threshold for normalized channels
              }
              if (similar(bg, scaffoldBg)) {
                bg = scheme.primaryContainer;
                if (similar(bg, scaffoldBg)) {
                  bg = scheme.secondary;
                }
              }
              final fg = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
                  ? Colors.white
                  : Colors.black87;
              return Material(
                color: bg,
                shape: const StadiumBorder(),
                elevation: 3,
                shadowColor: Colors.black.withOpacity(0.2),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    txt,
                    style: TextStyleHelper.instance.titleMediumInter.copyWith(color: fg, fontWeight: FontWeight.w700),
                  ),
                ),
              );
            }),
          ),
        ),
      );
    });
    overlay.insert(_timerPillEntry!);
    _timerPillTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      // If screen no longer visible, remove immediately
      final route = ModalRoute.of(context);
      final currentName = route?.settings.name;
      final isCurrent = route?.isCurrent ?? true;
      final bool stillVisible = isCurrent; // route name can be null when built via builder
      final bool onToday = _tabIndex == 0;
      if (!stillVisible || !onToday) {
        if (kDebugMode) {
          try {
            debugPrint('[Pill][CLEANUP] route_or_tab_changed current=${currentName ?? 'null'} isCurrent=$isCurrent tab=$_tabIndex questId=$questId');
          } catch (_) {}
        }
        _removeTimerPill(forQuestId: questId);
        return;
      }
      if (_timerPillEndAt == null) return;
      if (DateTime.now().isAfter(_timerPillEndAt!)) {
        _removeTimerPill(forQuestId: questId);
      } else {
        _timerPillEntry?.markNeedsBuild();
      }
    });
    _timerPillAnim?.addStatusListener((_) {});
  }

  void _removeTimerPill({String? forQuestId}) {
    if (forQuestId != null && _timerPillQuestId != null && _timerPillQuestId != forQuestId) return;
    if (kDebugMode) {
      try {
        debugPrint('[Pill][REMOVE] questId=${forQuestId ?? _timerPillQuestId ?? 'null'} hadTicker=${(_timerPillTicker != null)} hadEntry=${(_timerPillEntry != null)}');
      } catch (_) {}
    }
    // Cancel any scheduled auto-complete to avoid firing after navigation/cancel
    if (_autoCompleteTimer != null) {
      try { if (kDebugMode) debugPrint('[Pill][AUTO] cancel questId=${forQuestId ?? _timerPillQuestId ?? 'null'}'); } catch (_) {}
    }
    _autoCompleteTimer?.cancel();
    _autoCompleteTimer = null;
    // Ensure engine timer state is cleared whenever the pill is removed
    try {
      final String? qid = _timerPillQuestId ?? forQuestId;
      if (qid != null) {
        // Fire-and-forget; we don't need to await here
        _questsEngine?.stopTimer(qid);
      }
    } catch (_) {}
    _timerPillTicker?.cancel();
    _timerPillTicker = null;
    _timerPillEndAt = null;
    _timerPillQuestId = null;
    _timerPillAnim?.dispose();
    _timerPillAnim = null;
    _timerPillEntry?.remove();
    _timerPillEntry = null;
  }

  Future<void> _openTimerSheet({
    required String questId,
    required GlobalKey cardKey,
    required String title,
    required int durationMin,
  }) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyleHelper.instance.headline21Inter),
              const SizedBox(height: 8),
              Text('Estimated ${durationMin} min', style: TextStyleHelper.instance.titleMediumInter.copyWith(color: const Color(0xFF6B7280))),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    try {
                      await _questsEngine?.startTimer(questId);
                    } catch (_) {}
                    HapticFeedback.lightImpact();
                    SystemSound.play(SystemSoundType.click);
                    _showTimerRing(cardKey);
                    _startTimerPill(cardKey: cardKey, questId: questId, total: Duration(minutes: durationMin));
                    // Telemetry: quest_progress at timer start
                    try {
                      logAnalyticsEvent('quest_progress', metadata: {
                        'quest_id': questId,
                        'surface': 'wellness_dashboard',
                        'variant': 'today',
                        'tag': 'timer_start',
                        'ts': DateTime.now().millisecondsSinceEpoch,
                        'progress': 0.0,
                        'duration_ms': durationMin * 60000,
                        'ui': 'timer_sheet',
                      });
                    } catch (_) {}
                    // Auto-complete disabled: require explicit user action to complete
                    try { if (kDebugMode) debugPrint('[Pill][AUTO] disabled (require explicit completion) questId=$questId'); } catch (_) {}
                    _autoCompleteTimer?.cancel();
                    _autoCompleteTimer = null;
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Timer started for $durationMin min')),
                      );
                    }
                  },
                  child: Text('Start ${durationMin} min'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    // Close the bottom sheet first so SnackBar is visible
                    Navigator.of(ctx).pop();
                    try {
                      await _questsEngine?.markStart(questId);
                      if (kDebugMode) {
                        try { debugPrint('[TimerSheet][Complete] questId=$questId'); } catch (_) {}
                      }
                      await _questsEngine?.markComplete(questId);
                      // Sync lifetime XP immediately
                      try {
                        final lifetimeXp = _questsEngine?.computeLifetimeXp() ?? 0;
                        if (mounted) {
                          context.read<ProgressProvider>().updateLifetimeXp(lifetimeXp);
                        }
                      } catch (_) {}
                      // XP chip pop is handled by first-use logic on initial tap to avoid duplicates
                      _showCheckRipple(cardKey);
                      // Telemetry: quest_complete for instant completion
                      try {
                        logAnalyticsEvent('quest_complete', metadata: {
                          'quest_id': questId,
                          'surface': 'wellness_dashboard',
                          'variant': 'today',
                          'tag': 'complete_now',
                          'ts': DateTime.now().millisecondsSinceEpoch,
                          'success': true,
                          'progress': 1.0,
                          'ui': 'timer_sheet',
                        });
                      } catch (_) {}
                      await _refreshToday();
                      if (mounted) {
                        final messenger = ScaffoldMessenger.of(context);
                        messenger.hideCurrentSnackBar();
                        messenger.showSnackBar(
                          SnackBar(
                            duration: const Duration(seconds: 5),
                            content: Text('$title marked complete'),
                            action: SnackBarAction(
                              label: 'Undo',
                              onPressed: () async {
                                try { await _questsEngine?.uncompleteToday(questId); } catch (_) {}
                                // Sync lifetime XP after undo
                                try {
                                  final lifetimeXp = _questsEngine?.computeLifetimeXp() ?? 0;
                                  if (mounted) {
                                    context.read<ProgressProvider>().updateLifetimeXp(lifetimeXp);
                                  }
                                } catch (_) {}
                                await _refreshToday();
                              },
                            ),
                          ),
                        );
                      }
                    } catch (_) {}
                  },
                  child: const Text('Complete now'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCompleteConfirmation({
    required String questId,
    required String title,
    required String telemetryTag,
    required String ui,
    required GlobalKey cardKey,
  }) async {
    if (!mounted) return;
    final engine = _questsEngine;
    if (engine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please try again')),
      );
      return;
    }
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyleHelper.instance.headline21Inter),
              const SizedBox(height: 8),
              Text('Mark complete for today?', style: TextStyleHelper.instance.titleMediumInter.copyWith(color: const Color(0xFF6B7280))),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        HapticFeedback.lightImpact();
                        SystemSound.play(SystemSoundType.click);
                        bool alreadyDone = false;
                        try { alreadyDone = engine.isCompletedToday(questId); } catch (_) {}
                        try { await engine.markComplete(questId); } catch (_) {}
                        // Sync lifetime XP
                        try {
                          final lifetimeXp = engine.computeLifetimeXp();
                          if (mounted) context.read<ProgressProvider>().updateLifetimeXp(lifetimeXp);
                        } catch (_) {}
                        // Visual feedback
                        try { _showCheckRipple(cardKey); } catch (_) {}
                        // Telemetry: only on first award
                        try {
                          final awarded = !alreadyDone && engine.isCompletedToday(questId);
                          if (awarded) {
                            logAnalyticsEvent('quest_complete', metadata: {
                              'quest_id': questId,
                              'surface': 'wellness_dashboard',
                              'variant': 'today',
                              'tag': 'xp_awarded',
                              'ts': DateTime.now().millisecondsSinceEpoch,
                              'success': true,
                              'progress': 1.0,
                              'ui': ui,
                              'source': telemetryTag,
                            });
                          }
                        } catch (_) {}
                        await _refreshToday();
                        await _refreshExplore();
                        if (mounted) {
                          final messenger = ScaffoldMessenger.of(context);
                          messenger.hideCurrentSnackBar();
                          messenger.showSnackBar(
                            SnackBar(
                              duration: const Duration(seconds: 5),
                              content: Text('$title marked complete'),
                              action: SnackBarAction(
                                label: 'Undo',
                                onPressed: () async {
                                  try { await engine.uncompleteToday(questId); } catch (_) {}
                                  // Sync lifetime XP after undo
                                  try {
                                    final lifetimeXp = engine.computeLifetimeXp();
                                    if (mounted) context.read<ProgressProvider>().updateLifetimeXp(lifetimeXp);
                                  } catch (_) {}
                                  await _refreshToday();
                                  await _refreshExplore();
                                },
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('Mark complete'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Cancel'),
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

  // Short timer ring microinteraction centered on a card
  void _showTimerRing(GlobalKey sourceKey) {
    // Respect reduce-motion: skip decorative animation
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return;
    final startGlobal = _globalCenterOf(sourceKey);
    // Use screen-scoped overlay so ring belongs to this screen
    final overlayState = Overlay.of(context);
    if (startGlobal == null) return;
    final overlayBox = overlayState.context.findRenderObject() as RenderBox?;
    if (overlayBox == null || !overlayBox.attached) return;
    final start = overlayBox.globalToLocal(startGlobal);
    final size = overlayBox.size;

    final controller = AnimationController(
      vsync: this,
      duration: kRingDuration,
    );
    final anim = CurvedAnimation(parent: controller, curve: kRingCurve);

    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) {
      return Positioned.fill(
        child: IgnorePointer(
          ignoring: true,
          child: CustomPaint(
            painter: _RingPainter(
              center: Offset(
                start.dx.clamp(0.0, size.width),
                start.dy.clamp(0.0, size.height),
              ),
              progress: anim.value, // 0..1
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
    });
    overlayState.insert(entry);
    controller.addListener(() { entry.markNeedsBuild(); });
    controller.forward().whenComplete(() {
      entry.remove();
      controller.dispose();
    });
  }

  // Optional +XP chip pop animation from a source card to XP card
  void _showXpChipPop(GlobalKey sourceKey, {required int amount}) {
    final startGlobal = _globalCenterOf(sourceKey);
    final endGlobal = _globalCenterOf(_xpCardKey);
    if (startGlobal == null || endGlobal == null) return;

    final overlayState = Navigator.of(context).overlay ?? Overlay.of(context);

    final overlayBox = overlayState.context.findRenderObject() as RenderBox?;
    if (overlayBox == null || !overlayBox.attached) return;

    // Convert to overlay-local coordinates
    Offset start = overlayBox.globalToLocal(startGlobal);
    Offset end = overlayBox.globalToLocal(endGlobal);

    // Clamp and fallback for small screens or offscreen targets
    final size = overlayBox.size;
    bool endOff = end.dx.isNaN || end.dy.isNaN || end.dx < 0 || end.dy < 0 || end.dx > size.width || end.dy > size.height;
    if (endOff) {
      // simple upward pop if XP card is not visible
      end = start.translate(0, -80);
    }
    if (kDebugMode && _debugXpLogs) {
      // optional position logs removed
    }

    // Respect reduce-motion: show a lightweight toast instead of animated chip
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('+$amount XP'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 900),
        ),
      );
      return;
    }

    // Animation polish: snappier ease + minor timing tweak
    final controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    final position = Tween<Offset>(begin: start, end: end)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(controller);
    final fade = CurvedAnimation(parent: controller, curve: const Interval(0.0, 0.8, curve: Curves.easeOut));
    final scale = Tween<double>(begin: 0.92, end: 1.06)
        .chain(CurveTween(curve: Curves.fastOutSlowIn))
        .animate(controller);

    late OverlayEntry entry;
    entry = OverlayEntry(builder: (ctx) {
      final pos = position.value;
      final primary = Theme.of(context).colorScheme.primary;
      double left = pos.dx - 26;
      double top = pos.dy - 14;
      // Bound the chip within overlay to avoid rendering offscreen
      left = left.clamp(4.0, size.width - 52.0);
      top = top.clamp(4.0, size.height - 32.0);
      return Positioned(
        left: left,
        top: top,
        child: IgnorePointer(
          ignoring: true,
          child: Opacity(
            opacity: fade.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale.value,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '+$amount XP',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });

    overlayState.insert(entry);
    controller.addListener(() => entry.markNeedsBuild());
    controller.forward().whenComplete(() async {
      // Slightly faster fade-out tail (-80ms)
      await Future<void>.delayed(const Duration(milliseconds: 40));
      entry.remove();
      controller.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Build
    return Sizer(builder: (context, orientation, deviceType) {
      return KeyboardDismissibleScaffold(
        safeTop: false,
        safeBottom: false,
        bottomNavigationBar: widget.showBottomNav ? const AppBottomNav(current: AppTab.quest) : null,
        body: Column(
          children: [
            // Sticky header outside the scroll view (matches Mood Tracker)
            _buildHeader(),
            // Scrollable content below header
            Expanded(
              child: Stack(
                children: [
                  // Plain themed background (no image)
                  Container(
                    height: MediaQuery.of(context).size.height,
                    width: MediaQuery.of(context).size.width,
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Segmented tabs at top of scrollable content
                        _buildTabSwitcher(),
                        // Sections (conditional by tab)
                        if (_tabIndex == 0) ...[
                          _buildMoodCheckInSection(),
                          _buildProgressSection(),
                          _buildRecommendationsSection(),
                        ] else ...[
                          _buildExploreSection(),
                        ],
                        SizedBox(height: 24.h),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  // Sticky header above the segmented control
  Widget _buildHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: appTheme.whiteCustom,
          padding: EdgeInsets.symmetric(horizontal: 16.h, vertical: 16.h),
          child: SafeArea(
            top: true,
            bottom: false,
            child: Row(
              children: [
                Builder(
                  builder: (ctx) {
                    final canPop = Navigator.of(ctx).canPop();
                    final route = ModalRoute.of(ctx);
                    final isModal = route is PageRoute && route.fullscreenDialog == true;
                    if (canPop) {
                      return AppBackButton(isModal: isModal);
                    }
                    return SizedBox(width: 44.h);
                  },
                ),
                Expanded(
                  child: GestureDetector(
                    onLongPress: () async {
                      if (!kDebugMode) return;
                      try { HapticFeedback.selectionClick(); } catch (_) {}
                      if (kDebugMode) { try { debugPrint('[Debug][Quests] Reset via header long-press'); } catch (_) {} }
                      try { await QuestsEngine.debugResetAll(); } catch (_) {}
                      try {
                        await _refreshToday();
                        await _refreshExplore();
                      } catch (_) {}
                      if (mounted) {
                        try {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Quests reset (debug)')),
                          );
                        } catch (_) {}
                      }
                    },
                    child: Text(
                      'My Quest',
                      textAlign: TextAlign.center,
                      style: TextStyleHelper.instance.headline24Bold,
                    ),
                  ),
                ),
                SizedBox(width: 44.h),
              ],
            ),
          ),
        ),
        Container(
          height: 8.h,
          color: appTheme.colorFFF3F4,
        ),
      ],
    );
  }

  // Large Quick check-in prompt section (title, subtitle, and Start button)
  Widget _buildMoodCheckInSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.h, vertical: 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Large prompt card title
          Text('Quick check-in',
              textAlign: TextAlign.center,
              style: TextStyleHelper.instance.headline28Inter.copyWith(
                  fontFamily: CoreTextStyles
                      .TextStyleHelper.instance.headline24Bold.fontFamily,
                  color: Color(0xFF555F6D))),
          SizedBox(height: 8.h),
          // Prompt subtitle
          Text('Takes 2 minutes',
              textAlign: TextAlign.center,
              style: TextStyleHelper.instance.headline21Inter.copyWith(
                  fontFamily: CoreTextStyles
                      .TextStyleHelper.instance.headline24Bold.fontFamily,
                  color: Color(0xFF8C9CAA))),
          SizedBox(height: 32.h),
          Center(
            child: Builder(builder: (context) {
              // Determine today's Quick Check-in quest id
              final engine = _questsEngine;
              String? questId;
              try {
                final raw = (_todayData?['todayItems'] as List?) ?? const [];
                // Pass 1: prefer explicit CHECK-IN
                for (final e in raw) {
                  try {
                    if (e is Quest && e.tag == QuestTag.checkin) {
                      questId = e.id;
                      break;
                    } else if (e is Map<String, dynamic>) {
                      final t = (e['tag'] ?? '').toString().toUpperCase();
                      if (t == 'CHECK-IN' || t == 'CHECKIN') {
                        questId = (e['quest_id'] as String?) ?? (e['id'] as String?);
                        break;
                      }
                    }
                  } catch (_) {}
                }
                // Pass 2: allow PROGRESS only if no CHECK-IN was present
                if (questId == null) {
                  for (final e in raw) {
                    try {
                      if (e is Quest && e.tag == QuestTag.progress) {
                        questId = e.id;
                        break;
                      } else if (e is Map<String, dynamic>) {
                        final t = (e['tag'] ?? '').toString().toUpperCase();
                        if (t == 'PROGRESS') {
                          questId = (e['quest_id'] as String?) ?? (e['id'] as String?);
                          break;
                        }
                      }
                    } catch (_) {}
                  }
                }
              } catch (_) {}
              // Fallback to known ids if not present in today's list
              questId ??= (engine?.listAll().any((q) => q.id == 'checkin_quick_v2') == true)
                  ? 'checkin_quick_v2'
                  : 'checkin_quick_v1';

              bool isDone = false;
              try { if (engine != null && questId != null) { isDone = engine.isCompletedToday(questId); } } catch (_) {}

              final Color bg = isDone ? const Color(0xFFE6EAF0) : Theme.of(context).colorScheme.primary;
              final Color fg = isDone ? const Color(0xFF8C9CAA) : Colors.white;

              return CustomButton(
                  key: _startBtnKey,
                  text: isDone ? 'Done' : 'Start',
                  backgroundColor: bg,
                  textColor: fg,
                  borderColor: Colors.transparent,
                  showBorder: false,
                  padding: EdgeInsets.symmetric(horizontal: 48.h, vertical: 24.h),
                  borderRadius: 37.h,
                  textStyle: TextStyleHelper.instance.headline25BoldInter.copyWith(
                      fontFamily: CoreTextStyles
                          .TextStyleHelper.instance.headline24Bold.fontFamily),
                  onPressed: isDone
                      ? null
                      : () async {
                          HapticFeedback.selectionClick();
                          await Future<void>.delayed(const Duration(milliseconds: 220));
                          if (!mounted) return;
                          showDialog(
                            context: context,
                            barrierDismissible: false, // keep user on quest screen; use X to close
                            builder: (ctx) => AssessmentSplash(
                              onSubmitted: () {
                                // Fire-and-forget on explicit submission only.
                                _onQuickCheckinSubmitted();
                              },
                            ),
                          );
                        });
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    // Prefer engine-backed values via ProgressProvider once today data is loaded; fallback to UI-only
    final pp = context.watch<ProgressProvider>();
    final bool hasEngineData = _todayData != null;
    final int completedLocal = (_task1Done ? 1 : 0) + (_task2Done ? 1 : 0);
    // Keep Today tab unchanged: show Steps Left as before
    final int stepsLeft = hasEngineData
        ? pp.stepsLeft
        : (_baseSteps - completedLocal).clamp(0, _baseSteps);
    final int xpEarned = hasEngineData
        ? pp.xpEarned
        : (_baseXp + (completedLocal * 10));
    final int streak = (_questsEngine != null) ? _questsEngine!.computeFriendlyDailyStreak() : 0;
    final int recordStreak = (_questsEngine != null) ? _questsEngine!.computeRecordDailyStreak() : 0;
    // Responsive label and pluralization
    final double _w = MediaQuery.of(context).size.width;
    final bool _narrow = _w < 420;
    final String _dayWord = streak == 1 ? 'day' : 'days';
    final String _recordLabel = _narrow ? 'record' : 'record';
    // Only show record when it's strictly greater than current streak
    final String _streakRecordLabel = (recordStreak > streak) ? '($_recordLabel $recordStreak)' : '';
    // Lifetime XP -> Level and progress
    final int lifetimeXp = pp.lifetimeXp;
    const int _xpPerLevel = 100;
    final int level = (lifetimeXp ~/ _xpPerLevel) + 1; // Level 1 at 0..99 XP
    final double levelProgress = ((lifetimeXp % _xpPerLevel) / _xpPerLevel).clamp(0.0, 1.0);
    // Hide Total XP pill when lifetime equals today's XP (first-day clean UI)
    final bool showTotalPill = lifetimeXp > xpEarned;
    // Persist previous progress for smooth animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prevLevelProgress = levelProgress;
      _prevLifetimeXpForAnim = lifetimeXp;
    });
    // Level Up toast (only when level increases, not on first render)
    if (_lastLevelShown < 0) {
      _lastLevelShown = level;
    } else if (level > _lastLevelShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Level Up! Level $level'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } catch (_) {}
        // Trigger a brief flash glow on the knob
        setState(() { _levelUpFlash = true; });
        try { _levelUpTimer?.cancel(); } catch (_) {}
        _levelUpTimer = Timer(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          setState(() { _levelUpFlash = false; });
        });
      });
      _lastLevelShown = level;
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 70.h).copyWith(bottom: 32.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Progress',
              style: TextStyleHelper.instance.display31BoldInter.copyWith(
                  fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                  color: Color(0xFF444D5C))),
          SizedBox(height: 28.h),
          Row(children: [
            Expanded(
                child: ProgressCardWidget(
                    imagePath: ImageConstant.imgImage65x52,
                    value: '$streak\u2011day streak',
                    label: _streakRecordLabel,
                    backgroundColor: Color(0xFFE0F2E9),
                    valueWidget: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                      child: Column(
                        key: ValueKey<int>(streak),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$streak\u2011day streak',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyleHelper.instance.headline28BoldInter.copyWith(
                                fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                                color: const Color(0xFF4E5965),
                              ),
                            ),
                          ),
                          SizedBox(height: 18.h),
                        ],
                      ),
                    )))
,
            SizedBox(width: 24.h),
            Expanded(
                child: Container(
              key: _xpCardKey,
              child: ProgressCardWidget(
                  imagePath: ImageConstant.imgImage63x65,
                  value: 'Level $level',
                  label: '+$xpEarned today',
                  backgroundColor: Color(0xFFE8E7F8),
                  valueWidget: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                    child: Column(
                      key: ValueKey<int>(lifetimeXp),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Level $level',
                          style: TextStyleHelper.instance.headline28BoldInter.copyWith(
                            fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                            color: const Color(0xFF4E5965),
                          ),
                        ),
                        SizedBox(height: 6.h),
                        if (showTotalPill)
                          Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.h, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12.h),
                            ),
                            child: Text(
                              'Total ${lifetimeXp} XP',
                              style: TextStyleHelper.instance.titleSmallInter.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF4E5965),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6.h),
                          child: SizedBox(
                            height: 18.h,
                            child: Stack(
                              children: [
                                Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.18),
                                ),
                                // Animated fill + knob
                                TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: _prevLevelProgress, end: levelProgress),
                                  duration: const Duration(milliseconds: 450),
                                  curve: Curves.easeOut,
                                  builder: (context, value, _) {
                                    final primary = Theme.of(context).colorScheme.primary;
                                    final bool nearLevelUp = value >= 0.92;
                                    final bool flash = _levelUpFlash;
                                    return Stack(children: [
                                      FractionallySizedBox(
                                        widthFactor: value,
                                        child: Container(
                                          height: double.infinity,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                primary,
                                                primary.withOpacity(0.85),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment((value * 2) - 1.0, 0),
                                        child: Container(
                                          width: 14.h,
                                          height: 14.h,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              const BoxShadow(color: Color(0x1A000000), blurRadius: 4, offset: Offset(0, 2)),
                                              if (nearLevelUp)
                                                BoxShadow(
                                                  color: primary.withOpacity(0.30),
                                                  blurRadius: 14,
                                                  spreadRadius: 1.0,
                                                ),
                                              if (flash)
                                                BoxShadow(
                                                  color: primary.withOpacity(0.55),
                                                  blurRadius: 22,
                                                  spreadRadius: 2.0,
                                                ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Container(
                                              width: 8.h,
                                              height: 8.h,
                                              decoration: BoxDecoration(
                                                color: primary,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ]);
                                  },
                                ),
                                // Center overlay removed for cleaner look
                                const SizedBox.shrink(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            )),
          ]),
          // Estimated time moved below "Today's Recommendations" header
        ],
      ),
    );
  }

  Widget _buildRecommendationsSection() {
    // Determine daily completion state for RESOURCE and TIP to show subtle status
    final comp = (_todayData?['completedToday'] as Map?)?.cast<String, bool>() ?? const {};
    final bool resDone = _qResId != null ? (comp[_qResId!] ?? false) : false;
    final bool tipDone = _qTipId != null ? (comp[_qTipId!] ?? false) : false;
    // Pull durations for tasks from today's selection for accurate display
    final int? _task1Dur = _durationFor(_qTask1Id);
    final int? _task2Dur = _durationFor(_qTask2Id);
  return Padding(
        padding: EdgeInsets.symmetric(horizontal: 70.h).copyWith(bottom: 32.h),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Today\'s Recommendations',
              style: TextStyleHelper.instance.display32BoldInter.copyWith(
                  fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                  color: Color(0xFF4A5261))),
          SizedBox(height: 8.h),
          Text(
            'Estimated time: 10 min',
            style: TextStyleHelper.instance.headline21Inter.copyWith(
                fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                color: Color(0xFF8C9CAA)),
          ),
          SizedBox(height: 20.h),
          // Card 1 (TASK)
          RecommendationCardWidget(
              containerKey: _task1CardKey,
              category: 'TASK',
              title: _task1Dur != null ? 'Focus reset (${_task1Dur} min)' : 'Focus reset',
              subtitle: (_task1Done && _task2Done)
                  ? 'All steps complete 🎉'
                  : 'Quick breathing + desk tidy',
              imagePath: 'assets/images/quests/task_focus.svg',
              doneImagePath: 'assets/images/quests/task_focus_done.svg',
              completed: _task1Done,
              onTap: () async {
                // One-and-done: ignore taps once completed (use Undo to revert)
                if (_task1Done) return;
                // Ensure engine is ready
                if (_questsEngine == null) {
                  await _initQuests();
                }
                // Must have a selected quest from today's items; do not fall back to a non-today ID
                final questId = _qTask1Id;
                if (questId == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Focus task not available today')),);
                  }
                  return;
                }
                final dur = _durationFor(questId);
                if (dur != null && dur > 0) {
                  await _openTimerSheet(questId: questId, cardKey: _task1CardKey, title: 'Focus reset', durationMin: dur);
                  return;
                }
                 if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Focus duration missing')),);
                 }
                 return;
              }),
          SizedBox(height: 24.h),
          // Card 2 (TASK) - show only when a second TASK exists today
          if (_qTask2Id != null)
            RecommendationCardWidget(
                containerKey: _task2CardKey,
                category: 'TASK',
                title: _task2Dur != null ? 'Study sprint (${_task2Dur} min)' : 'Study sprint',
                subtitle: 'Timer + no‑phone rule',
                imagePath: 'assets/images/quests/task_study.svg',
                doneImagePath: 'assets/images/quests/task_study_done.svg',
                completed: _task2Done,
                onTap: () async {
                  if (_task2Done) return; // one-and-done; use Undo to revert
                  // Ensure engine is ready
                  if (_questsEngine == null) {
                    await _initQuests();
                  }
                  final questId = _qTask2Id;
                  if (questId == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Study sprint not available today')),);
                    }
                    return;
                  }
                  final dur = _durationFor(questId);
                  if (dur != null && dur > 0) {
                    await _openTimerSheet(questId: questId, cardKey: _task2CardKey, title: 'Study sprint', durationMin: dur);
                    return;
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Study sprint duration missing')),);
                  }
                  return;
                }),
          SizedBox(height: 24.h),
          // Card 3 (RESOURCE)
          RecommendationCardWidget(
              containerKey: _resCardKey,
              category: 'RESOURCE',
              title: 'Calm music',
              subtitle: 'Lo‑fi playlist',
              imagePath: 'assets/images/quests/resource_headphone_match_v8.svg',
              doneImagePath: 'assets/images/quests/resource_headphone_match_v8_done.svg',
              completed: resDone,
              onTap: () async {
                HapticFeedback.lightImpact();
                SystemSound.play(SystemSoundType.click);
                // Resolve engine and quest ID
                if (_questsEngine == null) {
                  await _initQuests();
                }
                final engine = _questsEngine;
                final questId = _qResId;
                if (questId == null || engine == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Calm music not available today')),
                    );
                  }
                  return;
                }
                bool isDone = false;
                try { isDone = engine.isCompletedToday(questId); } catch (_) {}
                if (!isDone) {
                  // Completing: optional soft XP pop only on first use per day
                  if (_enableSoftXpPop && await _isFirstUseToday(_prefsResPopDate)) {
                    _showXpChipPop(_resCardKey, amount: 5);
                    await _markUsedToday(_prefsResPopDate);
                  }
                  try {
                    await engine.markImpression(questId);
                    await engine.markStart(questId);
                  } catch (_) {}
                  bool alreadyDone = false;
                  try { alreadyDone = engine.isCompletedToday(questId); } catch (_) {}
                  try { await engine.markComplete(questId); } catch (_) {}
                  // Sync lifetime XP immediately
                  try {
                    final lifetimeXp = engine.computeLifetimeXp();
                    if (mounted) context.read<ProgressProvider>().updateLifetimeXp(lifetimeXp);
                  } catch (_) {}
                  // Visual feedback
                  try { _showCheckRipple(_resCardKey); } catch (_) {}
                  // Telemetry: only on first award
                  try {
                    final awarded = !alreadyDone && engine.isCompletedToday(questId);
                    if (awarded) {
                      logAnalyticsEvent('quest_complete', metadata: {
                        'quest_id': questId,
                        'surface': 'wellness_dashboard',
                        'variant': 'today',
                        'tag': 'xp_awarded',
                        'ts': DateTime.now().millisecondsSinceEpoch,
                        'success': true,
                        'progress': 1.0,
                        'ui': 'today_resource',
                        'source': 'resource_used',
                      });
                    }
                  } catch (_) {}
                } else {
                  // Un-completing (toggle off)
                  try { await engine.uncompleteToday(questId); } catch (_) {}
                  // Sync lifetime XP after undo
                  try {
                    final lifetimeXp = engine.computeLifetimeXp();
                    if (mounted) context.read<ProgressProvider>().updateLifetimeXp(lifetimeXp);
                  } catch (_) {}
                  if (mounted) {
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      const SnackBar(duration: Duration(milliseconds: 1200), content: Text('Marked undone')),
                    );
                  }
                  try {
                    logAnalyticsEvent('quest_uncomplete', metadata: {
                      'quest_id': questId,
                      'surface': 'wellness_dashboard',
                      'variant': 'today',
                      'tag': 'toggle_undo',
                      'ts': DateTime.now().millisecondsSinceEpoch,
                      'ui': 'today_resource',
                      'source': 'resource_used',
                    });
                  } catch (_) {}
                }
                await _refreshToday();
                await _refreshExplore();
              }),
          SizedBox(height: 24.h),
          // Card 4 (TIP)
          RecommendationCardWidget(
              containerKey: _tipCardKey,
              category: 'TIP',
              title: 'One tiny step',
              subtitle: 'Pick the easiest task first',
              imagePath: 'assets/images/quests/tip_generic.svg',
              doneImagePath: 'assets/images/quests/tip_generic_done.svg',
              completed: tipDone,
              onTap: () async {
                HapticFeedback.lightImpact();
                SystemSound.play(SystemSoundType.click);
                // Resolve engine and quest ID
                if (_questsEngine == null) {
                  await _initQuests();
                }
                final engine = _questsEngine;
                final questId = _qTipId;
                if (questId == null || engine == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tip not available today')),
                    );
                  }
                  return;
                }
                bool isDone = false;
                try { isDone = engine.isCompletedToday(questId); } catch (_) {}
                if (!isDone) {
                  // Completing: optional soft XP pop only on first use per day
                  if (_enableSoftXpPop && await _isFirstUseToday(_prefsTipPopDate)) {
                    _showXpChipPop(_tipCardKey, amount: 5);
                    await _markUsedToday(_prefsTipPopDate);
                  }
                  try {
                    await engine.markImpression(questId);
                    await engine.markStart(questId);
                  } catch (_) {}
                  bool alreadyDone = false;
                  try { alreadyDone = engine.isCompletedToday(questId); } catch (_) {}
                  try { await engine.markComplete(questId); } catch (_) {}
                  // Sync lifetime XP immediately
                  try {
                    final lifetimeXp = engine.computeLifetimeXp();
                    if (mounted) context.read<ProgressProvider>().updateLifetimeXp(lifetimeXp);
                  } catch (_) {}
                  // Visual feedback
                  try { _showCheckRipple(_tipCardKey); } catch (_) {}
                  // Telemetry: only on first award
                  try {
                    final awarded = !alreadyDone && engine.isCompletedToday(questId);
                    if (awarded) {
                      logAnalyticsEvent('quest_complete', metadata: {
                        'quest_id': questId,
                        'surface': 'wellness_dashboard',
                        'variant': 'today',
                        'tag': 'xp_awarded',
                        'ts': DateTime.now().millisecondsSinceEpoch,
                        'success': true,
                        'progress': 1.0,
                        'ui': 'today_tip',
                        'source': 'tip_viewed',
                      });
                    }
                  } catch (_) {}
                } else {
                  // Un-completing (toggle off)
                  try { await engine.uncompleteToday(questId); } catch (_) {}
                  // Sync lifetime XP after undo
                  try {
                    final lifetimeXp = engine.computeLifetimeXp();
                    if (mounted) context.read<ProgressProvider>().updateLifetimeXp(lifetimeXp);
                  } catch (_) {}
                  if (mounted) {
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      const SnackBar(duration: Duration(milliseconds: 1200), content: Text('Marked undone')),
                    );
                  }
                  try {
                    logAnalyticsEvent('quest_uncomplete', metadata: {
                      'quest_id': questId,
                      'surface': 'wellness_dashboard',
                      'variant': 'today',
                      'tag': 'toggle_undo',
                      'ts': DateTime.now().millisecondsSinceEpoch,
                      'ui': 'today_tip',
                      'source': 'tip_viewed',
                    });
                  } catch (_) {}
                }
                await _refreshToday();
                await _refreshExplore();
              }),
          SizedBox(height: 24.h),
          // Card 5 (REMINDER) - themed toggle + change time
          Builder(
              builder: (context) {
              final near = _isReminderNear();
              final now = DateTime.now();
              // Fire telemetry on transition into near state (release + debug)
              final becameNear = near && (_lastReminderNear != true);
              if (becameNear) {
                final qid = _qTask1Id ?? _qTask2Id;
                try {
                  logAnalyticsEvent('quest_reminder_fired', metadata: {
                    if (qid != null) 'quest_id': qid,
                    'surface': 'wellness_dashboard',
                    'variant': 'today',
                    'tag': 'fired',
                    'ts': now.millisecondsSinceEpoch,
                    'ui': 'reminder_near',
                  });
                } catch (_) {}
              }
              // Update last-seen state always
              _lastReminderNear = near;
              // Keep debug prints throttled
              if (kDebugMode) {
                final shouldLog = (_lastReminderLogAt == DateTime.fromMillisecondsSinceEpoch(0)) ||
                    (now.difference(_lastReminderLogAt).inSeconds >= 60) || becameNear;
                if (shouldLog) {
                  debugPrint('[Reminder][near] now=$near on=$_reminderOn time=${_reminderTime.format(context)}');
                  _lastReminderLogAt = now;
                }
              }
              if (near && !_pulseController.isAnimating) {
                _pulseController.repeat(reverse: true);
              } else if (!near && _pulseController.isAnimating) {
                _pulseController.stop();
              }
              final primary = Theme.of(context).colorScheme.primary;
              final borderBase = const Color(0xFFF4F5F7);
              final borderColor = near
                  ? Color.lerp(borderBase, primary, 0.6 + 0.4 * _pulseController.value)!
                  : borderBase;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: _reminderOn ? const Color(0xFFF4F1FF) : const Color(0xFFFEFEFE),
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(29.h),
                  boxShadow: _reminderOn
                      ? [
                          BoxShadow(
                            color: primary.withOpacity(0.12),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : [],
                ),
                padding: EdgeInsets.all(28.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'REMINDER',
                                style: TextStyleHelper.instance.title19BoldInter.copyWith(
                                  fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                                  color: const Color(0xFF8E98A7),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _reminderOn = !_reminderOn;
                                    _startMicrocopyRotation();
                                  });
                                  _saveReminderPrefs();
                                  // Apply scheduling change immediately
                                  _rescheduleReminder('toggle');
                                  if (kDebugMode) {
                                    debugPrint('[Reminder][toggle] on=$_reminderOn');
                                  }
                                  // Microinteraction: subtle ripple on toggle change
                                  HapticFeedback.lightImpact();
                                  SystemSound.play(SystemSoundType.click);
                                  _showCheckRipple(_reminderToggleKey);
                                  // Telemetry: quest_reminder_toggle
                                  final qid = _qTask1Id ?? _qTask2Id;
                                  try {
                                    logAnalyticsEvent('quest_reminder_toggle', metadata: {
                                      if (qid != null) 'quest_id': qid,
                                      'surface': 'wellness_dashboard',
                                      'variant': 'today',
                                      'tag': _reminderOn ? 'toggle_on' : 'toggle_off',
                                      'ts': DateTime.now().millisecondsSinceEpoch,
                                      'ui': 'reminder_toggle',
                                    });
                                  } catch (_) {}
                                },
                                child: Container(
                                  key: _reminderToggleKey,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    width: 56.h,
                                    height: 30.h,
                                    padding: EdgeInsets.symmetric(horizontal: 4.h, vertical: 4.h),
                                    decoration: BoxDecoration(
                                      color: _reminderOn ? Theme.of(context).colorScheme.primary : const Color(0xFFE6EAF0),
                                      borderRadius: BorderRadius.circular(20.h),
                                      boxShadow: _reminderOn
                                          ? [
                                              BoxShadow(
                                                color: Theme.of(context).colorScheme.primary.withOpacity(0.35),
                                                blurRadius: 14,
                                                spreadRadius: 1,
                                                offset: const Offset(0, 3),
                                              )
                                            ]
                                          : [],
                                    ),
                                    child: AnimatedAlign(
                                      duration: const Duration(milliseconds: 220),
                                      curve: Curves.easeOutCubic,
                                      alignment: _reminderOn ? Alignment.centerRight : Alignment.centerLeft,
                                      child: AnimatedScale(
                                        duration: const Duration(milliseconds: 160),
                                        curve: Curves.easeOutBack,
                                        scale: _reminderOn ? 1.0 : 0.96,
                                        child: Container(
                                          width: 22.h,
                                          height: 22.h,
                                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                          child: _reminderOn
                                              ? Icon(Icons.check, size: 16.h, color: Theme.of(context).colorScheme.primary)
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _formatReminderTime(_reminderTime),
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyleHelper.instance.headline26BoldInter.copyWith(
                                          fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                                          color: _reminderOn ? const Color(0xFF4C5664) : const Color(0xFFB8C0CC),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: _isTomorrowLabel(_reminderTime) ? 8.h : 0),
                                    _isTomorrowLabel(_reminderTime)
                                        ? Text(
                                            'tomorrow',
                                            style: TextStyleHelper.instance.headline21Inter.copyWith(
                                              fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                                              color: const Color(0xFF8E98A7),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8.h),
                              OutlinedButton.icon(
                                key: _reminderTimeKey,
                                onPressed: _reminderOn
                                    ? () async {
                                        final picked = await showTimePicker(
                                          context: context,
                                          initialTime: _reminderTime,
                                          builder: (context, child) {
                                            return Theme(data: Theme.of(context), child: child!);
                                          },
                                        );
                                        if (!mounted) return;
                                        if (picked != null) {
                                          setState(() {
                                            _reminderTime = picked;
                                            _reminderOn = true;
                                          });
                                          _saveReminderPrefs();
                                          // Reschedule to new time immediately
                                          _rescheduleReminder('time_changed');
                                          if (kDebugMode) {
                                            debugPrint('[Reminder][timeChanged] to=${_formatReminderTime(_reminderTime)}');
                                          }
                                          // Microinteraction: confirmation ring + haptics
                                          HapticFeedback.selectionClick();
                                          SystemSound.play(SystemSoundType.click);
                                          _showTimerRing(_reminderTimeKey);
                                          // Telemetry: quest_reminder_toggle (time changed)
                                          final qid = _qTask1Id ?? _qTask2Id;
                                          try {
                                            logAnalyticsEvent('quest_reminder_toggle', metadata: {
                                              if (qid != null) 'quest_id': qid,
                                              'surface': 'wellness_dashboard',
                                              'variant': 'today',
                                              'tag': 'time_changed',
                                              'ts': DateTime.now().millisecondsSinceEpoch,
                                              'ui': 'reminder_time',
                                            });
                                          } catch (_) {}
                                        }
                                      }
                                    : null,
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(horizontal: 12.h, vertical: 0),
                                  minimumSize: Size(0, 30.h), // match toggle height
                                  side: BorderSide(
                                    color: _reminderOn ? Theme.of(context).colorScheme.primary : const Color(0xFFB8C0CC),
                                  ),
                                  foregroundColor: _reminderOn ? Theme.of(context).colorScheme.primary : const Color(0xFFB8C0CC),
                                  shape: const StadiumBorder(),
                                ),
                                icon: Icon(Icons.edit, size: 18.h),
                                label: Text(
                                  'Change',
                                  style: TextStyleHelper.instance.headline21Inter.copyWith(
                                    fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                                    fontSize: 12.h,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _reminderOn ? _microcopy[_microIndex] : 'Nudge me to finish the quest',
                              key: ValueKey(_microIndex.toString() + _reminderOn.toString()),
                              style: TextStyleHelper.instance.headline21Inter.copyWith(
                                fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                                color: const Color(0xFFA8B1BF),
                              ),
                            ),
                          ),
                          
                        ],
                      ),
                    ),
                    // Removed right-side image to give space for time + tomorrow label
                    ],
                  ),
                );
            },
          ),
        ]));
  }

  // Utility: title-case a string for category display
  String _titleCase(String input) {
    if (input.isEmpty) return input;
    final normalized = input.replaceAll('_', ' ').replaceAll('-', ' ');
    final parts = normalized.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return parts
        .map((w) => w.substring(0, 1).toUpperCase() + (w.length > 1 ? w.substring(1).toLowerCase() : ''))
        .join(' ');
  }

  // Explore: minimal gating helper for awarding XP with daily "energy"
  Future<void> _handleExploreComplete(String questId) async {
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
    final engine = _questsEngine;
    if (engine == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please try again')),
      );
      return;
    }
    try {
      // Derive quest meta for clearer telemetry (TIP vs RESOURCE, etc.)
      String questTag = 'unknown';
      String questCategory = '';
      try {
        final meta = engine.listAll().firstWhere((q) => q.id == questId);
        questTag = meta.tag.name;
        questCategory = (meta.category ?? '').toLowerCase();
      } catch (_) {}
      if (kDebugMode) { try { debugPrint('[Explore][Meta] questId='+questId+' quest_tag='+questTag+' category='+questCategory); } catch (_) {} }
      if (kDebugMode) { try { debugPrint('[Explore][Tap] questId=$questId -> impression/start'); } catch (_) {} }
      await engine.markImpression(questId);
      await engine.markStart(questId);
      if (kDebugMode) { try { debugPrint('[Explore][Award] tryAwardExplore questId=$questId'); } catch (_) {} }
      final awarded = await engine.tryAwardExplore(questId);

      // Immediate UI refresh so energy pill decrements without delay
      if (mounted) setState(() {});

      // Figure out reason for no award
      String reason = awarded ? 'energy_spent' : 'unknown';
      if (!awarded) {
        if (engine.isCompletedToday(questId)) {
          reason = 'already_completed_today';
        } else if (engine.exploreEnergyLeft() <= 0) {
          reason = 'no_energy';
        }
      }
      if (kDebugMode) { try { debugPrint('[Explore][Result] questId=$questId awarded=$awarded reason=$reason energy_left=${engine.exploreEnergyLeft()}'); } catch (_) {} }

      // Telemetry: quest_complete with success + reason
      try {
        logAnalyticsEvent('quest_complete', metadata: {
          'quest_id': questId,
          'surface': 'wellness_dashboard',
          'variant': 'explore',
          'tag': awarded ? 'xp_awarded' : 'no_xp',
          'quest_tag': questTag,
          'category': questCategory,
          'ts': DateTime.now().millisecondsSinceEpoch,
          'success': awarded,
          'reason': reason,
          'ui': 'explore_legacy',
        });
      } catch (_) {}

      // Update Explore UI 'Done' state only when XP was actually awarded here
      if (awarded) {
        _exploreCompletedToday.add(questId);
        if (mounted) setState(() {});
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (awarded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(duration: Duration(milliseconds: 1400), content: Text('XP awarded')),
        );
      } else {
        final msg = (reason == 'no_energy')
            ? 'No XP remaining for Explore today'
            : (reason == 'already_completed_today')
                ? 'Already counted today'
                : 'No XP awarded';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(duration: const Duration(milliseconds: 1400), content: Text(msg)),
        );
      }

      // Sync lifetime XP and refresh energy pill
      try {
        final lifetimeXp = engine.computeLifetimeXp();
        if (mounted) context.read<ProgressProvider>().updateLifetimeXp(lifetimeXp);
      } catch (_) {}
      // Sync Today tab progress (steps/xp) after Explore award
      try {
        final data = await engine.getTodayData();
        final prog = (data['progress'] as Map?)?.cast<String, dynamic>() ?? const {};
        final stepsLeft = (prog['stepsLeft'] ?? 0) as int;
        final xpEarned = (prog['xpEarned'] ?? 0) as int;
        if (mounted) {
          context.read<ProgressProvider>()
              .updateFromQuests(stepsLeft: stepsLeft, xpEarned: xpEarned);
        }
        // Also update lifetime XP immediately for Explore header
        try {
          final lifetimeXp = engine.computeLifetimeXp();
          if (mounted) context.read<ProgressProvider>().updateLifetimeXp(lifetimeXp);
          if (kDebugMode) { try { debugPrint('[Explore][XP] lifetimeXp='+lifetimeXp.toString()); } catch (_) {} }
        } catch (_) {}
      } catch (_) {}
      if (mounted) setState(() {});
    } catch (e) {
      if (kDebugMode) debugPrint('[Explore][ERROR] $e');
    }
  }

  // Segmented control for Today | Explore
  Widget _buildTabSwitcher() {
    Widget segButton(String label, int index) {
      final bool selected = _tabIndex == index;
      final Color primary = Theme.of(context).colorScheme.primary;
      return InkWell(
        borderRadius: BorderRadius.circular(22.h),
        onTap: () {
          if (_tabIndex == index) return;
          HapticFeedback.selectionClick();
          SystemSound.play(SystemSoundType.click);
          if (kDebugMode) { try { debugPrint('[Tabs] switch to index=$index -> clearing pill'); } catch (_) {} }
          _removeTimerPill();
          setState(() { _tabIndex = index; });
          // Telemetry: log Explore tab view
          if (index == 1) {
            try {
              logAnalyticsEvent('quest_view', metadata: {
                'surface': 'wellness_dashboard',
                'variant': 'explore',
                'tag': 'explore_tab',
                'ts': DateTime.now().millisecondsSinceEpoch,
                'ui': 'tab_switch',
              });
            } catch (_) {}
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(horizontal: 16.h, vertical: 12.h),
          decoration: BoxDecoration(
            color: selected ? primary : Colors.white,
            borderRadius: BorderRadius.circular(22.h),
            border: Border.all(color: const Color(0xFFE0E6EE)),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: primary.withOpacity(0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyleHelper.instance.headline21Inter.copyWith(
                fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                color: selected ? Colors.white : const Color(0xFF47505E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.h),
      child: Row(
        children: [
          Expanded(child: segButton('Today', 0)),
          SizedBox(width: 12.h),
          Expanded(child: segButton('Discover', 1)),
        ],
      ),
    );
  }

  // Explore tab content (header + category filters + placeholder grid)
  Widget _buildExploreSection() {
    final pp = context.watch<ProgressProvider>();
    final List<String> cats = <String>{'All', ..._exploreCats}.toList();
    final List<String> visible = _exploreFilter == 'All'
        ? _exploreCats
        : _exploreCats.where((c) => c == _exploreFilter).toList();
    // Keep XP display consistent with Today tab (use provider's xpEarned)
    final int xpToday = pp.xpEarned;
    final int lifetimeXp = pp.lifetimeXp;
    // Streak values for header
    final engineForHeader = _questsEngine;
    final int streakDays = engineForHeader?.computeFriendlyDailyStreak() ?? 0;
    final int recordStreak = engineForHeader?.computeRecordDailyStreak() ?? 0;
    // Responsive tweaks
    final double _w = MediaQuery.of(context).size.width;
    final bool _narrow = _w < 420;
    final String _dayWord = streakDays == 1 ? 'day' : 'days';
    final String _recordLabel = _narrow ? 'rec' : 'record';
    final double _whiteBlur = _narrow ? 8 : 10;
    final double _whiteAlpha = _narrow ? 0.05 : 0.06;
    final double _xpBlur = _narrow ? 10 : 12;
    final double _xpAlpha = _narrow ? 0.14 : 0.18;

    // Responsive horizontal padding: tighter on narrow screens
    final double hp = _w >= 900 ? 70.h : 16.h;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hp).copyWith(top: 48.h, bottom: 32.h),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Category chips + compact metrics on the same row
        Builder(builder: (context) {
          final int energyLeft = _questsEngine?.exploreEnergyLeft() ?? 0;
          const int energyLimit = QuestsEngine.exploreDailyLimit;
          final bool energyEmpty = energyLeft <= 0;
          final Color energyFg = energyEmpty ? const Color(0xFF8C9CAA) : Theme.of(context).colorScheme.primary;
          // Tighten spacing for very narrow widths
          final double chipHPad = _narrow ? 8.h : 10.h;
          final double chipVPad = _narrow ? 4.h : 6.h;
          final double iconSize = _narrow ? 14 : 16;
          final double iconGap = _narrow ? 4.h : 6.h;
          final double wrapSpacing = _narrow ? 6.h : 8.h;
          final double groupGap = _narrow ? 6.h : 8.h;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: category chips (wrap)
              Expanded(
                child: Wrap(
                  spacing: wrapSpacing,
                  runSpacing: wrapSpacing,
                  children: cats.map((cat) {
                    final bool selected = _exploreFilter == cat;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: selected,
                      onSelected: (_) { setState(() { _exploreFilter = cat; }); },
                      labelStyle: TextStyleHelper.instance.headline21Inter.copyWith(
                        fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                        color: selected ? Colors.white : const Color(0xFF47505E),
                      ),
                      selectedColor: Theme.of(context).colorScheme.primary,
                      backgroundColor: Colors.white,
                      shape: const StadiumBorder(side: BorderSide(color: Color(0xFFE0E6EE))),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.symmetric(horizontal: chipHPad, vertical: chipVPad),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(width: groupGap),
              // Right: compact metrics (Energy, Streak, +XP)
              Flexible(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Wrap(
                    spacing: wrapSpacing,
                    runSpacing: wrapSpacing,
                    alignment: WrapAlignment.end,
                    children: [
                      // Standardize chip height to avoid mismatched sizes across metrics
                      // and ensure internal text never wraps.
                      // Keep this in sync with chip padding and font sizes.
                      // Narrow: slightly smaller height.

                      // Energy: flash + 3/3
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: chipHPad, vertical: chipVPad),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18.h),
                          border: Border.all(color: const Color(0xFFE0E6EE)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(_whiteAlpha),
                              blurRadius: _whiteBlur,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        constraints: BoxConstraints(minHeight: _narrow ? 30.h : 34.h),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.flash_on_outlined, size: iconSize, color: energyFg),
                          SizedBox(width: iconGap),
                          Flexible(
                            child: Text(
                              '$energyLeft/$energyLimit',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyleHelper.instance.titleMediumInter.copyWith(color: energyFg, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ]),
                      ),
                      // Streak: flame + 2d
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: chipHPad, vertical: chipVPad),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18.h),
                          border: Border.all(color: const Color(0xFFE0E6EE)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(_whiteAlpha),
                              blurRadius: _whiteBlur,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        constraints: BoxConstraints(
                          minHeight: _narrow ? 30.h : 34.h,
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.local_fire_department_outlined, size: iconSize, color: Theme.of(context).colorScheme.primary),
                          SizedBox(width: iconGap),
                          Flexible(
                            child: Text(
                              '${streakDays}d',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyleHelper.instance.titleMediumInter.copyWith(color: const Color(0xFF47505E), fontWeight: FontWeight.w700),
                            ),
                          ),
                        ]),
                      ),
                      // XP: star + "+today" (chip flexes to content; wraps with others when needed)
                      Container(
                        key: _xpCardKey,
                        padding: EdgeInsets.symmetric(horizontal: chipHPad, vertical: chipVPad),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(18.h),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withOpacity(_xpAlpha),
                              blurRadius: _xpBlur,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        constraints: BoxConstraints(
                          minHeight: _narrow ? 30.h : 34.h,
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.star_rounded, color: Colors.white, size: iconSize),
                          SizedBox(width: iconGap),
                          Flexible(
                            child: Text(
                              '+$xpToday',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyleHelper.instance.titleMediumInter.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
        SizedBox(height: _narrow ? 16.h : 20.h),

        // Dynamic Explore quest cards from catalog filtered by category
        Builder(builder: (context) {
          final engine = _questsEngine;
          if (engine == null) {
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 20.h, vertical: 18.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.h),
                border: Border.all(color: const Color(0xFFE0E6EE)),
              ),
              child: Text(
                'Loading quests…',
                textAlign: TextAlign.center,
                style: TextStyleHelper.instance.headline21Inter.copyWith(
                  fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                  color: const Color(0xFF8C9CAA),
                ),
              ),
            );
          }

          // Category filter => lowercase for engine
          final List<Quest> raw = (_exploreFilter == 'All')
              ? engine.listActive()
              : engine.listByCategory(_exploreFilter.toLowerCase());
          // Explore-only hide flag: filter out quests marked hidden for Explore surface
          final List<Quest> items = raw.where((q) => !q.hideInExplore).toList();

          // Best-effort: mark impressions once per quest when first shown
          WidgetsBinding.instance.addPostFrameCallback((_) {
            for (final q in items) {
              if (_impressedExplore.add(q.id)) {
                try { engine.markImpression(q.id); } catch (_) {}
                try {
                  logAnalyticsEvent('quest_view', metadata: {
                    'quest_id': q.id,
                    'tag': q.tag.name,
                    'category': (q.category ?? '').toLowerCase(),
                    'surface': 'wellness_dashboard',
                    'variant': 'explore',
                    'ts': DateTime.now().millisecondsSinceEpoch,
                    'ui': 'explore',
                  });
                } catch (_) {}
              }
            }
          });

          if (items.isEmpty) {
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 20.h, vertical: 18.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.h),
                border: Border.all(color: const Color(0xFFE0E6EE)),
              ),
              child: Text(
                'No quests available',
                textAlign: TextAlign.center,
                style: TextStyleHelper.instance.headline21Inter.copyWith(
                  fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                  color: const Color(0xFF8C9CAA),
                ),
              ),
            );
          }

          IconData iconFor(Quest q) {
            final c = (q.category ?? '').toLowerCase();
            switch (c) {
              case 'mindfulness':
                return Icons.self_improvement_outlined;
              case 'activity':
                return Icons.directions_walk;
              case 'social':
                return Icons.forum_outlined;
              case 'learning':
                return Icons.school_outlined;
              case 'challenge':
                return Icons.flag_outlined;
            }
            switch (q.tag) {
              case QuestTag.task:
                return Icons.check_circle_outline;
              case QuestTag.tip:
                return Icons.lightbulb_outline;
              case QuestTag.resource:
                return Icons.menu_book_outlined;
              case QuestTag.reminder:
                return Icons.alarm_outlined;
              case QuestTag.checkin:
                return Icons.favorite_border;
              case QuestTag.progress:
                return Icons.trending_up_outlined;
            }
          }

          Color colorFor(Quest q) {
            final c = (q.category ?? '').toLowerCase();
            switch (c) {
              case 'mindfulness':
                return Colors.teal;
              case 'activity':
                return Colors.green;
              case 'social':
                return Colors.indigo;
              case 'learning':
                return Colors.deepPurple;
              case 'challenge':
                return Colors.redAccent;
            }
            switch (q.tag) {
              case QuestTag.task:
                return Theme.of(context).colorScheme.primary;
              case QuestTag.tip:
                return Colors.orange;
              case QuestTag.resource:
                return Colors.blue;
              case QuestTag.reminder:
                return Colors.pink;
              case QuestTag.checkin:
                return Colors.cyan;
              case QuestTag.progress:
                return Colors.amber;
            }
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              final q = items[index];
              // Reflect actual same-day completion using engine state; also treat v1/v2 variants as equivalent
              final engine = _questsEngine;
              String? otherVariant;
              if (q.id.endsWith('_v1')) {
                otherVariant = q.id.replaceFirst('_v1', '_v2');
              } else if (q.id.endsWith('_v2')) {
                otherVariant = q.id.replaceFirst('_v2', '_v1');
              }
              bool doneToday = false;
              if (engine != null) {
                try {
                  doneToday = engine.isCompletedToday(q.id) || (otherVariant != null && engine.isCompletedToday(otherVariant));
                } catch (_) {}
              }
              // Also consider session-only completions so UI updates instantly after tap
              if (!doneToday) {
                doneToday = _exploreCompletedToday.contains(q.id) || (otherVariant != null && _exploreCompletedToday.contains(otherVariant));
              }
              final double? progress = doneToday ? 1.0 : null;

              return QuestCardWidget(
                title: q.title,
                subtitle: q.subtitle.isNotEmpty ? q.subtitle : null,
                icon: iconFor(q),
                color: colorFor(q),
                progress: progress,
                onTap: () {
                  try {
                    logAnalyticsEvent('quest_start', metadata: {
                      'quest_id': q.id,
                      'tag': q.tag.name,
                      'category': (q.category ?? '').toLowerCase(),
                      'surface': 'wellness_dashboard',
                      'variant': 'explore',
                      'ts': DateTime.now().millisecondsSinceEpoch,
                      if (q.durationMin != null) 'duration_min': q.durationMin,
                      if (progress != null) 'progress': progress,
                      'ui': 'explore',
                    });
                  } catch (_) {}
                  _handleExploreComplete(q.id);
                },
              );
            },
          );
        }),
      ]),
    );
  }

}
