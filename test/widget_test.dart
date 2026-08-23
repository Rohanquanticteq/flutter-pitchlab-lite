import 'package:flutter_test/flutter_test.dart';
import 'package:pitchlab_lite/main.dart';

void main() {
  testWidgets('shows the pitch detector start state', (tester) async {
    await tester.pumpWidget(const PitchLabApp());

    expect(find.text('Pitch Detector'), findsOneWidget);
    expect(find.text('Start listening'), findsOneWidget);
    expect(find.text('--'), findsOneWidget);
  });
}
