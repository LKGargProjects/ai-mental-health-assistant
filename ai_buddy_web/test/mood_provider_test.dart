import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_buddy_web/providers/mood_provider.dart';
import 'package:ai_buddy_web/services/api_service.dart';
import 'package:ai_buddy_web/models/mood_entry.dart';

class FakeApiService extends ApiService {
  bool postShouldFail;
  bool getShouldFail;
  List<MoodEntry> historyToReturn;

  FakeApiService({
    this.postShouldFail = false,
    this.getShouldFail = false,
    List<MoodEntry>? historyToReturn,
  }) : historyToReturn = historyToReturn ?? <MoodEntry>[];

  @override
  Future<Map<String, dynamic>> addMoodEntry(Map<String, dynamic> data) async {
    if (postShouldFail) {
      throw Exception('POST failed');
    }
    return <String, dynamic>{'ok': true};
  }

  @override
  Future<List<MoodEntry>> getMoodHistory() async {
    if (getShouldFail) {
      throw Exception('GET failed');
    }
    return historyToReturn;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('MoodProvider.addMoodEntry', () {
    test('sets error only when POST fails; optimistic entry remains', () async {
      final fake = FakeApiService(postShouldFail: true);
      final provider = MoodProvider(apiService: fake, eagerLoad: false);

      expect(provider.error, isNull);
      expect(provider.moodEntries.length, 0);

      await provider.addMoodEntry(4, note: 'test');

      expect(provider.error, isNotNull);
      expect(provider.moodEntries.length, 1, reason: 'optimistic entry should persist');
    });

    test('does not set error when refresh GET fails after successful POST; keeps optimistic data', () async {
      final fake = FakeApiService(postShouldFail: false, getShouldFail: true);
      final provider = MoodProvider(apiService: fake, eagerLoad: false);

      await provider.addMoodEntry(3);

      expect(provider.error, isNull, reason: 'GET failure should not surface error');
      expect(provider.moodEntries.length, 1, reason: 'optimistic entry remains when GET fails');
    });

    test('replaces local entries with server history when GET succeeds after POST', () async {
      final serverHistory = <MoodEntry>[
        MoodEntry(moodLevel: 2, note: 'server a', timestamp: DateTime.now().toUtc()),
        MoodEntry(moodLevel: 5, note: 'server b', timestamp: DateTime.now().toUtc()),
      ];
      final fake = FakeApiService(postShouldFail: false, getShouldFail: false, historyToReturn: serverHistory);
      final provider = MoodProvider(apiService: fake, eagerLoad: false);

      await provider.addMoodEntry(5, note: 'local optimistic');

      expect(provider.error, isNull);
      expect(provider.moodEntries.length, serverHistory.length);
      // Ensure the first returned entry matches server data (not the optimistic one)
      expect(provider.moodEntries.first.moodLevel, serverHistory.first.moodLevel);
      expect(provider.moodEntries.first.note, serverHistory.first.note);
    });
  });
}
