import 'dart:math' as math;

import 'package:feature_replay/feature_replay.dart'
    show
        ReplayActive,
        ReplayBloc,
        ReplayDirectPressed,
        ReplayLive,
        ReplayPausePressed,
        ReplayPlayPressed,
        ReplayRestartPressed,
        ReplaySeeked,
        ReplaySnapshot,
        ReplaySpeedSelected,
        ReplayState,
        ReplayStatus;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_design_system/shared_design_system.dart'
    show DsCaps, SceneRadius, ScenePanel, SceneShadow, SceneTheme;

/// Zone « REJEU » (FR-09, pdr-0066 D4) : deux rangées de 48 px.
///
/// Le panneau du protocole déplié se pose au-dessus de la rangée du bas
/// (pdr-0086) : il ne recouvre pas cette zone. Marges et écarts restent serrés
/// pour que l'étiquette « REJEU » en mono 24 px interlettré tienne sur la
/// rangée.
///
/// - rangée 1 : libellé, Lecture/Pause (un seul bouton), Recommencer, curseur
///   de position, « Direct » ;
/// - rangée 2 : les cinq vitesses.
///
/// En direct, tout est inactif sauf « Lecture » quand un journal jouable
/// existe. Le curseur ne positionne le rejeu qu'au relâché (`onChangeEnd`) :
/// pendant le glisser, seul l'affichage local bouge.
class ReplayBar extends StatelessWidget {
  const ReplayBar({super.key = const Key('replay-bar')});

  /// Largeur prévue par la page (A6 du plan 010).
  static const double width = 480;

  /// Hauteur d'une rangée et taille minimale d'une cible.
  static const double rowHeight = 48;

  /// Libellé d'une vitesse : « 0,25× », « 1× ».
  static String speedLabel(double speed) =>
      '${_speedId(speed).replaceAll('.', ',')}×';

  static String _speedId(double speed) =>
      speed == speed.truncate() ? '${speed.toInt()}' : '$speed';

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final ReplayBloc bloc = context.read<ReplayBloc>();
    return Material(
      type: MaterialType.transparency,
      // Fond : décoration de panneau du design system, sœur du contenu.
      child: ScenePanel(
        inset: 0,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: BlocBuilder<ReplayBloc, ReplayState>(
          builder: (BuildContext context, ReplayState state) {
            final bool live = state is ReplayLive;
            final ReplaySnapshot? snapshot = state is ReplayActive
                ? state.snapshot
                : null;
            final bool playing = snapshot?.status == ReplayStatus.playing;
            final bool canPlay = switch (state) {
              ReplayLive(:final bool canPlay) => canPlay,
              ReplayActive() => true,
            };
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  height: rowHeight,
                  child: Row(
                    children: <Widget>[
                      Text(
                        'REJEU',
                        style: theme.label.copyWith(color: theme.accent),
                        maxLines: 1,
                      ),
                      _PlayButton(
                        playing: playing,
                        onPressed: !canPlay
                            ? null
                            : () => bloc.add(
                                playing
                                    ? const ReplayPausePressed()
                                    : const ReplayPlayPressed(),
                              ),
                      ),
                      _IconTarget(
                        buttonKey: const Key('replay-restart'),
                        visualKey: const Key('replay-restart-visual'),
                        icon: const Icon(
                          Icons.replay,
                          semanticLabel: 'Recommencer',
                        ),
                        onPressed: live
                            ? null
                            : () => bloc.add(const ReplayRestartPressed()),
                      ),
                      Expanded(
                        child: _PositionSlider(
                          snapshot: snapshot,
                          onSeek: (Duration position) =>
                              bloc.add(ReplaySeeked(position)),
                        ),
                      ),
                      _DirectButton(
                        onPressed: live
                            ? null
                            : () => bloc.add(const ReplayDirectPressed()),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: rowHeight,
                  child: Row(
                    children: <Widget>[
                      for (final double speed in bloc.settings.speeds)
                        Expanded(
                          child: _SpeedChip(
                            speed: speed,
                            // En direct, la vitesse par défaut est celle du prochain rejeu.
                            selected:
                                (snapshot?.speed ??
                                    bloc.settings.defaultSpeed) ==
                                speed,
                            onPressed: live
                                ? null
                                : () => bloc.add(ReplaySpeedSelected(speed)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Style d'un bouton dont le fond est porté par son visuel : cible de 48
/// points, fond et ombre transparents.
ButtonStyle _targetStyle(
  SceneTheme theme, {
  EdgeInsetsGeometry padding = EdgeInsets.zero,
}) {
  final Color clear = theme.background.withValues(alpha: 0);
  return ButtonStyle(
    backgroundColor: WidgetStatePropertyAll<Color>(clear),
    overlayColor: WidgetStatePropertyAll<Color>(clear),
    shadowColor: WidgetStatePropertyAll<Color>(clear),
    surfaceTintColor: WidgetStatePropertyAll<Color>(clear),
    minimumSize: const WidgetStatePropertyAll<Size>(
      Size(ReplayBar.rowHeight, ReplayBar.rowHeight),
    ),
    padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(padding),
    shape: WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(borderRadius: SceneRadius.borderMd),
    ),
  );
}

/// Bouton icône `gc-btn--sm gc-btn--icon` : visuel de 34 points (rayon `md`,
/// fond `surface-300`, bordure `ink-muted`) centré dans une cible de 48.
class _IconTarget extends StatelessWidget {
  const _IconTarget({
    required this.buttonKey,
    required this.visualKey,
    required this.icon,
    required this.onPressed,
  });

  /// Hauteur et largeur du visuel.
  static const double visual = 34;

  /// Taille du glyphe dans le visuel.
  static const double glyph = 22;

  final Key buttonKey;
  final Key visualKey;
  final Icon icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return IconButton(
      key: buttonKey,
      onPressed: onPressed,
      style: _targetStyle(theme),
      icon: SizedBox.square(
        key: visualKey,
        dimension: visual,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.surface300,
            borderRadius: SceneRadius.borderMd,
            border: Border.all(color: theme.textSecondary),
          ),
          child: Center(
            child: Icon(
              icon.icon,
              semanticLabel: icon.semanticLabel,
              size: glyph,
              // Inactif mais lisible à distance (le gris par défaut disparaît).
              color: onPressed == null
                  ? theme.neutralForeground
                  : theme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onPressed});

  final bool playing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => _IconTarget(
    buttonKey: const Key('replay-play'),
    visualKey: const Key('replay-play-visual'),
    icon: playing
        ? const Icon(Icons.pause, semanticLabel: 'Pause')
        : const Icon(Icons.play_arrow, semanticLabel: 'Lecture'),
    onPressed: onPressed,
  );
}

/// « Direct » (`gc-live`) : point `signal` de 6 points puis le mot en capitales
/// `signal`. Le point clignotera au niveau B (T34, `gc-blink`).
class _DirectButton extends StatelessWidget {
  const _DirectButton({required this.onPressed});

  /// Diamètre du point.
  static const double dot = 6;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return TextButton(
      key: const Key('replay-direct'),
      onPressed: onPressed,
      style: _targetStyle(
        theme,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DecoratedBox(
            key: const Key('replay-direct-dot'),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.accent,
            ),
            child: const SizedBox.square(dimension: dot),
          ),
          const SizedBox(width: 6),
          DsCaps(
            'Direct',
            style: theme.micro.badge.copyWith(color: theme.accent),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

/// Vitesse `gc-speed` : segment de 26 points (rayon `sm`, bordure `line`,
/// texte `ink-muted`) dans une cible de 48 ; sélectionné (`is-on`) : fond et
/// bordure `ink`, texte `void`.
class _SpeedChip extends StatelessWidget {
  const _SpeedChip({
    required this.speed,
    required this.selected,
    required this.onPressed,
  });

  /// Hauteur du segment.
  static const double visualHeight = 26;

  final double speed;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final String id = ReplayBar._speedId(speed);
    final Widget label = SizedBox(
      key: Key('replay-speed-$id-visual'),
      width: double.infinity,
      height: visualHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? theme.textPrimary : null,
          borderRadius: SceneRadius.borderSm,
          border: Border.all(color: selected ? theme.textPrimary : theme.line),
        ),
        child: Center(
          child: Text(
            ReplayBar.speedLabel(speed),
            maxLines: 1,
            softWrap: false,
            style: theme.micro.speed.copyWith(
              color: selected ? theme.background : theme.textSecondary,
            ),
          ),
        ),
      ),
    );
    final ButtonStyle style = _targetStyle(
      theme,
      padding: const EdgeInsets.symmetric(horizontal: 2),
    );
    final Key key = Key('replay-speed-$id');
    return selected
        ? FilledButton(
            key: key,
            onPressed: onPressed,
            style: style,
            child: label,
          )
        : TextButton(
            key: key,
            onPressed: onPressed,
            style: style,
            child: label,
          );
  }
}

/// Curseur de position : la valeur suit le lecteur, sauf pendant un glisser
/// où elle suit le doigt ; le positionnement part au relâché.
class _PositionSlider extends StatefulWidget {
  const _PositionSlider({required this.snapshot, required this.onSeek});

  final ReplaySnapshot? snapshot;
  final void Function(Duration position) onSeek;

  @override
  State<_PositionSlider> createState() => _PositionSliderState();
}

class _PositionSliderState extends State<_PositionSlider> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final ReplaySnapshot? snapshot = widget.snapshot;
    final double max = snapshot == null
        ? 1
        : math.max(1, snapshot.duration.inMilliseconds).toDouble();
    final double value = (_dragging ?? snapshot?.position.inMilliseconds ?? 0)
        .toDouble()
        .clamp(0, max);
    final double fraction = _fraction(snapshot, value, max);
    final Color clear = theme.background.withValues(alpha: 0);
    return SizedBox(
      height: ReplayBar.rowHeight,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Visuel : piste, remplissage et poignée, inset de la poignée.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _knob / 2),
            child: _TrackVisual(fraction: fraction),
          ),
          // Interaction : la glissière fonctionnelle, transparente, dont la
          // piste coïncide avec le visuel.
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: _trackHeight,
              trackShape: const RectangularSliderTrackShape(),
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: _knob / 2,
                disabledThumbRadius: _knob / 2,
                elevation: 0,
                pressedElevation: 0,
              ),
              overlayShape: const RoundSliderOverlayShape(
                overlayRadius: _knob / 2,
              ),
              showValueIndicator: ShowValueIndicator.never,
              activeTrackColor: clear,
              inactiveTrackColor: clear,
              thumbColor: clear,
              overlayColor: clear,
              disabledActiveTrackColor: clear,
              disabledInactiveTrackColor: clear,
              disabledThumbColor: clear,
            ),
            child: Slider(
              key: const Key('replay-slider'),
              value: value,
              max: max,
              onChanged: snapshot == null
                  ? null
                  : (double v) => setState(() => _dragging = v),
              onChangeEnd: snapshot == null
                  ? null
                  : (double v) {
                      setState(() => _dragging = null);
                      widget.onSeek(Duration(milliseconds: v.round()));
                    },
            ),
          ),
        ],
      ),
    );
  }

  /// Fraction affichée : la piste est pleine en direct (bord du direct).
  static double _fraction(ReplaySnapshot? snapshot, double value, double max) =>
      snapshot == null ? 1 : (value / max).clamp(0.0, 1.0);
}

const double _trackHeight = 4;
const double _knob = 14;

/// Piste `gc-track` (4 points, `surface-300`), remplissage `signal` et
/// poignée ronde `ink` de 14 points à lueur `signal`.
class _TrackVisual extends StatelessWidget {
  const _TrackVisual({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        return SizedBox(
          height: _trackHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: DecoratedBox(
                  key: const Key('replay-track'),
                  decoration: BoxDecoration(
                    color: theme.surface300,
                    borderRadius: SceneRadius.borderPill,
                  ),
                ),
              ),
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: fraction,
                    child: DecoratedBox(
                      key: const Key('replay-track-fill'),
                      decoration: BoxDecoration(
                        color: theme.accent,
                        borderRadius: SceneRadius.borderPill,
                      ),
                      child: const SizedBox(height: _trackHeight),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: box.maxWidth * fraction - _knob / 2,
                top: (_trackHeight - _knob) / 2,
                child: DecoratedBox(
                  key: const Key('replay-track-knob'),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.textPrimary,
                    boxShadow: SceneShadow.glowSignal,
                  ),
                  child: const SizedBox.square(dimension: _knob),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
