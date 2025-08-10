import 'package:flutter/material.dart';
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
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint, listEquals;
import 'package:provider/provider.dart';
import '../../../providers/progress_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WellnessDashboardScreen extends StatefulWidget {
  WellnessDashboardScreen({Key? key}) : super(key: key);

  @override
  State<WellnessDashboardScreen> createState() => _WellnessDashboardScreenState();
}

class _WellnessDashboardScreenState extends State<WellnessDashboardScreen>
    with SingleTickerProviderStateMixin {
  // UI-only state for TASK completion and progress
  bool _task1Done = false; // Focus reset
  bool _task2Done = false; // Study sprint
  int _baseSteps = 2; // total tasks today
  int _baseXp = 20; // base example XP shown initially
  bool _reminderOn = true; // UI-only reminder toggle (default ON)
  TimeOfDay _reminderTime = const TimeOfDay(hour: 19, minute: 0);

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
  static bool _autoVerifiedOnce = false; // ensure automated verification runs once per session

  // Gentle pulse for near-time attention
  late AnimationController _pulseController;

  // Week 0 QuestsEngine (minimal glue, no UI changes)
  // ignore: unused_field
  QuestsEngine? _questsEngine;
  // ignore: unused_field
  Map<String, dynamic>? _todayData; // {'todayItems': List<Quest>, 'progress': {stepsLeft, xpEarned}}

  // Persist reminder prefs
  static const _prefsReminderOn = 'wellness.reminder_on_v1';
  static const _prefsReminderMinutes = 'wellness.reminder_minutes_v1';
  // Quests engine internal keys used for debug cleanup only
  static const _qeTelemetryKey = 'quests_engine.telemetry_v1';
  static const _qeHistoryKey = 'quests_engine.history_v1';
  static const _qeTimersKey = 'quests_engine.timers_v1';

  // Debug helper: extract today's quest titles
  List<String> _debugTodayTitles() {
    final items = _todayData?["todayItems"] as List<dynamic>?;
    if (items == null) return const [];
    return items.map((e) => (e as dynamic).title?.toString() ?? '').where((s) => s.isNotEmpty).toList();
  }

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
      if (kDebugMode) {
        final hh = _reminderTime.hour.toString().padLeft(2, '0');
        final mm = _reminderTime.minute.toString().padLeft(2, '0');
        debugPrint('[ReminderPrefs] loaded on='+_reminderOn.toString()+' time='+hh+':'+mm);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ReminderPrefs][ERROR] '+e.toString());
    }
  }

  // Debug cleanup helper used by automated verification
  Future<void> _clearQuestDebugState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_qeTelemetryKey);
      await prefs.remove(_qeHistoryKey);
      await prefs.remove(_qeTimersKey);
      if (kDebugMode) debugPrint('[QuestsEngine][DEBUG] Cleared debug telemetry/history/timers');
    } catch (e) {
      if (kDebugMode) debugPrint('[QuestsEngine][DEBUG][ERROR] cleanup '+e.toString());
    }
  }

  Future<void> _runAutomatedVerification() async {
    if (!kDebugMode) return;
    if (_questsEngine == null) return;
    try {
      final titles = _debugTodayTitles();
      if (titles.isNotEmpty) {
        debugPrint('[AutoVerify] todayTitles='+titles.join(' | '));
      }

      final before = _todayData?['progress'] as Map<String, dynamic>?;

      // Non-destructive actions
      await _questsEngine!.markImpression('resource_calm_music_v2');
      await _questsEngine!.markStart('resource_calm_music_v2');
      await _questsEngine!.markComplete('resource_calm_music_v2');
      await _questsEngine!.markImpression('tip_one_tiny_step_v2');
      await _questsEngine!.markStart('tip_one_tiny_step_v2');
      await _questsEngine!.markComplete('tip_one_tiny_step_v2');

      // One task completion
      await _questsEngine!.markStart('task_focus_reset_v2');
      await _questsEngine!.markComplete('task_focus_reset_v2');

      await _refreshToday();
      final after = _todayData?['progress'] as Map<String, dynamic>?;

      if (kDebugMode) {
        final stepsBefore = (before?['stepsLeft'] ?? 0) as int;
        final stepsAfter = (after?['stepsLeft'] ?? 0) as int;
        final xpBefore = (before?['xpEarned'] ?? 0) as int;
        final xpAfter = (after?['xpEarned'] ?? 0) as int;
        final okSteps = stepsAfter <= stepsBefore;
        final okXp = xpAfter >= xpBefore;
        debugPrint('[AutoVerify][ASSERT] steps ok='+okSteps.toString()+' xp ok='+okXp.toString());
      }

      // Reminder prefs persistence
      final origOn = _reminderOn;
      final origTime = _reminderTime;
      _reminderOn = !origOn;
      final newMinutes = (origTime.minute + 5) % 60;
      final carry = (origTime.minute + 5) ~/ 60;
      final newHour = (origTime.hour + carry) % 24;
      _reminderTime = TimeOfDay(hour: newHour, minute: newMinutes);
      await _saveReminderPrefs();
      await _loadReminderPrefs();
      final loadedMatches = (_reminderOn == !origOn) && (_reminderTime.hour == newHour && _reminderTime.minute == newMinutes);
      debugPrint('[AutoVerify][ASSERT] reminder persisted='+loadedMatches.toString()+' on='+_reminderOn.toString()+' time='+_reminderTime.hour.toString()+':'+_reminderTime.minute.toString().padLeft(2, '0'));
      _reminderOn = origOn;
      _reminderTime = origTime;
      await _saveReminderPrefs();
      await _loadReminderPrefs();

      // Simulate midnight
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final nextData = await _questsEngine!.getTodayData(date: tomorrow);
      final nextItems = nextData['todayItems'] as List?;
      final nextProgress = nextData['progress'] as Map<String, dynamic>?;
      debugPrint('[AutoVerify][MidnightSim] nextDay items='+(nextItems?.length.toString() ?? 'null')+' stepsLeft='+((nextProgress?['stepsLeft'])?.toString() ?? 'null')+' xp='+((nextProgress?['xpEarned'])?.toString() ?? 'null'));
    } catch (e) {
      if (kDebugMode) debugPrint('[AutoVerify][ERROR] '+e.toString());
    } finally {
      await _clearQuestDebugState();
      await _refreshToday();
      if (kDebugMode) debugPrint('[AutoVerify] cleanup done and state restored');
    }
  }

  Future<void> _saveReminderPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsReminderOn, _reminderOn);
      final mins = _reminderTime.hour * 60 + _reminderTime.minute;
      await prefs.setInt(_prefsReminderMinutes, mins);
      if (kDebugMode) {
        debugPrint('[ReminderPrefs] saved on=$_reminderOn minutes=$mins');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ReminderPrefs][ERROR] $e');
    }
  }

  Future<void> _initQuests() async {
    final engine = QuestsEngine();
    final data = await engine.getTodayData();
    if (kDebugMode) {
      // Log a brief summary for today
      final items = data['todayItems'] as List?;
      final progress = data['progress'] as Map<String, dynamic>?;
      debugPrint('[QuestsEngine] todayItems=${items?.length} stepsLeft=${progress?['stepsLeft']} xp=${progress?['xpEarned']}');

      // Stress test determinism & constraints across a 14-day window (non-destructive to UI)
      final base = DateTime.now();
      int failures = 0;
      for (int i = -3; i < 11; i++) {
        final d = DateTime(base.year, base.month, base.day).add(Duration(days: i));
        final set1 = engine.selectToday(d, const {});
        final set2 = engine.selectToday(d, const {});
        final ids1 = set1.map((e) => (e as dynamic).id as String).toList()..sort();
        final ids2 = set2.map((e) => (e as dynamic).id as String).toList()..sort();
        final same = listEquals(ids1, ids2);
        final hasTask = set1.any((q) => (q as dynamic).tag.toString().contains('task'));
        final hasTipRes = set1.any((q) => (q as dynamic).tag.toString().contains('tip') || (q as dynamic).tag.toString().contains('resource'));
        final hasCheckProg = set1.any((q) => (q as dynamic).tag.toString().contains('checkin') || (q as dynamic).tag.toString().contains('progress'));
        final hasShort = set1.any((q) => ((q as dynamic).durationMin ?? 999) <= 3);
        if (!(same && hasTask && hasTipRes && hasCheckProg && hasShort)) {
          failures++;
          debugPrint('[QuestsEngine][FAIL] ${d.toIso8601String().split('T').first} same=$same task=$hasTask tipRes=$hasTipRes checkProg=$hasCheckProg short=$hasShort');
        }
      }
      if (failures > 0) {
        debugPrint('[QuestsEngine][STRESS] window=14d failures=$failures');
      }
    }
    if (!mounted) return;
    setState(() {
      _questsEngine = engine;
      _todayData = data;
    });

    // Push progress summary to existing ProgressProvider (no widget changes)
    final progress = data['progress'] as Map<String, dynamic>?;
    if (progress != null && mounted) {
      final stepsLeft = (progress['stepsLeft'] ?? 0) as int;
      final xpEarned = (progress['xpEarned'] ?? 0) as int;
      context.read<ProgressProvider>().updateFromQuests(stepsLeft: stepsLeft, xpEarned: xpEarned);
      if (kDebugMode) {
        debugPrint('[ProgressProvider] updateFromQuests stepsLeft=$stepsLeft xp=$xpEarned');
      }
    }
  }

  Future<void> _refreshToday() async {
    if (_questsEngine == null) return _initQuests();
    final data = await _questsEngine!.getTodayData();
    if (!mounted) return;
    setState(() {
      _todayData = data;
    });
    final progress = data['progress'] as Map<String, dynamic>?;
    if (progress != null) {
      final stepsLeft = (progress['stepsLeft'] ?? 0) as int;
      final xpEarned = (progress['xpEarned'] ?? 0) as int;
      context.read<ProgressProvider>().updateFromQuests(stepsLeft: stepsLeft, xpEarned: xpEarned);
      if (kDebugMode) debugPrint('[ProgressProvider][refresh] stepsLeft=$stepsLeft xp=$xpEarned');
    }
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final ms = nextMidnight.difference(now).inMilliseconds;
    _midnightTimer = Timer(Duration(milliseconds: ms.clamp(1000, 86400000)), () async {
      if (kDebugMode) debugPrint('[QuestsEngine] Midnight refresh');
      await _refreshToday();
      _scheduleMidnightRefresh();
    });
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

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _startMicrocopyRotation();
    // Initialize asynchronously: reminder prefs, quests data, and midnight refresh
    Future.microtask(() async {
      await _loadReminderPrefs();
      await _initQuests();
      _scheduleMidnightRefresh();
      // Run automated in-app verification (debug-only), then restore state
      if (kDebugMode && !_autoVerifiedOnce) {
        await _runAutomatedVerification();
        _autoVerifiedOnce = true;
      }
    });
  }

  @override
  void dispose() {
    _microTimer?.cancel();
    _midnightTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
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
    // Compute dynamic values from UI state (UI-only)
    final int completed = (_task1Done ? 1 : 0) + (_task2Done ? 1 : 0);
    final int stepsLeft = (_baseSteps - completed).clamp(0, _baseSteps);
    final int xpEarned = _baseXp + (completed * 10);
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 70.h).copyWith(bottom: 32.h),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your Progress',
              style: TextStyleHelper.instance.display31BoldInter.copyWith(
                  fontFamily: CoreTextStyles
                      .TextStyleHelper.instance.headline24Bold.fontFamily,
                  color: Color(0xFF444D5C))),
          SizedBox(height: 28.h),
          Row(children: [
            Expanded(
                child: ProgressCardWidget(
                    imagePath: ImageConstant.imgImage65x52,
                    value: '$stepsLeft',
                    label: 'Steps Left',
                    backgroundColor: Color(0xFFE0F2E9))),
            SizedBox(width: 24.h),
            Expanded(
                child: ProgressCardWidget(
                    imagePath: ImageConstant.imgImage63x65,
                    value: '+$xpEarned',
                    label: 'XP Earned',
                    backgroundColor: Color(0xFFE8E7F8))),
          ]),
          SizedBox(height: 12.h),
          Text('Estimated time: 2–3 min',
              style: TextStyleHelper.instance.headline21Inter.copyWith(
                  fontFamily: CoreTextStyles
                      .TextStyleHelper.instance.headline24Bold.fontFamily,
                  color: Color(0xFF8C9CAA))),
        ]));
  }

  Widget _buildRecommendationsSection() {
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 69.h).copyWith(bottom: 32.h),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Today\'s Recommendations',
              style: TextStyleHelper.instance.display32BoldInter.copyWith(
                  fontFamily: CoreTextStyles
                      .TextStyleHelper.instance.headline24Bold.fontFamily,
                  color: Color(0xFF4A5261))),
          SizedBox(height: 28.h),
          // Card 1 (TASK)
          RecommendationCardWidget(
              category: 'TASK',
              title: 'Focus reset (2 min)',
              subtitle: (_task1Done && _task2Done)
                  ? 'All steps complete 🎉'
                  : 'Quick breathing + desk tidy',
              imagePath: ImageConstant.imgImage131x130,
              completed: _task1Done,
              onTap: () async {
                final newVal = !_task1Done;
                setState(() { _task1Done = newVal; });
                // Wire to engine: mark start/complete for known quest id
                const questId = 'task_focus_reset_v2';
                if (_questsEngine != null) {
                  try {
                    await _questsEngine!.markStart(questId);
                    if (newVal) {
                      await _questsEngine!.markComplete(questId);
                    }
                    if (kDebugMode) debugPrint('[QuestsEngine] toggled $questId completed=$newVal');
                  } catch (e) {
                    if (kDebugMode) debugPrint('[QuestsEngine][ERROR] $e');
                  }
                  await _refreshToday();
                }
              }),
          SizedBox(height: 24.h),
          // Card 2 (TASK)
          RecommendationCardWidget(
              category: 'TASK',
              title: 'Study sprint (10 min)',
              subtitle: 'Timer + no‑phone rule',
              imagePath: ImageConstant.imgImage130x130,
              completed: _task2Done,
              onTap: () async {
                final newVal = !_task2Done;
                setState(() { _task2Done = newVal; });
                const questId = 'task_study_sprint_v2';
                if (_questsEngine != null) {
                  try {
                    await _questsEngine!.markStart(questId);
                    if (newVal) {
                      await _questsEngine!.markComplete(questId);
                    }
                    if (kDebugMode) debugPrint('[QuestsEngine] toggled $questId completed=$newVal');
                  } catch (e) {
                    if (kDebugMode) debugPrint('[QuestsEngine][ERROR] $e');
                  }
                  await _refreshToday();
                }
              }),
          SizedBox(height: 24.h),
          // Card 3 (RESOURCE)
          RecommendationCardWidget(
              category: 'RESOURCE',
              title: 'Calm music',
              subtitle: 'Lo‑fi playlist',
              imagePath: ImageConstant.imgImage131x130,
              onTap: () async {
                // Telemetry: impression/start/complete for resource
                const questId = 'resource_calm_music_v2';
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
              category: 'TIP',
              title: 'One tiny step',
              subtitle: 'Pick the easiest task first',
              imagePath: ImageConstant.imgImage130x130,
              onTap: () async {
                const questId = 'tip_one_tiny_step_v2';
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
                                },
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
