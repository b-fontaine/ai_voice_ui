import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData(extensions: const [SceneTheme.dark()]),
  home: Scaffold(body: Center(child: child)),
);

double _fontSizeOf(WidgetTester tester, Finder f) {
  final paragraph = tester.renderObject<RenderParagraph>(f);
  return paragraph.text.style!.fontSize!;
}

void main() {
  testWidgets('DsSkeleton se rend, statique, pumpAndSettle termine', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const DsSkeleton(key: Key('sk'))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('sk')), findsOneWidget);
  });

  testWidgets('DsSkeleton animé reste désactivable par TickerMode', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const TickerMode(enabled: false, child: DsSkeleton(animate: true))),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('DsNeutralState affiche le message et une icône', (tester) async {
    await tester.pumpWidget(_host(const DsNeutralState()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final text = find.text('Données indisponibles');
    expect(text, findsOneWidget);
    expect(find.byType(Icon), findsOneWidget);
    // pdr-0087 / pdr-0088 F1 : échelle du design system (11 px au plus bas), plus de plancher de 24 px.
    expect(_fontSizeOf(tester, text), greaterThanOrEqualTo(11));
  });
}
