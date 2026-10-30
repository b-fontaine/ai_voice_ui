import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:entity_session/entity_session.dart';

import 'agent_activity_event.dart';
import 'agent_activity_state.dart';

/// Suit l'activité des agents à partir des événements de session.
///
/// Fin de session (`closed`) ou perte du canal : les agents `working` passent
/// à `interrupted`. Une nouvelle session (`connecting`) vide la liste.
class AgentActivityBloc extends Bloc<AgentActivityEvent, AgentActivityState> {
  AgentActivityBloc() : super(const AgentActivityState.empty()) {
    // Une nouvelle source remplace la précédente.
    on<AgentActivitySourceSubscribed>(
      _onSubscribed,
      transformer: restartable(),
    );
  }

  Future<void> _onSubscribed(
    AgentActivitySourceSubscribed event,
    Emitter<AgentActivityState> emit,
  ) => emit.onEach<SessionEvent>(
    event.events,
    onData: (SessionEvent sessionEvent) {
      switch (sessionEvent) {
        case AgentActivityReceived():
          _apply(sessionEvent, emit);
        case SessionStateChanged(state: SessionState.connecting):
          emit(const AgentActivityState.empty());
        case SessionStateChanged(state: SessionState.closed) || ChannelLost():
          _interrupt(emit);
        default:
          break;
      }
    },
    // Une erreur du flux est ignorée.
    onError: (Object error, StackTrace stackTrace) {},
  );

  void _apply(
    AgentActivityReceived received,
    Emitter<AgentActivityState> emit,
  ) {
    final AgentStatus line = AgentStatus(
      agent: received.agent,
      task: received.task,
      state: switch (received.state) {
        AgentTaskState.working => AgentRunState.working,
        AgentTaskState.completed => AgentRunState.completed,
        AgentTaskState.failed => AgentRunState.failed,
      },
      label: received.label,
      detail: received.detail,
    );
    final List<AgentStatus> agents = List<AgentStatus>.of(state.agents);
    final int index = agents.indexWhere((a) => a.agent == line.agent);
    if (index < 0) {
      agents.add(line);
    } else {
      agents[index] = line;
    }
    _emitIfChanged(AgentActivityState(agents), emit);
  }

  void _interrupt(Emitter<AgentActivityState> emit) {
    _emitIfChanged(
      AgentActivityState(<AgentStatus>[
        for (final AgentStatus a in state.agents)
          a.state == AgentRunState.working
              ? a.copyWith(state: AgentRunState.interrupted)
              : a,
      ]),
      emit,
    );
  }

  void _emitIfChanged(
    AgentActivityState next,
    Emitter<AgentActivityState> emit,
  ) {
    if (next != state) emit(next);
  }
}
