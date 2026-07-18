import 'package:flutter_test/flutter_test.dart';

import 'package:tfc_multicanal_app/main.dart';

void main() {
  testWidgets('L\'ecran d\'accueil affiche le titre et le champ IP',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TfcApp());

    expect(find.text('TFC Multicanal - Goma'), findsOneWidget);
    expect(find.text('Acces bailleur / administrateur'), findsOneWidget);
  });
}
