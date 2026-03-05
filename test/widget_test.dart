import 'package:flutter_test/flutter_test.dart';
import 'package:schtroumpf_tdha/main.dart';

void main() {
  testWidgets('App launches without error', (WidgetTester tester) async {
    await tester.pumpWidget(const SchtroumpfApp());
    expect(find.text('Schtroumpf Quest'), findsOneWidget);
  });
}
