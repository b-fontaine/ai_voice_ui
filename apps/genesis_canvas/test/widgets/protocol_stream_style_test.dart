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
import 'package:shared_design_system/shared_design_system.dart';

/// Flux A2UI en liste mono (`gc-stream`, FR-05, T33) : en-tête de panneau,
/// numéro `#nn` et genre du message en `signal`, une ligne par entrée avec
/// ellipse, masque de dégradé quand des entrées plus anciennes sont écartées.
/// Les rectangles de 018 ne changent pas.
class _Clock implements AppClock {
  int now = 1761800000000;

  @override
  int nowUnixMs() => now += 1000;
}

ValidatedEnvelope _accepted(String operation, String surface) =>
    ValidatedEnvelope(
      raw: <String, Object?>{
        'version': 'v0.9',
        operation: <String, Object?>{'surfaceId': surface},
      },
      verdict: const ValidationAccepted(),
      agent: 'Qualité',
    );

void main() {
  const SceneTheme theme = SceneTheme.dark();
  late ProtocolFeedBloc bloc;
  late StreamController<ValidatedEnvelope> envelopes;

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

  Future<void> receive(WidgetTester tester, ValidatedEnvelope e) async {
    envelopes.add(e);
    await tester.pump();
    await tester.pump();
  }

  Future<void> expand(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('protocol-toggle')));
    await tester.pump();
    await tester.pump();
  }

  Finder key(String name) => find.byKey(Key(name));

  Text text(WidgetTester tester, String name) => tester.widget<Text>(key(name));

  testWidgets('l\'en-tête est un DsPanelHead « FLUX A2UI · live » avec le '
      'bouton à droite', (tester) async {
    await pumpPanel(tester);
    await receive(tester, _accepted('createSurface', 'kpi'));

    final Finder head = find.descendant(
      of: key('protocol-panel'),
      matching: find.byType(DsPanelHead),
    );
    expect(head, findsOneWidget);
    expect(
      find.descendant(of: head, matching: find.text('FLUX A2UI · LIVE')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: head, matching: key('protocol-toggle')),
      findsOneWidget,
    );
  });

  testWidgets('chaque entrée a son numéro « #nn » en mono ink-muted et son '
      'genre en signal, sur une ligne avec ellipse', (tester) async {
    await pumpPanel(tester);
    await receive(tester, _accepted('createSurface', 'kpi'));
    await receive(tester, _accepted('updateComponents', 'kpi'));
    await expand(tester);

    for (final (int n, String no) in <(int, String)>[(0, '#00'), (1, '#01')]) {
      final Text number = text(tester, 'protocol-entry-$n-no');
      expect(number.data, no);
      expect(number.style!.color, theme.textSecondary, reason: 'F12');
      expect(number.style!.fontFamily, theme.micro.agentState.fontFamily);
      expect(number.style!.fontSize, theme.micro.agentState.fontSize);
      expect(number.maxLines, 1);
      final Text kind = text(tester, 'protocol-entry-$n-kind');
      expect(kind.textSpan!.style?.color ?? kind.style!.color, theme.accent);
      expect(kind.style!.fontFamily, theme.micro.agentState.fontFamily);
      expect(kind.maxLines, 1);
      expect(kind.overflow, TextOverflow.ellipsis);
    }
    expect(
      text(tester, 'protocol-entry-0-kind').textSpan!.toPlainText(),
      'createSurface · kpi',
    );
    expect(
      text(tester, 'protocol-entry-1-kind').textSpan!.toPlainText(),
      'updateComponents · kpi',
    );
  });

  testWidgets('masque de dégradé en haut quand des entrées plus anciennes '
      'sont écartées, pas avant', (tester) async {
    await pumpPanel(tester);
    await receive(tester, _accepted('createSurface', 's0'));
    await expand(tester);
    expect(
      find.descendant(
        of: key('protocol-panel'),
        matching: find.byType(ShaderMask),
      ),
      findsNothing,
      reason: 'tout tient : rien à estomper',
    );

    for (var i = 1; i <= ProtocolPanel.visibleEntries + 2; i++) {
      await receive(tester, _accepted('updateComponents', 's$i'));
    }

    expect(
      find.descendant(
        of: key('protocol-panel'),
        matching: find.byType(ShaderMask),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (Widget w) =>
            w.key is ValueKey<String> &&
            RegExp(r'^protocol-entry-\d+$')
                .hasMatch((w.key! as ValueKey<String>).value),
      ),
      findsNWidgets(ProtocolPanel.visibleEntries),
      reason: 'le nombre d\'entrées montrées ne change pas',
    );
  });

  testWidgets('les rectangles de 018 et l\'absence de boucle sont inchangés', (
    tester,
  ) async {
    await pumpPanel(tester);
    await receive(tester, _accepted('createSurface', 'kpi'));

    expect(tester.getSize(key('protocol-panel')), ProtocolPanel.collapsedSize);
    await expand(tester);
    expect(tester.getSize(key('protocol-panel')), ProtocolPanel.expandedSize);
    expect(
      tester.getRect(key('protocol-panel')).bottomRight,
      const Offset(1920, 1080),
    );
    await tester.pump(const Duration(seconds: 1)); // fin de l'éclat du bouton
    expect(tester.binding.transientCallbackCount, 0);
  });
}
