/// 版本号比较工具
///
/// 按 SemVer 主版本号 [major, minor, patch] 三段比较，**不考虑构建号**。
///
/// 设计：构建号（Flutter pubspec 的 `+N`、Android versionCode）是平台内部
/// 升降级机制，对用户和业务版本判断无意义。同一 versionName（如 `1.0.11`）
/// 在我们的发布规范下唯一对应一次正式发布，构建号只是 CI 自动生成的内部数字。
///
/// 解析示例：
/// - `1.0.8` → [1, 0, 8]
/// - `1.0.8+2` → [1, 0, 8]（构建号被丢弃）
/// - null / "" → [0, 0, 0]
/// - "1.0" → [1, 0, 0]（自动补零）
/// - "1.0.0-beta" → [1, 0, 0]（去除 pre-release 后缀）
/// - "abc" / "1.x.0" → 对应段解析为 0
/// - 任何输入都不抛异常
library;

/// 将版本号字符串解析为整数列表 [major, minor, patch]
///
/// 容错处理：去除 v 前缀、丢弃 +N 构建号、去除 pre-release 后缀、自动补零。
List<int> parseVersion(String? version) {
  if (version == null || version.isEmpty) return [0, 0, 0];

  // 去除 "v" 前缀
  final cleaned = version.startsWith('v') || version.startsWith('V')
      ? version.substring(1)
      : version;

  // 丢弃 +N 构建号（不参与比较）
  final coreWithPre = cleaned.split('+').first;

  // 去除 pre-release 后缀
  final core = coreWithPre.split('-').first;

  final parts = core.split('.');
  final result = <int>[];
  for (var i = 0; i < 3; i++) {
    result.add(i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0);
  }
  return result;
}

/// 比较两个版本号
///
/// 返回值：
/// - 负数：a < b
/// - 0：a == b
/// - 正数：a > b
int compareVersions(String? a, String? b) {
  final va = parseVersion(a);
  final vb = parseVersion(b);
  for (var i = 0; i < 3; i++) {
    if (va[i] != vb[i]) return va[i] - vb[i];
  }
  return 0;
}

/// 判断远程版本是否比本地版本更新
bool isNewerVersion({
  required String? localVersion,
  required String? remoteVersion,
}) {
  return compareVersions(remoteVersion, localVersion) > 0;
}
