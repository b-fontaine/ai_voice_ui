import 'package:flutter_test/flutter_test.dart';

import 'lagent_est_affiche.dart';

/// Usage: l'agent Livraison s'allume dans le rail
///
/// Livraison passe par « en cours » (`agent.activity working`) : le faux
/// backend laisse un temps de travail réel entre `working` et `completed`.
Future<void> lagentLivraisonSallumeDansLeRail(WidgetTester tester) =>
    lagentEstAffiche(tester, 'Livraison', 'en cours');
