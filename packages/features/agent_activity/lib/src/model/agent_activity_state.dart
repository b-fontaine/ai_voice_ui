/// État d'exécution d'un agent tel qu'affiché.
///
/// - `orchestrating` : ligne de l'orchestrateur, présente dès qu'un plan est
///   reçu ;
/// - `idle` : agent non retenu par le plan (« en veille ») ;
/// - `pending` : agent retenu, sans activité reçue pour l'instant ;
/// - `rejected` : agent retenu qui refuse (« hors périmètre »), pas un échec.
enum AgentRunState {
  orchestrating,
  idle,
  pending,
  working,
  completed,
  failed,
  rejected,
  interrupted,
}

/// Ligne d'activité d'un agent (une par nom d'agent).
class AgentStatus {
  const AgentStatus({
    required this.agent,
    required this.task,
    required this.state,
    this.label,
    this.detail,
  });

  final String agent;
  final String task;
  final AgentRunState state;
  final String? label;
  final String? detail;

  AgentStatus copyWith({AgentRunState? state}) => AgentStatus(
    agent: agent,
    task: task,
    state: state ?? this.state,
    label: label,
    detail: detail,
  );

  @override
  bool operator ==(Object other) =>
      other is AgentStatus &&
      other.agent == agent &&
      other.task == task &&
      other.state == state &&
      other.label == label &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(agent, task, state, label, detail);

  @override
  String toString() => 'AgentStatus($agent, $task, $state)';
}

/// Activité de tous les agents, dans l'ordre de première apparition.
class AgentActivityState {
  AgentActivityState(List<AgentStatus> agents, {this.noAgentSelected = false})
    : agents = List<AgentStatus>.unmodifiable(agents);

  const AgentActivityState.empty()
    : agents = const <AgentStatus>[],
      noAgentSelected = false;

  /// Nom d'affichage de la ligne de l'orchestrateur (constante, pas un agent).
  static const String orchestratorName = 'Orchestrateur';

  final List<AgentStatus> agents;

  /// Vrai si le dernier plan ne retient aucun agent (RG-08, « aucun agent
  /// retenu »).
  final bool noAgentSelected;

  /// Vrai si au moins un agent travaille.
  bool get anyWorking =>
      agents.any((AgentStatus a) => a.state == AgentRunState.working);

  @override
  bool operator ==(Object other) {
    if (other is! AgentActivityState ||
        other.noAgentSelected != noAgentSelected ||
        other.agents.length != agents.length) {
      return false;
    }
    for (int i = 0; i < agents.length; i++) {
      if (agents[i] != other.agents[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(noAgentSelected, Object.hashAll(agents));

  @override
  String toString() =>
      'AgentActivityState($agents, noAgentSelected: $noAgentSelected)';
}
