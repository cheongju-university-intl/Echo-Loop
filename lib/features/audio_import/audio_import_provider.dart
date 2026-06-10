import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/audio_item.dart';
import '../../providers/audio_library_provider.dart';
import '../../providers/collection_provider.dart';
import 'audio_import_models.dart';
import 'audio_import_service.dart';

part 'audio_import_provider.g.dart';

@riverpod
AudioImportService audioImportService(AudioImportServiceRef ref) {
  return AudioImportService();
}

@riverpod
class AudioImportController extends _$AudioImportController {
  CancelToken? _cancelToken;
  int _sessionId = 0;

  @override
  AudioImportState build() {
    ref.onDispose(() => _cancelToken?.cancel('disposed'));
    return const AudioImportIdle();
  }

  Future<AudioItem?> importFromUrl(String url, {String? collectionId}) async {
    if (state is AudioImportDownloading || state is AudioImportSaving) {
      return null;
    }

    _sessionId++;
    final sid = _sessionId;
    _cancelToken = CancelToken();
    state = const AudioImportResolving();

    try {
      final item = await ref
          .read(audioImportServiceProvider)
          .importFromUrl(
            url: url,
            audioLibrary: ref.read(audioLibraryProvider.notifier),
            audioLibraryState: ref.read(audioLibraryProvider),
            collectionList: collectionId == null
                ? null
                : ref.read(collectionListProvider.notifier),
            collectionState: collectionId == null
                ? null
                : ref.read(collectionListProvider),
            collectionId: collectionId,
            cancelToken: _cancelToken,
            onProgress: (received, total) {
              if (sid != _sessionId) return;
              final progress = total == null || total <= 0
                  ? -1.0
                  : received / total;
              state = AudioImportDownloading(
                displayName: url,
                progress: progress,
                receivedBytes: received,
                totalBytes: total,
              );
            },
          );
      if (sid != _sessionId) return null;
      state = AudioImportCompleted(item);
      return item;
    } on AudioImportException catch (e) {
      if (sid != _sessionId) return null;
      state = AudioImportFailed(e);
      return null;
    } catch (e) {
      if (sid != _sessionId) return null;
      state = AudioImportFailed(
        AudioImportException(
          AudioImportFailureCode.unknown,
          'Audio import failed',
          e,
        ),
      );
      return null;
    } finally {
      if (sid == _sessionId) _cancelToken = null;
    }
  }

  Future<void> cancel() async {
    _sessionId++;
    _cancelToken?.cancel('user-cancelled');
    _cancelToken = null;
    state = const AudioImportIdle();
  }

  void reset() {
    if (state is AudioImportDownloading || state is AudioImportSaving) return;
    state = const AudioImportIdle();
  }
}
