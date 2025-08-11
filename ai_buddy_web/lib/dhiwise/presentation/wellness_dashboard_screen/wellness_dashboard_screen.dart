import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../../core/app_export.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_image_view.dart';
import './widgets/progress_card_widget.dart';
import './widgets/recommendation_card_widget.dart';
import '../../../widgets/app_bottom_nav.dart';
import '../../../theme/text_style_helper.dart' as CoreTextStyles;
import '../../../widgets/assessment_splash.dart';
import '../../../quests/quests_engine.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:provider/provider.dart';
import '../../../providers/progress_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  WellnessDashboardScreen({Key? key}) : super(key: key);

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
    with TickerProviderStateMixin {
  // UI-only state for TASK completion and progress
  bool _task1Done = false; // Focus reset
  bool _task2Done = false; // Study sprint
  int _baseSteps = 2; // total tasks today
  int _baseXp = 20; // base example XP shown initially
  bool _reminderOn = true; // UI-only reminder toggle (default ON)
  TimeOfDay _reminderTime = const TimeOfDay(hour: 19, minute: 0);

  // Optional microinteraction flags (must be explicitly enabled)
  bool _enableSoftXpPop = true; // enabled per user approval
  // Reminder microinteraction anchors
  final GlobalKey _reminderToggleKey = GlobalKey();
  final GlobalKey _reminderTimeKey = GlobalKey();

  // Timer pill overlay state
  OverlayEntry? _timerPillEntry;
  Timer? _timerPillTicker;
  DateTime? _timerPillEndAt;
  String? _timerPillQuestId;

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

  // Guard to ensure chip pop occurs only once per task per session
  bool _task1Popped = false;
  bool _task2Popped = false;

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
  // ignore: unused_field
  QuestsEngine? _questsEngine;
  // ignore: unused_field
  Map<String, dynamic>? _todayData; // {'todayItems': List<Quest>, 'progress': {stepsLeft, xpEarned}}
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
  // Removed unused debug-only helpers and constants post-verification

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
    final overlayState = Overlay.of(context, rootOverlay: true);
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
    }
    if (kDebugMode) {
      try {
        final comp = (data['completedToday'] as Map?)?.cast<String, bool>() ?? const {};
        final prog = (data['progress'] as Map?)?.cast<String, dynamic>() ?? const {};
        debugPrint('[Quests][REFRESH] comp=${comp.toString()} progress=${prog.toString()}');
      } catch (_) {}
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
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final ms = nextMidnight.difference(now).inMilliseconds;
    _midnightTimer = Timer(Duration(milliseconds: ms.clamp(1000, 86400000)), () async {
      await _refreshToday();
      _scheduleMidnightRefresh();
    });
  }

  @override
  void dispose() {
    _removeTimerPill();
    _microTimer?.cancel();
    _midnightTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
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
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _startMicrocopyRotation();
    // Initialize asynchronously: reminder prefs, quests data, and midnight refresh
    Future.microtask(() async {
      await _loadReminderPrefs();
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
  }

  // Start a floating timer pill anchored near the given card.
  void _startTimerPill({required GlobalKey cardKey, required String questId, required Duration total}) {
    _removeTimerPill();
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    final centerGlobal = _globalCenterOf(cardKey);
    if (overlayBox == null || !overlayBox.attached || centerGlobal == null) return;
    final centerLocal = overlayBox.globalToLocal(centerGlobal);
    _timerPillQuestId = questId;
    _timerPillEndAt = DateTime.now().add(total);
    final controller = reduceMotion
        ? null
        : (AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true));
    final scaleAnim = controller == null
        ? const AlwaysStoppedAnimation<double>(1.0)
        : Tween<double>(begin: 0.98, end: 1.02).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: ShapeDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: const StadiumBorder(),
                shadows: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Text(
                txt,
                style: TextStyleHelper.instance.titleMediumInter.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      );
    });
    overlay.insert(_timerPillEntry!);
    _timerPillTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_timerPillEndAt == null) return;
      if (DateTime.now().isAfter(_timerPillEndAt!)) {
        _removeTimerPill(forQuestId: questId);
      } else {
        _timerPillEntry?.markNeedsBuild();
      }
    });
    controller?.addStatusListener((_) {});
  }

  void _removeTimerPill({String? forQuestId}) {
    if (forQuestId != null && _timerPillQuestId != null && _timerPillQuestId != forQuestId) return;
    _timerPillTicker?.cancel();
    _timerPillTicker = null;
    _timerPillEndAt = null;
    _timerPillQuestId = null;
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
              Row(children: [
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    try {
                      await _questsEngine?.startTimer(questId);
                    } catch (_) {}
                    HapticFeedback.lightImpact();
                    SystemSound.play(SystemSoundType.click);
                    _showTimerRing(cardKey);
                    _startTimerPill(cardKey: cardKey, questId: questId, total: Duration(minutes: durationMin));
                    Future.delayed(Duration(minutes: durationMin), () async {
                      if (!mounted) return;
                      try {
                        await _questsEngine?.autoCompleteTimer(questId, durationMin);
                        await _questsEngine?.markComplete(questId);
                        if (_enableSoftXpPop) _showXpChipPop(cardKey, amount: 10);
                      } catch (_) {}
                      _removeTimerPill(forQuestId: questId);
                      await _refreshToday();
                      // Offer Undo after auto-complete
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
                                await _refreshToday();
                              },
                            ),
                          ),
                        );
                      }
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Timer started for $durationMin min')),
                      );
                    }
                  },
                  child: Text('Start ${durationMin} min'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () async {
                    // Close the bottom sheet first so SnackBar is visible
                    Navigator.of(ctx).pop();
                    try {
                      await _questsEngine?.markStart(questId);
                      await _questsEngine?.markComplete(questId);
                      if (_enableSoftXpPop) _showXpChipPop(cardKey, amount: 10);
                      _showCheckRipple(cardKey);
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
                              await _refreshToday();
                            },
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Complete now'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
              ]),
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
    final overlayState = Overlay.of(context, rootOverlay: true);
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

    final overlayState = Navigator.of(context).overlay ?? Overlay.of(context, rootOverlay: true);

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
    return Sizer(builder: (context, orientation, deviceType) {
      return SafeArea(
          child: Scaffold(
            body: Stack(children: [
              // Background Image (use full viewport like chat/mood)
              CustomImageView(
                  imagePath: ImageConstant.imgBackground1440x6351,
                  height: MediaQuery.of(context).size.height,
                  width: MediaQuery.of(context).size.width,
                  fit: BoxFit.cover),

              // Content (full viewport sizing)
              Container(
                  height: MediaQuery.of(context).size.height,
                  width: MediaQuery.of(context).size.width,
                  child: Stack(children: [
                    // Side Background
                    Positioned(
                        left: 0,
                        top: 0,
                        child: CustomImageView(
                            imagePath: ImageConstant.imgBackground,
                            height: 635.h,
                            width: 3.h,
                            fit: BoxFit.cover)),

                    // Main Content
                    SingleChildScrollView(
                        child: Padding(
                            padding: EdgeInsets.all(
                                0), // Modified: Added required padding parameter
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildHeaderSection(),
                                  _buildMoodCheckInSection(),
                                  _buildProgressSection(),
                                  _buildRecommendationsSection(),
                                ]))),

                    // Bottom Background
                    Positioned(
                        bottom: 0,
                        left: 0,
                        child: CustomImageView(
                            imagePath: ImageConstant.imgBackground13x635,
                            height: 13.h,
                            width: MediaQuery.of(context).size.width,
                            fit: BoxFit.cover)),
                  ])),
            ]),
            bottomNavigationBar: const AppBottomNav(current: AppTab.quest)));
    });
  }

  Widget _buildHeaderSection() {
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 28.h, vertical: 32.h),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [
        // Header renamed per PDF priorities
        Text('Today\'s Quest',
            style: CoreTextStyles.TextStyleHelper.instance.headline24Bold
                .copyWith(color: Color(0xFF47505E))),
        SizedBox(width: 12.h),
        CustomImageView(
            imagePath: ImageConstant.imgImage43x43,
            height: 43.h,
            width: 43.h),
          ]),
          GestureDetector(
              onTap: () {
                // Handle settings click
              },
              child: Container(
                  height: 38.h,
                  width: 38.h,
                  child: CustomImageView(
                      imagePath: ImageConstant.imgImage38x38,
                      height: 38.h,
                      width: 38.h,
                      fit: BoxFit.cover))),
        ]));
  }

  Widget _buildMoodCheckInSection() {
    return Container(
        margin: EdgeInsets.symmetric(horizontal: 70.h)
            .copyWith(top: 64.h, bottom: 32.h),
        decoration: BoxDecoration(
            color: Color(0xFFE3ECEF),
            borderRadius: BorderRadius.circular(28.h)),
        padding: EdgeInsets.symmetric(horizontal: 32.h, vertical: 44.h),
        child: Column(children: [
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
          CustomButton(
              text: 'Start',
              backgroundColor: Colors.white,
              textColor: Color(0xFF5A616F),
              borderColor: Color(0xFFF1F5F7),
              showBorder: true,
              padding: EdgeInsets.symmetric(horizontal: 48.h, vertical: 24.h),
              borderRadius: 37.h,
              textStyle: TextStyleHelper.instance.headline25BoldInter.copyWith(
                  fontFamily: CoreTextStyles
                      .TextStyleHelper.instance.headline24Bold.fontFamily),
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: false, // keep user on quest screen; use X to close
                  builder: (ctx) => const AssessmentSplash(),
                );
              }),
        ]));
  }

  Widget _buildProgressSection() {
    // Prefer engine-backed values via ProgressProvider once today data is loaded; fallback to UI-only
    final pp = context.watch<ProgressProvider>();
    final bool hasEngineData = _todayData != null;
    final int completedLocal = (_task1Done ? 1 : 0) + (_task2Done ? 1 : 0);
    final int stepsLeft = hasEngineData
        ? pp.stepsLeft
        : (_baseSteps - completedLocal).clamp(0, _baseSteps);
    final int xpEarned = hasEngineData
        ? pp.xpEarned
        : (_baseXp + (completedLocal * 10));
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 70.h).copyWith(bottom: 32.h),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your Progress',
              style: TextStyleHelper.instance.display31BoldInter.copyWith(
                  fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                  color: Color(0xFF444D5C))),
          SizedBox(height: 28.h),
          Row(children: [
            Expanded(
                child: ProgressCardWidget(
                    imagePath: ImageConstant.imgImage65x52,
                    value: '$stepsLeft',
                    label: 'Steps Left',
                    backgroundColor: Color(0xFFE0F2E9),
                    valueWidget: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                      child: Text(
                        '$stepsLeft',
                        key: ValueKey<int>(stepsLeft),
                        style: TextStyleHelper.instance.headline28BoldInter.copyWith(
                          fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                          color: const Color(0xFF4E5965),
                        ),
                      ),
                    ))),
            SizedBox(width: 24.h),
            Expanded(
                child: Container(
                  key: _xpCardKey,
                  child: ProgressCardWidget(
                      imagePath: ImageConstant.imgImage63x65,
                      value: '+$xpEarned',
                      label: 'XP Earned',
                      backgroundColor: Color(0xFFE8E7F8),
                      valueWidget: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                        child: Text(
                          '+$xpEarned',
                          key: ValueKey<int>(xpEarned),
                          style: TextStyleHelper.instance.headline28BoldInter.copyWith(
                            fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                            color: const Color(0xFF4E5965),
                          ),
                        ),
                      )),
                )),
          ]),
          SizedBox(height: 12.h),
          // Compute duration locally for the header estimate to avoid scope issues
          Builder(builder: (context) {
            final int? _localTask1Dur = _durationFor(_qTask1Id);
            return Text(_localTask1Dur != null ? 'Estimated time: ${_localTask1Dur} min' : 'Estimated time',
              style: TextStyleHelper.instance.headline21Inter.copyWith(
                  fontFamily: CoreTextStyles
                      .TextStyleHelper.instance.headline24Bold.fontFamily,
                  color: Color(0xFF8C9CAA)));
          }),
        ]));
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
        padding: EdgeInsets.symmetric(horizontal: 69.h).copyWith(bottom: 32.h),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Today\'s Recommendations',
              style: TextStyleHelper.instance.display32BoldInter.copyWith(
                  fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                  color: Color(0xFF4A5261))),
          SizedBox(height: 28.h),
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
          // Card 2 (TASK)
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
              imagePath: 'assets/images/quests/resource_music_headphones.svg',
              completed: resDone,
              onTap: () async {
                HapticFeedback.lightImpact();
                SystemSound.play(SystemSoundType.click);
                if (_enableSoftXpPop && await _isFirstUseToday(_prefsResPopDate)) {
                  _showXpChipPop(_resCardKey, amount: 5);
                  await _markUsedToday(_prefsResPopDate);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(duration: Duration(milliseconds: 1200), content: Text('XP already counted for today')),
                    );
                  }
                }
                // Telemetry: impression/start/complete for resource
                final questId = _qResId ?? 'resource_calm_music_v2';
                if (_questsEngine != null) {
                  try {
                    await _questsEngine!.markImpression(questId);
                    await _questsEngine!.markStart(questId);
                    await _questsEngine!.markComplete(questId);
                    if (kDebugMode) debugPrint('[QuestsEngine] resource used $questId');
                  } catch (e) {
                    if (kDebugMode) debugPrint('[QuestsEngine][ERROR] $e');
                  }
                  await _refreshToday();
                }
              }),
          SizedBox(height: 24.h),
          // Card 4 (TIP)
          RecommendationCardWidget(
              containerKey: _tipCardKey,
              category: 'TIP',
              title: 'One tiny step',
              subtitle: 'Pick the easiest task first',
              imagePath: 'assets/images/quests/tip_generic.svg',
              completed: tipDone,
              onTap: () async {
                HapticFeedback.lightImpact();
                SystemSound.play(SystemSoundType.click);
                if (_enableSoftXpPop && await _isFirstUseToday(_prefsTipPopDate)) {
                  _showXpChipPop(_tipCardKey, amount: 5);
                  await _markUsedToday(_prefsTipPopDate);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(duration: Duration(milliseconds: 1200), content: Text('XP already counted for today')),
                    );
                  }
                }
                final questId = _qTipId ?? 'tip_one_tiny_step_v2';
                if (_questsEngine != null) {
                  try {
                    await _questsEngine!.markImpression(questId);
                    await _questsEngine!.markStart(questId);
                    await _questsEngine!.markComplete(questId);
                    if (kDebugMode) debugPrint('[QuestsEngine] tip viewed $questId');
                  } catch (e) {
                    if (kDebugMode) debugPrint('[QuestsEngine][ERROR] $e');
                  }
                  await _refreshToday();
                }
              }),
          SizedBox(height: 24.h),
          // Card 5 (REMINDER) - themed toggle + change time
          Builder(
            builder: (context) {
              final near = _isReminderNear();
              if (kDebugMode) {
                debugPrint('[Reminder][near] now=$near on=$_reminderOn time=${_reminderTime.format(context)}');
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
                                  if (kDebugMode) {
                                    debugPrint('[Reminder][toggle] on=$_reminderOn');
                                  }
                                  // Microinteraction: subtle ripple on toggle change
                                  HapticFeedback.lightImpact();
                                  SystemSound.play(SystemSoundType.click);
                                  _showCheckRipple(_reminderToggleKey);
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
                                        if (picked != null) {
                                          setState(() {
                                            _reminderTime = picked;
                                            _reminderOn = true;
                                          });
                                          _saveReminderPrefs();
                                          if (kDebugMode) {
                                            debugPrint('[Reminder][timeChanged] to=${_reminderTime.format(context)}');
                                          }
                                          // Microinteraction: confirmation ring + haptics
                                          HapticFeedback.selectionClick();
                                          SystemSound.play(SystemSoundType.click);
                                          _showTimerRing(_reminderTimeKey);
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
}
