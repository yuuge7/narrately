# PROMPTS.md

Six messages, one per slice from SPEC.md's build order. Paste them into the agent in order, one at a time, only moving to the next after the current slice is committed. Don't paste two in a row — read and correct the plan first (see the setup walkthrough on why that step matters most).

## Slice 1 — import and list chapters

```
/plan Read SPEC.md and AGENTS.md before doing anything. Plan only the
first vertical slice: importing an EPUB with file_picker, parsing it
with epub_pro, and showing the chapter list. No flutter_tts, no
playback, no database yet. List every file you'll create, then stop
and wait for my approval before writing any code.
```

## Slice 2 — single-chapter playback

```
/plan Slice 1 (import + chapter list) is committed. Plan slice 2: wire
flutter_tts to read the currently selected chapter aloud, with play,
pause, and stop only. No auto-advance to the next chapter yet, no
saved position. List every file you'll touch, then stop for my
approval.
```

## Slice 3 — auto-advance and resume

```
/plan Slice 2 (single-chapter playback) is committed. Plan slice 3:
auto-advance to the next chapter when one finishes, and save and
restore playback position in sqflite so closing and reopening the app
resumes where I left off. List every file you'll touch, then stop for
my approval.
```

## Slice 4 — player controls

```
/plan Slice 3 (auto-advance + resume) is committed. Plan slice 4: skip
forward and back controls, a speed control from 0.75x to 2x, and a
voice picker listing the voices already installed on the device via
flutter_tts. List every file you'll touch, then stop for my approval.
```

## Slice 5 — streaks and progress

```
/plan Slice 4 (player controls) is committed. Plan slice 5: track
daily minutes listened, calculate streaks, and build the Library
header widget plus the Progress screen described in SPEC.md. Use
sqflite for the daily stats. List every file you'll touch, then stop
for my approval.
```

## Slice 6 — bookmarks, errors, polish

```
/plan Slice 5 (streaks + progress) is committed. Plan slice 6:
bookmarks that save the current position with an optional note, an
empty state for an empty library, a readable error message for a
malformed or DRM-protected EPUB instead of a crash, and a final pass
confirming every screen stays portrait. List every file you'll touch,
then stop for my approval.
```
