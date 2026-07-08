import 'dart:io';

Future<void> prepareLogFile(String filePath, int maxFileBytes) async {
  final file = File(filePath);
  if (await file.exists() && await file.length() > maxFileBytes) {
    final content = await file.readAsString();
    final keep = content.length > maxFileBytes ~/ 2
        ? content.substring(content.length - maxFileBytes ~/ 2)
        : content;
    await file.writeAsString('--- log truncated ---\n$keep');
  }
}

Future<String?> readLogFile(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) return null;
  return file.readAsString();
}

void appendLogFile(String filePath, String line) {
  File(filePath).writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
}
