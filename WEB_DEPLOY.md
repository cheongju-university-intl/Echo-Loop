# Echo Loop 韩语网页版部署说明

这个分支把项目改成可以通过 GitHub Pages 发布 Flutter Web。

目标访问地址：

```text
https://cheongju-university-intl.github.io/Echo-Loop/
```

## 已新增内容

### 1. GitHub Pages 自动部署

新增 workflow：

```text
.github/workflows/deploy-web.yml
```

合并到 `main` 后，只要 `main` 有相关代码变化，就会自动执行：

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build web --release --base-href /Echo-Loop/ --dart-define-from-file=.web.env
```

构建产物会发布到 GitHub Pages。

### 2. Web / PWA 元数据

修改：

```text
web/index.html
web/manifest.json
```

把网页标题和 PWA 名称改成：

```text
Echo Loop 韩语
```

## 第一次使用前要设置 GitHub Pages

进入仓库页面：

```text
Settings → Pages
```

把 Source 设置成：

```text
GitHub Actions
```

然后合并这个 PR，等待 Actions 跑完。

## 可选：配置环境变量

进入：

```text
Settings → Secrets and variables → Actions
```

建议添加：

### Repository variables

```text
API_BASE_URL=https://dev.echo-loop.top
```

### Repository secrets

如果你要登录 / AI 功能，就填：

```text
SUPABASE_URL
SUPABASE_PUBLISHABLE_KEY
GOOGLE_WEB_CLIENT_ID
```

如果暂时只是打开界面和测试本地音频字幕，可以先不填。

## iPhone 上怎么试

用 iPhone Safari 打开：

```text
https://cheongju-university-intl.github.io/Echo-Loop/
```

也可以添加到桌面：

```text
Safari → 分享按钮 → 添加到主屏幕
```

这样看起来会像一个 App。

## 网页版限制

网页版可以先测试：

- App 页面是否能打开
- 韩语音频 / 字幕导入流程
- 播放和字幕查看
- 韩语查词清洗逻辑
- AI 翻译/解析，如果后端和 Supabase 环境配置正确

网页版可能受限：

- iOS Safari 后台播放限制
- 本地离线 ASR 模型可能无法正常使用
- 原生语音识别 / 跟读评分可能不稳定
- 文件选择和本地缓存能力弱于原生 App

所以网页版适合你现在没有 Mac、没有安卓时先体验韩语学习流程；完整体验以后仍建议做 iOS TestFlight 或安卓 APK。
