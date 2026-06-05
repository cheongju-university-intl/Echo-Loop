import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:echo_loop/database/daos/sentence_ai_cache_dao.dart';
import 'package:echo_loop/database/daos/saved_sense_group_dao.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/providers/sentence_ai_provider.dart';
import 'package:echo_loop/router/app_router.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';
import 'package:echo_loop/widgets/practice/annotation_content_view.dart';

import '../helpers/mock_providers.dart';

class _NoopSentenceAiApiClient extends SentenceAiApiClient {
  _NoopSentenceAiApiClient() : super.withDio(_UnusedDio());
}

class _UnusedDio extends MockDio {}

class _MockCacheDao extends Mock implements SentenceAiCacheDao {}

class _MockSavedSenseGroupDao extends Mock implements SavedSenseGroupDao {}

class MockDio extends Mock implements Dio {}

void main() {
  Future<void> pumpAuthTestApp(
    WidgetTester tester, {
    required SentenceAiCacheDao cacheDao,
    required SavedSenseGroupDao savedSenseGroupDao,
  }) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: AnnotationContentView(
              text: 'Hello world.',
              aiNotifier: SentenceAiNotifier(
                cacheDao: cacheDao,
                apiClient: _NoopSentenceAiApiClient(),
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const Scaffold(body: Text('Login page')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          analyticsOverride(),
          usageOverride(),
          ...learningSettingsOverrides(),
          supabaseSessionProvider.overrideWith(
            (ref) => Stream<Session?>.value(null),
          ),
          savedSenseGroupDaoProvider.overrideWithValue(savedSenseGroupDao),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('未登录请求新意群时展示可关闭的登录弹窗', (tester) async {
    final cacheDao = _MockCacheDao();
    final savedSenseGroupDao = _MockSavedSenseGroupDao();
    when(() => cacheDao.getByHash(any(), any())).thenAnswer((_) async => null);
    when(
      savedSenseGroupDao.watchSavedPhraseTexts,
    ).thenAnswer((_) => Stream<Set<String>>.value(const {}));

    await pumpAuthTestApp(
      tester,
      cacheDao: cacheDao,
      savedSenseGroupDao: savedSenseGroupDao,
    );

    await tester.tap(find.text('Groups'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Sign in to use AI features'), findsOneWidget);
    expect(
      find.textContaining(
        'AI translation, analysis, and sense group splitting',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sign in to use AI features'), findsNothing);

    await tester.tap(find.text('Groups'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Sign In'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Login page'), findsOneWidget);
  });

  testWidgets('未登录请求新翻译时展示登录弹窗', (tester) async {
    final cacheDao = _MockCacheDao();
    final savedSenseGroupDao = _MockSavedSenseGroupDao();
    when(() => cacheDao.getByHash(any(), any())).thenAnswer((_) async => null);
    when(
      savedSenseGroupDao.watchSavedPhraseTexts,
    ).thenAnswer((_) => Stream<Set<String>>.value(const {}));

    await pumpAuthTestApp(
      tester,
      cacheDao: cacheDao,
      savedSenseGroupDao: savedSenseGroupDao,
    );

    await tester.tap(find.text('Translate'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Sign in to use AI features'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
