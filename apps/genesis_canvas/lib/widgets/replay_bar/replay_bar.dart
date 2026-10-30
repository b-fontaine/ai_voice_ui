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
import 'package:shared_design_system/shared_design_system.dart' show SceneTheme;

/// Zone « REJEU » (FR-09, pdr-0066 D4) : deux rangées de 48 px.
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
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        const SizedBox(width: 4),
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
                        IconButton(
                          key: const Key('replay-restart'),
                          onPressed: live
                              ? null
                              : () => bloc.add(const ReplayRestartPressed()),
                          style: _iconStyle(theme),
                          icon: const Icon(
                            Icons.replay,
                            semanticLabel: 'Recommencer',
                          ),
                        ),
                        Expanded(
                          child: _PositionSlider(
                            snapshot: snapshot,
                            onSeek: (Duration position) =>
                                bloc.add(ReplaySeeked(position)),
                          ),
                        ),
                        TextButton(
                          key: const Key('replay-direct'),
                          onPressed: live
                              ? null
                              : () => bloc.add(const ReplayDirectPressed()),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.accent,
                            disabledForegroundColor: theme.neutralForeground,
                            textStyle: theme.label,
                            minimumSize: const Size(0, rowHeight),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text('Direct', maxLines: 1),
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
                              selected: snapshot?.speed == speed,
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
      ),
    );
  }
}

ButtonStyle _iconStyle(SceneTheme theme) => IconButton.styleFrom(
  foregroundColor: theme.textPrimary,
  // Inactif mais lisible à distance (le gris par défaut disparaît).
  disabledForegroundColor: theme.neutralForeground,
  iconSize: 36,
  minimumSize: const Size.square(ReplayBar.rowHeight),
);

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onPressed});

  final bool playing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('replay-play'),
    onPressed: onPressed,
    style: _iconStyle(SceneTheme.of(context)),
    icon: playing
        ? const Icon(Icons.pause, semanticLabel: 'Pause')
        : const Icon(Icons.play_arrow, semanticLabel: 'Lecture'),
  );
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({
    required this.speed,
    required this.selected,
    required this.onPressed,
  });

  final double speed;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final Key key = Key('replay-speed-${ReplayBar._speedId(speed)}');
    final Widget label = Text(
      ReplayBar.speedLabel(speed),
      maxLines: 1,
      softWrap: false,
    );
    const EdgeInsets padding = EdgeInsets.symmetric(horizontal: 2);
    const Size minimum = Size(0, ReplayBar.rowHeight);
    if (selected) {
      return FilledButton(
        key: key,
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: theme.accent,
          foregroundColor: theme.background,
          disabledBackgroundColor: theme.neutralBackground,
          disabledForegroundColor: theme.neutralForeground,
          textStyle: theme.label,
          minimumSize: minimum,
          padding: padding,
        ),
        child: label,
      );
    }
    return TextButton(
      key: key,
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: theme.textPrimary,
        disabledForegroundColor: theme.neutralForeground,
        textStyle: theme.label,
        minimumSize: minimum,
        padding: padding,
      ),
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
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: theme.accent,
        inactiveTrackColor: theme.neutralBackground,
        thumbColor: theme.accent,
        disabledActiveTrackColor: theme.neutralForeground,
        disabledInactiveTrackColor: theme.neutralBackground,
        disabledThumbColor: theme.neutralForeground,
      ),
      child: SizedBox(
        height: ReplayBar.rowHeight,
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
    );
  }
}
