<div align="center">

<img src="assets/icon.png" alt="Narrately icon" width="112" />

# Narrately

**Turn your own ebook library into an audiobook habit.**

Narrately reads your EPUB and PDF books aloud with your phone's built-in text-to-speech voices. It works fully offline, needs no account, and adds a daily listening goal and streaks so you keep coming back.

![Platform](https://img.shields.io/badge/platform-Android-3DDC84?logo=android&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.13-0175C2?logo=dart&logoColor=white)
![Offline](https://img.shields.io/badge/network-none-success)

[Download the latest APK](../../releases/latest) · [Report a bug](../../issues) · [Contribute](#contributing)

</div>

---

## Table of contents

- [Features](#features)
- [Installation](#installation)
- [Tech stack](#tech-stack)
- [Project structure](#project-structure)
- [Development setup](#development-setup)
- [Testing](#testing)
- [Releases and versioning](#releases-and-versioning)
- [Signing key (maintainers)](#signing-key-maintainers)
- [Contributing](#contributing)
- [Privacy](#privacy)

## Features

**Library**
- Import **EPUB** and **PDF** files from device storage
- EPUB chapters come from the book's table of contents, with cover art extraction
- PDF chapters come from the document outline (bookmarks) when one is present
- Duplicate import detection and readable error messages for broken files
- Remove books from your library

**Listening**
- On-device text-to-speech through Android's TTS engine, so it works offline
- Follow-along text: the passage being read is highlighted and scrolled into view
- Play/pause, skip back and forward (about 50 words), previous and next chapter
- Automatic advance to the next chapter
- Chapter drawer to jump anywhere in the book
- Remembers the last chapter you listened to in each book
- Background playback with notification and lock-screen media controls
- Sleep timer (15, 30 or 60 minutes)
- Voice settings: speed, pitch and any voice installed on the device, saved between sessions

**Habit**
- Daily listening goal with a progress bar on the Library screen
- Day streak counter
- A celebration when you reach the day's goal

**Appearance**
- Material 3 design with light, dark and system themes
- Portrait-only layout tuned for one-handed use

## Installation

1. Open the [latest release](../../releases/latest) on your Android phone.
2. Download `Narrately-vX.Y.apk`.
3. Open the file and allow installation from your browser or file manager if Android asks.

Updates install over the previous version and keep your library, because every release is signed with the same key.

> **Tip:** For more natural voices, install extra voices in Android's **Text-to-speech output** settings (usually under **Settings > System > Languages**, depending on the device), for example Google Speech Services voice packs. Narrately lists every voice your device has.

## Tech stack

| Area | Choice |
| --- | --- |
| Framework | [Flutter](https://flutter.dev) (Android only) |
| State management | [Riverpod 3](https://pub.dev/packages/flutter_riverpod) |
| Local storage | [sqflite](https://pub.dev/packages/sqflite) |
| Text-to-speech | [flutter_tts](https://pub.dev/packages/flutter_tts) |
| Background audio | [audio_service](https://pub.dev/packages/audio_service) |
| EPUB parsing | [epub_pro](https://pub.dev/packages/epub_pro) |
| PDF parsing | [syncfusion_flutter_pdf](https://pub.dev/packages/syncfusion_flutter_pdf) |
| File import | [file_picker](https://pub.dev/packages/file_picker) |
| CI/CD | GitHub Actions |

## Project structure

```
lib/
├── main.dart          # App entry: portrait lock, audio service, theme
├── models/            # Book, Chapter, UserStats
├── providers/         # Riverpod notifiers (library, player, stats, theme, database)
├── screens/           # Library, Book detail, Player, Settings, bottom navigation
├── services/          # Database, EPUB/PDF parsing, TTS, audio handler, file picker
└── widgets/           # Reusable UI components
test/                  # Unit and widget tests
integration_test/      # On-device integration tests
android/               # Android host project and signing configuration
.github/workflows/     # Release pipeline
```

## Development setup

### Prerequisites

| Tool | Version |
| --- | --- |
| [Flutter SDK](https://docs.flutter.dev/get-started/install) | 3.47.0 stable (includes Dart 3.13) |
| JDK | 17 or newer ([Temurin](https://adoptium.net) recommended) |
| Android SDK | Platform 37 and build tools (install through Android Studio) |
| Device | Android phone with USB debugging, or an emulator |

Run `flutter doctor` and fix anything it reports before continuing.

### Get the code running

```bash
# 1. Fork the repository on GitHub, then clone your fork
git clone https://github.com/<your-username>/<repository>.git
cd <repository>

# 2. Install dependencies
flutter pub get

# 3. Start the app on a connected device or emulator
flutter run
```

That's all you need to contribute. You do **not** need the release signing key: without it, release builds are signed with your local debug key.

```bash
flutter build apk --release   # output: build/app/outputs/flutter-apk/app-release.apk
```

> **Note:** Android refuses to install an APK over an app signed with a different key. If you already have the official release installed, uninstall it before installing your own build, or use a separate device or emulator.

## Testing

```bash
flutter analyze                  # static analysis, must report "No issues found!"
flutter test                     # unit and widget tests
flutter test integration_test    # integration tests, needs a device or emulator
```

The release pipeline runs `flutter analyze` and `flutter test` and will not publish if either fails.

## Releases and versioning

Every push to `main` runs [`.github/workflows/release.yml`](.github/workflows/release.yml), which:

1. Works out the next version from the latest `vX.Y` tag, so a release is never overwritten.
2. Runs static analysis and tests.
3. Builds a release APK signed with the official key.
4. Commits the bumped version in `pubspec.yaml` back to `main` and tags it `vX.Y`.
5. Publishes a GitHub Release named **Narrately vX.Y** with `Narrately-vX.Y.apk` attached and generated release notes.

**Version scheme**

| Situation | Result |
| --- | --- |
| First release | Uses the version in `pubspec.yaml` (`1.0.0+1` becomes **v1.0**) |
| Every following push to `main` | Minor number goes up: v1.0, v1.1, v1.2 … |
| Major release | Set `version: 2.0.0+<any>` in `pubspec.yaml` and push. The release is **v2.0** and later pushes continue from v2.1 |
| Build number (Android `versionCode`) | Always goes up by one, so updates install cleanly |

> **Important:** The bot pushes a version bump commit to `main` after each release, so your local `main` falls behind. Run `git pull --rebase` before you push again.

### One-time repository setup

1. **Default branch:** make sure the branch is named `main` (`git branch -M main`).
2. **Workflow permissions:** go to **Settings > Actions > General > Workflow permissions** and select **Read and write permissions**.
3. **Branch protection:** if `main` is protected, allow GitHub Actions to push to it, or the version bump step will fail.
4. **Signing secrets:** add the four secrets described in [Signing key](#add-the-key-to-github-actions).

## Signing key (maintainers)

Android identifies an app by its package name **and** its signing key. If the key is lost, you can no longer ship updates that install over existing copies, and users would have to uninstall and lose their data. Treat the key like a password.

The key consists of two files in the project root. Both are listed in `.gitignore` and must **never** be committed:

| File | Contents |
| --- | --- |
| `narrately-release.jks` | The keystore holding the private key (alias `narrately`) |
| `key.properties` | Keystore path, alias and passwords used by Gradle |

`android/app/build.gradle.kts` reads `key.properties` from the project root. When the file exists, release builds use the release key. When it doesn't, they fall back to the debug key.

### Back up the key

Store **both** files somewhere private and durable, for example as attachments in a password manager (Bitwarden, 1Password, KeePassXC) or in an encrypted archive kept in two separate places. GitHub secrets are **not** a backup, because they cannot be read back once saved.

### Use the key on another machine

1. Clone the repository and complete [Development setup](#development-setup).
2. Copy `narrately-release.jks` and `key.properties` from your backup into the **project root**, next to `pubspec.yaml`.
3. If you put the keystore somewhere else, set `storeFile` in `key.properties` to its absolute path. Use forward slashes on Windows, for example `storeFile=C:/keys/narrately-release.jks`.
4. Check that the key opens (it asks for the `storePassword` from `key.properties`):
   ```bash
   keytool -list -v -keystore narrately-release.jks -alias narrately
   ```
5. Build and confirm the APK is signed with the release key:
   ```bash
   flutter build apk --release
   # apksigner lives in <Android SDK>/build-tools/<version>/
   apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
   ```
   The certificate DN should read `CN=Narrately, OU=Android, O=yuuge7`, not `CN=Android Debug`.

### Add the key to GitHub Actions

In the repository, go to **Settings > Secrets and variables > Actions > New repository secret** and add:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | The keystore file encoded as base64 (see below) |
| `ANDROID_KEYSTORE_PASSWORD` | `storePassword` from `key.properties` |
| `ANDROID_KEY_ALIAS` | `keyAlias` from `key.properties` (`narrately`) |
| `ANDROID_KEY_PASSWORD` | `keyPassword` from `key.properties` |

Copy the base64-encoded keystore to your clipboard without writing it to disk:

```powershell
# Windows (PowerShell)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("narrately-release.jks")) | Set-Clipboard
```

```bash
# macOS
base64 -i narrately-release.jks | pbcopy
# Linux
base64 -w 0 narrately-release.jks | xclip -selection clipboard
```

## Contributing

Contributions are welcome, whether that's a bug fix, a new feature or better documentation.

1. **Open an issue first** for anything bigger than a small fix, so we can agree on the approach.
2. **Create a branch** from `main`: `git checkout -b feat/sleep-timer-presets`.
3. **Follow the project conventions:**
   - Null-safe Dart. Avoid `dynamic`.
   - Business logic lives in Riverpod notifiers under `lib/providers/`, not in widget `setState`.
   - Keep widgets small and extract them rather than nesting deeply.
   - Catch async errors and show them in the UI. Never swallow them silently.
   - The app is offline by design: no network calls, accounts or cloud services.
   - Portrait only.
   - Database schema changes must bump the version in `DatabaseService` and add an `onUpgrade` migration, so existing users keep their library.
   - Discuss new dependencies in the issue or pull request before adding them.
4. **Check your work:** `flutter analyze` must report no issues and `flutter test` must pass. Add tests for new logic.
5. **Commit** using [Conventional Commits](https://www.conventionalcommits.org), for example `feat: add bookmark notes` or `fix: resume after sleep timer`.
6. **Open a pull request** against `main` that describes what changed and how you tested it. Screenshots help for UI changes.

Merged pull requests ship automatically in the next release.

## Privacy

Narrately has no servers, analytics or accounts, and it never touches the network. Your books, listening progress and settings stay in the app's private storage on your device. Speech is generated by your phone's own text-to-speech engine.
