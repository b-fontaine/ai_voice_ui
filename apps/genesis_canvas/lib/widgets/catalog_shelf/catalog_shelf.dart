import 'package:feature_catalog_shelf/feature_catalog_shelf.dart'
    show CatalogShelfBloc, CatalogShelfState, ShelfComponent;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_design_system/shared_design_system.dart' show SceneTheme;

/// Étagère du catalogue (FR-06) : « CATALOGUE · n / 6 utilisés » puis une
/// pastille `shelf-Composant` par composant, au nom entier. L'état est porté
/// par une icône (coche pleine pour « utilisé », cercle vide pour « inutilisé »)
/// et par la sémantique (« nom, utilisé » ou « nom, inutilisé ») ; la
/// couleur n'est qu'un renfort, et le compte reste dans l'en-tête.
///
/// Six pastilles sur deux rangées de trois, de largeur égale, dans 900 x 140 px
/// (budget des zones). Le texte « utilisé » / « inutilisé » n'est plus écrit :
/// trois colonnes de 290 px ne tiennent pas le nom entier à 24 px plus ce mot.
class CatalogShelf extends StatelessWidget {
  const CatalogShelf({super.key = const Key('catalog-shelf')});

  /// Pastilles par rangée.
  static const int perRow = 3;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: BlocBuilder<CatalogShelfBloc, CatalogShelfState>(
        builder: (BuildContext context, CatalogShelfState state) {
          final List<ShelfComponent> items = state.components;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        'CATALOGUE ·',
                        style: theme.label.copyWith(color: theme.accent),
                        maxLines: 1,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${state.usedCount} / ${state.total} utilisés',
                          style: theme.label.copyWith(color: theme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (int start = 0; start < items.length; start += perRow)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: <Widget>[
                          for (
                            int i = start;
                            i < start + perRow && i < items.length;
                            i++
                          ) ...<Widget>[
                            if (i > start) const SizedBox(width: 8),
                            Expanded(child: _Pill(component: items[i])),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.component});

  final ShelfComponent component;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final bool used = component.used;
    final Color background = used
        ? theme.okBackground
        : theme.neutralBackground;
    final Color foreground = used
        ? theme.okForeground
        : theme.neutralForeground;
    final TextStyle style = theme.label.copyWith(color: foreground);
    return Semantics(
      key: Key('shelf-${component.name}'),
      container: true,
      label: '${component.name}, ${used ? 'utilisé' : 'inutilisé'}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: <Widget>[
              Icon(
                used ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 24,
                color: foreground,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(component.name, style: style, maxLines: 1)),
            ],
          ),
        ),
      ),
    );
  }
}
