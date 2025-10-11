import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/sentence.dart';
import '../services/subtitle_parser.dart';

class SentenceListView extends StatefulWidget {
  final List<Sentence> sentences;
  final int? currentIndex;
  final Set<int> bookmarkedIndices;
  final Function(int) onSentenceTap;
  final Function(int) onBookmarkToggle;
  final bool showTranscript;

  const SentenceListView({
    super.key,
    required this.sentences,
    required this.currentIndex,
    required this.bookmarkedIndices,
    required this.onSentenceTap,
    required this.onBookmarkToggle,
    this.showTranscript = true,
  });

  @override
  State<SentenceListView> createState() => _SentenceListViewState();
}

class _SentenceListViewState extends State<SentenceListView> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};

  @override
  void didUpdateWidget(SentenceListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.currentIndex != oldWidget.currentIndex && 
        widget.currentIndex != null) {
      _scrollToCurrentSentence();
    }
  }

  void _scrollToCurrentSentence() {
    if (widget.currentIndex == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _itemKeys[widget.currentIndex];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.3,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.sentences.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final sentence = widget.sentences[index];
        final isCurrent = widget.currentIndex == sentence.index;
        final isBookmarked = widget.bookmarkedIndices.contains(sentence.index);
        
        // Create key for current sentence
        if (isCurrent && !_itemKeys.containsKey(sentence.index)) {
          _itemKeys[sentence.index] = GlobalKey();
        }

        return _SentenceTile(
          key: isCurrent ? _itemKeys[sentence.index] : null,
          sentence: sentence,
          isCurrent: isCurrent,
          isBookmarked: isBookmarked,
          showTranscript: widget.showTranscript,
          onTap: () => widget.onSentenceTap(sentence.index),
          onBookmarkToggle: () => widget.onBookmarkToggle(sentence.index),
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _SentenceTile extends StatelessWidget {
  final Sentence sentence;
  final bool isCurrent;
  final bool isBookmarked;
  final bool showTranscript;
  final VoidCallback onTap;
  final VoidCallback onBookmarkToggle;

  const _SentenceTile({
    super.key,
    required this.sentence,
    required this.isCurrent,
    required this.isBookmarked,
    required this.showTranscript,
    required this.onTap,
    required this.onBookmarkToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isCurrent ? 8 : 1,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: isCurrent
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5)
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Index badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${sentence.index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isCurrent
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Sentence text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Text(
                          sentence.text,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        if (!showTranscript)
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
                    const SizedBox(height: 4),
                    Text(
                      '${SubtitleParser.formatDuration(sentence.startTime)} - ${SubtitleParser.formatDuration(sentence.endTime)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
              // Bookmark button
              IconButton(
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: isBookmarked ? Colors.amber : Colors.grey,
                ),
                onPressed: onBookmarkToggle,
                tooltip: isBookmarked ? 'Remove bookmark' : 'Add bookmark',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
