import 'dart:convert';
import 'dart:io';

import 'package:entity_catalog/entity_catalog.dart';
import 'package:test/test.dart';

final String _cid = GenesisContract.defaultCatalogId;

Map<String, Object?> _create(
  String id, {
  Object? catalog,
  Object? sdm = false,
}) => <String, Object?>{
  'version': 'v0.9',
  'createSurface': <String, Object?>{
    'surfaceId': id,
    'catalogId': catalog ?? _cid,
    'sendDataModel': ?sdm,
  },
};

Map<String, Object?> _components(String id, List<Object?> components) =>
    <String, Object?>{
      'version': 'v0.9',
      'updateComponents': <String, Object?>{
        'surfaceId': id,
        'components': components,
      },
    };

Map<String, Object?> _kpi([String cid = 'root', String path = '/kpi']) =>
    <String, Object?>{
      'id': cid,
      'component': 'KeyIndicator',
      'data': <String, Object?>{'path': path},
    };

Map<String, Object?> _data(String id, {Object? path = '/kpi'}) =>
    <String, Object?>{
      'version': 'v0.9',
      'updateDataModel': <String, Object?>{
        'surfaceId': id,
        'path': ?path,
        'value': <String, Object?>{'label': 'x'},
      },
    };

Map<String, Object?> _delete(String id) => <String, Object?>{
  'version': 'v0.9',
  'deleteSurface': <String, Object?>{'surfaceId': id},
};

String? _code(ValidatedEnvelope e) => switch (e.verdict) {
  ValidationRejected(:final code) => code,
  _ => null,
};

void main() {
  late GenesisMessageValidator v;
  setUp(() => v = GenesisMessageValidator());

  ValidatedEnvelope open(String id) {
    final e = v.check(_create(id));
    expect(e.verdict, const ValidationAccepted());
    return e;
  }

  group('codes stateless', () {
    final cases = <String, (Map<String, Object?> Function(), String)>{
      'bad_version': (
        () => {..._create('a'), 'version': 'v0.8'},
        'bad_version',
      ),
      'aucune opération': (
        () => <String, Object?>{'version': 'v0.9'},
        'bad_operation',
      ),
      'opération inconnue': (
        () => <String, Object?>{'version': 'v0.9', 'foo': <String, Object?>{}},
        'bad_operation',
      ),
      'deux opérations': (
        () => {
          ..._create('a'),
          'deleteSurface': <String, Object?>{'surfaceId': 'a'},
        },
        'bad_operation',
      ),
      'corps non objet': (
        () => <String, Object?>{'version': 'v0.9', 'createSurface': 3},
        'bad_operation',
      ),
      'surfaceId invalide': (() => _create('a b'), 'bad_surface_id'),
      'surfaceId trop long': (() => _create('a' * 65), 'bad_surface_id'),
      'catalogId': (() => _create('a', catalog: 'x'), 'bad_catalog'),
      'sendDataModel non booléen': (
        () => _create('a', sdm: 'oui'),
        'bad_operation',
      ),
      'zéro composant': (() => _components('a', []), 'bad_component_count'),
      '101 composants': (
        () => _components('a', [for (var i = 0; i < 101; i++) _kpi('c$i')]),
        'bad_component_count',
      ),
      'composant non objet': (() => _components('a', ['x']), 'bad_component'),
      'id manquant': (
        () => _components('a', [
          <String, Object?>{'component': 'KeyIndicator'},
        ]),
        'bad_component',
      ),
      'id dupliqué': (
        () => _components('a', [_kpi('x'), _kpi('x')]),
        'duplicate_component_id',
      ),
      'composant hors liste': (
        () => _components('a', [
          {'id': 'root', 'component': 'Text'},
        ]),
        'component_not_allowed',
      ),
      'propriété inconnue': (
        () => _components('a', [
          {..._kpi(), 'style': 1},
        ]),
        'bad_property',
      ),
      'data littéral': (
        () => _components('a', [
          {..._kpi(), 'data': '99'},
        ]),
        'bad_property',
      ),
      'data avec deux clés': (
        () => _components('a', [
          {
            ..._kpi(),
            'data': {'path': '/kpi', 'x': 1},
          },
        ]),
        'bad_property',
      ),
      'liaison sans barre': (
        () => _components('a', [_kpi('root', 'kpi')]),
        'bad_property',
      ),
      'liaison vide': (
        () => _components('a', [_kpi('root', '')]),
        'bad_property',
      ),
      'liaison > 128': (
        () => _components('a', [_kpi('root', '/${'a' * 128}')]),
        'bad_property',
      ),
      'liaison avec contrôle': (
        () => _components('a', [_kpi('root', '/k\u0007')]),
        'bad_property',
      ),
      'liaison tilde': (
        () => _components('a', [_kpi('root', '/k~2')]),
        'bad_property',
      ),
      'child hors liste blanche (bad_property avant bad_children, comme le Go)':
          (
            () => _components('a', [
              {..._kpi(), 'child': 3},
            ]),
            'bad_property',
          ),
      'children hors liste blanche': (
        () => _components('a', [
          {..._kpi(), 'children': 'x'},
        ]),
        'bad_property',
      ),
      'pointeur sans barre': (() => _data('a', path: 'kpi'), 'bad_pointer'),
      'pointeur non chaîne': (() => _data('a', path: 3), 'bad_pointer'),
      'pointeur tilde final': (() => _data('a', path: '/a~'), 'bad_pointer'),
      'trop profond': (
        () {
          Object? n = 'x';
          for (var i = 0; i < 20; i++) {
            n = <String, Object?>{'a': n};
          }
          return {..._create('a'), 'extra': n};
        },
        'too_deep',
      ),
      'trop gros': (
        () => _data('a', path: '/kpi')..['pad'] = 'x' * (64 * 1024),
        'too_large',
      ),
    };
    cases.forEach((name, c) {
      test(name, () {
        // Surface active : un refus la compense, mais le code reste celui-ci.
        v.check(_create('a'));
        expect(_code(v.check(c.$1())), c.$2);
      });
    });

    test('too_large compte les octets UTF-8, pas les caractères', () {
      // 25 000 × « é » = 50 000 caractères mais 50 000 octets ; 40 000 × « € »
      // = 40 000 caractères mais 120 000 octets.
      v.check(_create('a'));
      expect(_code(v.check(_data('a')..['pad'] = '€' * 40000)), 'too_large');
    });

    test('theme de createSurface toléré', () {
      final m = _create('a');
      (m['createSurface']! as Map<String, Object?>)['theme'] = {'x': 1};
      expect(v.check(m).verdict, const ValidationAccepted());
    });

    test('sendDataModel absent toléré, path absent toléré', () {
      expect(
        v.check(_create('a', sdm: null)).verdict,
        const ValidationAccepted(),
      );
      expect(
        v.check(_data('a', path: null)).verdict,
        const ValidationAccepted(),
      );
      expect(v.check(_data('a', path: '')).verdict, const ValidationAccepted());
    });

    test('catalogId attendu paramétrable', () {
      final other = GenesisMessageValidator(catalogId: 'urn:x');
      expect(other.check(_create('a')).verdict, isA<ValidationRejected>());
      expect(
        other.check(_create('a', catalog: 'urn:x')).verdict,
        const ValidationAccepted(),
      );
    });
  });

  group('état', () {
    test('surface inconnue', () {
      expect(_code(v.check(_components('ghost', [_kpi()]))), 'unknown_surface');
      expect(_code(v.check(_data('ghost'))), 'unknown_surface');
    });

    test('surface_exists', () {
      open('a');
      expect(_code(v.check(_create('a'))), 'surface_exists');
    });

    test(
      'createSurface en double : refusé sans compensation, surface gardée',
      () {
        open('a');
        final e = v.check(_create('a'));
        expect(_code(e), 'surface_exists');
        expect(e.compensations, isEmpty);
        expect(v.activeSurfaces, {'a'});
        expect(v.blockedSurfaces, isEmpty);
        expect(v.check(_data('a')).verdict, const ValidationAccepted());
        expect(
          v.check(_components('a', [_kpi()])).verdict,
          const ValidationAccepted(),
        );
      },
    );

    test('6 surfaces puis la 7e refusée sans compensation', () {
      for (var i = 0; i < 6; i++) {
        open('s$i');
      }
      final e = v.check(_create('s6'));
      expect(_code(e), 'surface_limit');
      expect(e.compensations, isEmpty);
      expect(v.activeSurfaces, hasLength(6));
    });

    test('plafond de 200 composants par surface (component_cap)', () {
      open('a');
      for (var b = 0; b < 2; b++) {
        expect(
          v
              .check(
                _components('a', [
                  for (var i = 0; i < 100; i++) _kpi('c$b-$i'),
                ]),
              )
              .verdict,
          const ValidationAccepted(),
        );
      }
      // Mise à jour d'ids existants : pas de croissance.
      expect(
        v.check(_components('a', [_kpi('c0-0')])).verdict,
        const ValidationAccepted(),
      );
      expect(
        _code(v.check(_components('a', [_kpi('nouveau')]))),
        'component_cap',
      );
    });

    test('compensation : le refus retire la surface et la bloque', () {
      open('a');
      final e = v.check(
        _components('a', [
          {'id': 'root', 'component': 'Text'},
        ]),
      );
      expect(_code(e), 'component_not_allowed');
      expect(e.compensations, ['a']);
      expect(v.activeSurfaces, isEmpty);
      expect(v.blockedSurfaces, {'a'});
      expect(_code(v.check(_components('a', [_kpi()]))), 'unknown_surface');
      expect(_code(v.check(_data('a'))), 'unknown_surface');
      // Nouveau createSurface valide : la surface revit.
      expect(v.check(_create('a')).verdict, const ValidationAccepted());
      expect(v.blockedSurfaces, isEmpty);
      expect(
        v.check(_components('a', [_kpi()])).verdict,
        const ValidationAccepted(),
      );
    });

    test('un message mal formé dont le surfaceId est actif compense aussi', () {
      open('a');
      final m = _data('a', path: 'kpi');
      expect(v.check(m).compensations, ['a']);
    });

    test('compensation limitée à la surface visée', () {
      open('a');
      open('b');
      v.check(_data('a', path: 'kpi'));
      expect(v.activeSurfaces, {'b'});
    });

    test('deleteSurface absente : ignored', () {
      final e = v.check(_delete('ghost'));
      expect(e.verdict, const ValidationIgnored());
      expect(e.compensations, isEmpty);
    });

    test('deleteSurface active : accepté et retire', () {
      open('a');
      expect(v.check(_delete('a')).verdict, const ValidationAccepted());
      expect(v.activeSurfaces, isEmpty);
      expect(v.check(_delete('a')).verdict, const ValidationIgnored());
      expect(_code(v.check(_data('a'))), 'unknown_surface');
    });

    test('deleteSurface mal formée : refusée', () {
      expect(_code(v.check(_delete('a b'))), 'bad_surface_id');
    });

    test('reset() vide surfaces actives et bloquées', () {
      open('a');
      open('b');
      v.check(_data('a', path: 'kpi'));
      v.reset();
      expect(v.activeSurfaces, isEmpty);
      expect(v.blockedSurfaces, isEmpty);
      open('a');
    });

    test('agent et task sont recopiés, raw conservé', () {
      final m = _create('a');
      final e = v.check(m, agent: 'Qualité', task: 'task_1');
      expect(e.agent, 'Qualité');
      expect(e.task, 'task_1');
      expect(e.raw, m);
    });
  });

  group('ValidatedEnvelope', () {
    test('égalité par valeur, raw comparé en profondeur', () {
      ValidatedEnvelope mk(Object? x) => ValidatedEnvelope(
        raw: <String, Object?>{
          'a': <Object?>[
            <String, Object?>{'b': x},
          ],
        },
        agent: 'q',
        task: 't',
        verdict: const ValidationRejected('bad_pointer'),
      );
      expect(mk(1), mk(1));
      expect(mk(1).hashCode, mk(1).hashCode);
      expect(mk(1), isNot(mk(2)));
      expect(
        const ValidationRejected('a') == const ValidationRejected('b'),
        isFalse,
      );
    });

    test('immuable : raw non modifiable', () {
      final e = ValidatedEnvelope(
        raw: <String, Object?>{'a': 1},
        verdict: const ValidationAccepted(),
      );
      expect(() => e.raw['a'] = 2, throwsUnsupportedError);
    });
  });

  group('fixtures positives de l acte 1', () {
    test('séquence acceptée, trois temps dans l ordre', () {
      final dir = _contractsDir();
      for (final f in [
        'act1-kpi.jsonl',
        'act1-trend.jsonl',
        'act1-reviews.jsonl',
        'act1-checklist.jsonl',
      ]) {
        final text = File('${dir.path}/examples/$f')
            .readAsStringSync()
            .replaceAll(r'${CATALOG_ID}', _cid);
        final kinds = <String>[];
        for (final l in const LineSplitter().convert(text)) {
          if (l.trim().isEmpty) continue;
          final m = Map<String, Object?>.from(jsonDecode(l) as Map);
          kinds.add(m.keys.firstWhere((k) => k != 'version'));
          expect(v.check(m).verdict, const ValidationAccepted(), reason: f);
        }
        expect(kinds, ['createSurface', 'updateComponents', 'updateDataModel']);
      }
      expect(v.activeSurfaces, {'kpi', 'trend', 'reviews', 'checklist'});
    });
  });
}

Directory _contractsDir() {
  var dir = Directory.current.absolute;
  while (true) {
    final c = Directory('${dir.path}/contracts/a2ui/genesis/v1');
    if (c.existsSync()) return c;
    if (dir.parent.path == dir.path) throw StateError('contracts/ introuvable');
    dir = dir.parent;
  }
}
