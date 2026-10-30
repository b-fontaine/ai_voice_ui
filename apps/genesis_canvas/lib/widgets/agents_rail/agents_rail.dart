import 'package:feature_agent_activity/feature_agent_activity.dart'
    show AgentActivityBloc, AgentActivityState, AgentRunState, AgentStatus;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Rail des agents : une ligne par agent (`agent-<nom>`) avec son état en
/// toutes lettres ; la couleur du point n'est qu'un renfort.
class AgentsRail extends StatelessWidget {
  const AgentsRail({super.key = const Key('agents-rail')});

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: BlocBuilder<AgentActivityBloc, AgentActivityState>(
      builder: (context, state) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final agent in state.agents) _AgentRow(agent: agent),
          if (state.noAgentSelected)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('aucun agent retenu', key: Key('agents-none')),
            ),
        ],
      ),
    ),
  );
}

class _AgentRow extends StatelessWidget {
  const _AgentRow({required this.agent});

  final AgentStatus agent;

  static String _stateText(AgentRunState state) => switch (state) {
    AgentRunState.orchestrating => 'orchestre',
    AgentRunState.idle => 'en veille',
    AgentRunState.pending => 'en attente',
    AgentRunState.working => 'en cours',
    AgentRunState.completed => 'terminé',
    AgentRunState.failed => 'échec',
    AgentRunState.rejected => 'hors périmètre',
    AgentRunState.interrupted => 'interrompu',
  };

  static Color _stateColor(AgentRunState state) => switch (state) {
    AgentRunState.orchestrating => Colors.lightBlueAccent,
    AgentRunState.idle => Colors.blueGrey,
    AgentRunState.pending => Colors.amberAccent,
    AgentRunState.working => Colors.amber,
    AgentRunState.completed => Colors.greenAccent,
    AgentRunState.failed => Colors.redAccent,
    AgentRunState.rejected => Colors.orangeAccent,
    AgentRunState.interrupted => Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    final label = agent.label;
    final stateText = _stateText(agent.state);
    // Un détail identique au libellé d'état (« hors périmètre ») n'est pas
    // répété.
    final detail = agent.detail == stateText ? null : agent.detail;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        key: Key('agent-${agent.agent}'),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _stateColor(agent.state),
            ),
            child: const SizedBox.square(dimension: 10),
          ),
          const SizedBox(width: 8),
          Text(agent.agent),
          if (label != null) ...<Widget>[const SizedBox(width: 8), Text(label)],
          const SizedBox(width: 8),
          Text(stateText),
          if (detail != null) ...<Widget>[
            const SizedBox(width: 8),
            Text(detail),
          ],
        ],
      ),
    );
  }
}
