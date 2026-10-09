import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/main.dart';

void main() {
  testWidgets('Orbit app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: OrbitApp()));
    expect(find.text('Orbit'), findsOneWidget);
    expect(find.text('Ações Rápidas'), findsOneWidget);
  });
}
