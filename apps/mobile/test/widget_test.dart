import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets('App should render', (WidgetTester tester) async {
    await tester.pumpWidget(const CommerceApp());
    await tester.pumpAndSettle();

    expect(find.text('短视频流'), findsOneWidget);
  });
}
