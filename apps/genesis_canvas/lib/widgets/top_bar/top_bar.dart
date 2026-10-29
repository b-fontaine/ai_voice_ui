import 'package:feature_agent_activity/feature_agent_activity.dart'
    show AgentActivityBloc, AgentActivityState;
import 'package:feature_voice_session/feature_voice_session.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'voice_failure_message.dart';
import 'voice_orb.dart';

export 'voice_failure_message.dart' show voiceFailureMessage;
export 'voice_orb.dart' show VoiceOrb;

/// Barre du haut : orbe, transcription (deux lignes), message d'état et
/// bouton Démarrer/Arrêter.
///
/// Elle lit les Blocs fournis plus haut (`VoiceSessionBloc`, `TranscriptBloc`,
/// `AgentActivityBloc`) et leur envoie les commandes. Le niveau de l'orbe
/// ([orbLevel]) va directement au painter : le changer ne reconstruit pas la
/// barre (NFR-04).
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.orbLevel,
    this.speakingThreshold = 0.03,
  });

  final ValueListenable<double> orbLevel;
  final double speakingThreshold;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: BlocBuilder<VoiceSessionBloc, VoiceSessionStatus>(
        builder: (context, status) => Row(
          children: <Widget>[
            BlocBuilder<AgentActivityBloc, AgentActivityState>(
              buildWhen: (previous, current) =>
                  previous.anyWorking != current.anyWorking,
              builder: (context, agents) => VoiceOrb(
                level: orbLevel,
                thinking: status is Active && agents.anyWorking,
                speakingThreshold: speakingThreshold,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: _Details(status: status)),
            const SizedBox(width: 16),
            _SessionButton(status: status),
          ],
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
              ),
              _TranscriptLine(
                key: const Key('transcript-ai'),
                role: 'IA',
                text: transcript.aiLine,
              ),
            ],
          ),
        ),
        if (message != null)
          Padding(
            key: const Key('status-message'),
            padding: const EdgeInsets.only(top: 4),
            child: Text(message, style: const TextStyle(color: Colors.amber)),
          ),
      ],
    );
  }
}

class _TranscriptLine extends StatelessWidget {
  const _TranscriptLine({super.key, required this.role, required this.text});

  final String role;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Text(role, style: const TextStyle(color: Colors.white54)),
      const SizedBox(width: 8),
      Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis)),
    ],
  );
}

class _SessionButton extends StatelessWidget {
  const _SessionButton({required this.status});

  final VoiceSessionStatus status;

  @override
  Widget build(BuildContext context) => switch (status) {
    Idle() || Failed() => FilledButton(
      key: const Key('start-button'),
      onPressed: () =>
          context.read<VoiceSessionBloc>().add(const VoiceSessionStarted()),
      child: const Text('Démarrer'),
    ),
    Connecting() || Active() => FilledButton(
      key: const Key('stop-button'),
      onPressed: () =>
          context.read<VoiceSessionBloc>().add(const VoiceSessionStopped()),
      child: const Text('Arrêter'),
    ),
    Stopping() => const FilledButton(
      key: Key('stop-button'),
      onPressed: null,
      child: Text('Arrêter'),
    ),
  };
}
