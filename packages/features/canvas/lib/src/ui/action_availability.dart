import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../model/canvas_action_bloc.dart';
import '../model/canvas_action_event.dart';
import '../model/canvas_action_state.dart';

/// Rappel d'une action cliquée : identifiant de l'action, surface qui la porte.
typedef ActionCallback = void Function(String name, String surfaceId);

/// Disponibilité des actions pour les Barres d'actions du dessous : `enabled`
/// dit si un clic est possible, `onAction` reçoit le clic.
///
/// Dit aussi quelle action est en cours (`busyAction`, indicateur sur son
/// bouton) et quelles décisions sont déjà prises (`doneActions` : bouton
/// « fait », inactif, sans requête).
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
  });

  final bool enabled;
  final ActionCallback onAction;

  /// Action en cours d'envoi ou d'exécution, s'il y en a une.
  final String? busyAction;

  /// Actions dont la décision est en place.
  final Set<String> doneActions;

  static ActionAvailability? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ActionAvailability>();

  @override
  bool updateShouldNotify(ActionAvailability oldWidget) =>
      enabled != oldWidget.enabled ||
      onAction != oldWidget.onAction ||
      busyAction != oldWidget.busyAction ||
      !setEquals(doneActions, oldWidget.doneActions);
}

/// Relie le `CanvasActionBloc` (fourni au-dessus) aux Barres d'actions de
/// [child] : actives tant que le Bloc est au repos et que [enabled] vaut
/// `true` (faux en mode rejeu : aucune requête ne part). La décision prise
/// (`doneAction`) vient du Bloc, qui reçoit le statut de la checklist de la
/// page.
class CanvasActionScope extends StatelessWidget {
  const CanvasActionScope({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  static void _onAction(BuildContext context, String name, String surfaceId) =>
      context.read<CanvasActionBloc>().add(ActionRequested(name, surfaceId));

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<CanvasActionBloc, CanvasActionState>(
        builder: (BuildContext context, CanvasActionState state) =>
            ActionAvailability(
              enabled: enabled && state is ActionIdle,
              onAction: (String name, String surfaceId) =>
                  _onAction(context, name, surfaceId),
              busyAction: switch (state) {
                ActionSending(:final String name) => name,
                ActionRunning(:final String name) => name,
                _ => null,
              },
              doneActions: <String>{?state.doneAction},
              child: child,
            ),
      );
}
