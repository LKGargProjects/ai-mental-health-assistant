import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_buddy_web/models/mood_entry.dart';
import 'package:ai_buddy_web/providers/mood_provider.dart';
import 'package:ai_buddy_web/services/api_service.dart';

class FakeApiService extends ApiService {
  bool failPost = true;
  List<MoodEntry> history = [];
  int postCalls = 0;

  @override
  Future<Map<String, dynamic>> addMoodEntry(Map<String, dynamic> data) async {
    postCalls += 1;
    if (failPost) {
      throw Exception('network');
    }
    return {'ok': true};
  }

  @override
  Future<List<MoodEntry>> getMoodHistory() async {
    return history;
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('MoodProvider enqueues failed POST and drains queue on retry', () async {
    final fake = FakeApiService();

    final provider = MoodProvider(apiService: fake, eagerLoad: false);

    expect(provider.pendingQueueLength, 0);

    // First attempt fails -> enqueued
    await provider.addMoodEntry(4, note: 'test');
    expect(fake.postCalls, 1);
    expect(provider.pendingQueueLength, 1);
    expect(provider.moodEntries.length, 1); // optimistic update
    expect(provider.error, isNotNull);

    // Now succeed and ensure drain clears queue and refreshes history
    fake.failPost = false;
    fake.history = [
      MoodEntry(
        moodLevel: 4,
        note: 'test',
        timestamp: DateTime.now().toUtc(),
      ),
    ];

    await provider.retryPendingMoodSends();

    expect(provider.pendingQueueLength, 0);
    expect(provider.moodEntries.length, 1);
    expect(provider.moodEntries.first.moodLevel, 4);
  });
}
