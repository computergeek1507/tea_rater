import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tea_rater/main.dart';

void main() {
  testWidgets('App shows empty state with no teas', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TeaRaterApp());
    await tester.pumpAndSettle();
    expect(find.text('No teas yet'), findsOneWidget);
    expect(find.text('Add tea'), findsOneWidget);
  });
}
