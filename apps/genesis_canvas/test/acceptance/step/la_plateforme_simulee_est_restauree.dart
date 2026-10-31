import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: la plateforme simulée est restaurée
///
/// Le banc de test refuse qu'une variable de débogage de la fondation reste
/// modifiée à la fin du test, et il vérifie cela avant les `addTearDown` : la
/// remise à l'état d'origine se fait dans l'étape `After`.
Future<void> laPlateformeSimuleeEstRestauree(WidgetTester tester) async {
  debugDefaultTargetPlatformOverride = null;
}
