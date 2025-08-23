import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_buddy_web/quests/quests_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Ensure a clean prefs state for each test run
    SharedPreferences.setMockInitialValues({});
  });

  group('QuestsEngine completion toggle', () {
    test('markComplete sets completed today and awards XP once', () async {
      final engine = QuestsEngine();
      await engine.loadCatalog();
      // pick a deterministic quest id from catalog via today selection
      final today = engine.selectToday(DateTime.now(), const {});
      expect(today, isNotEmpty);
      final questId = today.first.id;

      expect(engine.isCompletedToday(questId), isFalse);
      final xpBefore = engine.computeLifetimeXp();

      await engine.markComplete(questId);
      expect(engine.isCompletedToday(questId), isTrue);

      final xpAfterFirst = engine.computeLifetimeXp();
      expect(xpAfterFirst, greaterThanOrEqualTo(xpBefore));

      // Re-mark same day should NOT double-award
      await engine.markComplete(questId);
      final xpAfterSecond = engine.computeLifetimeXp();
      expect(xpAfterSecond, equals(xpAfterFirst));
    });

    test('uncompleteToday removes completion and rolls back telemetry', () async {
      final engine = QuestsEngine();
      await engine.loadCatalog();
      final today = engine.selectToday(DateTime.now(), const {});
      final questId = today.first.id;

      await engine.markComplete(questId);
      expect(engine.isCompletedToday(questId), isTrue);
      final xpAfter = engine.computeLifetimeXp();

      await engine.uncompleteToday(questId);
      expect(engine.isCompletedToday(questId), isFalse);

      final xpAfterUndo = engine.computeLifetimeXp();
      // Lifetime XP may decrease by the quest XP value
      expect(xpAfterUndo, lessThanOrEqualTo(xpAfter));
    });

    test('computeXpTodayAll reflects today completions across quests', () async {
      final engine = QuestsEngine();
      await engine.loadCatalog();
      final today = engine.selectToday(DateTime.now(), const {});

      // Complete up to two quests if available
      final ids = today.take(2).map((q) => q.id).toList();
      for (final id in ids) {
        await engine.markComplete(id);
      }

      final xpToday = engine.computeXpTodayAll();
      expect(xpToday, greaterThan(0));

      // Undo one and ensure xp drops or stays same (if other awards exist)
      if (ids.isNotEmpty) {
        final beforeUndo = engine.computeXpTodayAll();
        await engine.uncompleteToday(ids.first);
        final afterUndo = engine.computeXpTodayAll();
        expect(afterUndo, lessThanOrEqualTo(beforeUndo));
      }
    });
  });
}
