import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_neo_mobile/main.dart';

void main() {
  testWidgets('JARVIS NEO Mobile boots', (tester) async {
    await tester.pumpWidget(const JarvisApp());
    expect(find.text('J.A.R.V.I.S. NEO'), findsOneWidget);
  });
}
