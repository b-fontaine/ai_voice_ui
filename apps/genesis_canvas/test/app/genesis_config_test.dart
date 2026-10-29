import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/app/config/genesis_config.dart';

void main() {
  group('GenesisConfig.fromEnvironment', () {
    test('lit GENESIS_SCENARIO et GENESIS_SNAPSHOT', () {
      final config = GenesisConfig.fromEnvironment(<String, String>{
        'GENESIS_SCENARIO': 'act1-replay',
        'GENESIS_SNAPSHOT': '/tmp/capture.png',
      });

      expect(config.scenario, 'act1-replay');
      expect(config.snapshotPath, '/tmp/capture.png');
    });

    test('variables absentes : configuration vide', () {
      final config = GenesisConfig.fromEnvironment(const <String, String>{});

      expect(config.scenario, isNull);
      expect(config.snapshotPath, isNull);
    });

    test('variables vides : traitées comme absentes', () {
      final config = GenesisConfig.fromEnvironment(<String, String>{
        'GENESIS_SCENARIO': '',
        'GENESIS_SNAPSHOT': '  ',
      });

      expect(config.scenario, isNull);
      expect(config.snapshotPath, isNull);
    });
  });
}
