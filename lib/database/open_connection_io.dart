import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import '../utils/app_data_dir.dart';

LazyDatabase openConnection() {
  return openConnectionWithName('echo_loop.db');
}

LazyDatabase openConnectionWithName(String fileName) {
  return LazyDatabase(() async {
    final dbFolder = await getAppDataDirectory();
    final file = File(p.join(dbFolder.path, fileName));
    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        db.execute('PRAGMA foreign_keys = ON');
      },
    );
  });
}
