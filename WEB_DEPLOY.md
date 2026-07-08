# Echo Loop 韩语 Web 部署

这个仓库的 GitHub Pages 发布的是 `web_preview/` 下的静态 Web app。

它不是 Flutter Web 构建产物。移动端 Flutter App 目前仍包含 `dart:io`、原生语音、Firebase 原生配置等依赖，直接发布 Flutter Web 会比静态版多很多平台适配成本。

## 自动部署

工作流：

```text
.github/workflows/deploy-web.yml
```

触发条件：

- 推送 `web_preview/**`
- 推送 `.github/workflows/deploy-web.yml`
- 手动运行 workflow

部署地址：

```text
https://cheongju-university-intl.github.io/Echo-Loop/
```

## 当前 Web 功能

- 导入本地音频 / 视频
- 导入 SRT / VTT 字幕
- 逐句同步播放
- 单句循环、盲听、播放速度
- 韩语浏览器 TTS
- 浏览器录音跟读
- 点击韩语词打开 Naver / Daum / Papago / Google
- 复制 AI 查词提示
- 收藏、笔记、本地保存、导出 JSON

## 暂不做

- 不在 Pages 上构建完整 Flutter App。
- 不在纯静态页里接真实账号、订阅、云端 AI 和离线 ASR。

这些等 Web 版核心练习验证可用后，再拆成后端/API 工作。
