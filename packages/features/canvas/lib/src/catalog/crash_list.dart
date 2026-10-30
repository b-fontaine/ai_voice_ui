import 'package:flutter/material.dart';
import 'package:genui/genui.dart' show CatalogItem;
import 'package:shared_design_system/shared_design_system.dart';

import 'bound_item.dart';

/// `CrashList` : les principaux crashs d'une release (rang, libellé,
/// plateforme, volume), liée à `/crashes` (spec 012).
///
/// Trois états comme les autres composants liés : squelette (cellule du
/// board), sans données (objet absent, aucune ligne) et état neutre (RG-10)
/// si `items` n'est pas une liste ou si une ligne est incomplète.
final CatalogItem crashListItem = boundCatalogItem<_Crashes>(
  name: 'CrashList',
  description: 'Liste des principaux crashs liée à /crashes.',
  parse: _Crashes.tryParse,
  build: (BuildContext context, _Crashes c, String _) => _CrashListView(c),
);

class _CrashRow {
  const _CrashRow({
    required this.rank,
    required this.label,
    required this.platform,
    required this.volume,
    required this.sessions,
  });

  final int rank;
  final String label;
  final String platform;
  final int volume;
  final int sessions;
}

class _Crashes {
  const _Crashes({required this.title, required this.rows});

  final String title;
  final List<_CrashRow> rows;

  /// Une liste vide est valide (« sans lignes ») ; une ligne incomplète ou
  /// de mauvais type invalide toute la liste.
  static _Crashes? tryParse(Object raw) {
    if (raw is! Map) return null;
    final String? title = readString(raw, 'title');
    final List<Map<Object?, Object?>>? items = readMaps(raw, 'items');
    if (title == null || items == null) return null;
    final List<_CrashRow> rows = <_CrashRow>[];
    for (final Map<Object?, Object?> item in items) {
      final int? rank = readInt(item, 'rank');
      final String? label = readString(item, 'label');
      final String? platform = readString(item, 'platform');
      final int? volume = readInt(item, 'volume');
      final int? sessions = readInt(item, 'sessions');
      if (rank == null ||
          label == null ||
          platform == null ||
          volume == null ||
          sessions == null) {
        return null;
      }
      rows.add(
        _CrashRow(
          rank: rank,
          label: label,
          platform: platform,
          volume: volume,
          sessions: sessions,
        ),
      );
    }
    return _Crashes(title: title, rows: rows);
  }
}

class _CrashListView extends StatelessWidget {
  const _CrashListView(this.crashes);

  final _Crashes crashes;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return CellFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            crashes.title,
            style: theme.label.copyWith(color: theme.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Les lignes se partagent la hauteur restante : la cellule est
          // bornée, la liste ne défile pas.
          for (final _CrashRow row in crashes.rows)
            Expanded(child: _CrashRowView(row: row)),
        ],
      ),
    );
  }
}

class _CrashRowView extends StatelessWidget {
  const _CrashRowView({required this.row});

  final _CrashRow row;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return Row(
      key: Key('crash-row-${row.rank}'),
      children: <Widget>[
        Text(
          '${row.rank}',
          style: theme.label.copyWith(color: theme.textSecondary),
          maxLines: 1,
        ),
        const SizedBox(width: 12),
        // Une seule ligne avec ellipse, sur toute la largeur restante
        // (pdr-0062 D10) : cinq lignes se partagent environ 187 px dans une
        // cellule 3 x 2, soit de quoi loger 24 px sans rognage.
        Expanded(
          child: Text(
            row.label,
            key: Key('crash-label-${row.rank}'),
            style: theme.body.copyWith(color: theme.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        // Plateforme et volume à droite ; `sessions` reste dans les données
        // du contrat mais n'est pas affiché.
        Text(
          row.platform,
          style: theme.body.copyWith(color: theme.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(width: 12),
        Text(
          '${row.volume}',
          style: theme.label.copyWith(color: theme.textPrimary),
          maxLines: 1,
        ),
      ],
    );
  }
}
