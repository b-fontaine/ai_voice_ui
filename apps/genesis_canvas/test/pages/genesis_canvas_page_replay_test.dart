import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage;
import 'package:entity_session/entity_session.dart' show A2uiJournal;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/pages/genesis_canvas/genesis_canvas.dart';
import 'package:shared_core/shared_core.dart' show ReplayedMessage;

import '../support/page_rig.dart';

/// Câblage du journal de rejeu dans la page (010, T09a) : la page enregistre
/// les messages A2UI qui entrent dans le gate, sans changer le rendu.
void main() {
  /// Journal de la page montée (membre `@visibleForTesting` de son `State`).
  A2uiJournal journalOf(WidgetTester tester) =>
      (tester.state(find.byType(GenesisCanvasPage)) as dynamic).journal
          as A2uiJournal;

  Future<void> playEnvelopes(WidgetTester tester, PageRig rig) async {
    for (final envelope in await act1Envelopes(tester)) {
      rig.receiveEnvelope(envelope);
      await tester.pump();
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('en direct, les messages A2UI sont enregistrés et rendus', (
    tester,
  ) async {
    final rig = PageRig(tester);
    await rig.mount(tester, themed: true);
    await rig.start(tester);
    expect(journalOf(tester).length, 0);

    await playEnvelopes(tester, rig);

    expect(journalOf(tester).length, 12);
    expect(journalOf(tester).hasCreateSurface, isTrue);
    expect(find.byKey(const Key('surface-kpi')), findsOneWidget);
    expect(find.byKey(const Key('surface-checklist')), findsOneWidget);
    expect(find.text('4 / 6 utilisés'), findsOneWidget);
    expect(rig.errors.toString(), isEmpty);
  });

  testWidgets('la remise à vide vide aussi le journal', (tester) async {
    final rig = PageRig(tester);
    await rig.mount(tester, themed: true);
    await rig.start(tester);
    await playEnvelopes(tester, rig);
    expect(journalOf(tester).length, 12);

    await tester.tap(find.byKey(const Key('reset-button')));
    await tester.pump();
    await tester.pump();

    expect(journalOf(tester).length, 0);
    expect(find.byKey(const Key('surface-kpi')), findsNothing);
  });

  testWidgets('en mode scénario, le journal enregistre aussi', (tester) async {
    final rig = PageRig(tester);
    final messages = StreamController<ReplayedMessage>();
    addTearDown(messages.close);
    await rig.mount(tester, replay: messages.stream, themed: true);

    for (final envelope in await act1Envelopes(tester)) {
      if (envelope['type'] != 'a2ui') continue;
      final raw = Map<String, Object?>.from(envelope['data']! as Map);
      messages.add((raw: raw, message: A2uiMessage.fromJson(raw)));
      await tester.pump();
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 50));

    expect(journalOf(tester).length, 12);
    expect(find.byKey(const Key('surface-kpi')), findsOneWidget);
    expect(rig.errors.toString(), isEmpty);
  });
}
