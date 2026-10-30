import 'package:entity_session/entity_session.dart';
import 'package:feature_replay/feature_replay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les défauts sont ceux des constantes de la slice', () {
    const ReplaySettings settings = ReplaySettings();
    expect(settings.tick, ReplaySettings.defaultTick);
    expect(settings.maxGap, ReplaySettings.defaultMaxGap);
    expect(settings.defaultSpeed, ReplaySettings.defaultStartSpeed);
    expect(settings.speeds, ReplaySettings.defaultSpeeds);
    expect(ReplaySettings.defaultJournalMaxEntries, 5000);
  });

  /// Les contrôles de cohérence sont affirmés à la création du lecteur.
  void Function() build(ReplaySettings settings) =>
      () => ReplayPlayer(
        entries: const <JournalEntry>[],
        settings: settings,
        inject: (_) {},
        clearStage: () {},
      );

  test('un pas nul est refusé', () {
    expect(
      build(const ReplaySettings(tick: Duration.zero)),
      throwsAssertionError,
    );
  });

  test('un écart maximal négatif est refusé', () {
    expect(
      build(const ReplaySettings(maxGap: Duration(seconds: -1))),
      throwsAssertionError,
    );
  });

  test('une liste de vitesses vide est refusée', () {
    expect(
      build(const ReplaySettings(speeds: <double>[])),
      throwsAssertionError,
    );
  });

  test('une vitesse par défaut absente des vitesses est refusée', () {
    expect(build(const ReplaySettings(defaultSpeed: 3)), throwsAssertionError);
  });
}
