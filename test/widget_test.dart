import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gemma_san/main.dart';

void main() {
  testWidgets('Scaffold smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: GemmaSanApp()));
    expect(find.text('Gemma-San — scaffold ready'), findsOneWidget);
  });
}
