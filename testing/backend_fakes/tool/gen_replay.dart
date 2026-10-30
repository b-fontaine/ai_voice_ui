// Génère `apps/genesis_canvas/assets/replays/act1-replay.jsonl` à partir des
// exemples du contrat (artefact dérivé, A5d).
//
//   dart run tool/gen_replay.dart [--out <fichier>] [--catalog-id <id>]
//
// Sans `--out`, écrit sur la sortie standard.
import 'dart:io';

import 'package:testing_backend_fakes/testing_backend_fakes.dart';

Future<void> main(List<String> args) async {
  String? out;
  var catalogId = ContractFixtures.defaultCatalogId;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--out':
        out = args[++i];
      case '--catalog-id':
        catalogId = args[++i];
      default:
        stderr.writeln('Option inconnue : ${args[i]}');
        exitCode = 64;
        return;
    }
  }
  final content = await ContractFixtures.act1ReplayJsonl(catalogId: catalogId);
  if (out == null) {
    stdout.write(content);
  } else {
    File(out).writeAsStringSync(content);
  }
}
