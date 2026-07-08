# Full Flutter Web Port Checklist

Goal: bring the original app features to the website, then make the product a
Korean-learning version.

## Build Blockers

- Replace direct `dart:io` imports in web-reachable code.
- Add web Firebase options through `--dart-define`.
- Add a Drift web database executor instead of the native SQLite executor.
- Keep native implementations behind conditional imports.
- Run `.github/workflows/flutter-web-build.yml` until `flutter build web` is
  green.

## Feature Parity

- Audio playback: use browser-supported playback, seeking, clip loop, speed, and
  progress streams.
- Import: support browser file upload for audio and subtitle files.
- Storage: persist app data in IndexedDB or a backend, not native app folders.
- Transcript: keep SRT/VTT parsing, sentence timing, editing, and database
  backfill.
- Practice flows: keep repeat, intensive listen, blind listen, retell,
  difficult practice, bookmarks, notes, and progress.
- Dictionary: keep external Korean dictionary lookup and saved vocabulary.
- Recording: use browser `MediaRecorder` where permissions allow it.
- ASR: use browser speech APIs or server ASR; native offline models stay native.
- TTS: use browser speech synthesis or server TTS; native Kokoro/Piper stay
  native unless replaced with web-compatible inference.
- PDF/export/share: use browser download APIs.
- Auth/sync: keep Supabase sign-in and server sync where configured.
- Subscription: use web checkout/entitlement APIs instead of native IAP SDKs.

## Korean-Learning Conversion

- Replace bundled examples with Korean audio and transcripts.
- Change collection names, presets, onboarding copy, and defaults to Korean
  learning.
- Default dictionaries to Naver, Daum, Papago, and Korean search URLs.
- Prefer Korean voices for browser/server TTS.
- Prefer Korean ASR for browser/server recognition.
- Keep UI localizations separate from learning language defaults.

## Deployment Gate

Switch GitHub Pages from `web_preview/` to `flutter build web` only after:

- Web build passes in GitHub Actions.
- Main player opens in Chrome.
- Audio import, transcript import, loop repeat, playback speed, notes, saved
  words, and progress survive refresh.
- Auth and paid-feature gates degrade safely when secrets are absent.

