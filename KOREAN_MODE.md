# Echo Loop 韩语私人版修改说明

这个分支是把 Echo Loop 先改成“韩语学习私人版”的 v0.1。目标是先能用于：

- 导入韩语音频
- 导入韩语 SRT / VTT 字幕
- 按原来的盲听、精听、跟读、复述流程练韩语
- 用中文作为 AI 翻译、解析、查词的解释语言

## 已修改内容

### 1. Android 手机桌面名称

新增：

```text
android/app/src/main/res/values/strings.xml
```

把 Android 安装后的应用名改成：

```text
Echo Loop 韩语
```

### 2. iOS 权限说明

修改：

```text
ios/Runner/en.lproj/InfoPlist.strings
```

把“spoken English practice”改成“spoken Korean practice”。

### 3. 韩语查词清洗逻辑

修改：

```text
lib/utils/text_normalize.dart
```

原来的查词清洗规则只保留英文和数字，韩语单词可能会被清掉。现在加入了韩文字母范围：

- `가-힣`
- `ㄱ-ㅎ`
- `ㅏ-ㅣ`

这样选中或输入韩语单词，例如：

```text
학교
먹었다가
소외
```

不会在进入 AI 词典或缓存键之前被错误剥离。

## 当前版本定位

这是“韩语学习模式 v0.1”，重点是让你能先把韩语材料拿来练。

可以直接测试：

1. 手机安装这个分支编译出来的 APK
2. 导入韩语音频
3. 导入韩语字幕
4. 使用原来的精听 / 跟读 / 复述流程
5. 长按或选择韩语单词测试 AI 词典解释

## 还没彻底改完的地方

下面这些属于后续 v0.2 / v0.3：

### 1. 本地离线词典

原项目本地词典主要按英语词典设计，例如 `en_zh-CN`。韩语私人版如果要本地离线韩中词典，需要新增或替换成：

```text
ko_zh-CN
```

并准备对应的 `dict.db`。

### 2. 离线 ASR 模型

项目已有 sherpa-onnx / Whisper ONNX 结构。韩语跟读识别要更准确，需要接入支持韩语的 Whisper 多语模型，或者用系统韩语语音识别。

### 3. 韩语 TTS

原项目内置 TTS 音色主要是英语音色。韩语朗读建议后续接：

```text
ko-KR
```

例如系统 TTS 或韩语 Piper / Kokoro 可用模型。

### 4. 全部界面文案

本次只先改应用方向和关键代码。后续可以继续把“英语听说训练”等界面文案统一替换成“韩语听说训练”。

## 编译命令

```bash
git checkout korean-learning-mode
flutter pub get
dart run build_runner build
flutter run -d android --dart-define-from-file=.dev.env
```

打 APK：

```bash
flutter build apk --dart-define-from-file=.dev.env
```
