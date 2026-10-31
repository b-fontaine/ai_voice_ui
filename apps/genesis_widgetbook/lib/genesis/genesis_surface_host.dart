import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' as a2ui;
import 'package:entity_catalog/entity_catalog.dart' show GenesisContract;
import 'package:feature_canvas/feature_canvas.dart' show genesisCatalog;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:genui/genui.dart' show Surface, SurfaceController;

/// État montré par une story d'un composant du catalogue genesis.
enum GenesisSurfaceState {
  /// L'exemple complet du contrat : création, composants, données.
  data,

  /// Surface créée et composants posés, mais aucun `updateDataModel` : le
  /// composant montre son état « sans données » (RG-02).
  noData,

  /// Données invalides (objet vide) : état neutre, sans exception (RG-10).
  neutral,
}

/// Dossier des assets : copies des exemples de
/// `contracts/a2ui/genesis/v1/examples/` (déclarées dans le `pubspec.yaml`,
/// comparées aux originaux par `examples_assets_test.dart`).
const String _assetPrefix = 'assets/examples';

/// Chemin d'asset du fichier d'exemple [example] (sans extension).
String exampleAssetPath(String example) => '$_assetPrefix/$example.jsonl';

/// Remplace le placeholder `${CATALOG_ID}` des exemples du contrat par
/// l'identifiant du catalogue [catalogId], puis décode les lignes en messages
/// A2UI JSON.
List<Map<String, dynamic>> parseExample(String jsonl, String catalogId) =>
    const LineSplitter()
        .convert(jsonl)
        .where((String line) => line.trim().isNotEmpty)
        .map(
          (String line) =>
              jsonDecode(line.replaceAll(r'${CATALOG_ID}', catalogId))
                  as Map<String, dynamic>,
        )
        .toList();

/// Adapte les messages de l'exemple à l'[state] demandé.
///
/// - [GenesisSurfaceState.data] : tels quels ;
/// - [GenesisSurfaceState.noData] : sans le message `updateDataModel` ;
/// - [GenesisSurfaceState.neutral] : la valeur du `updateDataModel` devient un
///   objet vide, que le composant ne sait pas lire.
List<Map<String, dynamic>> messagesFor(
  List<Map<String, dynamic>> messages,
  GenesisSurfaceState state,
) => switch (state) {
  GenesisSurfaceState.data => messages,
  GenesisSurfaceState.noData =>
    messages.where((m) => !m.containsKey('updateDataModel')).toList(),
  GenesisSurfaceState.neutral => [
    for (final m in messages)
      if (m.containsKey('updateDataModel'))
        {
          ...m,
          'updateDataModel': {
            ...(m['updateDataModel'] as Map<String, dynamic>),
            'value': <String, dynamic>{},
          },
        }
      else
        m,
  ],
};

/// Hôte d'une surface du catalogue genesis, pour les stories.
///
/// Crée un `SurfaceController(catalogs: [genesisCatalog()])`, libéré dans
/// [State.dispose], lui injecte les messages A2UI de l'exemple [example] du
/// contrat (adaptés à [state]) et affiche la surface. C'est le motif
/// `CachedSurface` de la doc Widgetbook GenUI (ds-widgetbook-4-genui) : le
/// composant est rendu par le vrai moteur et le vrai catalogue, sans simulacre.
class GenesisSurfaceHost extends StatefulWidget {
  const GenesisSurfaceHost({
    super.key,
    required this.example,
    this.state = GenesisSurfaceState.data,
  });

  /// Nom du fichier d'exemple du contrat, sans extension (`act1-kpi`).
  final String example;

  /// État à montrer.
  final GenesisSurfaceState state;

  @override
  State<GenesisSurfaceHost> createState() => _GenesisSurfaceHostState();
}

class _GenesisSurfaceHostState extends State<GenesisSurfaceHost> {
  late final SurfaceController _controller = SurfaceController(
    catalogs: [genesisCatalog()],
  );
  String? _surfaceId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(GenesisSurfaceHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.example != widget.example ||
        oldWidget.state != widget.state) {
      _load();
    }
  }

  Future<void> _load() async {
    final example = widget.example;
    final state = widget.state;
    try {
      // `load` plutôt que `loadString` : ce dernier met le résultat en cache,
      // et un futur déjà résolu ne s'achève plus dans l'horloge simulée d'un
      // test.
      final bytes = await rootBundle.load(exampleAssetPath(example));
      final text = utf8.decode(bytes.buffer.asUint8List());
      // L'hôte peut avoir été libéré ou reconfiguré pendant la lecture.
      if (!mounted || widget.example != example || widget.state != state) {
        return;
      }
      final messages = messagesFor(
        parseExample(text, GenesisContract.defaultCatalogId),
        state,
      );
      // Un second `createSurface` sur le même contrôleur serait rejeté et le
      // modèle de données resterait rempli : on supprime d'abord la surface.
      final previous = _surfaceId;
      _surfaceId = null;
      if (previous != null) {
        _controller.handleMessage(
          a2ui.DeleteSurfaceMessage(surfaceId: previous),
        );
      }
      String? surfaceId;
      for (final json in messages) {
        final message = a2ui.A2uiMessage.fromJson(json);
        if (message is a2ui.CreateSurfaceMessage) surfaceId = message.surfaceId;
        _controller.handleMessage(message);
      }
      setState(() {
        _error = null;
        _surfaceId = surfaceId;
      });
    } on Object catch (error) {
      // Une story qui n'affiche rien cache la cause : on la montre.
      if (!mounted) return;
      setState(() {
        _surfaceId = null;
        _error = 'Chargement de « $example » impossible : $error';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) return Text(error, key: const Key('host-error'));
    final id = _surfaceId;
    if (id == null) return const SizedBox.shrink();
    return Surface(surfaceContext: _controller.contextFor(id));
  }
}
