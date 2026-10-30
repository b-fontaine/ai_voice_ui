import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/pages/genesis_canvas/genesis_canvas_page_settings.dart';

void main() {
  GenesisCanvasPageSettings make({double threshold = 0.03}) =>
      GenesisCanvasPageSettings(
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
      );

  test('égalité par valeur', () {
    expect(make(), make());
    expect(make().hashCode, make().hashCode);
    expect(make(), isNot(make(threshold: 0.5)));
  });
}
