import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mofumofu_license/main.dart';

void main() {
  testWidgets('App starts and shows home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MofumofuApp()));
    await tester.pumpAndSettle();

    expect(find.text('うちの子免許証'), findsAny);
    expect(find.text('免許証をつくる'), findsOneWidget);
  });
}
