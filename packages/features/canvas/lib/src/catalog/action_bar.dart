import 'package:entity_catalog/entity_catalog.dart' show GenesisContract;
import 'package:flutter/material.dart';
import 'package:genui/genui.dart' show CatalogItem;
import 'package:shared_design_system/shared_design_system.dart';

import '../ui/action_availability.dart';
import 'bound_item.dart';

/// `ActionBar` : la Barre d'actions (titre et boutons de décision) liée à
/// `/actions`. Le contrat est strict : un `id` hors de
/// `GenesisContract.actionIds` ou un `tone` hors de
/// `GenesisContract.actionTones` donnent l'état neutre (RG-10).
///
/// Les boutons ne sont actifs que si un [ActionAvailability] au-dessus les y
/// autorise ; le clic appelle son `onAction(id, surface)` (la barre ne connaît
/// ni Bloc ni backend). Sans fournisseur, ils restent inactifs.
final CatalogItem actionBarItem = boundCatalogItem<_ActionBar>(
  name: 'ActionBar',
  description: 'Barre d\'actions liée à /actions.',
  parse: _ActionBar.tryParse,
  build: (BuildContext context, _ActionBar bar) => _ActionBarView(bar: bar),
);

class _Action {
  const _Action(this.id, this.label, this.tone);

  final String id;
  final String label;
  final String tone;
}

class _ActionBar {
  const _ActionBar({required this.title, required this.actions});

  final String title;
  final List<_Action> actions;

  static _ActionBar? tryParse(Object raw) {
    if (raw is! Map) return null;
    final String? title = readString(raw, 'title');
    final List<Map<Object?, Object?>>? rawActions = readMaps(raw, 'actions');
    if (title == null || rawActions == null) return null;
    final List<_Action> actions = <_Action>[];
    for (final Map<Object?, Object?> a in rawActions) {
      final String? id = readString(a, 'id');
      final String? label = readString(a, 'label');
      final String? tone = readString(a, 'tone');
      if (id == null ||
          label == null ||
          tone == null ||
          !GenesisContract.actionIds.contains(id) ||
          !GenesisContract.actionTones.contains(tone)) {
        return null;
      }
      actions.add(_Action(id, label, tone));
    }
    return _ActionBar(title: title, actions: actions);
  }
}

/// Surface qui porte la Barre d'actions (le contrat n'en admet qu'une).
final String _surfaceId = GenesisContract.surfaceOf('ActionBar')!;

class _ActionBarView extends StatelessWidget {
  const _ActionBarView({required this.bar});

  final _ActionBar bar;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final ActionAvailability? availability = ActionAvailability.maybeOf(
      context,
    );
    final bool enabled = availability?.enabled ?? false;
    return CellFrame(
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(bar.title, style: theme.label),
          for (final _Action action in bar.actions)
            OutlinedButton(
              key: Key('action-${action.id}'),
              onPressed: enabled
                  ? () => availability!.onAction(action.id, _surfaceId)
                  : null,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                disabledForegroundColor: action.tone == 'danger'
                    ? theme.blockingForeground
                    : theme.textPrimary,
              ),
              child: Text(action.label, style: theme.body),
            ),
        ],
      ),
    );
  }
}
