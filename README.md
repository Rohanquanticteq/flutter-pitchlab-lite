# PitchLab Lite

A Flutter mobile application for real-time monophonic pitch detection. The current milestone focuses on the core microphone-to-pitch pipeline; the PitchLab-style scrolling visualization will be added later.

## Current feature: real-time microphone pitch detection

The app can now:

- request microphone permission on Android and iOS;
- start and stop microphone listening from the UI;
- stream actual PCM16 microphone samples (no mock/random pitch values);
- analyze audio continuously on a background isolate;
- estimate fundamental frequency with a YIN-style detector;
- convert frequency into note name, octave, and cents deviation;
- reject silence and low-confidence/noisy frames;
- release microphone, stream subscriptions, worker isolate, and recorder resources on stop/dispose;
- operate fully offline.

## Architecture

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
```

### Data flow

```text
Device microphone
      ↓
record package (PCM16 mono, 44.1 kHz)
      ↓
Fixed 2048-sample frame assembler
      ↓
Background Dart isolate
      ↓
YIN pitch detector
      ↓
frequency + confidence + RMS
      ↓
PitchReading
(frequency → note → octave → cents)
      ↓
PitchDetectorController
      ↓
Simple Flutter diagnostic UI
```

Raw microphone samples are analyzed in memory and are not persisted to disk.

## Dependency choice

The project uses:

```yaml
record: ^6.2.1
```

The project currently targets Dart `^3.11.1`. `record` 6.2.1 supports PCM16 microphone streaming on Android and iOS and remains compatible with that SDK range. The package is BSD-3-Clause licensed.

The package is used only for microphone capture and platform permission handling. Pitch detection itself is implemented inside this project so the DSP can be tuned and extended later.

## Audio configuration

Current capture settings:

- PCM signed 16-bit;
- mono;
- requested sample rate: 44,100 Hz;
- frame size: 2,048 samples (~46 ms at 44.1 kHz);
- automatic gain control disabled;
- echo cancellation disabled;
- noise suppression disabled.

Disabling voice-processing effects helps preserve the periodic waveform structure needed for pitch analysis.

## Pitch detection

The detector uses a YIN-style periodicity analysis:

1. remove DC offset by centering the frame around its mean;
2. calculate RMS and reject very quiet frames;
3. calculate the YIN difference function over plausible periods;
4. calculate cumulative mean normalized difference (CMND);
5. locate a strong periodic minimum;
6. refine the period using parabolic interpolation;
7. convert period to frequency with `frequency = sampleRate / period`;
8. reject low-confidence or out-of-range results.

The initial search range is approximately **65 Hz to 1200 Hz**, covering typical singing voice and many monophonic instruments.

## Frequency to note conversion

The current reference is equal temperament with **A4 = 440 Hz**.

```text
fractionalMidi = 69 + 12 × log2(frequency / 440)
nearestMidi    = round(fractionalMidi)
cents          = (fractionalMidi - nearestMidi) × 100
```

The nearest note is mapped to:

`C C# D D# E F F# G G# A A# B`

and the octave is derived from the MIDI-equivalent note number.

Examples:

- 440.00 Hz → A4, ~0 cents
- 261.63 Hz → C4, ~0 cents
- slightly above 440 Hz → A4 with positive cents

## Silence and noise handling

A frame produces no pitch when:

- RMS is below the silence threshold;
- periodicity is too weak;
- confidence is below the configured threshold;
- frequency is outside the supported range.

The UI then shows **Listening — no clear pitch detected** instead of inventing a note.

## Concurrency and latency

PCM bytes are assembled into fixed 2,048-sample frames and transferred to a persistent background isolate with `TransferableTypedData`. The YIN loops therefore do not run on Flutter's UI isolate.

A 2,048-sample frame at 44.1 kHz represents roughly 46 ms of audio, giving a practical starting point for responsive voice pitch tracking. Real-device profiling will determine whether overlap, adaptive frames, or native DSP are needed later.

## Permissions

### Android

`android/app/src/main/AndroidManifest.xml` declares `android.permission.RECORD_AUDIO`. The Android minimum SDK is set to API 23 to satisfy the microphone package requirements.

### iOS

`ios/Runner/Info.plist` contains `NSMicrophoneUsageDescription` explaining why microphone access is required.

## Running

Use a physical Android device or iPhone for meaningful microphone testing.

```bash
flutter pub get
flutter run
```

Tap **Start listening**, grant microphone permission, and sing or play one clear sustained note.

The temporary diagnostic UI displays:

- detected note and octave;
- frequency in Hz;
- cents deviation;
- confidence;
- listening/no-pitch/error state.

Tap **Stop listening** to release the microphone.

## Validation

The repository includes GitHub Actions validation. It runs:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

and an iOS simulator build on macOS:

```bash
flutter build ios --simulator --no-codesign
```

Unit tests cover note conversion, synthetic 440 Hz and 110 Hz tones, silence rejection, and the initial screen state.

## Scope of this milestone

This is intentionally not the final PitchLab visualization. The current screen is only a diagnostic interface for proving the pitch engine.

Not included yet:

- scrolling pitch-history graph;
- calibration UI;
- graph smoothing/history;
- instrument presets;
- polyphonic/chord detection;
- session recording or saved audio.

The next milestone should build the scrolling pitch visualization on top of the `PitchReading` stream after real-device accuracy and latency testing.
