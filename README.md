# PitchLab Lite

A Flutter mobile tuner inspired by the PitchLab Lite scrolling pitch display.

The project now has two working layers:

1. real-time monophonic pitch detection from the device microphone;
2. a PitchLab-style scrolling chromatic pitch-history visualization.

## Current functionality

- requests microphone permission on Android and iOS;
- starts/stops real microphone capture;
- streams PCM16 mono audio at a requested 44.1 kHz;
- analyzes frames on a persistent background isolate;
- estimates the fundamental frequency with a project-owned YIN-style detector;
- converts frequency into chromatic pitch class, cents, confidence, and scientific octave;
- uses octave-independent primary pitch labels (`D#`, not `D#2` / `D#3`);
- renders a full-screen 12-note chromatic history view;
- scrolls recent pitch from right to left over an 8-second window;
- shows continuous pitch movement between note centers for vibrato, bends, and slides;
- creates gaps during silence/no-pitch states;
- keeps history and DSP queues bounded to prevent memory/latency growth;
- operates fully offline.

## Architecture

```text
Device microphone
      ↓
record package (PCM16 mono)
      ↓
2048-sample frame assembler
      ↓
PitchAnalysisWorker (background isolate)
      ↓
YIN pitch detector
      ↓
frequency + confidence + RMS
      ↓
PitchReading
      ├─ noteName (C..B)
      ├─ cents
      ├─ octave (internal)
      └─ pitchClassPosition [0, 12)
      ↓
PitchDetectorController
      ↓
PitchHistoryBuffer (bounded rolling history)
      ↓
PitchHistoryPainter (CustomPainter)
      ↓
PitchLab-style scrolling tuner screen
```

### Folder structure

```text
lib/
  main.dart
  features/
    pitch_detection/
      application/
        pitch_detector_controller.dart
      data/
        microphone_pitch_service.dart
        pitch_analysis_worker.dart
        yin_pitch_detector.dart
      domain/
        pitch_reading.dart
      presentation/
        pitch_detector_screen.dart
        pitch_history_buffer.dart
        pitch_history_painter.dart
```

## PitchLab-style display behavior

The visualizer intentionally folds all octaves into one chromatic scale:

```text
C  C#  D  D#  E  F  F#  G  G#  A  A#  B
```

Examples:

- `D#2` → displayed on the `D#` row;
- `D#3` → displayed on the same `D#` row;
- `D#4` → displayed on the same `D#` row.

The raw frequency and octave are still kept internally. The graph uses `PitchReading.pitchClassPosition`, a continuous octave-independent coordinate where C = 0, C# = 1, ... B = 11. Fractional positions represent pitch between note centers, so vibrato and bends appear as continuous movement instead of discrete note jumps.

## Scrolling visualization

The current screen uses Flutter `CustomPainter` rather than a chart package.

- black full-screen background;
- 12 horizontal note guide lines;
- note labels on the left;
- recent pitch history retained for about 8 seconds;
- newest pitch appears at the right edge;
- older pitch moves left as time advances;
- trace color varies by pitch class;
- confidence influences trace strength;
- silence/no-pitch inserts a break rather than connecting unrelated notes;
- history is capped at 512 points and old points are trimmed continuously.

The renderer calculates horizontal position from sample age. It does not physically shift UI widgets or append an unlimited number of objects, keeping long-running rendering bounded.

## Pitch detection

The detector uses a YIN-style periodicity pipeline:

1. remove DC offset;
2. calculate RMS and reject very quiet frames;
3. calculate the difference function over plausible periods;
4. calculate cumulative mean normalized difference;
5. select a reliable periodic minimum;
6. refine the period with parabolic interpolation;
7. calculate `frequency = sampleRate / period`;
8. reject low-confidence/out-of-range results.

Current approximate detection range: **65 Hz–1200 Hz**.

## Frequency to musical pitch

Reference tuning is currently **A4 = 440 Hz**.

```text
fractionalMidi = 69 + 12 × log2(frequency / 440)
nearestMidi    = round(fractionalMidi)
cents          = (fractionalMidi - nearestMidi) × 100
pitchClass     = nearestMidi mod 12
```

The primary displayed note omits octave by design, matching the chromatic PitchLab view.

## Dependency

```yaml
record: ^6.2.1
```

`record` is used for microphone streaming and platform permission handling. Pitch analysis and the visualization are implemented inside this project.

## Permissions

### Android

`android/app/src/main/AndroidManifest.xml` declares:

```text
android.permission.RECORD_AUDIO
```

### iOS

`ios/Runner/Info.plist` contains `NSMicrophoneUsageDescription`.

## Running

Use a physical Android or iOS device for real microphone testing:

```bash
flutter pub get
flutter run
```

Tap the microphone icon to start listening. The graph will begin drawing when a reliable pitched sound is detected. Tap the stop icon to release the microphone.

## Validation

GitHub Actions runs:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

and on macOS:

```bash
flutter build ios --simulator --no-codesign
```

Tests cover pitch conversion, octave-independent note behavior, synthetic pitch detection, silence rejection, bounded history, gap handling, and the tuner screen start state.

## Next refinements

The visualization is now functionally in place. Remaining refinement work should be driven by physical-device testing, especially:

- exact scroll speed/history duration;
- trace density/glow appearance;
- real-device pitch stability and octave-error correction;
- confidence-to-intensity mapping;
- optional auto-start behavior;
- calibration/reference pitch settings.
