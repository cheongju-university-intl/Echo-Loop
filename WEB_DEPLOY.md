# Echo Loop Korean Web Deployment

The target is the full Flutter app running on the web, not the static
`web_preview/` prototype.

## Current State

- GitHub Pages still deploys `web_preview/` so the existing site does not break.
- `.github/workflows/flutter-web-build.yml` runs the real `flutter build web`
  check for the full app port.
- When the Flutter Web build is green and core flows work in-browser, switch
  `.github/workflows/deploy-web.yml` to publish `build/web`.

## Full Web Target

The web app should keep the original Echo Loop product shape:

- library/import flow
- synced transcript player
- sentence loop and range repeat
- intensive listening and blind listening
- shadowing, retell, and difficult sentence practice
- saved words, notes, progress, and collections
- dictionary lookup
- auth, sync, analytics, and subscription gates where configured

Then Korean-learning content should replace the generic/English learning content:

- Korean demo audio and transcripts
- Korean dictionary/search defaults
- Korean practice labels and presets
- Korean ASR/TTS choices where web support exists

## Porting Rule

Native-only app services must get web implementations or safe web fallbacks.
Do not call the static preview the finished product.
