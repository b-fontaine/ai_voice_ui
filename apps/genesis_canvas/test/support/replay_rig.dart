import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage;
import 'package:entity_session/entity_session.dart';
import 'package:feature_replay/feature_replay.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

A2uiEnvelopeReceived _envelope(Map<String, Object?> raw) =>
    A2uiEnvelopeReceived(message: A2uiMessage.fromJson(raw), raw: raw);

A2uiEnvelopeReceived _create(String id) => _envelope(<String, Object?>{
  'version': 'v0.9',
  'createSurface': <String, Object?>{
    'surfaceId': id,
    'catalogId': 'https://a2ui.org/specification/v0_9/basic_catalog.json',
  },
});

A2uiEnvelopeReceived _delete(String id) => _envelope(<String, Object?>{
  'version': 'v0.9',
  'deleteSurface': <String, Object?>{'surfaceId': id},
});

/// Scène de test : compte les appels du port.
class RecordingReplayStage implements ReplayStage {
  int clears = 0;
  int exits = 0;

  @override
  void clear() => clears++;

  @override
  void exit() => exits++;
}

/// Banc : vrai routeur, vrai journal, vrai lecteur : seule la scène est un double.
class ReplayRig {
  ReplayRig({required bool withJournal}) {
    router = ReplayRouter(
      live: live.stream,
      journal: A2uiJournal(maxEntries: 100),
      nowMs: () => now,
    );
    router.events.listen((_) {});
    if (withJournal) {
      live.add(_create('a'));
      now = 1000;
      live.add(_delete('x'));
      now = 2000;
      live.add(_delete('y'));
    }
    bloc = ReplayBloc(
      router: router,
      stage: stage,
      settings: const ReplaySettings(),
      playerFactory:
          (
            List<JournalEntry> entries, {
            required void Function(A2uiEnvelopeReceived) inject,
            required void Function() clearStage,
          }) => ReplayPlayer(
            entries: entries,
            settings: const ReplaySettings(),
            inject: inject,
            clearStage: clearStage,
          ),
    );
  }

  final StreamController<SessionEvent> live =
      StreamController<SessionEvent>.broadcast(sync: true);
  final RecordingReplayStage stage = RecordingReplayStage();
  late final ReplayRouter router;
  late final ReplayBloc bloc;
  int now = 0;

  void dispose() {
    unawaited(bloc.close());
    router.dispose();
    unawaited(live.close());
  }
}

/// Fournit un `ReplayBloc` (journal vide) aux tests qui montent la page ou
/// l'app entière : les widgets `ReplayBar` et `StageBar` le lisent dans
/// l'arbre. Le Bloc et son routeur sont fermés au démontage.
class ReplayScope extends StatefulWidget {
  const ReplayScope({super.key, required this.child});

  final Widget child;

  @override
  State<ReplayScope> createState() => _ReplayScopeState();
}

class _ReplayScopeState extends State<ReplayScope> {
  final ReplayRig _rig = ReplayRig(withJournal: false);

  @override
  void dispose() {
    _rig.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocProvider<ReplayBloc>.value(value: _rig.bloc, child: widget.child);
}

/// Pose un `Overlay` autour de [child] : le curseur de `ReplayBar` en exige un,
/// que les tests montés sous un simple `Directionality` n'ont pas.
Widget withOverlay(Widget child) => Overlay(
  initialEntries: <OverlayEntry>[
    OverlayEntry(builder: (BuildContext context) => child),
  ],
);
