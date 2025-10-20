// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:listen_master/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Create mock PackageInfo for testing
    final packageInfo = PackageInfo(
      appName: 'Listen Master',
      packageName: 'com.example.listen_master',
      version: '1.0.0',
      buildNumber: '1',
    );

    // Build our app and trigger a frame.
    await tester.pumpWidget(ListenMasterApp(packageInfo: packageInfo));

    // Verify that the app loads
    expect(find.text('Audio Library'), findsOneWidget);
  });
}
