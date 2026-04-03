import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paw_party/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('PawPartyApp shows after session restore', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(
        child: PawPartyApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(PawPartyApp), findsOneWidget);
  });
}
