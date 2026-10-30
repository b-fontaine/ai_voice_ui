import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../model/canvas_action_bloc.dart';
import '../model/canvas_action_event.dart';
import '../model/canvas_action_state.dart';

/// Rappel d'une action cliquée : identifiant de l'action, surface qui la porte.
typedef ActionCallback = void Function(String name, String surfaceId);

/// Rappel du statut de décision lu dans la checklist (`decisionStatus`).
typedef DecisionStatusCallback = void Function(String status);

/// Disponibilité des actions pour les Barres d'actions du dessous : `enabled`
/// dit si un clic est possible, `onAction` reçoit le clic.
///
/// Dit aussi quelle action est en cours (`busyAction`, indicateur sur son
/// bouton) et quelles décisions sont déjà prises (`doneActions` : bouton
/// « fait », inactif, sans requête). La checklist signale son statut par
/// `onDecisionStatus`.
///
/// Interne à la slice `canvas` (les composants du catalogue ne connaissent ni
/// Bloc ni backend). Sans fournisseur au-dessus, [maybeOf] renvoie `null` et
/// les boutons restent inactifs.
class ActionAvailability extends InheritedWidget {
  const ActionAvailability({
    super.key,
    required this.enabled,
    required this.onAction,
    required super.child,
    this.busyAction,
    this.doneActions = const <String>{},
    this.onDecisionStatus,
  });

  final bool enabled;
  final ActionCallback onAction;

  /// Action en cours d'envoi ou d'exécution, s'il y en a une.
  final String? busyAction;

  /// Actions dont la décision est en place.
  final Set<String> doneActions;

  /// Reçoit le statut de décision affiché par la checklist.
  final DecisionStatusCallback? onDecisionStatus;

  static ActionAvailability? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ActionAvailability>();

  /// Sans s'abonner : le rappel du statut est stable, la checklist n'a pas à
  /// se reconstruire quand les boutons changent d'état.
  static DecisionStatusCallback? decisionReporterOf(BuildContext context) =>
      context
          .getInheritedWidgetOfExactType<ActionAvailability>()
          ?.onDecisionStatus;

  @override
  bool updateShouldNotify(ActionAvailability oldWidget) =>
      enabled != oldWidget.enabled ||
      onAction != oldWidget.onAction ||
      busyAction != oldWidget.busyAction ||
      !setEquals(doneActions, oldWidget.doneActions);
}

/// Relie le `CanvasActionBloc` (fourni au-dessus) aux Barres d'actions de
/// [child] : actives tant que le Bloc est au repos et que [enabled] vaut
/// `true` (faux en mode rejeu : aucune requête ne part).
///
/// Garde aussi la décision prise : le statut de décision de la checklist qui
/// change après un clic fixe l'action cliquée comme « faite » ; un nouveau
/// changement de ce statut (par exemple une demande vocale qui réécrit
/// `/checklist`) la réactive. Un clic reste « en attente de décision » jusqu'à
/// ce changement, même après le retour des boutons au repos (le statut peut
/// arriver après la fin de l'activité) ; seul un échec de l'envoi l'annule.
class CanvasActionScope extends StatefulWidget {
  const CanvasActionScope({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  State<CanvasActionScope> createState() => _CanvasActionScopeState();
}

class _CanvasActionScopeState extends State<CanvasActionScope> {
  /// Dernier statut de décision vu dans la checklist.
  String? _status;

  /// Action cliquée dont la décision n'est pas encore arrivée, et statut au
  /// moment du clic.
  String? _clicked;
  String? _statusAtClick;

  /// Action dont la décision est en place, et le statut qui la porte.
  String? _decidedAction;
  String? _decidedStatus;

  void _onAction(String name, String surfaceId) {
    _clicked = name;
    _statusAtClick = _status;
    context.read<CanvasActionBloc>().add(ActionRequested(name, surfaceId));
  }

  void _onStatus(String status) {
    if (status == _status) return;
    setState(() {
      _status = status;
      final String? clicked = _clicked;
      if (clicked != null && status != _statusAtClick) {
        _decidedAction = clicked;
        _decidedStatus = status;
        _clicked = null;
      } else if (_decidedAction != null && status != _decidedStatus) {
        _decidedAction = null;
        _decidedStatus = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<CanvasActionBloc, CanvasActionState>(
        // Le clic n'a pas abouti : il n'attend plus de changement de statut.
        listenWhen: (CanvasActionState previous, CanvasActionState next) =>
            next is ActionFailed,
        listener: (BuildContext context, CanvasActionState state) =>
            _clicked = null,
        builder: (BuildContext context, CanvasActionState state) =>
            ActionAvailability(
              enabled: widget.enabled && state is ActionIdle,
              onAction: _onAction,
              busyAction: switch (state) {
                ActionSending(:final String name) => name,
                ActionRunning(:final String name) => name,
                _ => null,
              },
              doneActions: <String>{?_decidedAction},
              onDecisionStatus: _onStatus,
              child: widget.child,
            ),
      );
}
