import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:entity_catalog/entity_catalog.dart';
import 'package:feature_protocol_feed/feature_protocol_feed.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:testing_bloc_harness/testing_bloc_harness.dart';

class FakeClock implements AppClock {
  int now = 1000;

  @override
  int nowUnixMs() => now++;
}

Directory _examplesDir() {
  Directory d = Directory.current;
  while (!Directory('${d.path}/contracts/a2ui/genesis/v1/examples')
      .existsSync()) {
    d = d.parent;
  }
  return Directory('${d.path}/contracts/a2ui/genesis/v1/examples');
}

/// Messages réels de la fixture [name] (`kpi`, `trend`…), catalogue substitué.
List<Map<String, Object?>> fixture(String name) => <Map<String, Object?>>[
  for (final String l in const LineSplitter().convert(
    File('${_examplesDir().path}/act1-$name.jsonl')
        .readAsStringSync()
        .replaceAll(r'${CATALOG_ID}', GenesisContract.defaultCatalogId),
  ))
    if (l.trim().isNotEmpty) Map<String, Object?>.from(jsonDecode(l) as Map),
];

ValidatedEnvelope accepted(
  Map<String, Object?> raw, {
  String agent = 'release',
  String task = 't1',
}) => ValidatedEnvelope(
  raw: raw,
  verdict: const ValidationAccepted(),
  agent: agent,
  task: task,
);

Future<List<ProtocolFeedState>> run(
  List<ValidatedEnvelope> envelopes, {
  int maxJsonChars = 2000,
  int retention = 200,
  FutureOr<void> Function(ProtocolFeedBloc bloc)? after,
}) async {
  final StreamController<ValidatedEnvelope> controller =
      StreamController<ValidatedEnvelope>();
  return statesAfter(
    ProtocolFeedBloc(
      clock: FakeClock(),
      maxJsonChars: maxJsonChars,
      retention: retention,
    ),
    (bloc) async {
      bloc.add(ProtocolSourceSubscribed(controller.stream));
      await Future<void>.delayed(Duration.zero);
      envelopes.forEach(controller.add);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      if (after != null) await after(bloc);
    },
  );
}

void main() {
  test('état initial : replié, vide', () {
    final ProtocolFeedState s = ProtocolFeedBloc(clock: FakeClock()).state;
    expect(s.entries, isEmpty);
    expect(s.expanded, isFalse);
    expect(s.highlightedIndex, isNull);
    expect(s.highlightedSurfaceId, isNull);
    expect(s.totalCount, 0);
  });

  test(
    'séquence réelle de l acte 1 : opérations, surface, index, horloge',
    () async {
      final states = await run([for (final m in fixture('kpi')) accepted(m)]);
      final ProtocolFeedState s = states.last;
      expect(s.entries.map((e) => e.operation), [
        ProtocolOperation.createSurface,
        ProtocolOperation.updateComponents,
        ProtocolOperation.updateDataModel,
      ]);
      expect(s.entries.map((e) => e.index), [0, 1, 2]);
      expect(s.entries.map((e) => e.timestampMs), [1000, 1001, 1002]);
      expect(s.entries.every((e) => e.surfaceId == 'kpi'), isTrue);
      expect(s.entries.first.agent, 'release');
      expect(s.entries.first.task, 't1');
      expect(
        s.entries.every((e) => e.accepted && e.rejectionCode == null),
        isTrue,
      );
      expect(s.totalCount, 3);
      expect(s.expanded, isFalse);
    },
  );

  test('le dernier message est en évidence, avec sa surface', () async {
    final states = await run([
      for (final m in [...fixture('kpi'), ...fixture('trend').take(1)])
        accepted(m),
    ]);
    expect(states.last.highlightedIndex, 3);
    expect(states.last.highlightedSurfaceId, 'trend');
  });

  test('JSON brut mis en forme, identique au raw décodé, raw intact', () async {
    final Map<String, Object?> raw = fixture('kpi')[2];
    final states = await run([accepted(raw)]);
    final ProtocolEntry e = states.last.entries.single;
    expect(e.truncated, isFalse);
    expect(jsonDecode(e.json), raw);
    expect(e.json, contains('\n'));
    expect(raw['updateDataModel'], isNotNull);
  });

  test('JSON borné avec marque de troncature', () async {
    final states = await run([accepted(fixture('kpi')[2])], maxJsonChars: 50);
    final ProtocolEntry e = states.last.entries.single;
    expect(e.truncated, isTrue);
    expect(
      e.json.startsWith(
        const JsonEncoder.withIndent('  ')
            .convert(fixture('kpi')[2])
            .substring(0, 50),
      ),
      isTrue,
    );
    expect(e.json.length, lessThan(50 + 40));
    expect(e.json, endsWith(ProtocolEntry.truncationMark));
  });

  test('message refusé : ajouté, marqué refusé avec son code', () async {
    final states = await run([
      ValidatedEnvelope(
        raw: <String, Object?>{
          'version': 'v0.9',
          'updateComponents': <String, Object?>{'surfaceId': 'kpi'},
        },
        verdict: const ValidationRejected(ValidationCodes.componentNotAllowed),
        agent: 'release',
        task: 't1',
      ),
    ]);
    final ProtocolEntry e = states.last.entries.single;
    expect(e.accepted, isFalse);
    expect(e.rejectionCode, ValidationCodes.componentNotAllowed);
    expect(e.operation, ProtocolOperation.updateComponents);
    expect(e.surfaceId, 'kpi');
    expect(states.last.highlightedSurfaceId, 'kpi');
  });

  test(
    'message refusé sans surface lisible : pas de surface en évidence',
    () async {
      final states = await run([
        ValidatedEnvelope(
          raw: <String, Object?>{'version': 'v0.9', 'bogus': 1},
          verdict: const ValidationRejected(ValidationCodes.badOperation),
        ),
      ]);
      final ProtocolEntry e = states.last.entries.single;
      expect(e.operation, ProtocolOperation.unknown);
      expect(e.surfaceId, isNull);
      expect(states.last.highlightedIndex, 0);
      expect(states.last.highlightedSurfaceId, isNull);
    },
  );

  test('ignored n ajoute aucune entrée (A2d)', () async {
    final states = await run([
      ValidatedEnvelope(
        raw: <String, Object?>{
          'version': 'v0.9',
          'deleteSurface': <String, Object?>{'surfaceId': 'ghost'},
        },
        verdict: const ValidationIgnored(),
      ),
    ]);
    expect(states, isEmpty);
  });

  test('deleteSurface accepté est ajouté', () async {
    final states = await run([
      accepted(<String, Object?>{
        'version': 'v0.9',
        'deleteSurface': <String, Object?>{'surfaceId': 'kpi'},
      }),
    ]);
    final ProtocolEntry e = states.last.entries.single;
    expect(e.operation, ProtocolOperation.deleteSurface);
    expect(e.surfaceId, 'kpi');
  });

  test(
    'éviction : les plus anciennes sortent, le compteur total reste',
    () async {
      final List<Map<String, Object?>> msgs = fixture('kpi');
      final states = await run([
        for (final m in [...msgs, ...msgs]) accepted(m),
      ], retention: 4);
      final ProtocolFeedState s = states.last;
      expect(s.entries.length, 4);
      expect(s.entries.map((e) => e.index), [2, 3, 4, 5]);
      expect(s.totalCount, 6);
      expect(s.highlightedIndex, 5);
    },
  );

  test('PanelToggled déplie puis replie', () async {
    final states = await run(
      const [],
      after: (bloc) async {
        bloc.add(const PanelToggled());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const PanelToggled());
        await Future<void>.delayed(Duration.zero);
      },
    );
    expect(states.map((s) => s.expanded), [true, false]);
  });

  test(
    'MessageHighlighted change la mise en évidence ; null l efface',
    () async {
      final states = await run(
        [for (final m in fixture('kpi')) accepted(m)],
        after: (bloc) async {
          bloc.add(const MessageHighlighted(0));
          await Future<void>.delayed(Duration.zero);
          bloc.add(const MessageHighlighted(null));
          await Future<void>.delayed(Duration.zero);
        },
      );
      expect(states[states.length - 2].highlightedIndex, 0);
      expect(states[states.length - 2].highlightedSurfaceId, 'kpi');
      expect(states.last.highlightedIndex, isNull);
      expect(states.last.highlightedSurfaceId, isNull);
    },
  );

  test('ProtocolFeedCleared remet l état initial (replié, vide)', () async {
    final states = await run(
      [for (final m in fixture('kpi')) accepted(m)],
      after: (bloc) async {
        bloc.add(const PanelToggled());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ProtocolFeedCleared());
        await Future<void>.delayed(Duration.zero);
      },
    );
    expect(states.last, const ProtocolFeedState.empty());
    expect(states.last.expanded, isFalse);
  });

  test('une erreur du flux est ignorée, le suivi continue', () async {
    final StreamController<ValidatedEnvelope> c =
        StreamController<ValidatedEnvelope>();
    final states = await statesAfter(ProtocolFeedBloc(clock: FakeClock()), (
      bloc,
    ) async {
      bloc.add(ProtocolSourceSubscribed(c.stream));
      await Future<void>.delayed(Duration.zero);
      c.addError(StateError('boom'));
      c.add(accepted(fixture('kpi').first));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    });
    expect(states.last.entries.length, 1);
  });

  test(
    'une nouvelle source remplace la précédente ; fermeture sans fuite',
    () async {
      final StreamController<ValidatedEnvelope> a =
          StreamController<ValidatedEnvelope>();
      final StreamController<ValidatedEnvelope> b =
          StreamController<ValidatedEnvelope>();
      await statesAfter(ProtocolFeedBloc(clock: FakeClock()), (bloc) async {
        bloc.add(ProtocolSourceSubscribed(a.stream));
        await Future<void>.delayed(Duration.zero);
        expect(a.hasListener, isTrue);
        bloc.add(ProtocolSourceSubscribed(b.stream));
        await Future<void>.delayed(Duration.zero);
        expect(a.hasListener, isFalse);
        expect(b.hasListener, isTrue);
      });
      expect(b.hasListener, isFalse);
    },
  );
}
