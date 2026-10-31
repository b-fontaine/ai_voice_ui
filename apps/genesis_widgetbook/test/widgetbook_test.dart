import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_widgetbook/widgetbook.config.dart';
import 'package:widgetbook/test.dart';

/// Briques du design system attendues dans le catalogue (T32).
const _expectedBricks = <String>{
  'DsStatusChip',
  'DsSkeleton',
  'DsNeutralState',
};

Future<void> main() async {
  // Garde d'ensemble : la configuration ne signale jamais une story absente,
  // ce test compare donc les briques cataloguées à celles attendues.
  test('le catalogue contient exactement les 3 briques du design system', () {
    final names = {for (final c in config.components) c.name};
    expect(names, _expectedBricks);
    for (final c in config.components) {
      expect(c.stories, isNotEmpty, reason: '${c.name} sans story');
    }
  });

  // Un scénario par story et par viewport : PNG et JSON dans
  // build/.widgetbook/, sans comparaison (ds-widgetbook-4-testing).
  await testWidgetbook(config);
}
