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
/// En rejeu (`ReplayActive`, pdr-0066 D3 et D8) : l'indicateur affiche
/// « Acte 4 · Rejeu » en texte seul (non cliquable) et « Remettre à vide »
/// équivaut à « Direct » (`ReplayDirectPressed`), toujours actif.
class StageBar extends StatelessWidget {
  const StageBar({super.key, required this.onResetPressed});

  final VoidCallback onResetPressed;

  /// Largeur maximale : au-delà, les libellés s'abrègent avec une ellipse.
  static const double maxWidth = 520;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
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
                      builder: (BuildContext context, StageState stage) =>
                          TextButton(
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
                              textStyle: theme.actIndicator,
                              minimumSize: const Size(0, 44),
                            ),
                            child: Text(
                              replaying
                                  ? 'Acte 4 · Rejeu'
                                  : 'Acte ${stage.act}/${StageState.actCount} · '
                                        '${stage.actName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                    ),
                    const SizedBox(height: 4),
                    BlocSelector<AgentActivityBloc, AgentActivityState, bool>(
                      selector: (AgentActivityState state) => state.anyBusy,
                      builder: (BuildContext context, bool working) =>
                          FilledButton(
                            key: const Key('reset-button'),
                            onPressed: replaying
                                ? () => context.read<ReplayBloc>().add(
                                    const ReplayDirectPressed(),
                                  )
                                : (working ? null : onResetPressed),
                            style: FilledButton.styleFrom(
                              textStyle: theme.label,
                              minimumSize: const Size(0, 44),
                              // Inactif mais lisible : paire neutre du thème.
                              disabledBackgroundColor: theme.neutralBackground,
                              disabledForegroundColor: theme.neutralForeground,
                            ),
                            child: const Text(
                              'Remettre à vide',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
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
