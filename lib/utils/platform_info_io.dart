import 'dart:io' as io;

bool get isAndroid => io.Platform.isAndroid;
bool get isIOS => io.Platform.isIOS;
bool get isMacOS => io.Platform.isMacOS;
String get operatingSystem => io.Platform.operatingSystem;
String get localeName => io.Platform.localeName;
