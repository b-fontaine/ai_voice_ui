import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/pages/genesis_canvas/genesis_canvas_page_settings.dart';

void main() {
  GenesisCanvasPageSettings make({
    double threshold = 0.03,
    int replayJournalMaxEntries = 5000,
    Duration replayTick = const Duration(milliseconds: 100),
    Duration replayMaxGap = const Duration(seconds: 3),
    double replayDefaultSpeed = 1.0,
    double? replayCaptureAt,
  }) => GenesisCanvasPageSettings(
    orbAttack: const Duration(milliseconds: 80),
    orbRelease: const Duration(milliseconds: 250),
    orbSilenceTimeout: const Duration(milliseconds: 600),
    orbSpeakingThreshold: threshold,
    sessionCloseTimeout: const Duration(seconds: 10),
    exitCloseTimeout: const Duration(seconds: 12),
    canvasResetRetries: 8,
    canvasResetRetryInterval: const Duration(milliseconds: 1500),
    canvasActionRetries: 6,
    canvasActionRetryInterval: const Duration(seconds: 1),
    canvasActionMaxDuration: const Duration(seconds: 60),
    replayJournalMaxEntries: replayJournalMaxEntries,
    replayTick: replayTick,
    replayMaxGap: replayMaxGap,
    replayDefaultSpeed: replayDefaultSpeed,
    replayCaptureAt: replayCaptureAt,
  );

  test('égalité par valeur', () {
    expect(make(), make());
    expect(make().hashCode, make().hashCode);
    expect(make(), isNot(make(threshold: 0.5)));
  });

  test('réglages du rejeu : défauts et égalité par valeur', () {
    final settings = make();
    expect(settings.replayJournalMaxEntries, 5000);
    expect(settings.replayTick, const Duration(milliseconds: 100));
    expect(settings.replayMaxGap, const Duration(seconds: 3));
    expect(settings.replayDefaultSpeed, 1.0);
    expect(settings, isNot(make(replayMaxGap: const Duration(seconds: 1))));
    expect(settings, isNot(make(replayJournalMaxEntries: 10)));
    expect(settings, isNot(make(replayTick: const Duration(seconds: 1))));
    expect(settings, isNot(make(replayDefaultSpeed: 2)));
  });

  test(
    'position de capture du rejeu : absente par défaut, comparée par valeur',
    () {
      expect(make().replayCaptureAt, isNull);
      expect(make(replayCaptureAt: 0.5).replayCaptureAt, 0.5);
      expect(make(replayCaptureAt: 0.5), make(replayCaptureAt: 0.5));
      expect(
        make(replayCaptureAt: 0.5).hashCode,
        make(replayCaptureAt: 0.5).hashCode,
      );
      expect(make(replayCaptureAt: 0.5), isNot(make()));
      expect(make(replayCaptureAt: 0.5), isNot(make(replayCaptureAt: 0.25)));
    },
  );
}
