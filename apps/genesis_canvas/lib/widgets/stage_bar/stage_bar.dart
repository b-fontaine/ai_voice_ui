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
        canSilence,
        OrbPhase,
        OrbPhaseBloc,
        VoiceSessionBloc,
        VoiceSessionStatus;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_design_system/shared_design_system.dart'
    show SceneRadius, SceneTheme, sceneTargetStyle, sceneTextStyle;

import '../top_bar/sm_button.dart';

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
/// - `act-indicator` : un seul bouton à apparence de trois segments
///   `act-segment-1` à `-3` (« 01 ✓ Créer », « 02 ✓ Transformer »,
///   « 03 Interagir », pdr-0088 F8) ; son texte accessible reste « Acte n/3 ·
///   nom » ; un clic, où qu'il tombe, passe à l'acte suivant (cyclique), souris
///   d'abord (pdr-0033) ;
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
/// Les cibles de pointage sont hautes d'au moins [controlHeight] points sous
/// Linux (NFR-05, D-05) : `visualDensity` standard et `minimumSize`
/// explicites, sans quoi la densité de la plateforme réduirait la cible. Le
/// visuel de 34 points (`gc-btn--sm`, `SmButton`) ou la pilule des actes est
/// centré dans sa cible. `Semantics` de bouton.
///
/// En rejeu (`ReplayActive`, pdr-0066 D3 et D8) : l'indicateur affiche le seul
/// segment « Acte 4 · Rejeu » (non cliquable) et « Remettre à vide » équivaut
/// à « Direct » (`ReplayDirectPressed`), toujours actif.
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
                                  style: _targetStyle(SceneTheme.of(context)),
                                  child: _ActSegments(
                                    act: stage.act,
                                    label: label,
                                    replaying: replaying,
                                  ),
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
                              return SmButton(
                                buttonKey: const Key('reset-button'),
                                visualKey: const Key('reset-button-visual'),
                                label: 'Remettre à vide',
                                ghost: true,
                                onPressed: replaying
                                    ? () => context.read<ReplayBloc>().add(
                                        const ReplayDirectPressed(),
                                      )
                                    : (working ? null : onResetPressed),
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

/// Style de la cible de l'indicateur d'acte : cible transparente de
/// [StageBar.controlHeight] points (`sceneTargetStyle`, anneau de focus
/// `signal`), forme de pilule. Texte seul en rejeu : pas de teinte « inactif ».
ButtonStyle _targetStyle(SceneTheme theme) {
  return sceneTargetStyle(
    theme,
    shape: RoundedRectangleBorder(borderRadius: SceneRadius.borderPill),
    height: StageBar.controlHeight,
  ).copyWith(foregroundColor: WidgetStatePropertyAll<Color>(theme.textPrimary));
}

/// Sélecteur d'actes (`.gc-acts`) : pilule `surface-100` à bordure `line`,
/// trois segments de 34 points (`.gc-act`) : « 01 ✓ Créer », « 02 ✓
/// Transformer », « 03 Interagir ». Fait : numéro `go` avec ✓, mot `ink-muted`
/// ; actif : fond `plasma-ghost`, contour `plasma` à 53 %, numéro `plasma`,
/// mot `ink` ; à venir : numéro et mot `ink-muted` (jamais `ink-faint`,
/// pdr-0088 F12). Les mots sont ceux de `StageState.actName`.
///
/// En rejeu ([replaying]), un seul segment « Acte 4 · Rejeu » au style
/// `actIndicator`. Le libellé complet (« Acte n/3 · nom ») est porté par le
/// `Semantics` du bouton, que lisent aussi les tests.
class _ActSegments extends StatelessWidget {
  const _ActSegments({
    required this.act,
    required this.label,
    required this.replaying,
  });

  final int act;
  final String label;
  final bool replaying;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return SizedBox(
      height: SmButton.visualHeight + 10,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: SceneRadius.borderPill,
          border: Border.all(color: theme.line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          // Les polices de la scène tiennent dans la colonne ; le repli
          // réduit la pilule plutôt que de déborder avec une autre police.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (replaying)
                  _Segment(
                    key: const Key('act-segment-replay'),
                    active: true,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: sceneTextStyle(
                        context,
                        theme.actIndicator,
                      ).copyWith(color: theme.textPrimary),
                    ),
                  )
                else ...<Widget>[
                  for (var i = 1; i <= StageState.actCount; i++) ...<Widget>[
                    if (i > 1) const SizedBox(width: 4),
                    _actSegment(context, theme, i),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actSegment(BuildContext context, SceneTheme theme, int n) {
    final bool done = n < act;
    final bool active = n == act;
    final Color numberColor = done
        ? theme.okForeground
        : active
        ? theme.plasma
        : theme.textSecondary;
    final Color wordColor = active ? theme.textPrimary : theme.textSecondary;
    final String number = n.toString().padLeft(2, '0');
    return _Segment(
      key: Key('act-segment-$n'),
      active: active,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            done ? '$number ✓' : number,
            maxLines: 1,
            style: sceneTextStyle(
              context,
              theme.micro.segmentNo,
            ).copyWith(color: numberColor),
          ),
          const SizedBox(width: 8),
          Text(
            StageState.actNames[n - 1],
            maxLines: 1,
            style: sceneTextStyle(
              context,
              theme.micro.segment,
            ).copyWith(color: wordColor),
          ),
        ],
      ),
    );
  }
}

/// Un segment de 34 points (`.gc-act`) ; actif, il a le fond `plasma-ghost` et
/// le contour `plasma`.
class _Segment extends StatelessWidget {
  const _Segment({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return SizedBox(
      height: SmButton.visualHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: active ? theme.plasmaGhost : null,
          borderRadius: SceneRadius.borderPill,
          border: active ? Border.all(color: theme.plasmaOutline) : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Center(widthFactor: 1, child: child),
        ),
      ),
    );
  }
}

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BlocSelector<VoiceSessionBloc, VoiceSessionStatus, (bool, bool)>(
          selector: (VoiceSessionStatus status) =>
              (status is Active, status is Active && status.micMuted),
          builder: (BuildContext context, (bool, bool) state) {
            final (bool active, bool muted) = state;
            return SmButton(
              buttonKey: const Key('mic-button'),
              visualKey: const Key('mic-button-visual'),
              label: muted ? 'Rétablir le micro' : 'Couper le micro',
              // Point d'enregistrement : le micro est ouvert.
              recording: active && !muted,
              onPressed: active ? onMicPressed : null,
            );
          },
        ),
        const SizedBox(height: 4),
        BlocBuilder<VoiceSessionBloc, VoiceSessionStatus>(
          buildWhen: (
            VoiceSessionStatus previous,
            VoiceSessionStatus current,
          ) => (previous is Active) != (current is Active),
          builder: (BuildContext context, VoiceSessionStatus status) {
            return BlocBuilder<OrbPhaseBloc, OrbPhase>(
              buildWhen: (OrbPhase previous, OrbPhase current) =>
                  (previous is Interrupted) != (current is Interrupted),
              builder: (BuildContext context, OrbPhase phase) {
                return SmButton(
                  buttonKey: const Key('silence-button'),
                  visualKey: const Key('silence-button-visual'),
                  label: 'Faire taire',
                  ghost: true,
                  onPressed: canSilence(status, phase)
                      ? onSilencePressed
                      : null,
                );
              },
            );
          },
        ),
      ],
    );
  }
}
