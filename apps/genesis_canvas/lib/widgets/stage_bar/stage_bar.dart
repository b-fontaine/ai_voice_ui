import 'package:feature_agent_activity/feature_agent_activity.dart'
    show AgentActivityBloc, AgentActivityState;
import 'package:feature_replay/feature_replay.dart'
    show ReplayActive, ReplayBloc, ReplayDirectPressed, ReplayState;
import 'package:feature_stage_controls/feature_stage_controls.dart'
    show StageActAdvanced, StageBloc, StageState;
import 'package:feature_voice_session/feature_voice_session.dart'
    show
        Active,
        Interrupted,
        OrbPhase,
        OrbPhaseBloc,
        VoiceSessionBloc,
        VoiceSessionStatus;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_design_system/shared_design_system.dart'
    show SceneTheme, sceneTextStyle;

/// Régie de scène : l'indicateur d'acte (D1), la remise à vide (D4), le
/// micro et « Faire taire » (014).
///
/// Disposition (014, T13) : deux colonnes de largeur égale ([columnWidth])
/// côte à côte, chacune de deux lignes, dans les 104 points utiles de la
/// barre du haut (48 + 4 + 48) :
///
/// | micro (`mic-button`)       | indicateur d'acte (`act-indicator`) |
/// | « Faire taire » (`silence-button`) | « Remettre à vide » (`reset-button`) |
///
/// - `act-indicator` : « Acte n/3 · nom » ; un clic passe à l'acte suivant
///   (cyclique), souris d'abord (pdr-0033) ;
/// - `reset-button` : « Remettre à vide » ; il n'agit pas lui-même, il appelle
///   [onResetPressed] (la page coordonne tous les Blocs, A4a du plan 007).
///   Inactif tant qu'un agent travaille : le backend refuserait (409) de
///   retirer des surfaces en cours de fabrication ;
/// - `mic-button` : « Couper le micro » ou « Rétablir le micro » selon
///   `Active.micMuted` ; actif seulement en session `Active` ; il appelle
///   [onMicPressed] (la page calcule la valeur cible) ;
/// - `silence-button` : « Faire taire » ; actif en session `Active` tant que
///   l'orbe n'est pas `Interrupted` (idempotent) ; il appelle
///   [onSilencePressed].
///
/// Les contrôles sont hauts d'au moins [controlHeight] points sous Linux
/// (NFR-05) : `visualDensity` standard et `minimumSize` explicites, sans quoi
/// la densité de la plateforme réduirait la cible. Texte de scène (24 px et
/// plus, RG-09), bordure du thème de scène et `Semantics` de bouton.
///
/// En rejeu (`ReplayActive`, pdr-0066 D3 et D8) : l'indicateur affiche
/// « Acte 4 · Rejeu » en texte seul (non cliquable) et « Remettre à vide »
/// équivaut à « Direct » (`ReplayDirectPressed`), toujours actif.
class StageBar extends StatelessWidget {
  const StageBar({
    super.key,
    required this.onResetPressed,
    required this.onSilencePressed,
    required this.onMicPressed,
  });

  final VoidCallback onResetPressed;
  final VoidCallback onSilencePressed;
  final VoidCallback onMicPressed;

  /// Largeur de chaque colonne : le libellé le plus long (« Acte 2/3 ·
  /// Transformer », 28 px) y tient en entier.
  static const double columnWidth = 480;

  /// Écart entre les deux colonnes.
  static const double columnGap = 8;

  /// Largeur totale de la régie.
  static const double width = 2 * columnWidth + columnGap;

  /// Hauteur minimale de chaque contrôle (cible de pointage, NFR-05).
  static const double controlHeight = 48;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    // Le style d'un bouton Material remplace celui de l'ambiance : sans cela,
    // les deux contrôles se rendraient dans la police par défaut du moteur et
    // non dans celle du reste de la scène.
    final TextStyle actStyle = sceneTextStyle(context, theme.actIndicator);
    final TextStyle resetStyle = sceneTextStyle(context, theme.label);
    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        width: width,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: columnWidth,
              child: _VoiceControls(
                onSilencePressed: onSilencePressed,
                onMicPressed: onMicPressed,
              ),
            ),
            const SizedBox(width: columnGap),
            SizedBox(
              width: columnWidth,
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
                                    side: BorderSide(
                                      color: theme.accent,
                                      width: 2,
                                    ),
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
                          BlocSelector<
                            AgentActivityBloc,
                            AgentActivityState,
                            bool
                          >(
                            selector: (AgentActivityState state) =>
                                state.anyBusy,
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
                                  style: _neutralStyle(theme, resetStyle),
                                  child: const Text(
                                    'Remettre à vide',
                                    maxLines: 1,
                                  ),
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
          ],
        ),
      ),
    );
  }
}

/// Style commun des boutons neutres de la régie : fond de scène, texte
/// principal, bordure neutre (A5, C3), actif comme inactif.
ButtonStyle _neutralStyle(SceneTheme theme, TextStyle textStyle) =>
    FilledButton.styleFrom(
      backgroundColor: theme.neutralBackground,
      foregroundColor: theme.textPrimary,
      textStyle: textStyle,
      visualDensity: VisualDensity.standard,
      minimumSize: const Size(StageBar.controlHeight, StageBar.controlHeight),
      side: BorderSide(color: theme.actionNeutralBorder, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      // Inactif mais lisible : paire neutre du thème.
      disabledBackgroundColor: theme.neutralBackground,
      disabledForegroundColor: theme.neutralForeground,
    );

/// Colonne « voix » : micro et « Faire taire ». Les boutons n'agissent pas
/// eux-mêmes : la page porte les commandes.
class _VoiceControls extends StatelessWidget {
  const _VoiceControls({
    required this.onSilencePressed,
    required this.onMicPressed,
  });

  final VoidCallback onSilencePressed;
  final VoidCallback onMicPressed;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final ButtonStyle style = _neutralStyle(
      theme,
      sceneTextStyle(context, theme.label),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BlocSelector<VoiceSessionBloc, VoiceSessionStatus, (bool, bool)>(
          selector: (VoiceSessionStatus status) =>
              (status is Active, status is Active && status.micMuted),
          builder: (BuildContext context, (bool, bool) state) {
            final (bool active, bool muted) = state;
            final String label = muted
                ? 'Rétablir le micro'
                : 'Couper le micro';
            return Semantics(
              button: true,
              enabled: active,
              label: label,
              excludeSemantics: true,
              child: FilledButton(
                key: const Key('mic-button'),
                onPressed: active ? onMicPressed : null,
                style: style,
                child: Text(label, maxLines: 1),
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        BlocSelector<VoiceSessionBloc, VoiceSessionStatus, bool>(
          selector: (VoiceSessionStatus status) => status is Active,
          builder: (BuildContext context, bool active) {
            return BlocSelector<OrbPhaseBloc, OrbPhase, bool>(
              selector: (OrbPhase phase) => phase is Interrupted,
              builder: (BuildContext context, bool interrupted) {
                final bool enabled = active && !interrupted;
                return Semantics(
                  button: true,
                  enabled: enabled,
                  label: 'Faire taire',
                  excludeSemantics: true,
                  child: FilledButton(
                    key: const Key('silence-button'),
                    onPressed: enabled ? onSilencePressed : null,
                    style: style,
                    child: const Text('Faire taire', maxLines: 1),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
