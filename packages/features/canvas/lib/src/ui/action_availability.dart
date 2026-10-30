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
/// Interne à la slice `canvas` (les composants du catalogue ne connaissent ni
/// Bloc ni backend). Sans fournisseur au-dessus, [maybeOf] renvoie `null` et
/// les boutons restent inactifs.
class ActionAvailability extends InheritedWidget {
  const ActionAvailability({
    super.key,
    required this.enabled,
    required this.onAction,
    required super.child,
  });

  final bool enabled;
  final ActionCallback onAction;

  static ActionAvailability? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ActionAvailability>();

  @override
  bool updateShouldNotify(ActionAvailability oldWidget) =>
      enabled != oldWidget.enabled || onAction != oldWidget.onAction;
}

/// Relie le `CanvasActionBloc` (fourni au-dessus) aux Barres d'actions de
/// [child] : actives tant que le Bloc est au repos et que [enabled] vaut
/// `true` (faux en mode rejeu : aucune requête ne part).
class CanvasActionScope extends StatelessWidget {
  const CanvasActionScope({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final CanvasActionBloc bloc = context.read<CanvasActionBloc>();
    return BlocBuilder<CanvasActionBloc, CanvasActionState>(
      builder: (BuildContext context, CanvasActionState state) =>
          ActionAvailability(
            enabled: enabled && state is ActionIdle,
            onAction: (String name, String surfaceId) =>
                bloc.add(ActionRequested(name, surfaceId)),
            child: child,
          ),
    );
  }
}
