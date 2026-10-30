import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:entity_session/entity_session.dart';

import 'agent_activity_event.dart';
import 'agent_activity_state.dart';

/// Suit l'activité des agents à partir des événements de session.
///
/// Fin de session (`closed`) ou perte du canal : les agents `working`
/// (ou `pending`, jamais terminés) passent à `interrupted`. Une nouvelle
/// session (`connecting`) vide la liste ; le dernier `plan` fixe les lignes
/// du rail (orchestrateur, agents retenus, agents en veille).
class AgentActivityBloc extends Bloc<AgentActivityEvent, AgentActivityState> {
  AgentActivityBloc() : super(const AgentActivityState.empty()) {
    // Une nouvelle source remplace la précédente.
    on<AgentActivitySourceSubscribed>(
      _onSubscribed,
      transformer: restartable(),
    );
    // Les commandes s'exécutent dans l'ordre.
    on<AgentActivityReset>(
      (event, emit) => emit(const AgentActivityState.empty()),
      transformer: sequential(),
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
        case PlanReceived():
          _applyPlan(sessionEvent, emit);
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
        AgentTaskState.rejected => AgentRunState.rejected,
        AgentTaskState.canceled => AgentRunState.interrupted,
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
    _emitIfChanged(
      AgentActivityState(agents, noAgentSelected: state.noAgentSelected),
      emit,
    );
  }

  /// Le dernier plan remplace le rail : orchestrateur, `selected` (en attente)
  /// puis `idle` (en veille), dans l'ordre reçu.
  void _applyPlan(PlanReceived plan, Emitter<AgentActivityState> emit) {
    final Set<String> seen = <String>{AgentActivityState.orchestratorName};
    AgentStatus line(String name, AgentRunState runState) =>
        AgentStatus(agent: name, task: '', state: runState);
    _emitIfChanged(
      AgentActivityState(<AgentStatus>[
        line(AgentActivityState.orchestratorName, AgentRunState.orchestrating),
        for (final String name in plan.selected)
          if (seen.add(name)) line(name, AgentRunState.pending),
        for (final String name in plan.idle)
          if (seen.add(name)) line(name, AgentRunState.idle),
      ], noAgentSelected: plan.selected.isEmpty),
      emit,
    );
  }

  void _interrupt(Emitter<AgentActivityState> emit) {
    _emitIfChanged(
      AgentActivityState(<AgentStatus>[
        for (final AgentStatus a in state.agents)
          a.state == AgentRunState.working || a.state == AgentRunState.pending
              ? a.copyWith(state: AgentRunState.interrupted)
              : a,
      ], noAgentSelected: state.noAgentSelected),
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
