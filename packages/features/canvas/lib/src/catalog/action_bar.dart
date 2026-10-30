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
  build: (BuildContext context, _ActionBar bar, String surfaceId) =>
      _ActionBarView(bar: bar, surfaceId: surfaceId),
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

/// Ton `danger` de `GenesisContract.actionTones` (l'autre est `neutral`).
const String _toneDanger = 'danger';

/// Couleurs d'un bouton selon son `tone` : seule résolution du ton.
({Color foreground, Color border}) _toneColors(SceneTheme theme, String tone) =>
    tone == _toneDanger
    ? (foreground: theme.blockingForeground, border: theme.actionDangerBorder)
    : (foreground: theme.textPrimary, border: theme.actionNeutralBorder);

/// Style d'un bouton selon son `tone` (code fermé `neutral|danger`), jamais
/// selon son libellé (RG-09). Le texte reste lisible quand le bouton est
/// inactif ; seule l'épaisseur de la bordure distingue les deux états.
ButtonStyle _style(SceneTheme theme, String tone) {
  final (:Color foreground, border: Color borderColor) = _toneColors(
    theme,
    tone,
  );
  return OutlinedButton.styleFrom(
    minimumSize: const Size(0, 48),
    foregroundColor: foreground,
    disabledForegroundColor: foreground,
  ).copyWith(
    side: WidgetStateProperty.resolveWith(
      (Set<WidgetState> states) => BorderSide(
        color: borderColor,
        width: states.contains(WidgetState.disabled) ? 1 : 2,
      ),
    ),
  );
}

class _ActionBarView extends StatelessWidget {
  const _ActionBarView({required this.bar, required this.surfaceId});

  final _ActionBar bar;

  /// Surface du contexte de rendu, transmise au clic.
  final String surfaceId;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final ActionAvailability? availability = ActionAvailability.maybeOf(
      context,
    );
    final bool enabled = availability?.enabled ?? false;
    return CellFrame(
      // 12 + 48 + 12 = 72 : le bouton tient, centré, dans le bandeau.
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              bar.title,
              style: theme.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          for (final _Action action in bar.actions) ...<Widget>[
            const SizedBox(width: 16),
            Flexible(
              child: OutlinedButton(
                key: Key('action-${action.id}'),
                onPressed: enabled
                    ? () => availability!.onAction(action.id, surfaceId)
                    : null,
                style: _style(theme, action.tone),
                child: Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.body.copyWith(
                    color: _toneColors(theme, action.tone).foreground,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
