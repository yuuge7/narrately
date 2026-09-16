import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:narrately/main.dart';

void main() {
  testWidgets('Library screen empty state smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: NarratelyApp()));

    // Verify that the empty state is displayed
    expect(find.text('Your library is empty'), findsOneWidget);
    expect(find.text('Import EPUB'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
