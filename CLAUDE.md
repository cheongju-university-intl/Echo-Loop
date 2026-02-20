# CLAUDE.md - Claude Code 工作规范

## 0 目标

你是 Claude Code，在本仓库内协助完成开发任务。你的首要目标是按计划稳定推进，并保持改动可验证。

**核心原则**：
1. 文件驱动 — 决策写进 PLAN.md / TASKS.md，不依赖聊天记忆
2. 单任务聚焦 — 一次只做一件事，做完再下一件
3. 测试先行 — 先写测试定义预期，再写实现
4. 功能解耦 — 每个模块独立可测，不耦合无关逻辑；单文件 ≤500 行，单函数 ≤50 行
5. 逐步验证 — 每次改动立即可运行、可检查，不攒大变更
6. 注释完善 - 文件、函数、核心逻辑等必须有完善且符合规范的文档/注释，使用中文。
7. 文档同步 — 代码改完，立刻更新对应文档状态
8. 最小改动 - 避免大范围重构，除非任务明确要求，不允许改动与当前任务无关的文件和代码
9. 类型安全 - 优先使用类型安全的编码风格，避免在运行时出错

---

## 1 启动流程（每个会话必须执行）

⚠️ **强制要求**：开始任何工作前，必须按顺序完成以下步骤：

### 步骤 1: 读取 PLAN.md
### 步骤 2: 读取 TASKS.md
### 步骤 3: 输出要执行的任务，一次只做一个任务
### 步骤 4: 等待用户确认，再开始修改代码。

---

## 2 收尾流程（每次完成任务必须执行）

⚠️ **强制要求**：完成当前任务后，必须按顺序完成以下步骤：
### 步骤 1: 检查测试是否完整，包括unit test、widget test、integration test
### 步骤 2: 检测是否有死代码（包括测试代码），有就删除
### 步骤 3: 检查注释和文档是否完善、清晰
### 步骤 4: 运行验证命令
```bash
flutter analyze
flutter test
flutter build macos
```

### 步骤 5: 更新 TASKS.md
```markdown
# 必须完成：
1. 勾选已完成任务（- [x]）
2. 在任务下添加完成记录：

**完成时间**: 2026-01-31
**变更点**:
- 修改了 X 文件，实现 Y 功能
- 添加了 Z 测试，覆盖 A 场景
```

### 步骤 6: 更新 PLAN.md（如有需要）
如果本次任务导致里程碑进度变化，必须更新 PLAN.md。


### 步骤 7: 输出完成摘要
```markdown
**实现的任务**: [任务标题]
**修改的文件** (X 个):
- path/to/file.dart (+50 -10)
**对应的测试**:
- /path/to/test
**下一步建议**:
- 告诉用户如何验证结果
- 下一个任务是什么
```

---

## 5 TASKS.md 归档规则

### 5.1 何时触发归档

满足以下任一条件时，**必须执行归档**：

1. **里程碑完成**：当 PLAN.md 中的某个 Milestone 完成时
2. **文件过大**：TASKS.md 超过 200 行
3. **任务过多**：已完成任务超过 30 条
4. **手动触发**：用户明确要求归档

### 5.2 归档执行步骤

1. 创建归档文件：`docs/tasks-archive/milestone-X-completed.md`
2. 将已完成任务移入归档文件
3. 清理 TASKS.md，仅保留未完成任务
4. 在 TASKS.md 顶部添加归档链接
5. 更新 PLAN.md 里程碑状态

---

## 9 项目特定知识

### 9.1 项目概述

Fluency 是一款 Flutter 跨平台英语听说练习应用，支持 macOS / iOS / Android / Web。

### 9.3 项目结构

```
lib/
├── l10n/              # 国际化翻译文件（ARB 格式）
├── models/            # 数据模型（AudioItem, Sentence, Collection 等）
├── providers/         # Riverpod 状态管理
│   ├── audio_engine/  # 音频引擎层（底层播放控制）
│   └── listening_practice/  # 听力练习层（业务逻辑）
│       ├── sentence_tracker.dart     # 句子定位（二分查找）
│       └── bookmark_manager.dart     # 书签管理
├── screens/           # 页面
├── services/          # 服务层（StorageService, SubtitleParser）
└── widgets/           # 可复用组件

test/
├── models/            # 模型单元测试
├── providers/         # Provider / 辅助类测试
├── services/          # 服务层测试
└── widget_test.dart   # Widget 冒烟测试
```

### 9.4 架构设计

2 层架构：
- **AudioEngine**（底层）: 封装 just_audio，管理播放、暂停、seek 等底层操作
- **ListeningPractice**（业务层）: 句子追踪、书签管理、循环播放等业务逻辑

### 9.5 国际化

- 使用 Flutter 内置的 `flutter_localizations` + ARB 文件
- 翻译文件位置: `lib/l10n/`
- 模板文件: `app_en.arb`，当前支持 en / zh
- 配置文件: `l10n.yaml`

### 9.6 Lint 和格式化

- 使用 `flutter_lints` 进行静态分析
- 配置文件: `analysis_options.yaml`
- 运行检查: `flutter analyze`
- 代码格式化: `dart format .`

### 9.7 测试规范

- 使用 `flutter_test` + `mocktail` 作为测试框架
- 测试文件命名: `*_test.dart`
- 运行全部测试: `flutter test`
- 运行单个测试: `flutter test test/models/audio_item_test.dart`
- 每个新功能或 bug 修复应该包含相应的测试

### 9.8 代码生成

Riverpod Provider 使用代码生成（`riverpod_generator`）：
- Provider 文件包含 `part 'xxx.g.dart';`
- 修改 Provider 后运行: `dart run build_runner build`

### 9.9 常用命令

```bash
# 开发
flutter run -d macos          # macOS 运行
flutter run -d chrome          # Web 运行

# 质量检查
flutter analyze                # 静态分析
flutter test                   # 运行所有测试
dart format .                  # 代码格式化

# 依赖管理
flutter pub get                # 安装依赖
flutter pub upgrade            # 升级依赖

# 代码生成
dart run build_runner build    # 生成 Riverpod Provider 代码

# 构建
flutter build macos            # 构建 macOS 应用
flutter build apk              # 构建 Android APK
flutter build ios              # 构建 iOS
```

**文档版本**: v3.0
**更新时间**: 2026-02-20
**维护者**: Claude Code + Fluency Team
