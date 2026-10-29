import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/app/lifecycle/exit_guard.dart';

void main() {
  const timeout = Duration(seconds: 8);

  testWidgets('attend la fin de stop puis répond exit', (tester) async {
    final stop = Completer<void>();
    AppExitResponse? response;
    unawaited(
      ExitGuard(
        () => stop.future,
        timeout,
      ).onExitRequested().then((value) => response = value),
    );

    await tester.pump(const Duration(seconds: 2));
    expect(response, isNull);

    stop.complete();
    await tester.pump();
    expect(response, AppExitResponse.exit);
  });

  testWidgets('stop qui ne se termine jamais : exit au bout du délai', (
    tester,
  ) async {
    AppExitResponse? response;
    unawaited(
      ExitGuard(
        () => Completer<void>().future,
        timeout,
      ).onExitRequested().then((value) => response = value),
    );

    await tester.pump(timeout - const Duration(milliseconds: 1));
    expect(response, isNull);

    await tester.pump(const Duration(milliseconds: 1));
    expect(response, AppExitResponse.exit);
  });

  testWidgets('stop qui échoue : exit quand même', (tester) async {
    AppExitResponse? response;
    unawaited(
      ExitGuard(
        () async => throw StateError('boum'),
        timeout,
      ).onExitRequested().then((value) => response = value),
    );

    await tester.pump();
    expect(response, AppExitResponse.exit);
  });

  testWidgets('stop qui lève de façon synchrone : exit quand même', (
    tester,
  ) async {
    AppExitResponse? response;
    unawaited(
      ExitGuard(
        () => throw StateError('boum'),
        timeout,
      ).onExitRequested().then((value) => response = value),
    );

    await tester.pump();
    expect(response, AppExitResponse.exit);
  });
}
