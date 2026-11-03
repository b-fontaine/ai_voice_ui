import 'package:entity_catalog/entity_catalog.dart';
import 'package:feature_canvas/src/ui/generation_target.dart';
import 'package:flutter_test/flutter_test.dart';

ValidatedEnvelope _envelope(
  Map<String, Object?> raw, {
  ValidationVerdict verdict = const ValidationAccepted(),
  String? agent = 'release',
}) => ValidatedEnvelope(raw: raw, verdict: verdict, agent: agent);

Map<String, Object?> _create(String id) => <String, Object?>{
  'version': 'v0.9',
  'createSurface': <String, Object?>{'surfaceId': id, 'catalogId': 'c'},
};

void main() {
  group('generationTargetOf', () {
    test('un createSurface accepté désigne la surface et l\'agent', () {
      expect(
        generationTargetOf(_envelope(_create('s1'))),
        const GenerationTarget(surfaceId: 's1', agent: 'release'),
      );
    });

    test('sans agent, l\'agent est nul', () {
      expect(
        generationTargetOf(_envelope(_create('s1'), agent: null)),
        const GenerationTarget(surfaceId: 's1'),
      );
    });

    test('un createSurface refusé ne désigne rien', () {
      expect(
        generationTargetOf(
          _envelope(
            _create('s1'),
            verdict: const ValidationRejected(ValidationCodes.badOperation),
          ),
        ),
        isNull,
      );
    });

    test('updateComponents et updateDataModel ne changent pas la cible', () {
      expect(
        generationTargetOf(
          _envelope(<String, Object?>{
            'updateComponents': <String, Object?>{'surfaceId': 's1'},
          }),
        ),
        isNull,
      );
      expect(
        generationTargetOf(
          _envelope(<String, Object?>{
            'updateDataModel': <String, Object?>{'surfaceId': 's1'},
          }),
        ),
        isNull,
      );
    });

    test('un createSurface sans identifiant texte ne désigne rien', () {
      expect(
        generationTargetOf(
          _envelope(<String, Object?>{
            'createSurface': <String, Object?>{'surfaceId': 3},
          }),
        ),
        isNull,
      );
    });
  });
}
