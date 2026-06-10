/// 开发者日志查看页面
///
/// 实时显示应用内日志，支持滚动、清空、分享。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_logger.dart';
import '../theme/app_theme.dart';

/// 日志查看页面
class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    AppLogger.instance.addListener(_onLogUpdated);
  }

  @override
  void dispose() {
    AppLogger.instance.removeListener(_onLogUpdated);
    _scrollController.dispose();
    super.dispose();
  }

  void _onLogUpdated() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  /// 复制日志：优先导出落盘文件（含 Worker isolate 的 ASR 推理日志、跨进程历史），
  /// 落盘不可用时回退到内存缓冲。
  Future<void> _copyAll() async {
    final persisted = await AppLogger.readPersistedLog();
    final text = (persisted != null && persisted.trim().isNotEmpty)
        ? persisted
        : AppLogger.instance.entries.map((e) => e.toString()).join('\n');
    if (!mounted) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    final label = persisted != null ? '已复制完整日志（含落盘）' : '已复制到剪贴板';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(label), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = AppLogger.instance.entries;

    return Scaffold(
      appBar: AppBar(
        title: Text('日志 (${entries.length})'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: entries.isEmpty ? null : _copyAll,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: entries.isEmpty
                ? null
                : () {
                    AppLogger.instance.clear();
                    setState(() {});
                  },
          ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Text(
                '暂无日志',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              itemCount: entries.length,
              padding: const EdgeInsets.all(AppSpacing.s),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _LogEntryTile(entry: entry);
              },
            ),
    );
  }
}

/// 单条日志显示
class _LogEntryTile extends StatelessWidget {
  final LogEntry entry;
  const _LogEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr =
        '${entry.time.hour.toString().padLeft(2, '0')}:'
        '${entry.time.minute.toString().padLeft(2, '0')}:'
        '${entry.time.second.toString().padLeft(2, '0')}.'
        '${entry.time.millisecond.toString().padLeft(3, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: timeStr,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
            TextSpan(
              text: ' [${entry.tag}] ',
              style: TextStyle(
                color: _tagColor(entry.tag, theme),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
            TextSpan(
              text: entry.message,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _tagColor(String tag, ThemeData theme) {
    return switch (tag) {
      'Turn' => Colors.orange,
      'Player' => Colors.blue,
      'Screen' => Colors.green,
      _ => theme.colorScheme.primary,
    };
  }
}
