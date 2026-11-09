import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitchlab_lite/main.dart';

void main() {
  testWidgets('shows the PitchLab-style tuner start state', (tester) async {
    await tester.pumpWidget(const PitchLabApp());

    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(find.text('Tap the microphone to start'), findsOneWidget);
  });
}
