import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('Crypto Asset Manager App smoke test', (WidgetTester tester) async {
    // Build our app with ProviderScope
    await tester.pumpWidget(
      const ProviderScope(
        child: CryptoAssetManagerApp(),
      ),
    );

    await tester.pump();

    // Verify app builds without crashing and shows title
    expect(find.text('Asset Manager'), findsOneWidget);
  });
}
