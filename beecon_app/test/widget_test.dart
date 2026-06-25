import 'package:flutter_test/flutter_test.dart';
import 'package:beecon_app/main.dart';

void main() {
  testWidgets('BeeconApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BeeconApp());
  });
}
