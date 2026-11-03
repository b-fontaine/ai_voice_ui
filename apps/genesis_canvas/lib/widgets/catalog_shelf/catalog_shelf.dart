import 'package:feature_catalog_shelf/feature_catalog_shelf.dart'
    show CatalogShelfBloc, CatalogShelfState, ShelfComponent;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_design_system/shared_design_system.dart'
    show
        SceneMotion,
        SceneOneShot,
        SceneRadius,
        ScenePanel,
        SceneShadow,
        SceneTheme;

/// Étagère du catalogue (FR-06) : « CATALOGUE · n / 6 utilisés » puis une
/// pastille `shelf-Composant` par composant, au nom entier. L'état est porté
/// par une icône (carré plein pour « utilisé », carré vide pour « inutilisé »)
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
          // Fond : décoration de panneau du design system, sœur du contenu.
          return ScenePanel(
            inset: 0,
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
          );
        },
      ),
    );
  }
}

/// Puce `gc-chip` du design system : 30 points de haut, rayon `sm`, bordure de
/// 1 point, carré d'état de 8 points (plein si utilisée) puis le nom en
/// `micro.chip`.
///
/// Le texte inutilisé est en `ink-muted`, jamais `ink-faint` (F12 : moins de
/// 24 px). La première utilisation joue la lueur `gc-flash` (1,2 s, pic à 40 %,
/// pdr-0088 F9 niveau A) ; sous `disableAnimations`, au premier affichage et à
/// la remise à vide, la puce est d'emblée à son état final, sans lueur.
class _Pill extends StatefulWidget {
  const _Pill({required this.component});

  final ShelfComponent component;

  /// Hauteur de la puce.
  static const double height = 30;

  /// Taille de l'icône : le carré de 8 points occupe 18/24 de sa boîte.
  static const double iconSize = 11;

  @override
  State<_Pill> createState() => _PillState();
}

class _PillState extends State<_Pill>
    with SingleTickerProviderStateMixin<_Pill>, SceneOneShot<_Pill> {
  /// Une lueur éteinte vaut 1 : la puce démarre à son état final.
  @override
  double get oneShotInitialValue => 1;

  @override
  Duration get oneShotBase => SceneMotion.flash;

  @override
  void didUpdateWidget(_Pill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.component.used && widget.component.used) playOneShot();
  }

  /// Pic de la lueur (`gc-flash` : 40 % de la durée).
  static const double _peak = 0.4;

  /// Lueur à l'instant [t] (0 à 1) de l'animation `gc-flash` : de l'ombre
  /// nulle `signal` (0 %) à la lueur `glow-signal` (40 %), puis plus rien.
  List<BoxShadow>? _glow(SceneTheme theme, double t) {
    if (t >= 1) return null;
    if (t < _peak) {
      return BoxShadow.lerpList(
        <BoxShadow>[BoxShadow(color: theme.accent)],
        SceneShadow.glowSignal,
        t / _peak,
      );
    }
    return BoxShadow.lerpList(
      SceneShadow.glowSignal,
      null,
      (t - _peak) / (1 - _peak),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final ShelfComponent component = widget.component;
    final bool used = component.used;
    final Color foreground = used ? theme.accent : theme.textSecondary;
    final TextStyle style = theme.micro.chip.copyWith(color: foreground);
    final Border border = Border.all(
      color: used ? theme.accent.withValues(alpha: 1 / 3) : theme.line,
    );
    return Semantics(
      key: Key('shelf-${component.name}'),
      container: true,
      label: '${component.name}, ${used ? 'utilisé' : 'inutilisé'}',
      excludeSemantics: true,
      // La lueur se repeint seule : elle ne dérange pas le reste de l'écran.
      child: RepaintBoundary(
        child: SizedBox(
          height: _Pill.height,
          child: AnimatedBuilder(
            animation: oneShot,
            builder: (BuildContext context, Widget? child) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: used ? theme.signalGhost : theme.surface,
                  borderRadius: SceneRadius.borderSm,
                  border: border,
                  boxShadow: _glow(theme, oneShot.value),
                ),
                child: child,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: <Widget>[
                  Icon(
                    used ? Icons.square : Icons.square_outlined,
                    size: _Pill.iconSize,
                    color: foreground,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      component.name,
                      style: style,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
