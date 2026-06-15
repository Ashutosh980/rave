import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rave_app/app.dart';

void main() {
  testWidgets('App loads home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: RaveApp(),
      ),
    );

    expect(find.text('Watch together'), findsOneWidget);
    expect(find.text('Create Room'), findsOneWidget);
  });
}
