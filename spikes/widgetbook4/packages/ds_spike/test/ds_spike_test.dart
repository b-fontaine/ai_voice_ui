import 'package:ds_spike/ds_spike.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('DsButton lit le thème material_ui et sa ThemeExtension', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DsTheme.light(),
        home: Scaffold(body: DsButton(label: 'Valider', onPressed: () {})),
      ),
    );
    expect(find.text('Valider'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });
}
