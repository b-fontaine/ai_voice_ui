import 'package:feature_agent_activity/feature_agent_activity.dart'
    show AgentActivityBloc, AgentActivityState;
import 'package:feature_voice_session/feature_voice_session.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_design_system/shared_design_system.dart' show SceneTheme;

import 'voice_failure_message.dart';
import 'voice_orb.dart';

export 'voice_failure_message.dart' show voiceFailureMessage;
export 'voice_orb.dart' show VoiceOrb;

/// Barre du haut : orbe, transcription (deux lignes), message d'état, régie
/// de scène ([stage] : indicateur d'acte et remise à vide, D1) et bouton
/// Démarrer/Arrêter.
///
/// Hauteur fixe [height] (budget des zones à 1920 × 1080) et texte du thème de
/// scène (>= 24 px, RG-09) ; les lignes s'abrègent avec une ellipse.
///
/// Elle lit les Blocs fournis plus haut (`VoiceSessionBloc`, `TranscriptBloc`,
/// `AgentActivityBloc`, `OrbPhaseBloc`) et leur envoie les commandes. Le niveau de l'orbe
/// ([orbLevel]) va directement au painter : le changer ne reconstruit pas la
/// barre (NFR-04).
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.orbLevel,
    this.speakingThreshold = 0.03,
    this.startEnabled = true,
    this.stage,
  });

  /// Hauteur de la zone (A7b du plan 007).
  static const double height = 128;

  final ValueListenable<double> orbLevel;

  /// Régie de scène (indicateur d'acte, remise à vide), posée entre la
  /// transcription et le bouton de session ; `null` : aucune.
  final Widget? stage;
  final double speakingThreshold;

  /// `false` : « Démarrer » reste affiché mais désactivé (mode scénario, où
  /// la source vivante n'est pas branchée).
  final bool startEnabled;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: BlocBuilder<VoiceSessionBloc, VoiceSessionStatus>(
          builder: (context, status) => Row(
            children: <Widget>[
              BlocBuilder<AgentActivityBloc, AgentActivityState>(
                buildWhen: (previous, current) =>
                    previous.anyWorking != current.anyWorking,
                builder: (context, agents) =>
                    BlocBuilder<OrbPhaseBloc, OrbPhase>(
                      builder: (context, phase) => VoiceOrb(
                        level: orbLevel,
                        thinking: status is Active && agents.anyWorking,
                        interrupted: status is Active && phase is Interrupted,
                        listening: status is Active && phase is Listening,
                        speakingThreshold: speakingThreshold,
                      ),
                    ),
              ),
              const SizedBox(width: 16),
              Expanded(child: _Details(status: status)),
              if (stage case final Widget stage) ...<Widget>[
                const SizedBox(width: 16),
                stage,
              ],
              const SizedBox(width: 16),
              _SessionButton(status: status, startEnabled: startEnabled),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Details extends StatelessWidget {
  const _Details({required this.status});

  final VoiceSessionStatus status;

  String? get _message => switch (status) {
    Failed(:final failure) => voiceFailureMessage(failure),
    Connecting() => 'Connexion…',
    Stopping() => 'Arrêt…',
    Idle() || Active() => null,
  };

  @override
  Widget build(BuildContext context) {
    final message = _message;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        BlocBuilder<TranscriptBloc, TranscriptState>(
          builder: (context, transcript) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _TranscriptLine(
                key: const Key('transcript-user'),
                role: 'Vous',
                text: transcript.userLine,
                maxLines: 1,
              ),
              _TranscriptLine(
                key: const Key('transcript-ai'),
                role: 'IA',
                text: transcript.aiLine,
                maxLines: 2,
              ),
            ],
          ),
        ),
        if (message != null)
          Padding(
            key: const Key('status-message'),
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              message,
              style: SceneTheme.of(context).body
                  .copyWith(color: SceneTheme.of(context).riskForeground),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

class _TranscriptLine extends StatelessWidget {
  const _TranscriptLine({
    super.key,
    required this.role,
    required this.text,
    required this.maxLines,
  });

  final String role;
  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = SceneTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(role, style: theme.label, maxLines: 1),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.body,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SessionButton extends StatelessWidget {
  const _SessionButton({required this.status, required this.startEnabled});

  final VoiceSessionStatus status;
  final bool startEnabled;

  @override
  Widget build(BuildContext context) => switch (status) {
    Idle() || Failed() => FilledButton(
      key: const Key('start-button'),
      style: _buttonStyle(context),
      onPressed: startEnabled
          ? () => context.read<VoiceSessionBloc>().add(
              const VoiceSessionStarted(),
            )
          : null,
      child: const Text('Démarrer'),
    ),
    Connecting() || Active() => FilledButton(
      key: const Key('stop-button'),
      style: _buttonStyle(context),
      onPressed: () =>
          context.read<VoiceSessionBloc>().add(const VoiceSessionStopped()),
      child: const Text('Arrêter'),
    ),
    Stopping() => FilledButton(
      key: const Key('stop-button'),
      style: _buttonStyle(context),
      onPressed: null,
      child: const Text('Arrêter'),
    ),
  };

  /// Texte du bouton au format de la scène (>= 24 px).
  static ButtonStyle _buttonStyle(BuildContext context) =>
      FilledButton.styleFrom(textStyle: SceneTheme.of(context).label);
}
