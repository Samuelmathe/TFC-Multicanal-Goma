import 'package:flutter_test/flutter_test.dart';

import 'package:tfc_multicanal_app/main.dart';

void main() {
  testWidgets('L\'ecran de connexion affiche le titre et le formulaire',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TfcApp());

    expect(find.text('TFC Multicanal'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });
}
