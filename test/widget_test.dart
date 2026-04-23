import 'package:app_scan/src/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('onboarding is shown by default', (tester) async {
    await tester.pumpWidget(const PartnerScanApp());

    expect(find.text('Commencer'), findsOneWidget);
    expect(find.textContaining('Une expérience partenaire'), findsOneWidget);
  });
}
