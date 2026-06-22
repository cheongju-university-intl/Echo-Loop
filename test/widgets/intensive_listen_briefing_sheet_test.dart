import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/widgets/intensive_listen/intensive_listen_briefing_sheet.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('入口面板默认显示 1x 播放速度下拉菜单', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showIntensiveListenBriefingSheet(
                context: context,
                sentenceCount: 10,
                onStartPractice: (_, _) {},
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Playback Speed'), findsOneWidget);
    expect(find.text('1x'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButton<double> &&
            widget.value == 1.0 &&
            widget.elevation == 8,
      ),
      findsOneWidget,
    );
  });

  testWidgets('入口面板按 defaultPlaybackSpeed 初始化下拉值', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showIntensiveListenBriefingSheet(
                context: context,
                sentenceCount: 10,
                defaultPlaybackSpeed: 0.85,
                onStartPractice: (_, _) {},
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('0.85x'), findsOneWidget);
  });

  testWidgets('选择速度后随开始练习回调透出', (tester) async {
    double? selectedSpeed;
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showIntensiveListenBriefingSheet(
                context: context,
                sentenceCount: 10,
                onStartPractice: (speed, _) {
                  selectedSpeed = speed;
                },
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1x'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.5x').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Practice'));
    await tester.pumpAndSettle();

    expect(selectedSpeed, 1.5);
  });

  testWidgets('句间停顿默认为「自动」(-1.0)，点击开始练习时回传', (tester) async {
    double? selectedPause;
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showIntensiveListenBriefingSheet(
                context: context,
                sentenceCount: 10,
                onStartPractice: (_, pause) {
                  selectedPause = pause;
                },
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Pause between sentences'), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget);

    await tester.tap(find.text('Start Practice'));
    await tester.pumpAndSettle();

    expect(selectedPause, -1.0);
  });

  testWidgets('不传 onSkip 时不显示跳过按钮', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showIntensiveListenBriefingSheet(
                context: context,
                sentenceCount: 10,
                onStartPractice: (_, _) {},
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Skip'), findsNothing);
  });

  testWidgets('传 onSkip 时显示跳过按钮，点击触发回调', (tester) async {
    var skipped = false;
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showIntensiveListenBriefingSheet(
                context: context,
                sentenceCount: 10,
                onStartPractice: (_, _) {},
                onSkip: () => skipped = true,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(skipped, isTrue);
  });

  testWidgets('选择 3x 后回传 3.0', (tester) async {
    double? selectedPause;
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showIntensiveListenBriefingSheet(
                context: context,
                sentenceCount: 10,
                onStartPractice: (_, pause) {
                  selectedPause = pause;
                },
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Auto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3x').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Practice'));
    await tester.pumpAndSettle();

    expect(selectedPause, 3.0);
  });
}
