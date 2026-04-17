import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_logger.dart';

/// 页面级引导流程的运行状态。
///
/// 这里只保存当前正在展示的 flow 和 step，不保存跨页面业务流程。
/// 每个 flow 是否已看过由 [GuideRegistry] 单独持久化。
class GuideControllerState {
  final String? activeFlowId;
  final List<String> targetIds;
  final int activeIndex;
  final int sessionId;
  final int resetGeneration;

  const GuideControllerState({
    this.activeFlowId,
    this.targetIds = const [],
    this.activeIndex = 0,
    this.sessionId = 0,
    this.resetGeneration = 0,
  });

  bool get isActive => activeFlowId != null;

  String? get activeTargetId {
    if (!isActive || activeIndex < 0 || activeIndex >= targetIds.length) {
      return null;
    }
    return targetIds[activeIndex];
  }

  bool get isLastStep => activeIndex >= targetIds.length - 1;

  GuideControllerState copyWith({
    String? activeFlowId,
    List<String>? targetIds,
    int? activeIndex,
    int? sessionId,
    int? resetGeneration,
    bool clearActiveFlow = false,
  }) {
    return GuideControllerState(
      activeFlowId: clearActiveFlow ? null : activeFlowId ?? this.activeFlowId,
      targetIds: targetIds ?? this.targetIds,
      activeIndex: activeIndex ?? this.activeIndex,
      sessionId: sessionId ?? this.sessionId,
      resetGeneration: resetGeneration ?? this.resetGeneration,
    );
  }
}

/// 引导持久化注册表。
///
/// 每个 flow 独立保存 seen 状态；关闭或完成一个 flow 不会影响其它 flow。
class GuideRegistry {
  GuideRegistry({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async =>
      _prefs ?? SharedPreferences.getInstance();

  String keyFor(String flowId) => 'guide_v1_${flowId}_seen';

  Future<bool> isSeen(String flowId) async {
    final prefs = await _preferences;
    final seen = prefs.getBool(keyFor(flowId)) ?? false;
    AppLogger.log('Guide', 'registry isSeen flow=$flowId seen=$seen');
    return seen;
  }

  Future<void> markSeen(String flowId) async {
    final prefs = await _preferences;
    await prefs.setBool(keyFor(flowId), true);
    AppLogger.log('Guide', 'registry markSeen flow=$flowId');
  }

  Future<void> reset(String flowId) async {
    final prefs = await _preferences;
    await prefs.remove(keyFor(flowId));
    AppLogger.log('Guide', 'registry reset flow=$flowId');
  }
}

final guideRegistryProvider = Provider<GuideRegistry>((ref) {
  return GuideRegistry();
});

/// 当前版本的新用户引导 flow id。
///
/// [active] 是当前真正被 screen 使用的 flow id。
/// [legacy] 仅用于重置时清掉旧版本遗留在 SharedPreferences 中的 key，
/// 没有任何 screen 仍在引用，新增 flow 时不要往里加。
/// [all] 用于设置页"重置引导"一键清空，合并 active + legacy。
abstract final class GuideFlowIds {
  static const libraryCreateCollection = 'library_create_collection';
  static const libraryCollectionList = 'library_collection_list';
  static const collectionDetailUpload = 'collection_detail_upload';
  static const collectionDetailAudioList = 'collection_detail_audio_list';
  static const learningPlanNoTranscript = 'learning_plan_no_transcript';
  static const learningPlanWithTranscript = 'learning_plan_with_transcript';
  static const subtitleSheetTranscription = 'subtitle_sheet_transcription';

  static const active = [
    libraryCreateCollection,
    libraryCollectionList,
    collectionDetailUpload,
    collectionDetailAudioList,
    learningPlanNoTranscript,
    learningPlanWithTranscript,
    subtitleSheetTranscription,
  ];

  static const legacy = [
    'library',
    'collection_detail',
    'library_examples',
    'collection_detail_example_audio',
  ];

  static const all = [...active, ...legacy];
}

/// 当前版本的新用户引导 target id。
abstract final class GuideTargetIds {
  static const collectionList = 'collection_list';
  static const collectionMenu = 'collection_menu';
  static const createCollection = 'create_collection';
  static const audioList = 'audio_list';
  static const audioMenu = 'audio_menu';
  static const uploadAudio = 'upload_audio';
  static const addSubtitle = 'add_subtitle';
  static const aiTranscription = 'ai_transcription';
  static const startTranscription = 'start_transcription';
  static const freePlay = 'free_play';
  static const startLearning = 'start_learning';
}

final guideControllerProvider =
    NotifierProvider<GuideController, GuideControllerState>(
      GuideController.new,
    );

/// 页面级引导控制器。
///
/// 负责同一时刻只运行一个 flow，并按 flow 内的 target 顺序推进。
/// 是否展示由各 screen 自己决定，控制器不维护跨 screen 的全局 onboarding。
class GuideController extends Notifier<GuideControllerState> {
  @override
  GuideControllerState build() => const GuideControllerState();

  Future<bool> startFlow({
    required String flowId,
    required List<String> targetIds,
  }) async {
    if (targetIds.isEmpty) {
      AppLogger.log('Guide', 'start skipped flow=$flowId reason=emptyTargets');
      return false;
    }
    if (state.isActive) {
      final sameFlow = state.activeFlowId == flowId;
      AppLogger.log(
        'Guide',
        'start skipped flow=$flowId reason=activeFlow '
            'active=${state.activeFlowId} sameFlow=$sameFlow',
      );
      return sameFlow;
    }

    final registry = ref.read(guideRegistryProvider);
    if (await registry.isSeen(flowId)) {
      AppLogger.log('Guide', 'start skipped flow=$flowId reason=seen');
      return false;
    }

    state = GuideControllerState(
      activeFlowId: flowId,
      targetIds: List.unmodifiable(targetIds),
      sessionId: state.sessionId + 1,
      resetGeneration: state.resetGeneration,
    );
    AppLogger.log(
      'Guide',
      'start flow=$flowId targets=${targetIds.join(",")} '
          'session=${state.sessionId}',
    );
    return true;
  }

  Future<void> advanceActiveFlow() async {
    if (!state.isActive) {
      AppLogger.log('Guide', 'advance ignored reason=noActiveFlow');
      return;
    }
    if (state.isLastStep) {
      await completeActiveFlow();
      return;
    }
    final previousTarget = state.activeTargetId;
    state = state.copyWith(
      activeIndex: state.activeIndex + 1,
      sessionId: state.sessionId + 1,
    );
    AppLogger.log(
      'Guide',
      'advance flow=${state.activeFlowId} from=$previousTarget '
          'to=${state.activeTargetId} index=${state.activeIndex} '
          'session=${state.sessionId}',
    );
  }

  Future<void> completeActiveFlow() async {
    final flowId = state.activeFlowId;
    if (flowId == null) {
      AppLogger.log('Guide', 'complete ignored reason=noActiveFlow');
      return;
    }
    final targetId = state.activeTargetId;
    await ref.read(guideRegistryProvider).markSeen(flowId);
    state = GuideControllerState(
      sessionId: state.sessionId + 1,
      resetGeneration: state.resetGeneration,
    );
    AppLogger.log(
      'Guide',
      'complete flow=$flowId target=$targetId session=${state.sessionId}',
    );
  }

  Future<void> resetFlows(List<String> flowIds) async {
    final registry = ref.read(guideRegistryProvider);
    for (final flowId in flowIds) {
      await registry.reset(flowId);
    }

    state = GuideControllerState(
      sessionId: state.sessionId + 1,
      resetGeneration: state.resetGeneration + 1,
    );
    AppLogger.log(
      'Guide',
      'resetFlows flows=${flowIds.join(",")} '
          'clearedActive=true '
          'resetGeneration=${state.resetGeneration}',
    );
  }
}
