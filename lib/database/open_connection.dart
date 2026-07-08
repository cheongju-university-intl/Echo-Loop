import 'package:drift/drift.dart';

import 'open_connection_stub.dart'
    if (dart.library.io) 'open_connection_io.dart' as impl;

QueryExecutor openConnection() => impl.openConnection();

QueryExecutor openConnectionWithName(String fileName) =>
    impl.openConnectionWithName(fileName);
