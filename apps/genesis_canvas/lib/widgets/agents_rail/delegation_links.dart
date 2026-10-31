import 'package:feature_agent_activity/feature_agent_activity.dart'
    show AgentRunState, AgentStatus;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_design_system/shared_design_system.dart'
    show SceneMotion, SceneMotionScope, SceneTheme;

import 'delegation_link_geometry.dart';
import 'delegation_link_painter.dart';

/// Construit la rangée des tuiles ; [tileKey] donne la clé à poser sur chaque
/// tuile pour que [DelegationLinks] la mesure.
typedef DelegationRowBuilder = Widget Function(
  BuildContext context,
  Key Function(String agent) tileKey,
);

/// Rangée des tuiles d'agents du rail, recouverte des liaisons de délégation
/// (Q-85, FR-03) : un trait pointillé relie l'orchestrateur à chaque agent
/// « en attente » ou « en cours ».
///
/// Les tuiles sont mesurées par `GlobalKey` après chaque image et à chaque
/// changement de contraintes ; l'état n'est modifié que si un rectangle change.
/// Le filtre par état est ici, le peintre dessine toutes les liaisons reçues.
/// Chaque liaison est repérée par une clé `delegation-link-<agent>`, posée sur
/// un repère transparent qui contient son tracé.
class DelegationLinks extends StatefulWidget {
  const DelegationLinks({
    super.key,
    required this.agents,
    required this.rowBuilder,
  });

  /// Agents du rail, l'orchestrateur compris.
  final List<AgentStatus> agents;

  final DelegationRowBuilder rowBuilder;

  /// Un agent est relié tant qu'il est en attente ou en cours.
  static bool isLinked(AgentRunState state) =>
      state == AgentRunState.pending || state == AgentRunState.working;

  @override
  State<DelegationLinks> createState() => DelegationLinksState();
}

/// État de [DelegationLinks], public pour les tests.
class DelegationLinksState extends State<DelegationLinks>
    with SingleTickerProviderStateMixin {
  // Phase des pointillés (0 à 1 par période). Le peintre s'y abonne : aucune
  // reconstruction de widget à chaque image.
  late final AnimationController _phase = AnimationController(vsync: this);
  final Map<String, GlobalKey> _tileKeys = <String, GlobalKey>{};
  Map<String, Rect> _rects = const <String, Rect>{};
  Map<String, DelegationLinkGeometry> _geometries =
      <String, DelegationLinkGeometry>{};

  /// Nombre de clés de tuile conservées (une par agent affiché).
  @visibleForTesting
  int get tileKeyCount => _tileKeys.length;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(DelegationLinks oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  // Tourne tant qu'un lien est à dessiner, selon le réglage d'animation de la
  // scène ; s'arrête sans lien (aucun frame planifié pour rien).
  void _syncAnimation() {
    final bool anyLinked = widget.agents.any(
      (a) => DelegationLinks.isLinked(a.state),
    );
    if (anyLinked) {
      SceneMotionScope.loop(context, _phase, SceneMotion.link);
    } else {
      _phase.stop();
    }
  }

  Key _tileKey(String agent) =>
      _tileKeys.putIfAbsent(agent, () => GlobalKey(debugLabel: 'tile-$agent'));

  // Libère les clés des agents disparus.
  void _releaseGoneKeys() {
    final Set<String> names = <String>{
      for (final AgentStatus agent in widget.agents) agent.agent,
    };
    _tileKeys.removeWhere((String name, GlobalKey _) => !names.contains(name));
  }

  void _scheduleMeasure() => WidgetsBinding.instance.addPostFrameCallback((_) {
    _measure();
  });

  void _measure() {
    if (!mounted) return;
    final RenderObject? self = context.findRenderObject();
    if (self is! RenderBox || !self.attached || !self.hasSize) return;
    final Map<String, Rect> next = <String, Rect>{};
    _tileKeys.forEach((String agent, GlobalKey key) {
      final RenderObject? tile = key.currentContext?.findRenderObject();
      if (tile is RenderBox && tile.attached && tile.hasSize) {
        next[agent] = MatrixUtils.transformRect(
          tile.getTransformTo(self),
          Offset.zero & tile.size,
        );
      }
    });
    if (!mapEquals(next, _rects)) setState(() => _rects = next);
  }

  // Géométries des liens à dessiner ; celles dont les rectangles n'ont pas
  // changé sont reprises telles quelles (leur chemin est déjà calculé).
  List<DelegationLinkGeometry> _activeLinks() {
    final String? orchestrator = widget.agents
        .where((a) => a.state == AgentRunState.orchestrating)
        .map((a) => a.agent)
        .firstOrNull;
    final Rect? origin = orchestrator == null ? null : _rects[orchestrator];
    final Map<String, DelegationLinkGeometry> next =
        <String, DelegationLinkGeometry>{};
    if (origin != null) {
      for (final AgentStatus agent in widget.agents) {
        final Rect? target = _rects[agent.agent];
        if (!DelegationLinks.isLinked(agent.state) || target == null) continue;
        final DelegationLinkGeometry fresh = DelegationLinkGeometry(
          orchestrator: origin,
          target: target,
        );
        final DelegationLinkGeometry? known = _geometries[agent.agent];
        next[agent.agent] = known == fresh ? known! : fresh;
      }
    }
    _geometries = next;
    return next.values.toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    _releaseGoneKeys();
    final SceneTheme theme = SceneTheme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _scheduleMeasure();
        final List<DelegationLinkGeometry> links = _activeLinks();
        return Stack(
          fit: StackFit.passthrough,
          children: <Widget>[
            widget.rowBuilder(context, _tileKey),
            if (links.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: DelegationLinkPainter(
                        links: links,
                        color: theme.accent,
                        phase: _phase,
                      ),
                    ),
                  ),
                ),
              ),
            for (final MapEntry<String, DelegationLinkGeometry> link
                in _geometries.entries)
              Positioned.fromRect(
                rect: link.value.path.getBounds().inflate(
                  DelegationLinkGeometry.strokeWidth / 2,
                ),
                child: SizedBox.expand(key: Key('delegation-link-${link.key}')),
              ),
          ],
        );
      },
    );
  }
}
