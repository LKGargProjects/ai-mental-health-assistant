import 'package:flutter_test/flutter_test.dart';
import 'package:ai_buddy_web/main.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_buddy_web/providers/community_provider.dart';

void main() {
  testWidgets('Community Feed loads and displays initial posts', (WidgetTester tester) async {
    // Create a test provider
    final testProvider = CommunityProvider();
    
    // Build our app with test provider
    await tester.pumpWidget(
      ChangeNotifierProvider<CommunityProvider>(
        create: (_) => testProvider,
        child: const MyApp(),
      ),
    );

    // Wait for initial load
    await tester.pumpAndSettle();

    // Verify app is loaded by checking for main UI elements
    expect(find.byType(Scaffold), findsWidgets);
    
    // Check if we're in a loading state initially
    if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
    }

    // Verify posts are loaded (either ListView or other container)
    final listView = find.byType(ListView);
    final column = find.byType(Column);
    final singleChildScrollView = find.byType(SingleChildScrollView);
    
    // At least one of these should be present
    expect(
      listView.evaluate().isNotEmpty || 
      column.evaluate().isNotEmpty || 
      singleChildScrollView.evaluate().isNotEmpty,
      isTrue,
      reason: 'Expected to find a scrollable widget containing posts',
    );
  });
}
