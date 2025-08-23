/// Week 0 QuestsEngine — single-file module
/// - Deterministic local selection per date
/// - JSON catalog loader with embedded fallback
/// - Local telemetry via shared_preferences
/// - Timer helpers (start/stop/auto-complete)
/// - Minimal adapter methods for existing screen to call
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tags allowed for quests
enum QuestTag { task, tip, resource, reminder, checkin, progress }

// Debug logging verbosity (debug builds only). Set true during active debugging.
const bool _debugVerbose = false;

QuestTag _tagFromString(String s) {
  switch (s.toUpperCase()) {
    case 'TASK':
      return QuestTag.task;
    case 'TIP':
      return QuestTag.tip;
    case 'RESOURCE':
      return QuestTag.resource;
    case 'REMINDER':
      return QuestTag.reminder;
    case 'CHECK-IN':
    case 'CHECKIN':
      return QuestTag.checkin;
    case 'PROGRESS':
      return QuestTag.progress;
    default:
      return QuestTag.tip;
  }
}

String _tagToString(QuestTag t) {
  switch (t) {
    case QuestTag.task:
      return 'TASK';
    case QuestTag.tip:
      return 'TIP';
    case QuestTag.resource:
      return 'RESOURCE';
    case QuestTag.reminder:
      return 'REMINDER';
    case QuestTag.checkin:
      return 'CHECK-IN';
    case QuestTag.progress:
      return 'PROGRESS';
  }
}

class Quest {
  final String id;
  final QuestTag tag;
  final String title;
  final String subtitle;
  final int? durationMin;
  final String? url;
  final List<String> checklist;
  final bool timerSuggested;
  final bool active;
  final String? category; // e.g., mindfulness, activity, social, learning
  final int? points; // XP override per quest
  final String? streakGroup; // group id for streak tracking
  final String? recurrence; // e.g., daily, weekly, anytime
  final bool hideInExplore; // UI-only: hide from Explore tab

  const Quest({
    required this.id,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.durationMin,
    required this.url,
    required this.checklist,
    required this.timerSuggested,
    required this.active,
    this.category,
    this.points,
    this.streakGroup,
    this.recurrence,
    this.hideInExplore = false,
  });

  factory Quest.fromJson(Map<String, dynamic> j) => Quest(
    id: j['quest_id'] as String,
    tag: _tagFromString(j['tag'] as String),
    title: j['title'] as String,
    subtitle: j['subtitle'] as String,
    durationMin: j['duration_min'] == null
        ? null
        : (j['duration_min'] as num).toInt(),
    url: j['url'] as String?,
    checklist: (j['checklist'] is List)
        ? (j['checklist'] as List).map((e) => e.toString()).toList()
        : const <String>[],
    timerSuggested: j['timer_suggested'] == true,
    active: j['active'] == true,
    category: j['category'] as String?,
    points: j['points'] == null ? null : (j['points'] as num).toInt(),
    streakGroup: j['streak_group'] as String?,
    recurrence: j['recurrence'] as String?,
    hideInExplore:
        (j['hide_in_explore'] == true) || (j['hideInExplore'] == true),
  );

  Map<String, dynamic> toJson() => {
    'quest_id': id,
    'tag': _tagToString(tag),
    'title': title,
    'subtitle': subtitle,
    'duration_min': durationMin,
    'url': url,
    'checklist': checklist,
    'timer_suggested': timerSuggested,
    'active': active,
    'category': category,
    'points': points,
    'streak_group': streakGroup,
    'recurrence': recurrence,
    'hide_in_explore': hideInExplore,
  };
}

class TodayProgressSummary {
  final int stepsLeft;
  final int xpEarned;
  const TodayProgressSummary({required this.stepsLeft, required this.xpEarned});
}

class QuestsEngine {
  // Optional: set a remote URL here if desired. Leave null for Week 0.
  static String? remoteCatalogUrl; // e.g., 'https://example.com/quests.json'

  static const _prefsCatalogKey = 'quests_engine.catalog_v5';
  static const _prefsTelemetryKey = 'quests_engine.telemetry_v1';
  static const _prefsHistoryKey =
      'quests_engine.history_v1'; // for 7-day task repetition checks
  static const _prefsTimersKey = 'quests_engine.timers_v1';

  List<Quest> _catalog = [];
  Map<String, dynamic> _telemetry = {};
  Map<String, dynamic> _history = {};
  Map<String, dynamic> _timers = {};

  QuestsEngine() {
    _now = DateTime.now;
  }

  // Time source (injectable for tests)
  late DateTime Function() _now;
  @visibleForTesting
  void debugSetNow(DateTime Function() nowFn) {
    _now = nowFn;
  }

  /// DEBUG ONLY: wipe local quest persistence to test fresh state.
  /// Clears telemetry, history, and timers but keeps cached catalog.
  /// Safe to call on startup during debug sessions.
  static Future<void> debugResetAll() async {
    if (!kDebugMode) return; // never run in release/profile
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsTelemetryKey);
    await prefs.remove(_prefsHistoryKey);
    await prefs.remove(_prefsTimersKey);
  }

  // --- Helpers ---
  String _todayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  bool _isIsoSameDay(String? iso, DateTime now) {
    if (iso == null || iso.isEmpty) return false;
    try {
      final dt = DateTime.parse(iso);
      return _todayKey(dt) == _todayKey(now);
    } catch (_) {
      return false;
    }
  }

  /// Load catalog: prefer remote if set; else use embedded fallback.
  /// Cache the parsed catalog to prefs for quick startup.
  Future<void> loadCatalog() async {
    final prefs = await SharedPreferences.getInstance();

    // Try to use cached first.
    final cached = prefs.getString(_prefsCatalogKey);
    if (cached != null) {
      try {
        final List list = jsonDecode(cached) as List;
        _catalog = list
            .map((e) => Quest.fromJson(e as Map<String, dynamic>))
            .toList();
        if (kDebugMode && _debugVerbose) {
          debugPrint(
            '[QuestsEngine] Catalog loaded from cache: ${_catalog.length} items',
          );
        }
      } catch (_) {}
    }

    // Try remote if configured.
    if (remoteCatalogUrl != null && remoteCatalogUrl!.isNotEmpty) {
      try {
        // kIsWeb-friendly simple fetch using HttpClient not available; skip for Week 0.
        // We keep remote off by default. Documented in WEEK0.md.
      } catch (e) {
        if (kDebugMode && _debugVerbose) {
          debugPrint('[QuestsEngine][WARN] Remote catalog load failed: $e');
        }
      }
    }

    // Fallback to embedded if empty
    if (_catalog.isEmpty) {
      final List list = jsonDecode(_embeddedFallbackJson) as List;
      _catalog = list
          .map((e) => Quest.fromJson(e as Map<String, dynamic>))
          .toList();
      await prefs.setString(
        _prefsCatalogKey,
        jsonEncode(_catalog.map((e) => e.toJson()).toList()),
      );
      if (kDebugMode && _debugVerbose) {
        debugPrint(
          '[QuestsEngine] Catalog loaded from embedded: ${_catalog.length} items',
        );
      }
    }

    // Load telemetry/history/timers
    _telemetry = _readJsonMap(prefs.getString(_prefsTelemetryKey));
    _history = _readJsonMap(prefs.getString(_prefsHistoryKey));
    _timers = _readJsonMap(prefs.getString(_prefsTimersKey));
    if (kDebugMode && _debugVerbose) {
      debugPrint(
        '[QuestsEngine] Telemetry keys=${_telemetry.length} historyDays=${_history.length} timers=${_timers.length}',
      );
    }
  }

  Map<String, dynamic> _readJsonMap(String? s) {
    if (s == null || s.isEmpty) return {};
    try {
      final m = jsonDecode(s);
      return (m is Map<String, dynamic>) ? m : {};
    } catch (_) {
      return {};
    }
  }

  /// Deterministic RNG seeded by date (yyyy-mm-dd) so reopen shows same set.
  Random _rngForDate(DateTime date) {
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    // Simple hash
    int hash = 0;
    for (final code in key.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return Random(hash);
  }

  /// Select today’s 5–6 items with constraints.
  List<Quest> selectToday(DateTime date, Map<String, dynamic> userState) {
    final rng = _rngForDate(date);
    final active = _catalog.where((q) => q.active).toList();

    bool hasShort(Quest q) => (q.durationMin ?? 999) <= 3;

    // 7-day history to avoid overusing the same TASK
    final todayKey = _dateKey(date);
    final last7 = _lastNDaysKeys(date, 7);
    final Map<String, int> taskUse = {};
    for (final d in last7) {
      // IMPORTANT: exclude today's key so repeated calls on the same date remain deterministic
      if (d == todayKey) continue;
      // Safely read stored task list; tolerate corrupted or old entries
      List<String> used = const <String>[];
      final entryAny = _history[d];
      if (entryAny is Map) {
        final t = entryAny['tasks'];
        if (t is List) {
          used = t.map((e) => e.toString()).toList();
        }
      }
      for (final id in used) {
        taskUse[id] = (taskUse[id] ?? 0) + 1;
      }
    }

    Quest? pickOne(List<Quest> pool, bool Function(Quest) filter) {
      final candidates = pool.where(filter).toList();
      if (candidates.isEmpty) return null;
      return candidates[rng.nextInt(candidates.length)];
    }

    final picked = <Quest>[];

    // Buckets
    final tasks = active.where((q) => q.tag == QuestTag.task).toList();
    final tipsOrRes = active
        .where((q) => q.tag == QuestTag.tip || q.tag == QuestTag.resource)
        .toList();
    final checkOrProg = active
        .where((q) => q.tag == QuestTag.checkin || q.tag == QuestTag.progress)
        .toList();

    // Rules: ensure category coverage
    void addIfNotNull(Quest? q) {
      if (q != null && !picked.any((p) => p.id == q.id)) picked.add(q);
    }

    // Prefer tasks with lower use count
    Quest? pickTask() {
      if (tasks.isEmpty) return null;
      tasks.sort((a, b) => (taskUse[a.id] ?? 0).compareTo(taskUse[b.id] ?? 0));
      final slice = tasks.take(min(4, tasks.length)).toList();
      return slice[rng.nextInt(slice.length)];
    }

    // Ensure at least two TASKs when available for consistent UI (two task cards)
    final t1 = pickTask();
    addIfNotNull(t1);
    if (tasks.length > 1) {
      // build a second-pick pool excluding t1
      final pool2 = tasks.where((q) => q.id != (t1?.id ?? '')).toList();
      if (pool2.isNotEmpty) {
        pool2.sort(
          (a, b) => (taskUse[a.id] ?? 0).compareTo(taskUse[b.id] ?? 0),
        );
        final slice2 = pool2.take(min(4, pool2.length)).toList();
        final t2 = slice2[rng.nextInt(slice2.length)];
        addIfNotNull(t2);
      }
    }

    // Category coverage: at least one TIP/RESOURCE and one CHECK-IN/PROGRESS
    addIfNotNull(pickOne(tipsOrRes, (_) => true));
    addIfNotNull(pickOne(checkOrProg, (_) => true));

    // Ensure at least one short (<=3 min)
    if (!picked.any(hasShort)) {
      final shortPool = active.where(hasShort).toList();
      if (shortPool.isNotEmpty) {
        addIfNotNull(shortPool[rng.nextInt(shortPool.length)]);
      }
    }

    // Fill to 5–6 total
    while (picked.length < 5) {
      final next = active[rng.nextInt(active.length)];
      if (!picked.any((p) => p.id == next.id)) picked.add(next);
      if (picked.length == 5 && rng.nextBool()) break; // ~50% chance of 6th
      if (picked.length < 6 && rng.nextBool()) {
        final extra = active[rng.nextInt(active.length)];
        if (!picked.any((p) => p.id == extra.id)) picked.add(extra);
      }
    }

    // Record today’s task IDs for repetition control
    final existing =
        (_history[todayKey] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    existing['tasks'] = picked
        .where((q) => q.tag == QuestTag.task)
        .map((q) => q.id)
        .toList();
    _history[todayKey] = existing;
    _persistHistory();

    if (kDebugMode && _debugVerbose) {
      final ids = picked.map((e) => e.id).toList();
      debugPrint(
        '[QuestsEngine] selectToday ${_dateKey(date)} => ${ids.join(', ')}',
      );
    }
    return picked;
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  List<String> _lastNDaysKeys(DateTime d, int n) =>
      List.generate(n, (i) => _dateKey(d.subtract(Duration(days: i))));

  // Telemetry
  Future<void> markImpression(String questId) async {
    _ensureQuestStats(questId);
    _telemetry[questId]['impressions'] =
        (_telemetry[questId]['impressions'] ?? 0) + 1;
    _telemetry[questId]['last_shown_at'] = _now().toIso8601String();
    await _persistTelemetry();
  }

  Future<void> markStart(String questId) async {
    _ensureQuestStats(questId);
    _telemetry[questId]['starts'] = (_telemetry[questId]['starts'] ?? 0) + 1;
    _telemetry[questId]['last_started_at'] = _now().toIso8601String();
    await _persistTelemetry();
  }

  Future<void> markComplete(String questId, {int? elapsedMs}) async {
    _ensureQuestStats(questId);
    final now = _now();
    final lastIso = (_telemetry[questId]['last_completed_at'] as String?);
    // Prevent double-award on the same day
    if (_isIsoSameDay(lastIso, now)) {
      // Already completed today; do not increment counters again
      if (kDebugMode && _debugVerbose) {
        debugPrint(
          '[QuestsEngine] markComplete noop (already today) questId=$questId',
        );
      }
      return;
    }
    _telemetry[questId]['completes'] =
        (_telemetry[questId]['completes'] ?? 0) + 1;
    _telemetry[questId]['last_completed_at'] = now.toIso8601String();
    if (elapsedMs != null) {
      _telemetry[questId]['elapsed_ms'] =
          (_telemetry[questId]['elapsed_ms'] ?? 0) + elapsedMs;
    }
    await _persistTelemetry();

    // Track per-day completion history to support streaks and Explore filters
    final dayKey = _dateKey(now);
    final entry =
        (_history[dayKey] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final dynamic completedAny = entry['completed'];
    final List<String> completed = (completedAny is List)
        ? completedAny.map((e) => e.toString()).toList()
        : <String>[];
    if (!completed.contains(questId)) completed.add(questId);
    entry['completed'] = completed;
    _history[dayKey] = entry;
    await _persistHistory();
    if (kDebugMode && _debugVerbose) {
      debugPrint(
        '[QuestsEngine] markComplete questId=$questId completes=${_telemetry[questId]['completes']}',
      );
    }
  }

  /// Undo today's completion, used by UI 'Undo' actions.
  /// If the quest was marked complete today, clears the marker and
  /// decrements the 'completes' counter once (not below zero).
  Future<void> uncompleteToday(String questId) async {
    _ensureQuestStats(questId);
    final now = _now();
    final lastIso = (_telemetry[questId]['last_completed_at'] as String?);
    if (_isIsoSameDay(lastIso, now)) {
      // Clear today's completion marker
      (_telemetry[questId] as Map<String, dynamic>).remove('last_completed_at');
      final c = _telemetry[questId]['completes'];
      if (c is int && c > 0) {
        _telemetry[questId]['completes'] = c - 1;
      }
      await _persistTelemetry();
      // Remove from per-day completion history
      final dayKey = _dateKey(now);
      final entry =
          (_history[dayKey] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      final dynamic completedAny = entry['completed'];
      final List<String> completed = (completedAny is List)
          ? completedAny.map((e) => e.toString()).toList()
          : <String>[];
      completed.removeWhere((e) => e == questId);
      entry['completed'] = completed;
      _history[dayKey] = entry;
      await _persistHistory();
      if (kDebugMode && _debugVerbose) {
        debugPrint(
          '[QuestsEngine] undoComplete questId=$questId completes=${_telemetry[questId]['completes']}',
        );
      }
    } else {
      if (kDebugMode && _debugVerbose) {
        debugPrint(
          '[QuestsEngine] undoComplete noop (not completed today) questId=$questId',
        );
      }
    }
  }

  Future<void> rateUsefulness(String questId, int rating1to5) async {
    _ensureQuestStats(questId);
    _telemetry[questId]['usefulness_rating'] = rating1to5.clamp(1, 5);
    await _persistTelemetry();
  }

  Future<void> rateControl(String questId, int rating1to5) async {
    _ensureQuestStats(questId);
    _telemetry[questId]['control_rating'] = rating1to5.clamp(1, 5);
    await _persistTelemetry();
  }

  // Timers
  Future<void> startTimer(String questId) async {
    final start = _now().millisecondsSinceEpoch;
    _timers[questId] = {'start': start};
    await _persistTimers();
  }

  Future<int> stopTimer(String questId) async {
    final now = _now().millisecondsSinceEpoch;
    final start = (_timers[questId]?['start'] as int?) ?? now;
    final elapsed = now - start;
    _timers.remove(questId);
    await _persistTimers();
    return elapsed;
  }

  // Auto-complete for suggested timers (can be used with a countdown in UI later)
  Future<void> autoCompleteTimer(String questId, int durationMin) async {
    final elapsedMs = durationMin * 60 * 1000;
    await markComplete(questId, elapsedMs: elapsedMs);
  }

  // Progress
  // Unified XP awards
  static const int xpTask = 10;
  static const int xpOther = 5;
  // Explore: daily XP-limited awards (MVP)
  static const int exploreDailyLimit = 3;

  int _xpForQuest(Quest q) =>
      q.points ?? ((q.tag == QuestTag.task) ? xpTask : xpOther);

  // Mirror Today UI selection: pick up to 4 IDs
  //  - Two TASKs (prefer titles containing 'focus' and 'study' where possible)
  //  - One RESOURCE (preferred), else TIP, else CHECK/PROGRESS
  //  - One TIP distinct from the resource pick, else CHECK/PROGRESS distinct
  Set<String> _selectDisplayedCardIds(List<Quest> today) {
    String titleOf(Quest q) => q.title;

    final tasks = today.where((q) => q.tag == QuestTag.task).toList();

    Quest? focusCandidate;
    final focusMatches = tasks
        .where((q) => titleOf(q).toLowerCase().contains('focus'))
        .toList();
    if (focusMatches.isNotEmpty) {
      focusCandidate = focusMatches.first;
    } else if (tasks.isNotEmpty) {
      focusCandidate = tasks.first;
    }

    Quest? sprintCandidate;
    final sprintMatches = tasks
        .where((q) => titleOf(q).toLowerCase().contains('study'))
        .toList();
    if (sprintMatches.isNotEmpty) {
      // Prefer a sprint distinct from focus pick
      sprintCandidate = sprintMatches.firstWhere(
        (q) => q.id != (focusCandidate?.id ?? ''),
        orElse: () => sprintMatches.first,
      );
    } else if (tasks.length > 1) {
      // Fallback: any other task (distinct if possible)
      final alt = tasks.where((q) => q.id != (focusCandidate?.id ?? ''));
      if (alt.isNotEmpty) {
        sprintCandidate = alt.first;
      } else {
        sprintCandidate = tasks.first;
      }
    }

    final Set<String> ids = <String>{};
    if (focusCandidate != null) ids.add(focusCandidate.id);
    if (sprintCandidate != null && sprintCandidate.id != focusCandidate?.id) {
      ids.add(sprintCandidate.id);
    } else {
      for (final q in tasks) {
        if (q.id != focusCandidate?.id) {
          ids.add(q.id);
          break;
        }
      }
    }

    final resources = today.where((q) => q.tag == QuestTag.resource).toList();
    final tips = today.where((q) => q.tag == QuestTag.tip).toList();
    final checks = today
        .where((q) => q.tag == QuestTag.checkin || q.tag == QuestTag.progress)
        .toList();

    Quest? resPick;
    if (resources.isNotEmpty) {
      resPick = resources.first;
    } else if (tips.isNotEmpty) {
      resPick = tips.first;
    } else if (checks.isNotEmpty) {
      resPick = checks.first;
    }
    if (resPick != null) ids.add(resPick.id);

    Quest? tipPick;
    if (tips.isNotEmpty) {
      tipPick = tips.firstWhere(
        (q) => q.id != resPick?.id,
        orElse: () => tips.first,
      );
      if (tipPick.id == resPick?.id && checks.isNotEmpty) {
        tipPick = checks.firstWhere(
          (q) => q.id != resPick?.id,
          orElse: () => checks.first,
        );
      }
    } else if (checks.isNotEmpty) {
      tipPick = checks.firstWhere(
        (q) => q.id != resPick?.id,
        orElse: () => checks.first,
      );
    }
    if (tipPick != null) ids.add(tipPick.id);

    // Ensure at most 4
    if (ids.length > 4) {
      return ids.take(4).toSet();
    }
    return ids;
  }

  TodayProgressSummary computeProgress(List<Quest> today) {
    final now = _now();
    int stepsLeft = 0; // remaining among the 4 displayed cards
    int xpEarned = 0;

    // Compute stepsLeft against the same 4-card selection shown on Today
    final Set<String> displayed = _selectDisplayedCardIds(today);
    for (final id in displayed) {
      final lastIso =
          (_telemetry[id] as Map<String, dynamic>?)?['last_completed_at']
              as String?;
      final doneToday = _isIsoSameDay(lastIso, now);
      if (!doneToday) stepsLeft += 1;
    }

    // Pragmatic change: XP reflects all completions today (any quest),
    // while stepsLeft continues to be derived from the Today task list.
    xpEarned = computeXpTodayAll();

    if (kDebugMode && _debugVerbose) {
      debugPrint('[QuestsEngine] progress stepsLeft=$stepsLeft xp=$xpEarned');
    }
    return TodayProgressSummary(stepsLeft: stepsLeft, xpEarned: xpEarned);
  }

  Future<Map<String, dynamic>> getTodayData({
    DateTime? date,
    Map<String, dynamic> userState = const {},
  }) async {
    await loadCatalog();
    final d = date ?? _now();
    final todayItems = selectToday(d, userState);
    final progress = computeProgress(todayItems);
    // Expose completed state per item for UI
    final now = _now();
    final Map<String, bool> completedToday = {
      for (final q in todayItems)
        q.id: _isIsoSameDay(
          (_telemetry[q.id] as Map<String, dynamic>?)?['last_completed_at']
              as String?,
          now,
        ),
    };
    return {
      'todayItems': todayItems,
      'progress': {
        'stepsLeft': progress.stepsLeft,
        'xpEarned': progress.xpEarned,
      },
      'completedToday': completedToday,
    };
  }

  // --- Explore helpers ---
  // NOTE: Call loadCatalog() before using these in a fresh engine instance.

  /// All quests (may include inactive)
  List<Quest> listAll() => List<Quest>.from(_catalog);

  /// Only active quests
  List<Quest> listActive() => _catalog.where((q) => q.active).toList();

  /// Quests ever completed at least once (based on telemetry 'completes')
  List<Quest> listCompletedEver() => _catalog.where((q) {
    final c = (_telemetry[q.id]?['completes']);
    return (c is int) && c > 0;
  }).toList();

  /// Quests filtered by category (case-insensitive). Null/empty categories are ignored.
  List<Quest> listByCategory(String category) {
    final needle = category.trim().toLowerCase();
    if (needle.isEmpty) return listAll();
    return _catalog
        .where((q) => (q.category ?? '').toLowerCase() == needle)
        .toList();
  }

  /// Unique category names present in catalog (lower-cased)
  Set<String> categories() => _catalog
      .map((q) => (q.category ?? '').trim().toLowerCase())
      .where((c) => c.isNotEmpty)
      .toSet();

  /// Lifetime XP across all days, summing completes * xp per quest.
  int computeLifetimeXp() {
    int total = 0;
    for (final q in _catalog) {
      final c = _telemetry[q.id]?['completes'];
      if (c is int && c > 0) {
        total += c * _xpForQuest(q);
      }
    }
    return total;
  }

  /// XP earned today across all quests (not limited to today's selection).
  int computeXpTodayAll() {
    final now = _now();
    int xp = 0;
    for (final q in _catalog) {
      final lastIso =
          (_telemetry[q.id] as Map<String, dynamic>?)?['last_completed_at']
              as String?;
      if (_isIsoSameDay(lastIso, now)) {
        xp += _xpForQuest(q);
      }
    }
    return xp;
  }

  // --- Explore energy helpers (confined to Explore tab usage) ---
  /// How many Explore awards have been used today (0..limit)
  int exploreEnergySpentToday() {
    final dayKey = _dateKey(_now());
    final entry =
        (_history[dayKey] as Map?)?.cast<String, dynamic>() ?? const {};
    final spent = entry['explore_energy_spent'];
    return (spent is int && spent >= 0) ? spent : 0;
  }

  /// Remaining award capacity for Explore today
  int exploreEnergyLeft({int limit = exploreDailyLimit}) {
    final spent = exploreEnergySpentToday();
    final left = limit - spent;
    return left < 0 ? 0 : left;
  }

  /// Attempt to award a completion for Explore with daily energy gating.
  /// Returns true if XP was awarded (and energy consumed), false otherwise.
  Future<bool> tryAwardExplore(
    String questId, {
      int? elapsedMs,
      int limit = exploreDailyLimit,
    }) async {
    // Do not double-award same quest on the same day
    if (isCompletedToday(questId)) {
      if (kDebugMode && _debugVerbose) {
        debugPrint(
          '[QuestsEngine][Explore] Already completed today questId=$questId',
        );
      }
      return false;
    }

    // Respect daily energy limit
    if (exploreEnergyLeft(limit: limit) <= 0) {
      if (kDebugMode && _debugVerbose) {
        debugPrint('[QuestsEngine][Explore] No energy left for today');
      }
      return false;
    }

    // Award completion and consume 1 energy
    await markComplete(questId, elapsedMs: elapsedMs);
    final dayKey = _dateKey(_now());
    final Map<String, dynamic> entry =
        (_history[dayKey] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    final int spentPrev = (entry['explore_energy_spent'] is int)
        ? (entry['explore_energy_spent'] as int)
        : 0;
    entry['explore_energy_spent'] = spentPrev + 1;
    _history[dayKey] = entry;
    await _persistHistory();
    if (kDebugMode && _debugVerbose) {
      debugPrint(
        '[QuestsEngine][Explore] Awarded questId=$questId energy_used=${spentPrev + 1}/$limit',
      );
    }
    return true;
  }

  /// Current streak length for a streak group over recent days, starting today.
  /// Counts consecutive days (up to [days]) where at least one quest in the
  /// given group was completed.
  int computeStreak(String streakGroup, {int days = 7}) {
    final group = (streakGroup).trim().toLowerCase();
    if (group.isEmpty) return 0;
    final Set<String> groupIds = _catalog
        .where((q) => (q.streakGroup ?? '').trim().toLowerCase() == group)
        .map((q) => q.id)
        .toSet();
    if (groupIds.isEmpty) return 0;

    final now = _now();
    int streak = 0;
    for (int i = 0; i < days; i++) {
      final key = _dateKey(now.subtract(Duration(days: i)));
      final entry =
          (_history[key] as Map?)?.cast<String, dynamic>() ?? const {};
      final dynamic completedAny = entry['completed'];
      final List<String> completed = (completedAny is List)
          ? completedAny.map((e) => e.toString()).toList()
          : const <String>[];
      final bool anyInGroup = completed.any((id) => groupIds.contains(id));
      if (anyInGroup) {
        streak += 1;
      } else {
        break;
      }
    }
    return streak;
  }

  /// Daily streak across all quests: counts consecutive days starting today
  /// where at least one quest (any quest) was completed.
  int computeDailyStreak({int days = 90}) {
    final now = _now();
    int streak = 0;
    for (int i = 0; i < days; i++) {
      final key = _dateKey(now.subtract(Duration(days: i)));
      final entry =
          (_history[key] as Map?)?.cast<String, dynamic>() ?? const {};
      final dynamic completedAny = entry['completed'];
      final List<String> completed = (completedAny is List)
          ? completedAny.map((e) => e.toString()).toList()
          : const <String>[];
      if (completed.isNotEmpty) {
        streak += 1;
      } else {
        break;
      }
    }
    return streak;
  }

  /// Friendly variant of the daily streak for display purposes.
  /// If there are no completions today, returns the streak as of yesterday
  /// (i.e., counts consecutive days ending yesterday). Otherwise, returns the
  /// normal streak including today.
  int computeFriendlyDailyStreak({int days = 90}) {
    final now = _now();
    // Check if there is any completion today
    final todayKey = _dateKey(now);
    final todayEntry =
        (_history[todayKey] as Map?)?.cast<String, dynamic>() ?? const {};
    final dynamic todayCompletedAny = todayEntry['completed'];
    final List<String> todayCompleted = (todayCompletedAny is List)
        ? todayCompletedAny.map((e) => e.toString()).toList()
        : const <String>[];

    if (todayCompleted.isNotEmpty) {
      // Use the standard computation when today has activity
      return computeDailyStreak(days: days);
    }

    // Otherwise, compute streak ending yesterday
    int streak = 0;
    for (int i = 1; i <= days; i++) { // start from yesterday
      final key = _dateKey(now.subtract(Duration(days: i)));
      final entry =
          (_history[key] as Map?)?.cast<String, dynamic>() ?? const {};
      final dynamic completedAny = entry['completed'];
      final List<String> completed = (completedAny is List)
          ? completedAny.map((e) => e.toString()).toList()
          : const <String>[];
      if (completed.isNotEmpty) {
        streak += 1;
      } else {
        break;
      }
    }
    return streak;
  }

  /// Record (max) daily streak across recent days.
  /// Scans up to [days] days including today, counting contiguous segments
  /// of days with any completion, and returns the maximum segment length.
  int computeRecordDailyStreak({int days = 365}) {
    if (days <= 0) return 0;
    final now = _now();
    int maxStreak = 0;
    int current = 0;
    // Iterate oldest -> newest to build contiguous segments
    for (int i = days - 1; i >= 0; i--) {
      final key = _dateKey(now.subtract(Duration(days: i)));
      final entry = (_history[key] as Map?)?.cast<String, dynamic>() ?? const {};
      final dynamic completedAny = entry['completed'];
      final List<String> completed = (completedAny is List)
          ? completedAny.map((e) => e.toString()).toList()
          : const <String>[];
      if (completed.isNotEmpty) {
        current += 1;
        if (current > maxStreak) maxStreak = current;
      } else {
        current = 0;
      }
    }
    return maxStreak;
  }

  /// Whether the given quest has been completed today.
  bool isCompletedToday(String questId) {
    final lastIso =
        (_telemetry[questId] as Map<String, dynamic>?)?['last_completed_at']
            as String?;
    return _isIsoSameDay(lastIso, _now());
  }

  void _ensureQuestStats(String questId) {
    _telemetry[questId] = (_telemetry[questId] as Map<String, dynamic>?) ?? {};
  }

  Future<void> _persistTelemetry() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsTelemetryKey, jsonEncode(_telemetry));
  }

  Future<void> _persistHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsHistoryKey, jsonEncode(_history));
  }

  Future<void> _persistTimers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsTimersKey, jsonEncode(_timers));
  }

  // Built-in lightweight checks (run in debug/dev)
  @visibleForTesting
  void debugRunSelectorChecks() {
    final baseDate = DateTime(2025, 1, 1);
    final day1 = selectToday(baseDate, const {});
    final day2 = selectToday(baseDate, const {});
    assert(
      listEquals(
        day1.map((e) => e.id).toList(),
        day2.map((e) => e.id).toList(),
      ),
      'Selection must be deterministic per date',
    );

    bool hasTask = day1.any((q) => q.tag == QuestTag.task);
    bool hasTipRes = day1.any(
      (q) => q.tag == QuestTag.tip || q.tag == QuestTag.resource,
    );
    bool hasCheckProg = day1.any(
      (q) => q.tag == QuestTag.checkin || q.tag == QuestTag.progress,
    );
    bool hasShort = day1.any((q) => (q.durationMin ?? 999) <= 3);

    assert(hasTask, 'Must include at least 1 TASK');
    assert(hasTipRes, 'Must include at least 1 of {TIP, RESOURCE}');
    assert(hasCheckProg, 'Must include at least 1 of {CHECK-IN, PROGRESS}');
    assert(hasShort, 'Must include at least 1 item with duration <= 3 minutes');
  }
}

// Embedded fallback JSON (Week 0)
const String _embeddedFallbackJson = r'''[
  {"quest_id":"task_focus_reset_v1","tag":"TASK","title":"Focus reset","subtitle":"Quick breathing + desk tidy","duration_min":2,"url":null,"checklist":["Open window","4× box breaths","Clear top 3 items"],"timer_suggested":true,"active":true,"hide_in_explore":true},
  {"quest_id":"task_study_sprint_v1","tag":"TASK","title":"Study sprint","subtitle":"Timer + no‑phone rule","duration_min":10,"url":null,"checklist":["Set 10‑min timer","Phone away","Single task only"],"timer_suggested":true,"active":true,"hide_in_explore":true},
  {"quest_id":"checkin_quick_v1","tag":"CHECK-IN","title":"Quick check‑in","subtitle":"Mood, Energy, Stress chips","duration_min":2,"url":null,"checklist":[],"timer_suggested":false,"active":true,"hide_in_explore":true},
  {"quest_id":"resource_calm_music_v1","tag":"RESOURCE","title":"Calm music","subtitle":"Lo‑fi playlist","duration_min":null,"url":null,"checklist":[],"timer_suggested":false,"active":true,"hide_in_explore":true},
  {"quest_id":"tip_one_tiny_step_v1","tag":"TIP","title":"One tiny step","subtitle":"Pick the easiest task first","duration_min":null,"url":null,"checklist":[],"timer_suggested":false,"active":true,"hide_in_explore":true},
  {"quest_id":"progress_weekly_reassess_v1","tag":"PROGRESS","title":"Weekly reassess","subtitle":"View last 3 assessments","duration_min":5,"url":null,"checklist":[],"timer_suggested":false,"active":true,"hide_in_explore":true},
  {"quest_id":"reminder_plan_v1","tag":"REMINDER","title":"Plan + reminder","subtitle":"Set a nudge for tomorrow","duration_min":3,"url":null,"checklist":[],"timer_suggested":false,"active":true,"hide_in_explore":true},
  {"quest_id":"task_stretch_break_v1","tag":"TASK","title":"Stretch break","subtitle":"Neck/shoulder/chest","duration_min":3,"url":null,"checklist":["Neck rolls x5","Shoulder shrugs x10","Chest opener x5"],"timer_suggested":true,"active":true,"category":"activity"},
  {"quest_id":"task_micro_review_v1","tag":"TASK","title":"Micro‑review","subtitle":"Skim yesterday’s toughest concept","duration_min":5,"url":null,"checklist":[],"timer_suggested":true,"active":true,"category":"learning"},
  {"quest_id":"resource_study_focus_tips_v1","tag":"RESOURCE","title":"Study focus tips","subtitle":"Three pointers","duration_min":null,"url":null,"checklist":[],"timer_suggested":false,"active":true,"hide_in_explore":true},
  {"quest_id":"tip_time_block_v1","tag":"TIP","title":"Time block","subtitle":"Reserve 10 min for hardest task","duration_min":null,"url":null,"checklist":[],"timer_suggested":true,"active":true,"category":"learning"},
  {"quest_id":"tip_phone_away_v1","tag":"TIP","title":"Phone away","subtitle":"Put device in another room","duration_min":null,"url":null,"checklist":[],"timer_suggested":false,"active":true,"category":"challenge"},
  {"quest_id":"task_gratitude_note_v1","tag":"TASK","title":"Gratitude note","subtitle":"Write 1 line you’re thankful for","duration_min":2,"url":null,"checklist":[],"timer_suggested":false,"active":true,"category":"social"},
  {"quest_id":"resource_short_stretch_v1","tag":"RESOURCE","title":"Short stretch","subtitle":"Illustrated routine","duration_min":null,"url":null,"checklist":[],"timer_suggested":false,"active":true,"category":"activity"},
  {"quest_id":"task_focus_reset_v2","tag":"TASK","title":"Focus reset","subtitle":"2‑min reset: breathe + tidy","duration_min":2,"url":null,"checklist":["4× box breaths","Clear top item"],"timer_suggested":true,"active":true,"hide_in_explore":true},
  {"quest_id":"task_study_sprint_v2","tag":"TASK","title":"Study sprint","subtitle":"10‑min deep focus","duration_min":10,"url":null,"checklist":["Timer set","Desk clear"],"timer_suggested":true,"active":true,"hide_in_explore":true},
  {"quest_id":"checkin_quick_v2","tag":"CHECK-IN","title":"Quick check‑in","subtitle":"How’s your energy?","duration_min":2,"url":null,"checklist":[],"timer_suggested":false,"active":true,"hide_in_explore":true},
  {"quest_id":"resource_calm_music_v2","tag":"RESOURCE","title":"Calm music","subtitle":"Instrumental mix","duration_min":null,"url":null,"checklist":[],"timer_suggested":false,"active":true,"hide_in_explore":true},
  {"quest_id":"tip_one_tiny_step_v2","tag":"TIP","title":"One tiny step","subtitle":"Start with 1 minute","duration_min":null,"url":null,"checklist":[],"timer_suggested":false,"active":true,"hide_in_explore":true},
  {"quest_id":"progress_weekly_reassess_v2","tag":"PROGRESS","title":"Weekly reassess","subtitle":"Review last notes","duration_min":5,"url":null,"checklist":[],"timer_suggested":false,"active":true,"hide_in_explore":true},
  {"quest_id":"reminder_plan_v2","tag":"REMINDER","title":"Plan + reminder","subtitle":"Set nudge for morning","duration_min":3,"url":null,"checklist":[],"timer_suggested":false,"active":true,"hide_in_explore":true},
  {"quest_id":"task_stretch_break_v2","tag":"TASK","title":"Stretch break","subtitle":"Back/hips quick set","duration_min":3,"url":null,"checklist":["Hip opener x5","Cat‑cow x5"],"timer_suggested":true,"active":true,"category":"activity"},
  {"quest_id":"task_micro_review_v2","tag":"TASK","title":"Micro‑review","subtitle":"Skim hard topic","duration_min":5,"url":null,"checklist":[],"timer_suggested":true,"active":true,"category":"learning"},
  {"quest_id":"resource_study_focus_tips_v2","tag":"RESOURCE","title":"Study focus tips","subtitle":"2 quick ideas","duration_min":null,"url":null,"checklist":[],"timer_suggested":false,"active":true,"hide_in_explore":true},
  {"quest_id":"tip_time_block_v2","tag":"TIP","title":"Time block","subtitle":"Block 15 minutes","duration_min":null,"url":null,"checklist":[],"timer_suggested":true,"active":true,"category":"learning"},
  {"quest_id":"tip_phone_away_v2","tag":"TIP","title":"Phone away","subtitle":"Silent + out of reach","duration_min":null,"url":null,"checklist":[],"timer_suggested":false,"active":true,"category":"challenge"},
  {"quest_id":"task_gratitude_note_v2","tag":"TASK","title":"Gratitude note","subtitle":"1 line to someone","duration_min":2,"url":null,"checklist":[],"timer_suggested":false,"active":true,"category":"social"},
  {"quest_id":"resource_short_stretch_v2","tag":"RESOURCE","title":"Short stretch","subtitle":"Standing sequence","duration_min":null,"url":null,"checklist":[],"timer_suggested":false,"active":true,"category":"activity"},
  {"quest_id":"tip_water_break_v1","tag":"TIP","title":"Water break","subtitle":"Drink a glass of water","duration_min":1,"url":null,"checklist":[],"timer_suggested":false,"active":true,"category":"activity"},
  {"quest_id":"resource_breathing_v1","tag":"RESOURCE","title":"Box breathing guide","subtitle":"Simple visual","duration_min":2,"url":null,"checklist":[],"timer_suggested":false,"active":true,"category":"mindfulness"}
  ,
  {"quest_id":"task_morning_meditation_v1","tag":"TASK","title":"Morning meditation","subtitle":"5‑min calm start","duration_min":5,"url":null,"checklist":["Find quiet spot","4× box breaths"],"timer_suggested":true,"active":true,"category":"mindfulness","points":12,"streak_group":"morning_meditation","recurrence":"daily"},
  {"quest_id":"task_take_walk_v1","tag":"TASK","title":"Take a walk","subtitle":"10‑min light walk","duration_min":10,"url":null,"checklist":["Shoes on","Airplane mode optional"],"timer_suggested":true,"active":true,"category":"activity","points":12,"streak_group":"daily_walk","recurrence":"daily"},
  {"quest_id":"task_connect_friend_v1","tag":"TASK","title":"Connect with a friend","subtitle":"Send a short message","duration_min":2,"url":null,"checklist":["Pick a name","Send 1 line"],"timer_suggested":false,"active":true,"category":"social","points":10,"streak_group":"social_reachout","recurrence":"anytime"},
  {"quest_id":"resource_learn_mental_health_v1","tag":"RESOURCE","title":"Learn about mental health","subtitle":"Read a short article","duration_min":5,"url":"https://www.who.int/health-topics/mental-health","checklist":[],"timer_suggested":false,"active":true,"category":"learning","points":8,"streak_group":null,"recurrence":"anytime"}
]''';
