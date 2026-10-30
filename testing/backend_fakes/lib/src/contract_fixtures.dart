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
