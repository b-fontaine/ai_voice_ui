import 'package:flutter_test/flutter_test.dart';

/// Fait avancer le test jusqu'à ce que [condition] soit vraie, en laissant
/// tourner la boucle d'événements **réelle** (sockets `dart:io`) entre deux
/// `pump` : un `testWidgets` s'exécute dans une zone `FakeAsync` où ni les
/// sockets ni les `Future.delayed` réels n'avancent seuls.
///
/// L'attente est bornée par [timeout] (mesuré à l'horloge réelle) : au-delà,
/// le test échoue avec [reason].
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required Duration timeout,
  required String reason,
  Duration interval = const Duration(milliseconds: 25),
}) async {
  final watch = Stopwatch()..start();
  while (true) {
    if (condition()) return;
    if (watch.elapsed >= timeout) {
      fail('Délai de ${timeout.inMilliseconds} ms dépassé : $reason');
    }
    await tester.runAsync(() => Future<void>.delayed(interval));
    await tester.pump(interval);
  }
}

/// Laisse s'écouler [duration] de temps réel puis un cadre, pour vérifier
/// qu'un événement attendu **ne** se produit **pas**.
Future<void> settleReal(
  WidgetTester tester, {
  Duration duration = const Duration(milliseconds: 300),
}) async {
  await tester.runAsync(() => Future<void>.delayed(duration));
  await tester.pump(duration);
}
