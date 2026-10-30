import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:entity_catalog/entity_catalog.dart';
import 'package:feature_catalog_shelf/feature_catalog_shelf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testing_bloc_harness/testing_bloc_harness.dart';

Directory _examplesDir() {
  Directory d = Directory.current;
  while (!Directory('${d.path}/contracts/a2ui/genesis/v1/examples')
      .existsSync()) {
    d = d.parent;
  }
  return Directory('${d.path}/contracts/a2ui/genesis/v1/examples');
}

List<Map<String, Object?>> fixture(String name) => <Map<String, Object?>>[
  for (final String l in const LineSplitter().convert(
    File('${_examplesDir().path}/act1-$name.jsonl')
        .readAsStringSync()
        .replaceAll(r'${CATALOG_ID}', GenesisContract.defaultCatalogId),
  ))
    if (l.trim().isNotEmpty) Map<String, Object?>.from(jsonDecode(l) as Map),
];

ValidatedEnvelope accepted(Map<String, Object?> raw) =>
    ValidatedEnvelope(raw: raw, verdict: const ValidationAccepted());

ValidatedEnvelope delete(String surface, {ValidationVerdict? verdict}) =>
    ValidatedEnvelope(
      raw: <String, Object?>{
        'version': 'v0.9',
        'deleteSurface': <String, Object?>{'surfaceId': surface},
      },
      verdict: verdict ?? const ValidationAccepted(),
    );

Future<List<CatalogShelfState>> run(
  List<ValidatedEnvelope> envelopes, {
  FutureOr<void> Function(CatalogShelfBloc bloc)? after,
}) async {
  final StreamController<ValidatedEnvelope> controller =
      StreamController<ValidatedEnvelope>();
  return statesAfter(CatalogShelfBloc(), (bloc) async {
    bloc.add(CatalogShelfSourceSubscribed(controller.stream));
    await Future<void>.delayed(Duration.zero);
    envelopes.forEach(controller.add);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    if (after != null) await after(bloc);
  });
}

Set<String> usedOf(CatalogShelfState s) => {
  for (final c in s.components)
    if (c.used) c.name,
};

void main() {
  test('état initial : les 6 composants du contrat, tous éteints', () {
    final CatalogShelfState s = CatalogShelfBloc().state;
    expect(s.components.map((c) => c.name), GenesisContract.catalogComponents);
    expect(s.components.every((c) => !c.used), isTrue);
    expect(s.usedCount, 0);
    expect(s.total, 6);
  });

  test('acte 1 : 4 utilisés, ActionBar et CrashList éteints', () async {
    final states = await run([
      for (final f in ['kpi', 'trend', 'reviews', 'checklist'])
        for (final m in fixture(f)) accepted(m),
    ]);
    final CatalogShelfState s = states.last;
    expect(usedOf(s), {
      'KeyIndicator',
      'TrendChart',
      'ReviewSentiment',
      'ReleaseChecklist',
    });
    expect(s.usedCount, 4);
    expect(s.total, 6);
    expect(s.components.map((c) => c.name), GenesisContract.catalogComponents);
  });

  test('un message refusé ou ignoré n allume rien', () async {
    final Map<String, Object?> raw = fixture('kpi')[1];
    final states = await run([
      ValidatedEnvelope(
        raw: raw,
        verdict: const ValidationRejected(ValidationCodes.badComponent),
      ),
      ValidatedEnvelope(raw: raw, verdict: const ValidationIgnored()),
    ]);
    expect(states, isEmpty);
  });

  test('un type inconnu du contrat est ignoré', () async {
    final states = await run([
      accepted(<String, Object?>{
        'version': 'v0.9',
        'updateComponents': <String, Object?>{
          'surfaceId': 'x',
          'components': [
            <String, Object?>{'id': 'root', 'component': 'Mystery'},
          ],
        },
      }),
    ]);
    expect(states, isEmpty);
  });

  test('deleteSurface accepté libère les composants de la surface', () async {
    final states = await run([
      for (final m in fixture('kpi')) accepted(m),
      delete('kpi'),
    ]);
    expect(usedOf(states[states.length - 2]), {'KeyIndicator'});
    expect(states.last.usedCount, 0);
  });

  test(
    'même type sur deux surfaces : utilisé tant qu une surface le porte',
    () async {
      Map<String, Object?> update(String surface) => <String, Object?>{
        'version': 'v0.9',
        'updateComponents': <String, Object?>{
          'surfaceId': surface,
          'components': [
            <String, Object?>{'id': 'root', 'component': 'KeyIndicator'},
          ],
        },
      };
      final states = await run([
        accepted(update('a')),
        accepted(update('b')),
        delete('a'),
        delete('b'),
      ]);
      expect(states.map((s) => s.usedCount), [1, 0]);
    },
  );

  test('deleteSurface refusé ou ignoré ne libère rien', () async {
    final states = await run([
      for (final m in fixture('kpi')) accepted(m),
      delete('kpi', verdict: const ValidationIgnored()),
      delete('kpi', verdict: const ValidationRejected('unknown_surface')),
    ]);
    expect(states.last.usedCount, 1);
  });

  test(
    'CatalogShelfCleared éteint tout, y compris la mémoire des surfaces',
    () async {
      final states = await run(
        [for (final m in fixture('kpi')) accepted(m)],
        after: (bloc) async {
          bloc.add(const CatalogShelfCleared());
          await Future<void>.delayed(Duration.zero);
          // Après remise à vide, un deleteSurface ne doit rien casser.
        },
      );
      expect(states.last, const CatalogShelfState.empty());
    },
  );

  test(
    'un refus avec compensation libère les composants de la surface',
    () async {
      final states = await run([
        for (final m in fixture('kpi')) accepted(m),
        ValidatedEnvelope(
          raw: <String, Object?>{
            'version': 'v0.9',
            'updateComponents': <String, Object?>{
              'surfaceId': 'kpi',
              'components': <Object?>[
                <String, Object?>{'id': 'root', 'component': 'Inconnu'},
              ],
            },
          },
          verdict: const ValidationRejected(
            ValidationCodes.componentNotAllowed,
          ),
          compensations: const <String>['kpi'],
        ),
      ]);
      expect(states.map((s) => s.usedCount), [1, 0]);
    },
  );

  test('un refus sans compensation ne change rien', () async {
    final states = await run([
      for (final m in fixture('kpi')) accepted(m),
      ValidatedEnvelope(
        raw: fixture('kpi')[1],
        verdict: const ValidationRejected(ValidationCodes.surfaceExists),
      ),
    ]);
    expect(states.map((s) => s.usedCount), [1]);
  });

  test(
    'après Cleared, la table est vide : un delete ancien ne libère rien',
    () async {
      final states = await run(
        [for (final m in fixture('kpi')) accepted(m)],
        after: (bloc) async {
          bloc.add(const CatalogShelfCleared());
          await Future<void>.delayed(Duration.zero);
        },
      );
      expect(states.last, const CatalogShelfState.empty());

      // Une surface « trend » posée après Cleared, puis delete de l'ancienne
      // « kpi » : seule « trend » compte, et rien n'est libéré par erreur.
      final StreamController<ValidatedEnvelope> c =
          StreamController<ValidatedEnvelope>();
      final after = await statesAfter(CatalogShelfBloc(), (bloc) async {
        bloc.add(CatalogShelfSourceSubscribed(c.stream));
        await Future<void>.delayed(Duration.zero);
        for (final m in fixture('kpi')) {
          c.add(accepted(m));
        }
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CatalogShelfCleared());
        await Future<void>.delayed(Duration.zero);
        for (final m in fixture('trend')) {
          c.add(accepted(m));
        }
        c.add(delete('kpi'));
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
      });
      expect(usedOf(after.last), {'TrendChart'});
      expect(after.last.usedCount, 1);
    },
  );

  test('erreur de flux ignorée ; fermeture annule l abonnement', () async {
    final StreamController<ValidatedEnvelope> c =
        StreamController<ValidatedEnvelope>();
    final states = await statesAfter(CatalogShelfBloc(), (bloc) async {
      bloc.add(CatalogShelfSourceSubscribed(c.stream));
      await Future<void>.delayed(Duration.zero);
      c.addError(StateError('boom'));
      c.add(accepted(fixture('kpi')[1]));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    });
    expect(states.last.usedCount, 1);
    expect(c.hasListener, isFalse);
  });
}
