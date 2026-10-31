import 'package:feature_agent_activity/feature_agent_activity.dart'
    show AgentActivityBloc, AgentActivityState;
import 'package:feature_replay/feature_replay.dart'
    show ReplayActive, ReplayBloc, ReplayDirectPressed, ReplayState;
import 'package:feature_stage_controls/feature_stage_controls.dart'
    show StageActAdvanced, StageBloc, StageState;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_design_system/shared_design_system.dart' show SceneTheme;

/// Régie de scène : l'indicateur d'acte (D1) et la remise à vide (D4).
///
/// - `act-indicator` : « Acte n/3 · nom » ; un clic passe à l'acte suivant
///   (cyclique), souris d'abord (pdr-0033) ;
/// - `reset-button` : « Remettre à vide » ; il n'agit pas lui-même, il appelle
///   [onResetPressed] (la page coordonne tous les Blocs, A4a du plan 007).
///   Inactif tant qu'un agent travaille : le backend refuserait (409) de
///   retirer des surfaces en cours de fabrication.
///
/// Les deux contrôles sont empilés, de largeur égale ([width]) et hauts d'au
/// moins [controlHeight] points sous Linux (NFR-05) : `visualDensity` standard
/// et `minimumSize` explicites, sans quoi la densité de la plateforme réduirait
/// la cible. Ils tiennent dans les 104 points utiles de la barre du haut
/// (48 + 4 + 48). Chacun porte une bordure du thème de scène et une
/// `Semantics` de bouton.
///
/// En rejeu (`ReplayActive`, pdr-0066 D3 et D8) : l'indicateur affiche
/// « Acte 4 · Rejeu » en texte seul (non cliquable) et « Remettre à vide »
/// équivaut à « Direct » (`ReplayDirectPressed`), toujours actif.
class StageBar extends StatelessWidget {
  const StageBar({super.key, required this.onResetPressed});

  final VoidCallback onResetPressed;

  /// Largeur des deux contrôles : le libellé le plus long (« Acte 2/3 ·
  /// Transformer », 28 px) y tient en entier.
  static const double width = 520;

  /// Hauteur minimale de chaque contrôle (cible de pointage, NFR-05).
  static const double controlHeight = 48;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    // Le style d'un bouton Material remplace celui de l'ambiance : sans cela,
    // les deux contrôles se rendraient dans la police par défaut du moteur et
    // non dans celle du reste de la scène.
    final TextStyle ambient = DefaultTextStyle.of(context).style;
    final TextStyle actStyle = theme.actIndicator.copyWith(
      fontFamily: ambient.fontFamily,
      fontFamilyFallback: ambient.fontFamilyFallback,
    );
    final TextStyle resetStyle = theme.label.copyWith(
      fontFamily: ambient.fontFamily,
      fontFamilyFallback: ambient.fontFamilyFallback,
    );
    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            BlocSelector<ReplayBloc, ReplayState, bool>(
              selector: (ReplayState replay) => replay is ReplayActive,
              builder: (BuildContext context, bool replaying) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    BlocBuilder<StageBloc, StageState>(
                      builder: (BuildContext context, StageState stage) {
                        final String label = replaying
                            ? 'Acte 4 · Rejeu'
                            : 'Acte ${stage.act}/${StageState.actCount} · '
                                  '${stage.actName}';
                        return Semantics(
                          button: !replaying,
                          enabled: !replaying,
                          label: label,
                          excludeSemantics: true,
                          child: TextButton(
                            key: const Key('act-indicator'),
                            onPressed: replaying
                                ? null
                                : () => context.read<StageBloc>().add(
                                    const StageActAdvanced(),
                                  ),
                            style: TextButton.styleFrom(
                              foregroundColor: theme.accent,
                              // Texte seul en rejeu : pas de teinte « inactif ».
                              disabledForegroundColor: theme.accent,
                              textStyle: actStyle,
                              visualDensity: VisualDensity.standard,
                              minimumSize: const Size(
                                controlHeight,
                                controlHeight,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              side: BorderSide(color: theme.accent, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(label, maxLines: 1),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    BlocSelector<AgentActivityBloc, AgentActivityState, bool>(
                      selector: (AgentActivityState state) => state.anyBusy,
                      builder: (BuildContext context, bool working) {
                        final bool enabled = replaying || !working;
                        return Semantics(
                          button: true,
                          enabled: enabled,
                          label: 'Remettre à vide',
                          excludeSemantics: true,
                          child: FilledButton(
                            key: const Key('reset-button'),
                            onPressed: replaying
                                ? () => context.read<ReplayBloc>().add(
                                    const ReplayDirectPressed(),
                                  )
                                : (working ? null : onResetPressed),
                            style: FilledButton.styleFrom(
                              textStyle: resetStyle,
                              visualDensity: VisualDensity.standard,
                              minimumSize: const Size(
                                controlHeight,
                                controlHeight,
                              ),
                              side: BorderSide(
                                color: theme.actionNeutralBorder,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              // Inactif mais lisible : paire neutre du thème.
                              disabledBackgroundColor: theme.neutralBackground,
                              disabledForegroundColor: theme.neutralForeground,
                            ),
                            child: const Text('Remettre à vide', maxLines: 1),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
