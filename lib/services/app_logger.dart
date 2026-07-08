library;

import 'dart:collection';

import 'log_file_sink.dart';

class LogEntry {
  final DateTime time;
  final String tag;
  final String message;

  const LogEntry({
    required this.time,
    required this.tag,
    required this.message,
  });

  @override
  String toString() => AppLogger.formatLine(time, tag, message);
}

class AppLogger {
  AppLogger._();

  static final instance = AppLogger._();
  static const _maxEntries = 500;
  static const _maxFileBytes = 512 * 1024;

  static String? _filePath;

  final _entries = Queue<LogEntry>();
  final _listeners = <void Function()>[];

  List<LogEntry> get entries => List.unmodifiable(_entries);

  static String formatLine(DateTime time, String tag, String message) {
    final t =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}.'
        '${time.millisecond.toString().padLeft(3, '0')}';
    return '$t [$tag] $message';
  }

  static Future<void> initFileSink(String filePath) async {
    _filePath = filePath;
    try {
      await prepareLogFile(filePath, _maxFileBytes);
    } catch (_) {}
  }

  static Future<String?> readPersistedLog() async {
    final path = _filePath;
    if (path == null) return null;
    try {
      return await readLogFile(path);
    } catch (_) {
      return null;
    }
  }

  static void _appendToFile(String line) {
    final path = _filePath;
    if (path == null) return;
    try {
      appendLogFile(path, line);
    } catch (_) {}
  }

  static void log(String tag, String message) {
    final entry = LogEntry(time: DateTime.now(), tag: tag, message: message);
    // ignore: avoid_print
    print(entry);
    _appendToFile(entry.toString());

    final logger = instance;
    logger._entries.addLast(entry);
    if (logger._entries.length > _maxEntries) {
      logger._entries.removeFirst();
    }
    for (final listener in logger._listeners) {
      listener();
    }
  }

  void clear() {
    _entries.clear();
    for (final listener in _listeners) {
      listener();
    }
  }

  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }
}
