# AGENTS.md

## What this is
Narrately — see SPEC.md for the full brief. A personal ebook player: on-device text-to-speech reads the user's own EPUBs aloud, wrapped in Headway-style streaks and a daily listening goal. Flutter + Dart, Android only, portrait only.

## Stack
- Flutter (latest stable), Dart, Android only — no iOS target
- State management: Riverpod
- Local storage: sqflite
- EPUB parsing: epub_pro
- TTS: flutter_tts (on-device, no cloud voice)
- File import: file_picker

## Commands
- Install deps: `flutter pub get`
- Run on a connected device or emulator: `flutter run`
- Static analysis: `flutter analyze`
- Run tests: `flutter test`
- Build a release APK: `flutter build apk --release`

## How I want code written
- Null-safe Dart. No `dynamic` unless genuinely unavoidable.
- Business logic lives in Riverpod providers, not in `setState`, once a feature touches more than one screen.
- Small widgets, extracted rather than nested three levels deep.
- Async errors are caught and surfaced to the UI, never swallowed silently.
- New code matches the style of the file it lives in.

## Hard rules
- Read SPEC.md before planning any new slice.
- Never add a dependency without telling me what it is and why.
- Never touch a file outside the current slice's approved file list without asking first.
- No backend, no login, no network calls of any kind — this app is fully offline by design.
- Portrait only. If a change risks landscape behaving differently, flag it before writing code.
- If a test or `flutter analyze` fails, fix the code, not the test.

## Before you say a slice is done
Run `flutter analyze` and `flutter test`. Paste the real output. Tell me plainly if anything is still failing — don't round up to "done."
