import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:narrately/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App boot and settings toggle', (WidgetTester tester) async {
    await app.main();
    await tester.pumpAndSettle();

    // Verify Library Screen is shown initially
    expect(find.text('Library'), findsWidgets);
    expect(find.text('Import EPUB'), findsWidgets);

    // Tap on Settings tab
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();

    // Verify Settings Screen is shown
    expect(find.text('Appearance'), findsWidgets);
    expect(find.text('Dark'), findsWidgets);

    // Tap on Dark Mode
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    // Give it a second to see it visually if we were watching
    await Future.delayed(const Duration(seconds: 2));
    
    // Tap back to System Default
    await tester.tap(find.text('System Default'));
    await tester.pumpAndSettle();
    
    // Tap back to Library tab
    await tester.tap(find.text('Library').last);
    await tester.pumpAndSettle();
    
    expect(find.text('Import EPUB'), findsWidgets);
  });
}
