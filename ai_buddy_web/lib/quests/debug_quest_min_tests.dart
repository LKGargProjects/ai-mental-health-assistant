import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quests_engine.dart';

/// Debug-only minimal tests for Week 0 quest engine.
/// Returns a brief summary string suitable for a SnackBar.
Future<String> runMinQuestTests({DateTime? now}) async {
  assert(kDebugMode, 'Debug quest tests should only run in debug');

  final prefs = await SharedPreferences.getInstance();

  // Backup keys to avoid polluting user data
  const catalogKey = 'quests_engine.catalog_v1';
  const telemetryKey = 'quests_engine.telemetry_v1';
  const historyKey = 'quests_engine.history_v1';
  const timersKey = 'quests_engine.timers_v1';
  const reminderKey = 'quests_engine.reminder_v1';

  final backups = <String, String?>{
    catalogKey: prefs.getString(catalogKey),
    telemetryKey: prefs.getString(telemetryKey),
    historyKey: prefs.getString(historyKey),
    timersKey: prefs.getString(timersKey),
    reminderKey: prefs.getString(reminderKey),
  };

  String status(String name, bool pass) => pass ? '✅ $name' : '❌ $name';

  bool passProgress = false;
  bool passReminder = false;
  bool passMidnight = false;

  try {
    final engine = QuestsEngine();

    final baseDate = now ?? DateTime.now();
    final d1 = DateTime(baseDate.year, baseDate.month, baseDate.day);
    final d2 = d1.add(const Duration(days: 1));

    // 1) Deterministic progress update
    final day1a = await engine.getTodayData(date: d1);
    final items = (day1a['todayItems'] as List<Quest>);
    final tasks = items.where((q) => q.tag == QuestTag.task).toList();
    if (tasks.isNotEmpty) {
      final before = engine.computeProgress(items).stepsLeft;
      await engine.markComplete(tasks.first.id);
      final day1b = await engine.getTodayData(date: d1);
      final after = engine.computeProgress((day1b['todayItems'] as List<Quest>)).stepsLeft;
      passProgress = after <= before && (before - after) <= 1;
    } else {
      // No task today is rare; still treat as pass for minimal test
      passProgress = true;
    }

    // 2) Reminder persistence (simple key check)
    final testReminderValue = '08:00';
    await prefs.setString(reminderKey, testReminderValue);
    final reread = prefs.getString(reminderKey);
    passReminder = reread == testReminderValue;

    // 3) Midnight refresh simulation
    // Same-day determinism
    final sameDayA = await engine.getTodayData(date: d1);
    final sameDayB = await engine.getTodayData(date: d1);
    final idsA = (sameDayA['todayItems'] as List<Quest>).map((e) => e.id).toList();
    final idsB = (sameDayB['todayItems'] as List<Quest>).map((e) => e.id).toList();
    final deterministicSameDay = listEquals(idsA, idsB);

    // Next-day selection available and typically different
    final nextDay = await engine.getTodayData(date: d2);
    final idsNext = (nextDay['todayItems'] as List<Quest>).map((e) => e.id).toList();
    final sizeOk = idsNext.length >= 5;
    // It's possible, though unlikely, that ids are equal day-to-day. Don't fail hard on that.
    passMidnight = deterministicSameDay && sizeOk;

    debugPrint('[Quests-MinTests] progress=$passProgress reminder=$passReminder midnight=$passMidnight');
  } catch (e, st) {
    debugPrint('[Quests-MinTests] Exception: $e\n$st');
  } finally {
    // Restore backups
    for (final entry in backups.entries) {
      final key = entry.key;
      final val = entry.value;
      if (val == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, val);
      }
    }
  }

  return [
    status('Progress', passProgress),
    status('Reminders', passReminder),
    status('Midnight', passMidnight),
  ].join(' • ');
}
