/// 段落内容可见性菜单
///
/// 目前用于段落复述页面的文本可见性切换。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/retell_settings.dart';

/// 段落内容可见性菜单
class ParagraphVisibilityControls extends StatelessWidget {
  final RetellDisplayMode selectedMode;
  final ValueChanged<RetellDisplayMode> onChanged;

  const ParagraphVisibilityControls({
    super.key,
    required this.selectedMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SegmentedButton<RetellDisplayMode>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: RetellDisplayMode.hideAll,
          label: _ParagraphVisibilitySegmentLabel(
            text: l10n.retellDisplayHideAll,
          ),
        ),
        ButtonSegment(
          value: RetellDisplayMode.keywordsOnly,
          label: _ParagraphVisibilitySegmentLabel(
            text: l10n.retellDisplayKeywordsOnly,
          ),
        ),
        ButtonSegment(
          value: RetellDisplayMode.showAll,
          label: _ParagraphVisibilitySegmentLabel(
            text: l10n.retellDisplayShowAll,
          ),
        ),
      ],
      selected: {selectedMode},
      onSelectionChanged: (selected) => onChanged(selected.first),
    );
  }
}

class _ParagraphVisibilitySegmentLabel extends StatelessWidget {
  final String text;

  const _ParagraphVisibilitySegmentLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
  }
}
