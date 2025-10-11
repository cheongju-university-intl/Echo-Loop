import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import '../l10n/app_localizations.dart';
import '../providers/player_provider.dart';
import '../models/playback_settings.dart';
import '../services/subtitle_parser.dart';
import '../widgets/playback_controls.dart';
import '../widgets/sentence_list_view.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Request focus on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event, PlayerProvider player) {
    if (event is! KeyDownEvent) return;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        if (player.isPlaying) {
          player.pause();
        } else {
          player.play();
        }
      case LogicalKeyboardKey.arrowLeft:
        if (player.hasSentences) {
          player.previousSentence();
        }
      case LogicalKeyboardKey.arrowRight:
        if (player.hasSentences) {
          player.nextSentence();
        }
      case LogicalKeyboardKey.arrowUp:
        final settings = player.settings;
        player.updateSettings(
          settings.copyWith(showTranscript: !settings.showTranscript),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, child) {
        return KeyboardListener(
          focusNode: _focusNode,
          onKeyEvent: (event) => _handleKeyEvent(event, player),
          child: Scaffold(
            appBar: AppBar(
              title: Text(player.currentAudioItem?.name ?? 'Player'),
            ),
            body: !player.hasAudio
                ? const Center(child: Text('No audio loaded'))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isWideScreen = constraints.maxWidth > 800;
                      return isWideScreen
                          ? _buildWideLayout(context, player)
                          : _buildNarrowLayout(context, player);
                    },
                  ),
          ),
        );
      },
    );
  }

  Widget _buildWideLayout(BuildContext context, PlayerProvider player) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Expanded(child: _buildTranscriptView(player)),
              _buildControlPanel(context, player),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 2,
          child: _buildSidePanel(player),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context, PlayerProvider player) {
    return Column(
      children: [
        Expanded(child: _buildTranscriptView(player)),
        _buildControlPanel(context, player),
      ],
    );
  }

  Widget _buildTranscriptView(PlayerProvider player) {
    if (!player.hasSentences) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.subtitles_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No transcript available',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Single sentence mode: only show current sentence
    if (player.settings.mode == PlaybackMode.singleSentence) {
      if (player.currentSentenceIndex == null) {
        return const Center(
          child: Text('No sentence selected', style: TextStyle(color: Colors.grey)),
        );
      }
      final currentSentence = player.sentences[player.currentSentenceIndex!];
      final isBookmarked = player.bookmarkedIndices.contains(currentSentence.index);
      
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Text(
                        currentSentence.text,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.normal,
                        ),
                        textAlign: TextAlign.left,
                      ),
                      if (!player.settings.showTranscript)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                              child: Container(
                                color: Colors.grey.withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        SubtitleParser.formatDuration(currentSentence.startTime),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      IconButton(
                        icon: Icon(
                          isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                          color: isBookmarked ? Colors.amber : Colors.grey,
                        ),
                        onPressed: () => player.toggleBookmark(currentSentence.index),
                        tooltip: isBookmarked ? 'Remove bookmark' : 'Add bookmark',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Full article and bookmarked modes: show list
    final displaySentences = player.settings.mode == PlaybackMode.bookmarkedOnly
        ? player.bookmarkedSentences
        : player.sentences;

    if (displaySentences.isEmpty && player.settings.mode == PlaybackMode.bookmarkedOnly) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No bookmarked sentences',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap ⭐ on sentences to bookmark them',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SentenceListView(
      sentences: displaySentences,
      currentIndex: player.currentSentenceIndex,
      bookmarkedIndices: player.bookmarkedIndices,
      showTranscript: player.settings.showTranscript,
      onSentenceTap: (index) => player.seek(player.sentences[index].startTime),
      onBookmarkToggle: (index) => player.toggleBookmark(index),
    );
  }

  Widget _buildSidePanel(PlayerProvider player) {
    final l10n = AppLocalizations.of(context)!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle(l10n.playbackMode),
                _buildModeSelector(player, l10n),
                const SizedBox(height: 24),
                _buildDisplayRow(player, l10n),
                const SizedBox(height: 24),
                _buildSpeedRow(player, l10n),
                const SizedBox(height: 24),
                _buildLoopRow(player, l10n),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildModeSelector(PlayerProvider player, AppLocalizations l10n) {
    return Column(
      children: [
        ListTile(
          leading: Radio<PlaybackMode>(
            value: PlaybackMode.fullArticle,
            groupValue: player.settings.mode,
            onChanged: (mode) {
              if (mode != null) {
                player.updateSettings(player.settings.copyWith(mode: mode));
              }
            },
          ),
          title: Row(
            children: [
              const Icon(Icons.article, size: 20),
              const SizedBox(width: 12),
              Text(l10n.fullArticle),
            ],
          ),
          onTap: () => player.updateSettings(
            player.settings.copyWith(mode: PlaybackMode.fullArticle),
          ),
        ),
        ListTile(
          leading: Radio<PlaybackMode>(
            value: PlaybackMode.singleSentence,
            groupValue: player.settings.mode,
            onChanged: (mode) {
              if (mode != null) {
                player.updateSettings(player.settings.copyWith(mode: mode));
              }
            },
          ),
          title: Row(
            children: [
              const Icon(Icons.format_quote, size: 20),
              const SizedBox(width: 12),
              Text(l10n.singleSentence),
            ],
          ),
          onTap: () => player.updateSettings(
            player.settings.copyWith(mode: PlaybackMode.singleSentence),
          ),
        ),
        ListTile(
          leading: Radio<PlaybackMode>(
            value: PlaybackMode.bookmarkedOnly,
            groupValue: player.settings.mode,
            onChanged: (mode) {
              if (mode != null) {
                player.updateSettings(player.settings.copyWith(mode: mode));
              }
            },
          ),
          title: Row(
            children: [
              const Icon(Icons.bookmark, size: 20),
              const SizedBox(width: 12),
              Text('${l10n.bookmarkedOnly} (${player.bookmarkedSentences.length})'),
            ],
          ),
          onTap: () => player.updateSettings(
            player.settings.copyWith(mode: PlaybackMode.bookmarkedOnly),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedRow(PlayerProvider player, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l10n.playbackSpeed,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 90,
          child: DropdownButtonFormField<double>(
            initialValue: player.settings.playbackSpeed,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            isExpanded: true,
            menuMaxHeight: 300,
            items: [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((speed) {
              return DropdownMenuItem(
                value: speed,
                child: Text('${speed}x'),
              );
            }).toList(),
            onChanged: (speed) {
              if (speed != null) {
                player.updateSettings(player.settings.copyWith(playbackSpeed: speed));
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoopRow(PlayerProvider player, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.loopSettings,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Switch(
              value: player.settings.loopEnabled,
              onChanged: (value) {
                player.updateSettings(player.settings.copyWith(loopEnabled: value));
              },
            ),
          ],
        ),
        if (player.settings.loopEnabled) ...[
          const SizedBox(height: 12),
          _buildCounterRow(
            label: l10n.loopCount,
            value: player.settings.loopCount,
            onChanged: (newValue) {
              player.updateSettings(
                player.settings.copyWith(loopCount: newValue),
              );
            },
            min: 1,
            max: 20,
          ),
          const SizedBox(height: 12),
          _buildCounterRow(
            label: '${l10n.pauseInterval} (${l10n.seconds})',
            value: player.settings.pauseInterval.inSeconds,
            onChanged: (newValue) {
              player.updateSettings(
                player.settings.copyWith(
                  pauseInterval: Duration(seconds: newValue),
                ),
              );
            },
            min: 0,
            max: 30,
          ),
        ],
      ],
    );
  }

  Widget _buildDisplayRow(PlayerProvider player, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.showTranscript,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              '${l10n.shortcutKey}: ↑',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        Switch(
          value: player.settings.showTranscript,
          onChanged: (value) {
            player.updateSettings(player.settings.copyWith(showTranscript: value));
          },
        ),
      ],
    );
  }

  Widget _buildCounterRow({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    required int min,
    required int max,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: value > min
                  ? () => onChanged(value - 1)
                  : null,
            ),
            Container(
              width: 60,
              alignment: Alignment.center,
              child: Text(
                '$value',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: value < max
                  ? () => onChanged(value + 1)
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControlPanel(BuildContext context, PlayerProvider player) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildProgressBar(player),
            PlaybackControls(player: player),
            _buildInfoBar(player),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(PlayerProvider player) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: StreamBuilder(
        stream: player.audioPlayer.positionStream,
        builder: (context, snapshot) {
          final position = snapshot.data ?? Duration.zero;
          final total = player.totalDuration ?? Duration.zero;
          
          return ProgressBar(
            progress: position,
            total: total,
            onSeek: (duration) => player.seek(duration),
            barHeight: 4,
            thumbRadius: 6,
            timeLabelTextStyle: const TextStyle(fontSize: 12),
          );
        },
      ),
    );
  }

  Widget _buildInfoBar(PlayerProvider player) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _getModeIcon(player.settings.mode),
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                _getModeLabel(player.settings.mode),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          if (player.settings.loopEnabled)
            Row(
              children: [
                Icon(Icons.repeat, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  player.settings.loopCount == 0
                      ? '∞'
                      : 'x${player.settings.loopCount}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          Text(
            '${player.settings.playbackSpeed}x',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  IconData _getModeIcon(PlaybackMode mode) {
    switch (mode) {
      case PlaybackMode.fullArticle:
        return Icons.article;
      case PlaybackMode.singleSentence:
        return Icons.format_quote;
      case PlaybackMode.bookmarkedOnly:
        return Icons.bookmark;
    }
  }

  String _getModeLabel(PlaybackMode mode) {
    switch (mode) {
      case PlaybackMode.fullArticle:
        return '全文精听';
      case PlaybackMode.singleSentence:
        return '逐句精听';
      case PlaybackMode.bookmarkedOnly:
        return '复习收藏';
    }
  }
}
