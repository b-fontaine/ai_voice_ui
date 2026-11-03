import 'package:feature_agent_activity/feature_agent_activity.dart'
    show AgentActivityBloc, AgentActivityState, AgentRunState, AgentStatus;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_design_system/shared_design_system.dart'
    show
        DsBeacon,
        DsCaps,
        SceneLoop,
        SceneMotion,
        SceneMotionScope,
        SceneRadius,
        SceneTheme;

import 'delegation_link_geometry.dart' show DelegationLinkGeometry;
import 'delegation_links.dart';

/// Rail des agents, en rangée horizontale de [height] px (A1 de 013, pdr-0075
/// D1) : l'étiquette « Agents A2A » (capitales, `agents-rail-label`) en colonne
/// de tête, puis une tuile par agent (`agent-<nom>`), l'orchestrateur d'abord.
///
/// Une tuile (`agent-tile-<nom>`, `gc-agent` du design system, pdr-0088 F10)
/// tient sur deux lignes : point (`agent-dot-<nom>`) et nom, puis
/// `agent-state-<nom>` « état · tâche ». L'état est dit en toutes lettres (la
/// couleur du point n'est qu'un renfort) ; seule la tâche s'abrège avec une
/// ellipse. Trois états ont l'habillage du design system : orchestrateur
/// (`plasma`), au travail (`signal`, barre indéterminée), terminé (`go`, ✓) ;
/// les autres gardent leur libellé sur le même habillage, aux jetons. La hauteur et la largeur sont celles du budget, vide ou
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
                    padding: const EdgeInsets.only(right: 8),
                    child: DsCaps(
                      'Agents A2A',
                      key: const Key('agents-rail-label'),
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

  /// Épaisseur de la barre indéterminée.
  static const double barHeight = 2;

  /// Période du battement du point d'un agent au travail (`gc-beacon 1.2s`,
  /// la puce Bloquant bat plus lentement : 1,6 s).
  static const Duration beaconPeriod = Duration(milliseconds: 1200);

  /// Halo du point de l'orchestrateur.
  static const double glowBlur = 10;

  /// Glyphe d'un agent terminé.
  static const String doneGlyph = '✓';

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

  /// Couleur du point (décoratif : l'état est dit en toutes lettres).
  static Color _dotColor(SceneTheme theme, AgentRunState state) =>
      switch (state) {
        AgentRunState.orchestrating => theme.plasma,
        AgentRunState.idle => theme.agentIdle,
        AgentRunState.pending => theme.riskForeground,
        AgentRunState.working => theme.agentWorking,
        AgentRunState.completed => theme.okForeground,
        AgentRunState.failed => theme.blockingForeground,
        AgentRunState.rejected => theme.agentRejected,
        AgentRunState.interrupted => theme.agentInterrupted,
      };

  /// Bordure : `plasma` à 33 % (orchestrateur), `signal` à 40 % (au travail),
  /// `line` sinon.
  static Color _borderColor(SceneTheme theme, AgentRunState state) =>
      switch (state) {
        AgentRunState.orchestrating => theme.plasma.withValues(alpha: 0.33),
        AgentRunState.working => theme.accent.withValues(alpha: 0.4),
        _ => theme.line,
      };

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final AgentRunState state = agent.state;
    final String stateText = _stateText(state);
    // Un détail identique au libellé d'état (« hors périmètre ») n'est pas
    // répété.
    final String? detail = agent.detail == stateText ? null : agent.detail;
    final String task = <String>[?agent.label, ?detail].join(' · ');
    final bool working = state == AgentRunState.working;
    final Color stateColor = working ? theme.accent : theme.textSecondary;
    final TextStyle stateStyle = theme.micro.agentState.copyWith(
      color: stateColor,
    );
    final Color dot = _dotColor(theme, state);
    final Widget dotView = DecoratedBox(
      key: Key('agent-dot-${agent.agent}'),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: dot,
        boxShadow: state == AgentRunState.orchestrating
            ? <BoxShadow>[
                BoxShadow(
                  color: theme.plasma.withValues(alpha: 0.6),
                  blurRadius: glowBlur,
                ),
              ]
            : null,
      ),
      child: const SizedBox.square(dimension: DelegationLinkGeometry.dotSize),
    );
    return KeyedSubtree(
      key: Key('agent-${agent.agent}'),
      child: DecoratedBox(
        key: Key('agent-tile-${agent.agent}'),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: SceneRadius.borderMd,
          border: Border.all(
            color: _borderColor(theme, state),
            width: DelegationLinkGeometry.tileBorder,
          ),
        ),
        // Une `DecoratedBox` ne réserve pas la place de sa bordure.
        child: Padding(
          padding: const EdgeInsets.all(DelegationLinkGeometry.tileBorder),
          child: ClipRRect(
            borderRadius: SceneRadius.borderMd,
            child: Stack(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DelegationLinkGeometry.tilePaddingX,
                    vertical: 10,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          working
                              ? DsBeacon(
                                  color: dot,
                                  size: DelegationLinkGeometry.dotSize,
                                  period: beaconPeriod,
                                  child: dotView,
                                )
                              : dotView,
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              agent.agent,
                              style: theme.micro.agentName.copyWith(
                                color: theme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        key: Key('agent-state-${agent.agent}'),
                        children: <Widget>[
                          if (state == AgentRunState.completed) ...<Widget>[
                            // Décoratif : le mot « terminé » suffit au lecteur
                            // d'écran.
                            ExcludeSemantics(
                              child: Text(
                                doneGlyph,
                                style: stateStyle.copyWith(
                                  color: theme.okForeground,
                                ),
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(stateText, style: stateStyle, maxLines: 1),
                          if (task.isNotEmpty) ...<Widget>[
                            Text(' · ', style: stateStyle, maxLines: 1),
                            Flexible(
                              child: Text(
                                task,
                                style: stateStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (working)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: barHeight,
                    child: _IndeterminateBar(
                      barKey: Key('agent-bar-${agent.agent}'),
                      color: theme.accent,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barre indéterminée d'un agent au travail (`gc-indet`, 1,3 s, pdr-0088 F9) :
/// un segment de 40 % de la largeur qui glisse de -100 % à
/// 260 % de sa propre largeur, sur la courbe du design system, en boucle.
///
/// La clé va sur le segment (taille 40 % × 2 px, inchangée). Un seul
/// contrôleur, lancé une fois par `SceneMotionScope.loop` ; la tuile
/// (`ClipRRect`) rogne ce qui dépasse. Dans son `RepaintBoundary` : le texte de
/// la tuile n'est pas repeint. **Phase de repos** (animations coupées) : le
/// segment immobile, à gauche et visible, comme avant le niveau B.
class _IndeterminateBar extends StatefulWidget {
  const _IndeterminateBar({required this.barKey, required this.color});

  /// Largeur du segment, en part de la tuile (`width: 40%`).
  static const double widthFactor = 0.4;

  /// Départ et arrivée du glissement, en largeurs du segment.
  static const double from = -1;
  static const double to = 2.6;

  /// Clé du segment (`agent-bar-<nom>`).
  final Key barKey;

  final Color color;

  @override
  State<_IndeterminateBar> createState() => _IndeterminateBarState();
}

class _IndeterminateBarState extends State<_IndeterminateBar>
    with SingleTickerProviderStateMixin, SceneLoop<_IndeterminateBar> {
  @override
  Duration get loopBase => SceneMotion.indet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncLoop();
  }

  @override
  Widget build(BuildContext context) {
    final bool still = SceneMotionScope.of(context).disabled;
    return RepaintBoundary(
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: _IndeterminateBar.widthFactor,
          heightFactor: 1,
          // Le segment est peint par un `CustomPainter` qui écoute le
          // contrôleur : aucune reconstruction par image (les tuiles sont sous
          // un `LayoutBuilder`, qu'un `AnimatedBuilder` remettrait en page à
          // chaque image). La clé est sur ce `CustomPaint` (40 % × 2 pt).
          child: CustomPaint(
            key: widget.barKey,
            painter: _BarPainter(
              phase: loop,
              color: widget.color,
              still: still,
            ),
          ),
        ),
      ),
    );
  }
}

/// Peint le segment de la barre indéterminée, décalé de -100 % à 260 % de sa
/// propre largeur selon la phase ; immobile à gauche si [still].
class _BarPainter extends CustomPainter {
  _BarPainter({required this.phase, required this.color, required this.still})
    : super(repaint: phase);

  final Animation<double> phase;
  final Color color;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final double shift = still
        ? 0
        : _IndeterminateBar.from +
              (_IndeterminateBar.to - _IndeterminateBar.from) *
                  SceneMotion.curve.transform(phase.value);
    canvas.drawRect(
      Rect.fromLTWH(shift * size.width, 0, size.width, size.height),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.phase != phase || old.color != color || old.still != still;
}
