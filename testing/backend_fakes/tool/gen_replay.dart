// Génère les assets de rejeu `apps/genesis_canvas/assets/replays/act1-replay.jsonl`
// `act2-replay.jsonl`, `act3-replay.jsonl` et `crashlist-replay.jsonl` à partir des exemples du contrat (artefacts dérivés,
// A5d).
//
//   dart run tool/gen_replay.dart [--scenario act1|act2|act3|crashlist] [--out <fichier>]
//       [--catalog-id <id>]
//
// `--scenario` vaut `act1` par défaut. `act2` : l'acte 1, les
// `updateDataModel` du tour de transformation, puis la création de la Barre
// d'actions. `act3` : l'acte 2 puis le résultat de « Bloquer la release ».
// `crashlist` : l'acte 1 puis la surface `crashes` (liste des crashs, 012).

// Sans `--out`, écrit sur la sortie standard.
import 'dart:io';

import 'package:testing_backend_fakes/testing_backend_fakes.dart';

Future<void> main(List<String> args) async {
  String? out;
  var scenario = 'act1';
  var catalogId = ContractFixtures.defaultCatalogId;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--out':
        out = args[++i];
      case '--scenario':
        scenario = args[++i];
      case '--catalog-id':
        catalogId = args[++i];
      default:
        stderr.writeln('Option inconnue : ${args[i]}');
        exitCode = 64;
        return;
    }
  }
  final String content;
  switch (scenario) {
    case 'act1':
      content = await ContractFixtures.act1ReplayJsonl(catalogId: catalogId);
    case 'act2':
      content = await ContractFixtures.act2ReplayJsonl(catalogId: catalogId);
    case 'act3':
      content = await ContractFixtures.act3ReplayJsonl(catalogId: catalogId);
    case 'crashlist':
      content = await ContractFixtures.crashlistReplayJsonl(
        catalogId: catalogId,
      );
    default:
      stderr.writeln(
        'Scénario inconnu : $scenario (act1, act2, act3 ou crashlist)',
      );
      exitCode = 64;
      return;
  }
  if (out == null) {
    stdout.write(content);
  } else {
    File(out).writeAsStringSync(content);
  }
}
