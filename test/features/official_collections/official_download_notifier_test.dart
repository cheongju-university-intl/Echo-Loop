import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fluency/database/app_database.dart';
import 'package:fluency/features/official_collections/download/download_progress.dart';
import 'package:fluency/features/official_collections/download/official_download_notifier.dart';
import 'package:fluency/database/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 只测 start() 的纯逻辑分支（busy / alreadyDownloaded）。
///
/// 完整下载流程涉及真实 Dio + 文件系统 + API，在单测中不可靠且无价值；
/// 端到端走 integration test + 手动 E2E 验证。
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    initAppDatabase(db);
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> seedAudio(
    String id, {
    String? remoteAudioId,
    bool downloaded = false,
  }) async {
    await db.audioItemDao.upsert(
      AudioItemsCompanion(
        id: Value(id),
        name: const Value('Track'),
        audioPath: downloaded
            ? const Value<String?>('audios/official/sha.m4a')
            : const Value<String?>(null),
        transcriptPath: downloaded
            ? const Value<String?>('transcripts/official_x.srt')
            : const Value<String?>(null),
        addedDate: Value(DateTime(2026, 4, 19)),
        updatedAt: Value(DateTime(2026, 4, 19)),
        remoteAudioId: Value(remoteAudioId),
        audioSha256: const Value('sha'),
      ),
    );
  }

  test('audio 已下载 → alreadyDownloaded，不启动任务', () async {
    await seedAudio('a1', remoteAudioId: 'r1', downloaded: true);
    final result = await container
        .read(officialDownloadProvider.notifier)
        .start(audioItemId: 'a1', displayName: 'Track 1');
    expect(result, StartResult.alreadyDownloaded);
    expect(container.read(officialDownloadProvider), isA<DownloadIdle>());
  });

  test('audio 不存在（remoteAudioId=null） → alreadyDownloaded', () async {
    await seedAudio('a2', remoteAudioId: null, downloaded: false);
    final result = await container
        .read(officialDownloadProvider.notifier)
        .start(audioItemId: 'a2', displayName: 'Track 2');
    expect(result, StartResult.alreadyDownloaded);
  });

  test(
    'audioItemId 在 DB 不存在 → alreadyDownloaded（防御性，调用端可忽略）',
    () async {
      final result = await container
          .read(officialDownloadProvider.notifier)
          .start(audioItemId: 'missing', displayName: 'x');
      expect(result, StartResult.alreadyDownloaded);
    },
  );

  test('并发约束：已有任务在跑 → busy', () async {
    await seedAudio('a1', remoteAudioId: 'r1');
    await seedAudio('a2', remoteAudioId: 'r2');

    // 手动把 state 设为 InProgress，模拟前一个任务正在跑
    final notifier = container.read(officialDownloadProvider.notifier);
    notifier.state = const DownloadInProgress(
      audioItemId: 'a1',
      displayName: 'Track 1',
      progress: 0.3,
    );

    final result = await notifier.start(
      audioItemId: 'a2',
      displayName: 'Track 2',
    );
    expect(result, StartResult.busy);
    // state 不变：仍是 a1 的 InProgress
    final s = container.read(officialDownloadProvider) as DownloadInProgress;
    expect(s.audioItemId, 'a1');
  });

  test('cancel 将 state 切回 Idle（即使没有活跃任务也幂等）', () async {
    final notifier = container.read(officialDownloadProvider.notifier);
    notifier.state = const DownloadInProgress(
      audioItemId: 'a1',
      displayName: 'Track 1',
      progress: 0.5,
    );
    await notifier.cancel();
    expect(container.read(officialDownloadProvider), isA<DownloadIdle>());

    // 再次 cancel 不抛
    await notifier.cancel();
    expect(container.read(officialDownloadProvider), isA<DownloadIdle>());
  });

  test('activeAudioItemId 反映当前 InProgress 的 audioItemId', () async {
    final notifier = container.read(officialDownloadProvider.notifier);
    expect(notifier.activeAudioItemId, isNull);
    notifier.state = const DownloadInProgress(
      audioItemId: 'a1',
      displayName: 'x',
      progress: 0,
    );
    expect(notifier.activeAudioItemId, 'a1');
  });
}
