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
    expect(_fontSizeOf(tester, text), greaterThanOrEqualTo(24));
  });

  testWidgets('DsStatusChip affiche le libellé tel quel', (tester) async {
    await tester.pumpWidget(
      _host(
        const DsStatusChip(
          status: SceneStatus.risk,
          label: 'À risque (libellé du backend)',
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final text = find.text('À risque (libellé du backend)');
    expect(text, findsOneWidget);
    expect(_fontSizeOf(tester, text), greaterThanOrEqualTo(24));
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(DsStatusChip),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(
      (box.decoration as BoxDecoration).color,
      const SceneTheme.dark().riskBackground,
    );
  });

  testWidgets('DsStatusChip sans statut utilise le style neutre', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const DsStatusChip(status: null, label: 'x')),
    );
    expect(tester.takeException(), isNull);
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(DsStatusChip),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(
      (box.decoration as BoxDecoration).color,
      const SceneTheme.dark().neutralBackground,
    );
  });

  testWidgets('DsStatusChip.verticalPadding est le remplissage vertical réel', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const DsStatusChip(key: Key('chip'), status: null, label: 'Go')),
    );
    expect(
      tester.getSize(find.byKey(const Key('chip'))).height -
          tester.getSize(find.text('Go')).height,
      2 * DsStatusChip.verticalPadding,
    );
  });
}
