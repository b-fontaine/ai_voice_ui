import 'package:feature_agent_activity/feature_agent_activity.dart'
    show AgentActivityBloc, AgentActivityState, AgentRunState, AgentStatus;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_design_system/shared_design_system.dart' show SceneTheme;

/// Rail des agents : une ligne par agent (`agent-<nom>`) avec son état en
/// toutes lettres ; la couleur du point n'est qu'un renfort.
///
/// Texte du thème de scène (>= 24 px, RG-09) ; une ligne par agent, le libellé
/// de tâche et le détail s'abrègent avec une ellipse plutôt que de déborder
/// (budget : l'orchestrateur et trois agents tiennent dans 200 px).
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'aucun agent retenu',
                key: const Key('agents-none'),
                style: SceneTheme.of(context).body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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
    final theme = SceneTheme.of(context);
    final label = agent.label;
    final stateText = _stateText(agent.state);
    // Un détail identique au libellé d'état (« hors périmètre ») n'est pas
    // répété.
    final detail = agent.detail == stateText ? null : agent.detail;
    final secondary = theme.body.copyWith(color: theme.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        key: Key('agent-${agent.agent}'),
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _stateColor(agent.state),
            ),
            child: const SizedBox.square(dimension: 14),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              agent.agent,
              style: theme.label.copyWith(color: theme.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (label != null) ...<Widget>[
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                style: secondary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(width: 12),
          Text(stateText, style: theme.body, maxLines: 1),
          if (detail != null) ...<Widget>[
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                detail,
                style: secondary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
