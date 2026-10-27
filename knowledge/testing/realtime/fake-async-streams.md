---
id: test-fake-async-streams
title: fakeAsync et injection de streams pour le code temporel
tags: [fake_async, time, streams, realtime-voice, reconnect]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/fake_async, https://pub.dev/documentation/fake_async/latest/fake_async/FakeAsync-class.html]
links: [test-realtime-fake-runner, test-bloc-test, bloc-emit-foreach]
---
# Contrôler le temps plutôt que l'attendre

Version observée le 2026-10-26 : `fake_async` 1.3.3 (dart.dev, publiée le 2025-01-28). Les timeouts, les backoffs de reconnexion, le debounce VAD et les keep-alive se testent sans délai réel.

```dart
test('reconnecte après 2 s puis 4 s (backoff)', () {
  fakeAsync((async) {
    final transport = FakeTransport()..failNext(2);
    final session = ReconnectingSession(transport, clock: clock);
    session.connect();
    async.flushMicrotasks();
    expect(transport.attempts, 1);
    async.elapse(const Duration(seconds: 2));
    expect(transport.attempts, 2);
    async.elapse(const Duration(seconds: 4));
    expect(transport.attempts, 3);
    session.dispose();
    expect(async.pendingTimers, isEmpty); // pas de timer qui fuit
  });
});
```

## API `FakeAsync`
- `elapse(d)` : avance le temps et déclenche timers et microtasks.
- `elapseBlocking(d)` : simule un bloc synchrone.
- `flushMicrotasks()` et `flushTimers()` (timeout 1 h par défaut).
- Inspection : `pendingTimers`, `periodicTimerCount`, `nonPeriodicTimerCount`, `microtaskCount`.

## Règles
- **Temps lu :** il doit passer par `package:clock` (`clock.now()`, `clock.stopwatch()`), que `FakeAsync` surcharge automatiquement dans `run` ; `DateTime.now()` et `Stopwatch` ne sont pas contrôlés (README).
- **Tests de widgets (opinion) :** `testWidgets` tourne déjà en temps fake piloté par `tester.pump(duration)` ; ne pas imbriquer `fakeAsync`.

## ⚠️ Pièges
- Une vraie IO (socket, fichier, `HttpClient`) ne progresse pas dans `fakeAsync`. Il faut injecter des streams (cf. `test-realtime-fake-runner`). Ce point relève de l'expérience et n'est pas formulé sur la page pub.dev.
