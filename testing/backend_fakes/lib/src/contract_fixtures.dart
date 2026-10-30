import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

/// Une surface de l'acte 1 : les trois messages de son exemple et l'agent
/// (nom de rôle, RG-29) qui la produit.
class Act1Surface {
  const Act1Surface({
    required this.surfaceId,
    required this.agent,
    required this.task,
    required this.messages,
  });

  final String surfaceId;
  final String agent;
  final String task;

  /// `createSurface`, `updateComponents`, `updateDataModel` (RG-02).
  final List<Map<String, Object?>> messages;
}

/// Tour de parole qui transforme un tableau déjà affiché (spec 008) : les
/// fixtures `examples/<prefix>-*.jsonl` ne contiennent que des
/// `updateDataModel` (D1) et se rejouent après l'acte 1.
enum GenesisFollowUp {
  /// « Concentre-toi sur Android et compare avec la 3.3 » (S-02).
  act2('act2', 4),

  /// « Non, plutôt iOS » (B2, FR-17 premier temps).
  correctionIos('correction-ios', 7);

  const GenesisFollowUp(this.filePrefix, this.firstTask);

  /// Préfixe des fichiers d'exemple.
  final String filePrefix;

  /// Numéro de la première tâche A2A du tour : les identifiants de tâche sont
  /// uniques sur toute la démo (ceux de l'acte 1 sont `task_1` à `task_3`).
  final int firstTask;
}

/// Lecture des fixtures du contrat `contracts/a2ui/genesis/v1`.
///
/// Le dossier `contracts/` est retrouvé en remontant les répertoires depuis
/// l'emplacement de ce paquet : aucun chemin absolu, aucun répertoire courant.
abstract final class ContractFixtures {
  /// Défaut de `A2UI_CATALOG_ID` (docker-compose.yaml, pdr-0055).
  static const String defaultCatalogId =
      'https://genesis-canvas.example/a2ui/catalogs/genesis/v1';

  static const String catalogPlaceholder = r'${CATALOG_ID}';

  /// Exemples de l'acte 1, dans l'ordre de mise en scène, avec leur agent.
  static const List<(String file, String agent, String task)> act1Files =
      <(String, String, String)>[
        ('act1-kpi.jsonl', 'Qualité', 'task_1'),
        ('act1-trend.jsonl', 'Qualité', 'task_1'),
        ('act1-reviews.jsonl', 'Voix du client', 'task_2'),
        ('act1-checklist.jsonl', 'Livraison', 'task_3'),
      ];

  /// Agents retenus par le plan de l'acte 1, dans l'ordre du rail.
  static const List<String> act1Agents = <String>[
    'Qualité',
    'Voix du client',
    'Livraison',
  ];

  /// Dossier `contracts/a2ui/genesis/v1`.
  static Future<Directory> genesisDirectory() async {
    final start = await resolvePackageFile(
      'package:testing_backend_fakes/testing_backend_fakes.dart',
    );
    var dir = Directory.fromUri(start).parent.absolute;
    while (true) {
      final candidate = Directory.fromUri(
        dir.uri.resolve('contracts/a2ui/genesis/v1/'),
      );
      if (candidate.existsSync()) return candidate;
      final parent = dir.parent;
      if (parent.path == dir.path) {
        throw StateError('Dossier contracts/a2ui/genesis/v1 introuvable');
      }
      dir = parent;
    }
  }

  /// Charge les quatre surfaces, `${CATALOG_ID}` remplacé textuellement et
  /// partout par [catalogId].
  static Future<List<Act1Surface>> act1Surfaces({
    String catalogId = defaultCatalogId,
  }) async {
    final dir = await genesisDirectory();
    final surfaces = <Act1Surface>[];
    for (final (file, agent, task) in act1Files) {
      final text = File.fromUri(dir.uri.resolve('examples/$file'))
          .readAsStringSync()
          .replaceAll(catalogPlaceholder, catalogId);
      final messages = const LineSplitter()
          .convert(text)
          .where((l) => l.trim().isNotEmpty)
          .map((l) => Map<String, Object?>.from(jsonDecode(l) as Map))
          .toList();
      final body =
          messages.first[messages.first.keys.firstWhere((k) => k != 'version')]
              as Map;
      surfaces.add(
        Act1Surface(
          surfaceId: body['surfaceId']! as String,
          agent: agent,
          task: task,
          messages: messages,
        ),
      );
    }
    return surfaces;
  }

  /// Surfaces d'un tour de transformation : un `updateDataModel` par surface,
  /// dans l'ordre de l'acte 1. Qualité sert `kpi` et `trend` (une tâche),
  /// Voix du client `reviews`, Livraison `checklist` ; les identifiants de
  /// tâche sont distincts de ceux de l'acte 1 et des autres tours.
  static Future<List<Act1Surface>> followUpSurfaces(
    GenesisFollowUp followUp, {
    String catalogId = defaultCatalogId,
  }) async {
    final dir = await genesisDirectory();
    final surfaces = <Act1Surface>[];
    for (final (file, agent, task) in act1Files) {
      final offset = int.parse(task.substring('task_'.length)) - 1;
      final text = File.fromUri(
        dir.uri.resolve(
          'examples/${followUp.filePrefix}-${file.substring('act1-'.length)}',
        ),
      ).readAsStringSync().replaceAll(catalogPlaceholder, catalogId);
      final messages = const LineSplitter()
          .convert(text)
          .where((l) => l.trim().isNotEmpty)
          .map((l) => Map<String, Object?>.from(jsonDecode(l) as Map))
          .toList();
      final update = messages.first['updateDataModel']! as Map;
      surfaces.add(
        Act1Surface(
          surfaceId: update['surfaceId']! as String,
          agent: agent,
          task: 'task_${followUp.firstTask + offset}',
          messages: messages,
        ),
      );
    }
    return surfaces;
  }

  /// Agent qui produit la Barre d'actions et les résultats d'action (Livraison,
  /// pdr-0065 D2 et D3), et numéro de la tâche A2A de l'acte 3 : les
  /// identifiants de tâche sont uniques sur toute la démo (acte 1 : 1 à 3,
  /// acte 2 : 4 à 6, correction iOS : 7 à 9).
  static const String actionAgent = 'Livraison';
  static const String act2ActionsTask = 'task_6';
  static const String act3Task = 'task_10';

  /// Messages de la surface `actions` créée à la fin de l'acte 2
  /// (`examples/act2-actions.jsonl`) : `createSurface`, `updateComponents`,
  /// `updateDataModel`.
  static Future<List<Map<String, Object?>>> actionsMessages({
    String catalogId = defaultCatalogId,
  }) => _exampleMessages('act2-actions.jsonl', catalogId);

  /// Message du résultat d'une action (`examples/act3-block.jsonl` ou
  /// `act3-validate.jsonl`) : un `updateDataModel` de sous-chemin (A7).
  static Future<List<Map<String, Object?>>> actionResultMessages(
    String action, {
    String catalogId = defaultCatalogId,
  }) {
    final file = switch (action) {
      'block_release' => 'act3-block.jsonl',
      'validate_release' => 'act3-validate.jsonl',
      _ => throw ArgumentError('Action inconnue du contrat : $action'),
    };
    return _exampleMessages(file, catalogId);
  }

  static Future<List<Map<String, Object?>>> _exampleMessages(
    String file,
    String catalogId,
  ) async {
    final dir = await genesisDirectory();
    final text = File.fromUri(dir.uri.resolve('examples/$file'))
        .readAsStringSync()
        .replaceAll(catalogPlaceholder, catalogId);
    return const LineSplitter()
        .convert(text)
        .where((l) => l.trim().isNotEmpty)
        .map((l) => Map<String, Object?>.from(jsonDecode(l) as Map))
        .toList();
  }

  /// Messages d'une fixture négative `invalid/<name>.jsonl`, `${CATALOG_ID}`
  /// remplacé par [catalogId].
  static Future<List<Map<String, Object?>>> invalidMessages(
    String name, {
    String catalogId = defaultCatalogId,
  }) async {
    final dir = await genesisDirectory();
    final text = File.fromUri(dir.uri.resolve('invalid/$name.jsonl'))
        .readAsStringSync()
        .replaceAll(catalogPlaceholder, catalogId);
    return const LineSplitter()
        .convert(text)
        .where((l) => l.trim().isNotEmpty)
        .map((l) => Map<String, Object?>.from(jsonDecode(l) as Map))
        .toList();
  }

  /// Contenu de `assets/replays/act1-replay.jsonl` dérivé du contrat (A5d) :
  /// une ligne `{t_ms, message}` par message, les surfaces espacées de 500 ms
  /// et les trois temps de 50 ms.
  static Future<String> act1ReplayJsonl({
    String catalogId = defaultCatalogId,
  }) async {
    final buffer = StringBuffer();
    final surfaces = await act1Surfaces(catalogId: catalogId);
    for (var s = 0; s < surfaces.length; s++) {
      for (var m = 0; m < surfaces[s].messages.length; m++) {
        buffer.writeln(
          jsonEncode(<String, Object?>{
            't_ms': s * 500 + m * 50,
            'message': surfaces[s].messages[m],
          }),
        );
      }
    }
    return buffer.toString();
  }

  /// Contenu de `assets/replays/act2-replay.jsonl` dérivé du contrat : l'acte 1
  /// à l'identique ([act1ReplayJsonl]), puis les `updateDataModel` du tour de
  /// transformation ([GenesisFollowUp.act2]), une surface toutes les 500 ms,
  /// la première 500 ms après la dernière surface de l'acte 1, enfin la
  /// création de la Barre d'actions ([actionsMessages], A2 : après la mutation
  /// de la checklist), 500 ms plus tard, les messages espacés de 50 ms.
  static Future<String> act2ReplayJsonl({
    String catalogId = defaultCatalogId,
  }) async {
    final buffer = StringBuffer(await act1ReplayJsonl(catalogId: catalogId));
    final act1Count = act1Files.length;
    final updates = await followUpSurfaces(
      GenesisFollowUp.act2,
      catalogId: catalogId,
    );
    for (var s = 0; s < updates.length; s++) {
      for (var m = 0; m < updates[s].messages.length; m++) {
        buffer.writeln(
          jsonEncode(<String, Object?>{
            't_ms': (act1Count + s) * 500 + m * 50,
            'message': updates[s].messages[m],
          }),
        );
      }
    }
    final actions = await actionsMessages(catalogId: catalogId);
    for (var m = 0; m < actions.length; m++) {
      buffer.writeln(
        jsonEncode(<String, Object?>{
          't_ms': (act1Count + updates.length) * 500 + m * 50,
          'message': actions[m],
        }),
      );
    }
    return buffer.toString();
  }

  /// Contenu de `assets/replays/act3-replay.jsonl` dérivé du contrat : l'acte 2
  /// à l'identique ([act2ReplayJsonl], Barre d'actions comprise), puis le
  /// résultat du clic sur « Bloquer la release » (`act3-block.jsonl`), 500 ms
  /// après la création de la barre.
  static Future<String> act3ReplayJsonl({
    String catalogId = defaultCatalogId,
  }) async {
    final buffer = StringBuffer(await act2ReplayJsonl(catalogId: catalogId));
    final block = await actionResultMessages(
      'block_release',
      catalogId: catalogId,
    );
    final start = (act1Files.length * 2) * 500 + 500;
    for (var m = 0; m < block.length; m++) {
      buffer.writeln(
        jsonEncode(<String, Object?>{
          't_ms': start + m * 50,
          'message': block[m],
        }),
      );
    }
    return buffer.toString();
  }

  /// Contenu de `assets/replays/crashlist-replay.jsonl` dérivé du contrat
  /// (spec 012, T43) : l'acte 1 à l'identique ([act1ReplayJsonl]), puis les
  /// trois messages de `examples/crashlist-global.jsonl` (surface `crashes`),
  /// 500 ms après la dernière surface de l'acte 1, espacés de 50 ms.
  static Future<String> crashlistReplayJsonl({
    String catalogId = defaultCatalogId,
  }) async {
    final buffer = StringBuffer(await act1ReplayJsonl(catalogId: catalogId));
    final crashes = await _exampleMessages('crashlist-global.jsonl', catalogId);
    final start = act1Files.length * 500;
    for (var m = 0; m < crashes.length; m++) {
      buffer.writeln(
        jsonEncode(<String, Object?>{
          't_ms': start + m * 50,
          'message': crashes[m],
        }),
      );
    }
    return buffer.toString();
  }

  /// Résout une URI `package:` : `Isolate.resolvePackageUri` d'abord ; le
  /// lanceur `flutter_tester` ne le prend pas en charge, on lit alors le
  /// `package_config.json` de l'espace de travail (remonté depuis le
  /// répertoire courant), ce qui revient à la même résolution par paquet.
  static Future<Uri> resolvePackageFile(String packageUri) async {
    final uri = Uri.parse(packageUri);
    try {
      final resolved = await Isolate.resolvePackageUri(uri);
      if (resolved != null) return resolved;
    } on UnsupportedError {
      // Repli ci-dessous.
    }
    var dir = Directory.current.absolute;
    while (true) {
      final config = File.fromUri(
        dir.uri.resolve('.dart_tool/package_config.json'),
      );
      if (config.existsSync()) {
        final packages =
            (jsonDecode(await config.readAsString())
                    as Map<String, Object?>)['packages']!
                as List<Object?>;
        for (final entry in packages.cast<Map<String, Object?>>()) {
          if (entry['name'] != uri.pathSegments.first) continue;
          final rootUri = entry['rootUri']! as String;
          final root = config.uri.resolve(
            rootUri.endsWith('/') ? rootUri : '$rootUri/',
          );
          final lib = root.resolve(entry['packageUri']! as String);
          return lib.resolve(uri.pathSegments.skip(1).join('/'));
        }
      }
      final parent = dir.parent;
      if (parent.path == dir.path) {
        throw StateError('Fichier de paquet introuvable : $packageUri');
      }
      dir = parent;
    }
  }
}
