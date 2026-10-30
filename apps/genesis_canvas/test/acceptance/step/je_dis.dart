import 'package:flutter_test/flutter_test.dart';

import '../support/acte3_harness.dart';

/// Usage: je dis {'Concentre-toi sur Android et compare avec la 3.3'}
///
/// Le faux backend émet le tour qui répond à la phrase : la phrase, la
/// délégation, le plan des trois agents, leur activité au travail et les seules
/// mises à jour de données (`updateDataModel`) lues dans les exemples du
/// contrat. Phrases connues : l'acte 2 et la correction « Non, plutôt iOS ».
/// La Barre d'actions de l'acte 3 n'est pas créée ici (voir
/// « la checklist go/no-go est affichée »).
Future<void> jeDis(WidgetTester tester, String phrase) =>
    Acte3Harness.say(tester, phrase);
