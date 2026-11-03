import 'package:feature_agent_activity/feature_agent_activity.dart'
    show AgentActivityBloc, AgentActivityState;

import 'dart:async';

import 'package:feature_voice_session/feature_voice_session.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_design_system/shared_design_system.dart'
    show DsBlink, DsCaps, SceneMotion, SceneTheme;

import 'sm_button.dart';
import 'voice_failure_message.dart';
import 'voice_orb.dart';
import 'voice_wave.dart';

export 'voice_failure_message.dart' show voiceFailureMessage;
export 'voice_orb.dart' show VoiceOrb;

/// Barre du haut (barre vocale du design system) : orbe à anneaux,
/// transcription « VOUS » / « IA » (deux lignes, curseur) avec l'onde de la
/// voix de l'IA dessous, message d'état, régie de scène ([stage] : sélecteur
/// d'actes, micro, « Faire taire » et remise à vide, D1) et bouton
/// Démarrer/Arrêter.
///
/// Hauteur fixe [height] (budget des zones à 1920 × 1080) et texte du thème de
/// scène ; les lignes s'abrègent avec une ellipse. L'emplacement de l'onde
/// (28 points) est réservé même quand l'IA se tait, sauf si un message d'état
/// le prend.
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
        // La hauteur utile (116 points) loge les deux lignes de l'IA et l'onde.
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: BlocBuilder<VoiceSessionBloc, VoiceSessionStatus>(
          builder: (context, status) => Row(
            children: <Widget>[
              BlocBuilder<AgentActivityBloc, AgentActivityState>(
                buildWhen: (previous, current) =>
                    previous.anyWorking != current.anyWorking,
                builder: (context, agents) =>
                    BlocBuilder<OrbPhaseBloc, OrbPhase>(
                      // Seule l'interruption change l'orbe : la distinction
                      // parole/écoute vient du niveau lissé (NFR-04).
                      buildWhen: (previous, current) =>
                          (previous is Interrupted) != (current is Interrupted),
                      builder: (context, phase) => VoiceOrb(
                        level: orbLevel,
                        thinking: status is Active && agents.anyWorking,
                        interrupted: status is Active && phase is Interrupted,
                        listening: status is Active,
                        micMuted: status is Active && status.micMuted,
                        speakingThreshold: speakingThreshold,
                      ),
                    ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _Details(
                  status: status,
                  orbLevel: orbLevel,
                  speakingThreshold: speakingThreshold,
                ),
              ),
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
  const _Details({
    required this.status,
    required this.orbLevel,
    required this.speakingThreshold,
  });

  final VoiceSessionStatus status;
  final ValueListenable<double> orbLevel;
  final double speakingThreshold;

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
                whoKey: const Key('transcript-user-who'),
                role: 'Vous',
                text: transcript.userLine,
                maxLines: 1,
              ),
              _CaretWhileWriting(
                text: transcript.aiLine,
                builder: (context, writing) => _TranscriptLine(
                  key: const Key('transcript-ai'),
                  whoKey: const Key('transcript-ai-who'),
                  role: 'IA',
                  ai: true,
                  text: transcript.aiLine,
                  // Avec un message d'état, la zone loge peu de lignes : la
                  // réplique de l'IA s'abrège.
                  maxLines: message == null ? 2 : 1,
                  showCaret: writing,
                ),
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
          )
        else
          // Aligné sur le texte : colonne de l'étiquette (52) et écart (8).
          Padding(
            padding: const EdgeInsets.only(left: _TranscriptLine.whoWidth + 8),
            child: VoiceWave(
              level: orbLevel,
              speakingThreshold: speakingThreshold,
            ),
          ),
      ],
    );
  }
}

/// Une ligne de transcription (`.gc-transcript p`) : grille étiquette de 52
/// points | texte. L'étiquette « VOUS » ou « IA » (`.who`, micro-style
/// `quoteMeta`) est mise en capitales à l'affichage seulement ([DsCaps]) ; son
/// `Semantics` garde la casse d'origine (« Vous »). Le texte, lui, n'est jamais
/// transformé.
class _TranscriptLine extends StatelessWidget {
  const _TranscriptLine({
    super.key,
    required this.whoKey,
    required this.role,
    required this.text,
    required this.maxLines,
    this.ai = false,
    this.showCaret = false,
  });

  /// Largeur de la colonne de l'étiquette.
  static const double whoWidth = 52;

  final Key whoKey;
  final String role;
  final String text;
  final int maxLines;

  /// Ligne de l'IA : étiquette en `plasma` (sinon `ink-muted`).
  final bool ai;

  /// Curseur de saisie derrière le texte (l'IA écrit sa réplique).
  final bool showCaret;

  @override
  Widget build(BuildContext context) {
    final theme = SceneTheme.of(context);
    final double lineHeight =
        theme.transcript.fontSize! * theme.transcript.height!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: whoWidth,
          height: lineHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: DsCaps(
              role,
              key: whoKey,
              style: theme.micro.quoteMeta.copyWith(
                color: ai ? theme.plasma : theme.textSecondary,
              ),
              maxLines: 1,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Flexible(
                child: Text(
                  text,
                  style: theme.transcript,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showCaret) _Caret(height: theme.transcript.fontSize!),
            ],
          ),
        ),
      ],
    );
  }
}

/// Curseur de saisie (`.caret::after`) : barre de 2 points, `plasma`, de la
/// hauteur du texte, posée contre le bas de la dernière ligne. Il clignote
/// (`gc-blink` .9 s, `DsBlink`, pdr-0088 F9, T34) tant qu'il est affiché,
/// c'est-à-dire tant que la réplique s'écrit et 1,2 s après ; plein au repos.
class _Caret extends StatelessWidget {
  const _Caret({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 4),
    child: DsBlink(
      period: SceneMotion.caretBlink,
      child: DecoratedBox(
        key: const Key('transcript-ai-caret'),
        decoration: BoxDecoration(color: SceneTheme.of(context).plasma),
        child: SizedBox(width: 2, height: height),
      ),
    ),
  );
}

/// Dit à [builder] si l'IA est en train d'écrire sa réplique : vrai dès que le
/// texte change, et jusqu'à [SceneMotion.caretHold] après la dernière modification (le curseur
/// reste un instant, comme dans le design system).
class _CaretWhileWriting extends StatefulWidget {
  const _CaretWhileWriting({required this.text, required this.builder});

  final String text;
  final Widget Function(BuildContext context, bool writing) builder;

  @override
  State<_CaretWhileWriting> createState() => _CaretWhileWritingState();
}

class _CaretWhileWritingState extends State<_CaretWhileWriting> {
  Timer? _timer;
  bool _writing = false;

  @override
  void didUpdateWidget(_CaretWhileWriting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text && widget.text.isNotEmpty) {
      _writing = true;
      _timer?.cancel();
      _timer = Timer(SceneMotion.caretHold, () {
        if (mounted) setState(() => _writing = false);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _writing);
}

class _SessionButton extends StatelessWidget {
  const _SessionButton({required this.status, required this.startEnabled});

  final VoiceSessionStatus status;
  final bool startEnabled;

  @override
  Widget build(BuildContext context) => switch (status) {
    Idle() || Failed() => SmButton(
      buttonKey: const Key('start-button'),
      visualKey: const Key('start-button-visual'),
      label: 'Démarrer',
      onPressed: startEnabled
          ? () => context.read<VoiceSessionBloc>().add(
              const VoiceSessionStarted(),
            )
          : null,
    ),
    Connecting() || Active() => SmButton(
      buttonKey: const Key('stop-button'),
      visualKey: const Key('stop-button-visual'),
      label: 'Arrêter',
      onPressed: () =>
          context.read<VoiceSessionBloc>().add(const VoiceSessionStopped()),
    ),
    Stopping() => const SmButton(
      buttonKey: Key('stop-button'),
      visualKey: Key('stop-button-visual'),
      label: 'Arrêter',
      onPressed: null,
    ),
  };
}
