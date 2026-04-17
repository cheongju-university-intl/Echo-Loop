import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';

import '../l10n/app_localizations.dart';
import '../providers/new_user_guide_provider.dart';
import '../services/app_logger.dart';

/// 单个页面级引导步骤。
///
/// 当前所有步骤都是展示型：用户点 tooltip 的“下一步/完成”或点 barrier 推进。
class GuideStep {
  final String targetId;
  final String title;
  final String description;

  const GuideStep({
    required this.targetId,
    required this.title,
    required this.description,
  });
}

/// 单个页面级引导 flow 的声明。
///
/// 一个 screen 可能存在多段互相独立的引导，每段用一个 [GuideFlow] 描述。
class GuideFlow {
  final String flowId;
  final bool shouldRun;
  final List<GuideStep> steps;

  const GuideFlow({
    required this.flowId,
    required this.shouldRun,
    required this.steps,
  });
}

/// 在 screen 内按顺序声明并启动一组页面级 flow。
///
/// 所有 screen 统一使用该组件，单 flow 场景传长度为 1 的列表即可。
/// 每次 controller 空闲时按 [flows] 顺序尝试启动：挑到第一个 shouldRun
/// 为 true、steps 非空且未看过的 flow 展示；当前 flow 完成后再尝试下一个。
class GuideFlowSequenceHost extends ConsumerStatefulWidget {
  final List<GuideFlow> flows;
  final Widget child;

  const GuideFlowSequenceHost({
    super.key,
    required this.flows,
    required this.child,
  });

  @override
  ConsumerState<GuideFlowSequenceHost> createState() =>
      _GuideFlowSequenceHostState();
}

class _GuideFlowSequenceHostState extends ConsumerState<GuideFlowSequenceHost> {
  ProviderSubscription<GuideControllerState>? _guideSubscription;
  bool _attemptScheduled = false;
  bool _lastTickerEnabled = true;

  @override
  void initState() {
    super.initState();
    _guideSubscription = ref.listenManual<GuideControllerState>(
      guideControllerProvider,
      _onControllerStateChanged,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleAttempt();
    });
  }

  /// 响应 controller 状态变化：复位或上一个 flow 结束时尝试启动下一个。
  void _onControllerStateChanged(
    GuideControllerState? previous,
    GuideControllerState next,
  ) {
    if (!mounted) return;
    final resetChanged =
        previous != null && previous.resetGeneration != next.resetGeneration;
    if (resetChanged) {
      AppLogger.log(
        'Guide',
        'host reset observed from=${previous.resetGeneration} '
            'to=${next.resetGeneration}',
      );
      _attemptScheduled = false;
      _scheduleAttempt();
      return;
    }
    if (!next.isActive) {
      _attemptScheduled = false;
      _scheduleAttempt();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    // 场景：IndexedStack 中从隐藏切回可见，ticker 从禁用变为启用时重新尝试。
    if (tickerEnabled && !_lastTickerEnabled) {
      _attemptScheduled = false;
      _scheduleAttempt();
    }
    _lastTickerEnabled = tickerEnabled;
  }

  @override
  void didUpdateWidget(covariant GuideFlowSequenceHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_flowsConfigChanged(oldWidget.flows, widget.flows)) {
      _attemptScheduled = false;
      _scheduleAttempt();
    }
  }

  @override
  void dispose() {
    _guideSubscription?.close();
    super.dispose();
  }

  bool _flowsConfigChanged(List<GuideFlow> a, List<GuideFlow> b) {
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      if (a[i].flowId != b[i].flowId ||
          a[i].shouldRun != b[i].shouldRun ||
          a[i].steps.map((s) => s.targetId).join('|') !=
              b[i].steps.map((s) => s.targetId).join('|')) {
        return true;
      }
    }
    return false;
  }

  void _scheduleAttempt() {
    if (_attemptScheduled ||
        widget.flows.isEmpty ||
        !TickerMode.valuesOf(context).enabled) {
      AppLogger.log(
        'Guide',
        'host attempt not scheduled flows=${_flowSummary()} '
            'alreadyScheduled=$_attemptScheduled '
            'ticker=${TickerMode.valuesOf(context).enabled}',
      );
      return;
    }
    _attemptScheduled = true;
    AppLogger.log('Guide', 'host scheduleAttempt flows=${_flowSummary()}');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _attemptScheduled = false;
      if (!mounted) {
        AppLogger.log('Guide', 'host attempt aborted reason=unmounted');
        return;
      }
      if (!TickerMode.valuesOf(context).enabled) {
        AppLogger.log('Guide', 'host attempt aborted reason=inactiveTicker');
        return;
      }
      final showcase = _tryGetShowcase();
      if (showcase == null) {
        AppLogger.log('Guide', 'host attempt aborted reason=noShowCaseView');
        return;
      }
      if (ref.read(guideControllerProvider).isActive) {
        AppLogger.log('Guide', 'host attempt aborted reason=activeFlow');
        return;
      }
      for (final flow in widget.flows) {
        if (!flow.shouldRun || flow.steps.isEmpty) {
          AppLogger.log(
            'Guide',
            'host attempt skip flow=${flow.flowId} '
                'shouldRun=${flow.shouldRun} steps=${flow.steps.length}',
          );
          continue;
        }
        final started = await ref
            .read(guideControllerProvider.notifier)
            .startFlow(
              flowId: flow.flowId,
              targetIds: flow.steps.map((s) => s.targetId).toList(),
            );
        if (!mounted) return;
        if (started) return;
      }
      AppLogger.log('Guide', 'host attempt exhausted flows=${_flowSummary()}');
    });
  }

  String _flowSummary() =>
      widget.flows.map((f) => '${f.flowId}(${f.shouldRun})').join(',');

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 获取全局 ShowcaseView；注册前（如测试环境未初始化）时返回 null。
ShowcaseView? _tryGetShowcase() {
  try {
    return ShowcaseView.get();
  } catch (_) {
    return null;
  }
}

/// 引导 tooltip 的视觉方案（light / dark 双主题）。
///
/// 风格参考 Linear / Raycast：中性无彩色表面 + 高对比主操作按钮，
/// 不引入品牌主色，把视觉焦点留给"下一步"按钮本身的黑/白反差。
class _GuideTooltipScheme {
  const _GuideTooltipScheme._({
    required this.surface,
    required this.title,
    required this.description,
    required this.actionBg,
    required this.actionText,
    required this.barrier,
    required this.barrierOpacity,
  });

  final Color surface;
  final Color title;
  final Color description;
  final Color actionBg;
  final Color actionText;
  final Color barrier;
  final double barrierOpacity;

  static const _light = _GuideTooltipScheme._(
    surface: Color(0xFFFFFFFF),
    title: Color(0xFF0F1115),
    description: Color(0xFF5A6270),
    actionBg: Color(0xFF111418),
    actionText: Color(0xFFFFFFFF),
    barrier: Color(0xFF0A0D12),
    barrierOpacity: 0.55,
  );

  static const _dark = _GuideTooltipScheme._(
    surface: Color(0xFF1B1E23),
    title: Color(0xFFF4F5F7),
    description: Color(0xFF9BA3AE),
    actionBg: Color(0xFFF4F5F7),
    actionText: Color(0xFF0F1115),
    barrier: Color(0xFF000000),
    barrierOpacity: 0.62,
  );

  static _GuideTooltipScheme of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;
}

/// 引导 tooltip 的几何与字体 tokens（与配色解耦）。
abstract class _GuideTooltipStyle {
  static const tooltipRadius = BorderRadius.all(Radius.circular(14));
  static const tooltipPadding = EdgeInsets.fromLTRB(18, 16, 18, 14);
  // 与全局 Card 主题的 16px 圆角对齐，避免高亮切口在卡片四角露出白色楔形；
  // padding 收紧到 4 让切口更贴合目标。
  static const targetPadding = EdgeInsets.all(4);
  static const targetRadius = BorderRadius.all(Radius.circular(16));
  static const actionRadius = BorderRadius.all(Radius.circular(8));
  static const actionPadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 8,
  );

  static TextStyle title(Color color) => TextStyle(
    fontSize: 15,
    height: 1.35,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: color,
  );

  static TextStyle description(Color color) => TextStyle(
    fontSize: 13,
    height: 1.55,
    fontWeight: FontWeight.w400,
    color: color,
  );

  static TextStyle action(Color color) => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: color,
  );
}

/// 可复用的 showcase target 包装器。
///
/// screen 只需要用该组件包住目标控件，并传入对应 flow/target 信息。
class GuideTarget extends ConsumerStatefulWidget {
  final String flowId;
  final GuideStep step;
  final Widget child;

  const GuideTarget({
    super.key,
    required this.flowId,
    required this.step,
    required this.child,
  });

  @override
  ConsumerState<GuideTarget> createState() => _GuideTargetState();
}

class _GuideTargetState extends ConsumerState<GuideTarget> {
  final GlobalKey _showcaseKey = GlobalKey();
  ProviderSubscription<GuideControllerState>? _guideSubscription;
  int? _startedSessionId;

  @override
  void initState() {
    super.initState();
    _guideSubscription = ref.listenManual<GuideControllerState>(
      guideControllerProvider,
      (_, next) {
        if (_isCurrentTarget(next)) {
          _startShowcase(next.sessionId);
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void didUpdateWidget(covariant GuideTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final state = ref.read(guideControllerProvider);
    if (_isCurrentTarget(state)) {
      _startShowcase(state.sessionId);
    }
  }

  @override
  void dispose() {
    _guideSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(guideControllerProvider);
    final isLastStep = state.isLastStep;
    final scheme = _GuideTooltipScheme.of(context);

    return Showcase(
      key: _showcaseKey,
      title: widget.step.title,
      description: widget.step.description,

      // 表面
      tooltipBackgroundColor: scheme.surface,
      tooltipBorderRadius: _GuideTooltipStyle.tooltipRadius,
      tooltipPadding: _GuideTooltipStyle.tooltipPadding,
      targetPadding: _GuideTooltipStyle.targetPadding,
      targetBorderRadius: _GuideTooltipStyle.targetRadius,

      // 版式
      titleTextStyle: _GuideTooltipStyle.title(scheme.title),
      descTextStyle: _GuideTooltipStyle.description(scheme.description),
      titleAlignment: Alignment.centerLeft,
      descriptionAlignment: Alignment.centerLeft,
      titleTextAlign: TextAlign.left,
      descriptionTextAlign: TextAlign.left,

      // barrier（遮罩）
      overlayColor: scheme.barrier,
      overlayOpacity: scheme.barrierOpacity,

      // 动作按钮
      tooltipActionConfig: const TooltipActionConfig(
        alignment: MainAxisAlignment.end,
        position: TooltipActionPosition.inside,
        actionGap: 8,
        gapBetweenContentAndAction: 12,
      ),
      tooltipActions: [_nextAction(context, l10n, isLastStep, scheme)],

      onBarrierClick: _advanceFromPassiveTap,
      onTargetClick: _ignoreTargetClick,
      disposeOnTap: false,
      child: Semantics(label: widget.step.title, child: widget.child),
    );
  }

  bool _isCurrentTarget(GuideControllerState state) {
    return state.activeFlowId == widget.flowId &&
        state.activeTargetId == widget.step.targetId;
  }

  void _startShowcase(int sessionId) {
    if (_startedSessionId == sessionId) {
      AppLogger.log(
        'Guide',
        'target start skipped flow=${widget.flowId} '
            'target=${widget.step.targetId} reason=sameSession '
            'session=$sessionId',
      );
      return;
    }
    _startedSessionId = sessionId;
    _scheduleShowcaseStart(sessionId, 0);
  }

  void _scheduleShowcaseStart(int sessionId, int attempt) {
    AppLogger.log(
      'Guide',
      'target scheduleShowcase flow=${widget.flowId} '
          'target=${widget.step.targetId} session=$sessionId attempt=$attempt',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        AppLogger.log(
          'Guide',
          'target start aborted flow=${widget.flowId} '
              'target=${widget.step.targetId} reason=unmounted',
        );
        return;
      }
      final state = ref.read(guideControllerProvider);
      if (!_isCurrentTarget(state)) {
        AppLogger.log(
          'Guide',
          'target start aborted flow=${widget.flowId} '
              'target=${widget.step.targetId} reason=notCurrent '
              'activeFlow=${state.activeFlowId} '
              'activeTarget=${state.activeTargetId}',
        );
        return;
      }
      final showcase = _tryGetShowcase();
      if (showcase == null) {
        _retryShowcaseStart(sessionId, attempt, 'noShowCaseView');
        return;
      }
      AppLogger.log(
        'Guide',
        'target startShowcase flow=${widget.flowId} '
            'target=${widget.step.targetId} session=$sessionId',
      );
      showcase.startShowCase([_showcaseKey]);
    });
  }

  void _retryShowcaseStart(int sessionId, int attempt, String reason) {
    if (attempt >= 3) {
      AppLogger.log(
        'Guide',
        'target start aborted flow=${widget.flowId} '
            'target=${widget.step.targetId} reason=$reason '
            'session=$sessionId attempts=$attempt '
            'fallback=completeActiveFlow',
      );
      // 兜底：showcase 起不来就把当前 flow 标记已看并清空 active，
      // 避免 controller 一直卡在 active 导致后续 flow 再也无法启动。
      final state = ref.read(guideControllerProvider);
      if (_isCurrentTarget(state)) {
        unawaited(
          ref.read(guideControllerProvider.notifier).completeActiveFlow(),
        );
      }
      return;
    }
    AppLogger.log(
      'Guide',
      'target start retry flow=${widget.flowId} '
          'target=${widget.step.targetId} reason=$reason '
          'session=$sessionId nextAttempt=${attempt + 1}',
    );
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      _scheduleShowcaseStart(sessionId, attempt + 1);
    });
  }

  TooltipActionButton _nextAction(
    BuildContext context,
    AppLocalizations l10n,
    bool showDone,
    _GuideTooltipScheme scheme,
  ) {
    return TooltipActionButton(
      type: TooltipDefaultActionType.next,
      name: showDone ? l10n.guideDone : l10n.guideNext,
      backgroundColor: scheme.actionBg,
      textStyle: _GuideTooltipStyle.action(scheme.actionText),
      borderRadius: _GuideTooltipStyle.actionRadius,
      padding: _GuideTooltipStyle.actionPadding,
      onTap: () {
        AppLogger.log(
          'Guide',
          'tooltip action flow=${widget.flowId} '
              'target=${widget.step.targetId} showDone=$showDone',
        );
        _tryGetShowcase()?.dismiss();
        unawaited(
          ref.read(guideControllerProvider.notifier).advanceActiveFlow(),
        );
      },
    );
  }

  void _ignoreTargetClick() {
    AppLogger.log(
      'Guide',
      'target click ignored flow=${widget.flowId} '
          'target=${widget.step.targetId} reason=passiveStep',
    );
  }

  void _advanceFromPassiveTap() {
    AppLogger.log(
      'Guide',
      'barrier advance flow=${widget.flowId} target=${widget.step.targetId}',
    );
    _tryGetShowcase()?.dismiss();
    unawaited(ref.read(guideControllerProvider.notifier).advanceActiveFlow());
  }
}
