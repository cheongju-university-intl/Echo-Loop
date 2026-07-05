/// AI 句子翻译/解析 Provider
///
/// 三级缓存查找：L1 内存 → L2 SQLite → L3 API。
/// 支持并发请求去重，避免同一句子重复发起 API 调用。
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_logger.dart';

import '../database/daos/sentence_ai_cache_dao.dart';
import '../database/providers.dart';
import '../features/subscription/models/premium_feature.dart';
import '../features/subscription/providers/ai_trial_usage_provider.dart';
import '../features/subscription/providers/feature_access_provider.dart';
import '../features/subscription/providers/subscription_controller.dart';
import '../models/sense_group_result.dart';
import '../models/sentence_ai_result.dart';
import '../services/sentence_ai_api_client.dart';
import '../utils/text_normalize.dart';

/// 请求云端 AI 功能但当前用户未登录。
class AiFeatureAuthRequiredException implements Exception {
  const AiFeatureAuthRequiredException();

  @override
  String toString() => 'AiFeatureAuthRequiredException';
}

/// 已登录但未解锁该 AI 功能（非会员且免费试用已用尽）。
///
/// 由额度闸在发起 L3 请求前抛出，UI 捕获后引导订阅升级（Paywall）。
/// 仅在缓存未命中、确需消耗后端算力时触发，已缓存结果不受影响。
class AiFeatureQuotaExceededException implements Exception {
  const AiFeatureQuotaExceededException();

  @override
  String toString() => 'AiFeatureQuotaExceededException';
}

/// AI 句子翻译/解析服务
///
/// 通过三级缓存（内存 → SQLite → API）获取句子的翻译和解析结果。
/// 使用 pending 请求 Map 实现并发去重。
class SentenceAiNotifier {
  final SentenceAiCacheDao _cacheDao;
  final SentenceAiApiClient _apiClient;

  /// 额度闸：发起 L3 请求前调用。已登录但未解锁（非会员且免费试用用尽）时
  /// 抛 [AiFeatureQuotaExceededException]；会员或仍有试用额度则放行。
  /// 注入而非内联订阅依赖，保持数据层与订阅状态解耦（通过 [PremiumFeature] 中性枚举）。
  final void Function(PremiumFeature feature)? _guardFeature;

  /// L3 成功后调用：消耗一次免费试用（实现内部对会员不计数）。
  final void Function(PremiumFeature feature)? _onConsumeTrial;

  /// L1 内存缓存
  final Map<String, SentenceTranslation> _translationCache = {};
  final Map<String, SentenceAnalysis> _analysisCache = {};
  final Map<String, SenseGroupResult> _senseGroupCache = {};

  /// 正在进行的请求（用于去重）
  final Map<String, Future<SentenceTranslation>> _pendingTranslations = {};
  final Map<String, Future<SentenceAnalysis>> _pendingAnalyses = {};
  final Map<String, Future<SenseGroupResult>> _pendingSenseGroups = {};

  SentenceAiNotifier({
    required SentenceAiCacheDao cacheDao,
    required SentenceAiApiClient apiClient,
    void Function(PremiumFeature feature)? guardFeature,
    void Function(PremiumFeature feature)? onConsumeTrial,
  }) : _cacheDao = cacheDao,
       _apiClient = apiClient,
       _guardFeature = guardFeature,
       _onConsumeTrial = onConsumeTrial;

  /// 执行一次 AI API 调用，把后端「本月免费额度用尽」的 402 统一映射为
  /// [AiFeatureQuotaExceededException]，交由上层弹订阅。其余异常原样抛出。
  ///
  /// 额度裁决在后端（按用户+功能+自然月计数），客户端只负责把 402 翻成领域异常，
  /// 不做本地预判（见 free_allowance_policy 的 AlwaysAllow）。
  Future<T> _callWithQuotaMapping<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      if (e.response?.statusCode == 402) {
        throw const AiFeatureQuotaExceededException();
      }
      rethrow;
    }
  }

  /// 获取翻译（三级缓存查找）
  ///
  /// L1 内存 → L2 SQLite → L3 API。
  /// 并发请求同一句子会复用同一个 Future。
  /// [targetLanguage] 为 BCP 47 代码，用于缓存隔离和 API 调用。
  Future<SentenceTranslation> getTranslation(
    String text, {
    required String targetLanguage,
    String? accessToken,
    CancelToken? cancelToken,
  }) async {
    final hash = hashText(text);
    final cacheKey = '$hash:$targetLanguage';

    // L1: 内存缓存
    final cached = _translationCache[cacheKey];
    if (cached != null) return cached;

    // 去重：复用正在进行的请求
    if (_pendingTranslations.containsKey(cacheKey)) {
      return _pendingTranslations[cacheKey]!;
    }

    final future = _fetchTranslation(
      hash,
      text,
      targetLanguage: targetLanguage,
      accessToken: accessToken,
      cancelToken: cancelToken,
    );
    _pendingTranslations[cacheKey] = future;
    try {
      return await future;
    } finally {
      _pendingTranslations.remove(cacheKey);
    }
  }

  /// 获取解析（三级缓存查找）
  ///
  /// [targetLanguage] 为 BCP 47 代码，用于缓存隔离和 API 调用。
  Future<SentenceAnalysis> getAnalysis(
    String text, {
    required String targetLanguage,
    String? accessToken,
    CancelToken? cancelToken,
  }) async {
    final hash = hashText(text);
    final cacheKey = '$hash:$targetLanguage';

    // L1: 内存缓存
    final cached = _analysisCache[cacheKey];
    if (cached != null) return cached;

    // 去重：复用正在进行的请求
    if (_pendingAnalyses.containsKey(cacheKey)) {
      return _pendingAnalyses[cacheKey]!;
    }

    final future = _fetchAnalysis(
      hash,
      text,
      targetLanguage: targetLanguage,
      accessToken: accessToken,
      cancelToken: cancelToken,
    );
    _pendingAnalyses[cacheKey] = future;
    try {
      return await future;
    } finally {
      _pendingAnalyses.remove(cacheKey);
    }
  }

  /// 获取意群拆分（三级缓存查找）
  Future<SenseGroupResult> getSenseGroups(
    String text, {
    String? accessToken,
    CancelToken? cancelToken,
  }) async {
    final hash = hashText(text);

    // L1: 内存缓存（空结果不视为有效缓存）
    final cached = _senseGroupCache[hash];
    if (cached != null && cached.medium.isNotEmpty) {
      AppLogger.log(
        'SenseGroup',
        'L1 命中 | medium=${cached.medium.length}组 fine=${cached.fine.length}组 | "${text.length > 40 ? '${text.substring(0, 40)}...' : text}"',
      );
      return cached;
    }
    if (cached != null) {
      _senseGroupCache.remove(hash);
    }

    // 去重：复用正在进行的请求
    if (_pendingSenseGroups.containsKey(hash)) {
      AppLogger.log('SenseGroup', '复用进行中请求 | "$text"');
      return _pendingSenseGroups[hash]!;
    }

    AppLogger.log('SenseGroup', 'L1 未命中，开始查找 | "$text"');
    final future = _fetchSenseGroups(
      hash,
      text,
      accessToken: accessToken,
      cancelToken: cancelToken,
    );
    _pendingSenseGroups[hash] = future;
    try {
      return await future;
    } finally {
      _pendingSenseGroups.remove(hash);
    }
  }

  /// 同步查找 L1 翻译缓存（仅内存）
  ///
  /// [targetLanguage] 不传时遍历所有语言版本（向后兼容），传入时精确匹配。
  SentenceTranslation? getCachedTranslation(
    String text, {
    String? targetLanguage,
  }) {
    final hash = hashText(text);
    if (targetLanguage != null) {
      return _translationCache['$hash:$targetLanguage'];
    }
    // 向后兼容：遍历查找任意语言版本
    for (final entry in _translationCache.entries) {
      if (entry.key.startsWith('$hash:')) return entry.value;
    }
    return null;
  }

  /// 同步查找 L1 解析缓存（仅内存）
  ///
  /// [targetLanguage] 不传时遍历所有语言版本（向后兼容），传入时精确匹配。
  SentenceAnalysis? getCachedAnalysis(String text, {String? targetLanguage}) {
    final hash = hashText(text);
    if (targetLanguage != null) {
      return _analysisCache['$hash:$targetLanguage'];
    }
    for (final entry in _analysisCache.entries) {
      if (entry.key.startsWith('$hash:')) return entry.value;
    }
    return null;
  }

  /// 同步查找 L1 意群缓存（仅内存）
  SenseGroupResult? getCachedSenseGroups(String text) {
    return _senseGroupCache[hashText(text)];
  }

  /// 从 L2 SQLite 预加载翻译到 L1 内存（不调用 L3 API）
  ///
  /// 返回 true 表示 L1 或 L2 命中，false 表示无缓存。
  Future<bool> preloadTranslationFromDb(
    String text, {
    required String targetLanguage,
  }) async {
    final hash = hashText(text);
    final cacheKey = '$hash:$targetLanguage';
    if (_translationCache.containsKey(cacheKey)) return true;
    final dbResult = await _cacheDao.getByHash(
      hash,
      'translation:$targetLanguage',
    );
    if (dbResult != null) {
      try {
        final translation = SentenceTranslation.fromJson(
          jsonDecode(dbResult) as Map<String, dynamic>,
        );
        _translationCache[cacheKey] = translation;
        return true;
      } catch (_) {
        // JSON 损坏，跳过
      }
    }
    return false;
  }

  /// 从 L2 SQLite 预加载解析到 L1 内存（不调用 L3 API）
  ///
  /// 返回 true 表示 L1 或 L2 命中，false 表示无缓存。
  Future<bool> preloadAnalysisFromDb(
    String text, {
    required String targetLanguage,
  }) async {
    final hash = hashText(text);
    final cacheKey = '$hash:$targetLanguage';
    if (_analysisCache.containsKey(cacheKey)) return true;
    final dbResult = await _cacheDao.getByHash(
      hash,
      'analysis:$targetLanguage',
    );
    if (dbResult != null) {
      try {
        final analysis = SentenceAnalysis.fromJson(
          jsonDecode(dbResult) as Map<String, dynamic>,
        );
        _analysisCache[cacheKey] = analysis;
        return true;
      } catch (_) {
        // JSON 损坏，跳过
      }
    }
    return false;
  }

  /// 从 L2 SQLite 预加载意群到 L1 内存（不调用 L3 API）
  ///
  /// 返回 true 表示 L1 或 L2 命中，false 表示无缓存。
  Future<bool> preloadSenseGroupsFromDb(String text) async {
    final hash = hashText(text);
    if (_senseGroupCache.containsKey(hash)) return true;
    final dbResult = await _cacheDao.getByHash(hash, 'sense_groups');
    if (dbResult != null) {
      try {
        final result = SenseGroupResult.fromJson(
          jsonDecode(dbResult) as Map<String, dynamic>,
        );
        if (result.medium.isNotEmpty) {
          _senseGroupCache[hash] = result;
          return true;
        }
      } catch (_) {
        // JSON 损坏，跳过
      }
    }
    return false;
  }

  /// 清除内存缓存
  void clearMemoryCache() {
    _translationCache.clear();
    _analysisCache.clear();
    _senseGroupCache.clear();
  }

  /// L2 + L3 翻译查找
  Future<SentenceTranslation> _fetchTranslation(
    String hash,
    String text, {
    required String targetLanguage,
    String? accessToken,
    CancelToken? cancelToken,
  }) async {
    final cacheKey = '$hash:$targetLanguage';
    final l2Type = 'translation:$targetLanguage';

    // L2: SQLite 缓存（JSON 损坏时跳过，fallthrough 到 L3）
    final dbResult = await _cacheDao.getByHash(hash, l2Type);
    if (dbResult != null) {
      try {
        final translation = SentenceTranslation.fromJson(
          jsonDecode(dbResult) as Map<String, dynamic>,
        );
        _translationCache[cacheKey] = translation;
        return translation;
      } catch (_) {
        // L2 数据损坏或结构变更，继续到 L3 API 调用
      }
    }

    // L3: API 调用
    if (accessToken == null || accessToken.isEmpty) {
      AppLogger.log('SentenceAI', '翻译 L3 需要登录，未发现 Supabase access token');
      throw const AiFeatureAuthRequiredException();
    }
    // 已登录前提下做额度闸：未解锁则抛配额超限，引导升级。
    _guardFeature?.call(PremiumFeature.aiTranslation);
    final translation = await _callWithQuotaMapping(
      () => _apiClient.translate(
        text,
        targetLanguage: targetLanguage,
        accessToken: accessToken,
        cancelToken: cancelToken,
      ),
    );
    // 写入 L1 + L2
    _translationCache[cacheKey] = translation;
    await _cacheDao.upsert(
      hash,
      l2Type,
      jsonEncode({'translation': translation.translation}),
    );
    _onConsumeTrial?.call(PremiumFeature.aiTranslation);
    return translation;
  }

  /// L2 + L3 解析查找
  Future<SentenceAnalysis> _fetchAnalysis(
    String hash,
    String text, {
    required String targetLanguage,
    String? accessToken,
    CancelToken? cancelToken,
  }) async {
    final cacheKey = '$hash:$targetLanguage';
    final l2Type = 'analysis:$targetLanguage';

    // L2: SQLite 缓存（JSON 损坏时跳过，fallthrough 到 L3）
    final dbResult = await _cacheDao.getByHash(hash, l2Type);
    if (dbResult != null) {
      try {
        final analysis = SentenceAnalysis.fromJson(
          jsonDecode(dbResult) as Map<String, dynamic>,
        );
        _analysisCache[cacheKey] = analysis;
        return analysis;
      } catch (_) {
        // L2 数据损坏或结构变更，继续到 L3 API 调用
      }
    }

    // L3: API 调用
    if (accessToken == null || accessToken.isEmpty) {
      AppLogger.log('SentenceAI', '解析 L3 需要登录，未发现 Supabase access token');
      throw const AiFeatureAuthRequiredException();
    }
    _guardFeature?.call(PremiumFeature.aiAnalysis);
    final analysis = await _callWithQuotaMapping(
      () => _apiClient.analyze(
        text,
        targetLanguage: targetLanguage,
        accessToken: accessToken,
        cancelToken: cancelToken,
      ),
    );
    // 写入 L1 + L2
    _analysisCache[cacheKey] = analysis;
    await _cacheDao.upsert(
      hash,
      l2Type,
      jsonEncode({
        'analysis': {
          'grammar': analysis.grammar,
          'vocabulary': analysis.vocabulary,
          'listening': analysis.listening,
        },
      }),
    );
    _onConsumeTrial?.call(PremiumFeature.aiAnalysis);
    return analysis;
  }

  /// L2 + L3 意群查找
  Future<SenseGroupResult> _fetchSenseGroups(
    String hash,
    String text, {
    String? accessToken,
    CancelToken? cancelToken,
  }) async {
    // L2: SQLite 缓存（JSON 损坏或字段不一致时跳过，fallthrough 到 L3）
    final dbResult = await _cacheDao.getByHash(hash, 'sense_groups');
    if (dbResult != null) {
      try {
        final result = SenseGroupResult.fromJson(
          jsonDecode(dbResult) as Map<String, dynamic>,
        );
        // 检查结果是否有效（旧格式数据 fromJson 不会报错但会返回空列表）
        if (result.medium.isNotEmpty) {
          _senseGroupCache[hash] = result;
          AppLogger.log(
            'SenseGroup',
            'L2 SQLite 命中 | medium=${result.medium.length}组 fine=${result.fine.length}组 equal=${result.areBothEqual}',
          );
          return result;
        }
        // 空结果视为旧格式缓存，删除并 fallthrough 到 L3
        AppLogger.log('SenseGroup', 'L2 SQLite 缓存为空（可能是旧格式），删除并重新请求');
        await _cacheDao.deleteByHash(hash, 'sense_groups');
      } catch (e) {
        // 缓存格式不兼容，删除旧数据后 fallthrough 到 L3
        AppLogger.log('SenseGroup', 'L2 SQLite 格式不兼容，删除旧缓存 | error=$e');
        await _cacheDao.deleteByHash(hash, 'sense_groups');
      }
    }

    // L3: API 调用
    if (accessToken == null || accessToken.isEmpty) {
      AppLogger.log('SenseGroup', 'L3 需要登录，未发现 Supabase access token');
      throw const AiFeatureAuthRequiredException();
    }
    _guardFeature?.call(PremiumFeature.aiSenseGroup);
    AppLogger.log('SenseGroup', 'L3 调用 API...');
    final sw = Stopwatch()..start();
    final result = await _callWithQuotaMapping(
      () => _apiClient.splitSenseGroups(
        text,
        accessToken: accessToken,
        cancelToken: cancelToken,
      ),
    );
    sw.stop();
    AppLogger.log(
      'SenseGroup',
      'L3 API 返回 | ${sw.elapsedMilliseconds}ms | medium=${result.medium.length}组 fine=${result.fine.length}组 equal=${result.areBothEqual}',
    );

    // 打印具体分组内容
    for (var i = 0; i < result.medium.length; i++) {
      AppLogger.log('SenseGroup', '  中等[$i]: "${result.medium[i]}"');
    }
    for (var i = 0; i < result.fine.length; i++) {
      AppLogger.log('SenseGroup', '  细粒[$i]: "${result.fine[i]}"');
    }

    // 空结果不缓存（允许用户重试）
    if (result.medium.isEmpty) return result;

    // 写入 L1 + L2
    _senseGroupCache[hash] = result;
    await _cacheDao.upsert(hash, 'sense_groups', jsonEncode(result.toJson()));
    _onConsumeTrial?.call(PremiumFeature.aiSenseGroup);
    return result;
  }
}

/// SentenceAiNotifier Provider
final sentenceAiNotifierProvider = Provider<SentenceAiNotifier>((ref) {
  return SentenceAiNotifier(
    cacheDao: ref.watch(sentenceAiCacheDaoProvider),
    apiClient: ref.watch(sentenceAiApiClientProvider),
    // 额度闸：已登录前提下未解锁（非会员且试用用尽）→ 抛配额超限。
    guardFeature: (feature) {
      if (!ref.read(featureAccessProvider(feature))) {
        throw const AiFeatureQuotaExceededException();
      }
    },
    // 消耗一次免费试用；会员无限不计数。
    onConsumeTrial: (feature) {
      if (ref.read(subscriptionControllerProvider).isActive) return;
      ref.read(aiTrialUsageProvider.notifier).consume(feature);
    },
  );
});
