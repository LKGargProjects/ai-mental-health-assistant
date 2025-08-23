import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_buddy_web/quests/quests_engine.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('Today tasks completions reset when advancing the day', () async {
    final engine = QuestsEngine();
    await engine.loadCatalog();

    final base = DateTime(2025, 1, 1, 10, 0, 0);
    engine.debugSetNow(() => base);

    // Select today and complete all of them
    final today = engine.selectToday(base, const {});
    expect(today, isNotEmpty);

    for (final q in today) {
      await engine.markComplete(q.id);
    }

    // Progress should show zero steps left after completing all displayed cards
    final progressDone = engine.computeProgress(today);
    expect(progressDone.stepsLeft, 0);
    expect(engine.computeXpTodayAll(), greaterThan(0));

    // Advance one day
    final nextDay = base.add(const Duration(days: 1));
    engine.debugSetNow(() => nextDay);

    // Load new today data using the new date
    final data = await engine.getTodayData(date: nextDay, userState: const {});
    final List completedFlags = (data['completedToday'] as Map<String, bool>)
        .values
        .toList();

    // All should be false on a new day
    expect(completedFlags.every((e) => e == false), isTrue);

    // XP for today should be zero at start of the new day
    expect(engine.computeXpTodayAll(), 0);
  });

  test('Explore awards: prevent double-award same day and reset next day', () async {
    final engine = QuestsEngine();
    await engine.loadCatalog();

    final base = DateTime(2025, 2, 1, 9, 0, 0);
    engine.debugSetNow(() => base);

    // Find an active quest visible in Explore
    final exploreQuest = engine
        .listActive()
        .firstWhere((q) => q.hideInExplore == false, orElse: () => engine.listActive().first);

    // Initially, energy spent should be 0
    expect(engine.exploreEnergySpentToday(), 0);

    // First award succeeds
    final ok1 = await engine.tryAwardExplore(exploreQuest.id);
    expect(ok1, isTrue);
    expect(engine.exploreEnergySpentToday(), 1);
    expect(engine.isCompletedToday(exploreQuest.id), isTrue);

    // Second award for same quest same day should fail (already completed today)
    final ok2 = await engine.tryAwardExplore(exploreQuest.id);
    expect(ok2, isFalse);
    expect(engine.exploreEnergySpentToday(), 1);

    // Advance to next day: energy and completion reset
    final nextDay = base.add(const Duration(days: 1));
    engine.debugSetNow(() => nextDay);

    expect(engine.exploreEnergySpentToday(), 0);
    expect(engine.isCompletedToday(exploreQuest.id), isFalse);

    // Award again should succeed on the new day
    final ok3 = await engine.tryAwardExplore(exploreQuest.id);
    expect(ok3, isTrue);
    expect(engine.exploreEnergySpentToday(), 1);
    expect(engine.isCompletedToday(exploreQuest.id), isTrue);
  });
}
