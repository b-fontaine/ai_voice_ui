import 'package:flutter_test/flutter_test.dart';

/// Usage: les animations du système sont désactivées
///
/// Réglage d'accessibilité de la plateforme (`MediaQuery.disableAnimations`),
/// frontière plateforme simulée par le banc de test.
Future<void> lesAnimationsDuSystemeSontDesactivees(WidgetTester tester) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pump();
}
