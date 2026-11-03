import 'package:flutter/material.dart';
import 'package:shared_design_system/shared_design_system.dart';

import 'blocking_summary.dart';
import 'checklist_model.dart';
import 'text_metrics.dart';

/// Espace entre le titre, le verdict et la puce de décision (`.gc-verdict`).
const double _headerGap = 14;

/// Espace entre deux lignes de l'en-tête quand il ne tient pas sur une seule.
const double _headRunGap = 4;

/// Statut de décision en pastille, jamais tronqué ; un changement de valeur
/// est mis en avant par une brève transition.
class _DecisionStatus extends StatelessWidget {
  const _DecisionStatus({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    key: const Key('decision-status'),
    duration: SceneMotionScope.of(context).durationFor(SceneMotion.status),
    child: DsStatusChip(
      key: ValueKey<String>(status),
      status: null,
      label: status,
    ),
  );
}

/// En-tête du panneau : titre et verdict (grande puce) à gauche, compteur
/// « n bloquants / total » à droite, et la puce de décision.
///
/// Selon la largeur, mesurée avec les polices réelles :
/// - tout tient : titre, verdict et décision à gauche, compteur à droite ;
/// - sinon : titre et verdict à gauche, décision au-dessus du compteur à
///   droite (l'en-tête garde environ la hauteur de la grande puce) ;
/// - sinon : le côté gauche passe à la ligne. Rien n'est jamais tronqué.
class ChecklistHead extends StatefulWidget {
  const ChecklistHead({super.key, required this.checklist});

  final ChecklistData checklist;

  @override
  State<ChecklistHead> createState() => _HeadState();
}

class _HeadState extends State<ChecklistHead> {
  /// La puce de décision change de place selon la largeur que prend son texte :
  /// la clé globale conserve son `State` (et donc la transition de statut)
  /// quand elle passe d'un côté à l'autre.
  final GlobalKey _decisionKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final ChecklistData checklist = widget.checklist;
    final SceneTheme theme = SceneTheme.of(context);
    final String count = blockingSummary(
      checklist.items.map((ChecklistItem item) => item.level),
    );
    final Widget title = Text(checklist.title, style: theme.title);
    final Widget verdict = DsStatusChip(
      key: const Key('checklist-verdict'),
      status: checklist.recommendationLevel,
      label: checklist.recommendationLabel,
      large: true,
    );
    final Widget decision = _DecisionStatus(
      key: _decisionKey,
      status: checklist.decisionStatus,
    );
    final Widget counter = DsCaps(count, key: const Key('checklist-count'));

    Widget wrapped(List<Widget> children) => Wrap(
      spacing: _headerGap,
      runSpacing: _headRunGap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: DsPanelHead.bottomMargin),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double titleW = measureTextWidth(
            context,
            checklist.title,
            theme.title,
          );
          final double verdictW = DsStatusChip.measure(
            context,
            checklist.recommendationLevel,
            checklist.recommendationLabel,
            large: true,
          ).width;
          final double decisionW = DsStatusChip.measure(
            context,
            null,
            checklist.decisionStatus,
          ).width;
          final double countW = measureTextWidth(
            context,
            count.toUpperCase(),
            theme.label,
          );
          // Marge d'arrondi : un demi-pixel ne doit pas faire passer à la ligne.
          const double slack = 2;
          final double avail = constraints.maxWidth - DsPanelHead.gap;
          final double lead = titleW + _headerGap + verdictW + slack;
          final bool oneLine =
              lead + _headerGap + decisionW + countW + slack <= avail;
          final bool stacked =
              !oneLine &&
              lead + (decisionW > countW ? decisionW : countW) + slack <= avail;
          return Row(
            crossAxisAlignment: stacked
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: wrapped(
                  stacked
                      ? <Widget>[title, verdict]
                      : <Widget>[title, verdict, decision],
                ),
              ),
              const SizedBox(width: DsPanelHead.gap),
              if (stacked)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    decision,
                    const SizedBox(height: _headRunGap),
                    counter,
                  ],
                )
              else
                counter,
            ],
          );
        },
      ),
    );
  }
}
