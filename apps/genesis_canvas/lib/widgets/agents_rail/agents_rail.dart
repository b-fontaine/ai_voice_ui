import 'package:feature_agent_activity/feature_agent_activity.dart'
    show AgentActivityBloc, AgentActivityState, AgentRunState, AgentStatus;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_design_system/shared_design_system.dart' show SceneTheme;

import 'delegation_links.dart';

/// Rail des agents, en rangée horizontale de [height] px (A1 de 013, pdr-0075
/// D1) : le repère « AGENTS A2A » en colonne de tête, puis une tuile par agent
/// (`agent-<nom>`), l'orchestrateur d'abord.
///
/// Une tuile tient sur deux lignes : pastille et nom, puis « état · tâche ».
/// L'état est dit en toutes lettres (la couleur de la pastille n'est qu'un
/// renfort) ; seule la tâche s'abrège avec une ellipse. Texte du thème de scène
/// (>= 24 px, RG-09). La hauteur et la largeur sont celles du budget, vide ou
/// rempli : l'arrivée du premier plan ne déplace rien. L'intervalle entre
/// l'orchestrateur et les agents reste libre. Une liaison animée relie
/// l'orchestrateur à chaque agent en attente ou en cours ([DelegationLinks],
/// Q-85).
class AgentsRail extends StatelessWidget {
  const AgentsRail({super.key = const Key('agents-rail')});

  /// Hauteur fixe du rail, en points.
  static const double height = 96;

  /// Intervalle réservé entre l'orchestrateur et les agents.
  static const double delegationGap = 48;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: BlocBuilder<AgentActivityBloc, AgentActivityState>(
          builder: (context, state) {
            final List<AgentStatus> agents = state.agents;
            return DelegationLinks(
              agents: agents,
              rowBuilder: (context, tileKey) => Row(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: Text(
                      'AGENTS A2A',
                      style: theme.label.copyWith(color: theme.textSecondary),
                      maxLines: 1,
                    ),
                  ),
                  for (int i = 0; i < agents.length; i++) ...<Widget>[
                    if (i == 1) const SizedBox(width: delegationGap),
                    if (i > 1) const SizedBox(width: 16),
                    Expanded(
                      child: KeyedSubtree(
                        key: tileKey(agents[i].agent),
                        child: _AgentTile(agent: agents[i]),
                      ),
                    ),
                  ],
                  if (state.noAgentSelected) ...<Widget>[
                    const SizedBox(width: delegationGap),
                    Text(
                      'aucun agent retenu',
                      key: const Key('agents-none'),
                      style: theme.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (agents.length < 2 && !state.noAgentSelected)
                    const Spacer(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AgentTile extends StatelessWidget {
  const _AgentTile({required this.agent});

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

  static Color _stateColor(SceneTheme theme, AgentRunState state) =>
      switch (state) {
        AgentRunState.orchestrating => theme.accent,
        AgentRunState.idle => theme.agentIdle,
        AgentRunState.pending => theme.riskForeground,
        AgentRunState.working => theme.agentWorking,
        AgentRunState.completed => theme.okForeground,
        AgentRunState.failed => theme.blockingForeground,
        AgentRunState.rejected => theme.agentRejected,
        AgentRunState.interrupted => theme.agentInterrupted,
      };

  @override
  Widget build(BuildContext context) {
    final theme = SceneTheme.of(context);
    final stateText = _stateText(agent.state);
    // Un détail identique au libellé d'état (« hors périmètre ») n'est pas
    // répété.
    final detail = agent.detail == stateText ? null : agent.detail;
    final task = <String>[?agent.label, ?detail].join(' · ');
    final secondary = theme.body.copyWith(color: theme.textSecondary);
    return Column(
      key: Key('agent-${agent.agent}'),
      // Hauteur du contenu, centrée par le rail : le rectangle de la tuile est
      // celui des deux lignes de texte, la bande libre au-dessus accueille la
      // liaison de délégation.
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _stateColor(theme, agent.state),
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
          ],
        ),
        Row(
          children: <Widget>[
            Text(stateText, style: theme.body, maxLines: 1),
            if (task.isNotEmpty) ...<Widget>[
              Text(' · ', style: secondary, maxLines: 1),
              Flexible(
                child: Text(
                  task,
                  style: secondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
