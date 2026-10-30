import 'dart:async';

import 'package:entity_catalog/entity_catalog.dart';
import 'package:feature_protocol_feed/feature_protocol_feed.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart' hide testWidgets;
import 'package:flutter_test/flutter_test.dart'
    as flutter_test
    show testWidgets;
import 'package:genesis_canvas/widgets/protocol_panel/protocol_panel.dart';
import 'package:shared_core/shared_core.dart';

class _Clock implements AppClock {
  int now = 1761800000000;

  @override
  int nowUnixMs() => now += 1000;
}

Map<String, Object?> _message(String operation, String surface) =>
    <String, Object?>{
      'version': 'v0.9',
      operation: <String, Object?>{'surfaceId': surface},
    };

ValidatedEnvelope _accepted(String operation, String surface) =>
    ValidatedEnvelope(
      raw: _message(operation, surface),
      verdict: const ValidationAccepted(),
      agent: 'Qualité',
    );

void main() {
  late ProtocolFeedBloc bloc;
  late StreamController<ValidatedEnvelope> envelopes;

  // Bloc et flux créés dans la zone du test (FakeAsync), sinon `pump` ne vide
  // pas leurs microtâches.
  void testWidgets(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) => flutter_test.testWidgets(description, (tester) async {
    bloc = ProtocolFeedBloc(clock: _Clock());
    envelopes = StreamController<ValidatedEnvelope>.broadcast();
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    unawaited(envelopes.close());
    unawaited(bloc.close());
    await tester.pump();
  });

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.bottomRight,
          child: BlocProvider<ProtocolFeedBloc>.value(
            value: bloc,
            child: const ProtocolPanel(),
          ),
        ),
      ),
    );
    bloc.add(ProtocolSourceSubscribed(envelopes.stream));
    await tester.pump();
  }

  Future<void> receive(WidgetTester tester, ValidatedEnvelope envelope) async {
    envelopes.add(envelope);
    await tester.pump();
    await tester.pump();
  }

  Future<void> toggle(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('protocol-toggle')));
    await tester.pump();
    await tester.pump();
  }

  Finder entry(int n) => find.byKey(Key('protocol-entry-$n'));

  testWidgets('replié par défaut : titre, bouton, aucune entrée même reçue', (
    tester,
  ) async {
    await pumpPanel(tester);
    await receive(tester, _accepted('createSurface', 'kpi'));

    expect(find.byKey(const Key('protocol-panel')), findsOneWidget);
    expect(find.text('FLUX A2UI · live'), findsOneWidget);
    expect(find.byKey(const Key('protocol-toggle')), findsOneWidget);
    expect(entry(0), findsNothing);
    expect(find.byKey(const Key('protocol-current')), findsNothing);
    // Replié, le panneau dit combien de messages il retient.
    expect(find.text('1 message'), findsOneWidget);
  });

  testWidgets('le bouton déplie puis replie le panneau', (tester) async {
    await pumpPanel(tester);
    await receive(tester, _accepted('createSurface', 'kpi'));

    final Size collapsed = tester.getSize(
      find.byKey(const Key('protocol-panel')),
    );
    await toggle(tester);
    expect(bloc.state.expanded, isTrue);
    expect(entry(0), findsOneWidget);
    // Déplié, le panneau grandit (il recouvre le canevas à sa gauche).
    expect(
      tester.getSize(find.byKey(const Key('protocol-panel'))).height,
      greaterThan(collapsed.height),
    );

    await toggle(tester);
    expect(bloc.state.expanded, isFalse);
    expect(entry(0), findsNothing);
    expect(tester.getSize(find.byKey(const Key('protocol-panel'))), collapsed);
  });

  testWidgets('déplié et vide : message d\'attente, aucune entrée', (
    tester,
  ) async {
    await pumpPanel(tester);
    await toggle(tester);

    expect(entry(0), findsNothing);
    expect(find.byKey(const Key('protocol-current')), findsNothing);
    expect(find.text('Aucun message pour l\'instant'), findsOneWidget);
  });

  testWidgets('une entrée affiche agent, opération et surface ; la dernière '
      'est en cours, une seule', (tester) async {
    await pumpPanel(tester);
    await toggle(tester);
    await receive(tester, _accepted('createSurface', 'kpi'));
    await receive(tester, _accepted('updateComponents', 'kpi'));
    await receive(tester, _accepted('updateDataModel', 'trend'));

    expect(entry(0), findsOneWidget);
    expect(entry(1), findsOneWidget);
    expect(entry(2), findsOneWidget);
    final Finder current = find.byKey(const Key('protocol-current'));
    expect(current, findsOneWidget);
    expect(
      find.descendant(
        of: current,
        matching: find.textContaining('updateDataModel'),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(of: current, matching: find.textContaining('trend')),
      findsWidgets,
    );
    // L'entrée en cours est l'entrée 2, pas les précédentes.
    expect(find.descendant(of: entry(2), matching: current), findsOneWidget);
    expect(find.descendant(of: entry(0), matching: current), findsNothing);
    expect(find.text('refusé'), findsNothing);
    expect(
      find.descendant(of: entry(0), matching: find.textContaining('Qualité')),
      findsWidgets,
    );
  });

  testWidgets('un message refusé est marqué « refusé » avec son code fermé', (
    tester,
  ) async {
    await pumpPanel(tester);
    await toggle(tester);
    await receive(
      tester,
      ValidatedEnvelope(
        raw: _message('updateComponents', 'kpi'),
        verdict: const ValidationRejected(ValidationCodes.componentNotAllowed),
      ),
    );

    expect(
      find.descendant(of: entry(0), matching: find.text('refusé')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: entry(0),
        matching: find.text(ValidationCodes.componentNotAllowed),
      ),
      findsOneWidget,
    );
  });

  testWidgets('le JSON est du texte brut borné, jamais du Markdown', (
    tester,
  ) async {
    await pumpPanel(tester);
    await toggle(tester);
    await receive(
      tester,
      ValidatedEnvelope(
        raw: <String, Object?>{
          'version': 'v0.9',
          'updateComponents': <String, Object?>{
            'surfaceId': 'kpi',
            'note': '**gras** [lien](http://exemple.test) <b>x</b>',
          },
        },
        verdict: const ValidationRejected(ValidationCodes.badProperty),
      ),
    );

    final Finder json = find.byKey(const Key('protocol-json-0'));
    expect(json, findsOneWidget);
    final Text text = tester.widget<Text>(json);
    expect(text.data, contains('**gras** [lien](http://exemple.test)'));
    expect(text.textSpan, isNull, reason: 'pas de rendu enrichi');
    expect(text.maxLines, isNotNull);
    expect(text.overflow, TextOverflow.ellipsis);
    // Aucun widget de rendu enrichi dans l'entrée.
    expect(
      find.descendant(of: entry(0), matching: find.byType(RichText)),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: entry(0),
        matching: find.byWidgetPredicate(
          (w) => w.runtimeType.toString().toLowerCase().contains('markdown'),
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('seules les dernières entrées sont montrées, le numéro reste '
      'celui du Bloc', (tester) async {
    await pumpPanel(tester);
    await toggle(tester);
    for (var i = 0; i < 9; i++) {
      await receive(tester, _accepted('updateDataModel', 's$i'));
    }

    expect(entry(8), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('protocol-current')),
        matching: find.textContaining('s8'),
      ),
      findsWidgets,
    );
    expect(entry(0), findsNothing);
  });

  testWidgets('la remise à vide vide le panneau et le replie', (tester) async {
    await pumpPanel(tester);
    await toggle(tester);
    await receive(tester, _accepted('createSurface', 'kpi'));
    expect(entry(0), findsOneWidget);

    bloc.add(const ProtocolFeedCleared());
    await tester.pump();
    await tester.pump();

    expect(entry(0), findsNothing);
    expect(find.byKey(const Key('protocol-panel')), findsOneWidget);
    expect(find.byKey(const Key('protocol-current')), findsNothing);
    // État initial : replié.
    expect(bloc.state.expanded, isFalse);
    expect(find.text('0 messages'), findsOneWidget);
  });
}
