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
        ],
      ),
    ),
  );
}

class _AgentRow extends StatelessWidget {
  const _AgentRow({required this.agent});

  final AgentStatus agent;

  static String _stateText(AgentRunState state) => switch (state) {
    AgentRunState.working => 'en cours',
    AgentRunState.completed => 'terminé',
    AgentRunState.failed => 'échec',
    AgentRunState.interrupted => 'interrompu',
  };

  static Color _stateColor(AgentRunState state) => switch (state) {
    AgentRunState.working => Colors.amber,
    AgentRunState.completed => Colors.greenAccent,
    AgentRunState.failed => Colors.redAccent,
    AgentRunState.interrupted => Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    final label = agent.label;
    final detail = agent.detail;
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
          Text(_stateText(agent.state)),
          if (detail != null) ...<Widget>[
            const SizedBox(width: 8),
            Text(detail),
          ],
        ],
      ),
    );
  }
}
