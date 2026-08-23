import 'package:flutter/material.dart';
import 'package:pitchlab_lite/features/pitch_detection/presentation/pitch_detector_screen.dart';

void main() {
  runApp(const PitchLabApp());
}

class PitchLabApp extends StatelessWidget {
  const PitchLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PitchLab Lite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const PitchDetectorScreen(),
    );
  }
}
