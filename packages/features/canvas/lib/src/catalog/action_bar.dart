import 'package:entity_catalog/entity_catalog.dart' show GenesisContract;
import 'package:flutter/material.dart';
import 'package:genui/genui.dart' show CatalogItem;
import 'package:shared_design_system/shared_design_system.dart';

import '../ui/action_availability.dart';
import '../ui/dashed_outline_painter.dart';
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

/// Hauteur du visuel d'un bouton (`.gc-btn`, 44 px) ; la cible interactive
/// reste de 48 pt, le visuel y est centré (D-05 de 013).
const double _visualHeight = 44;
const double _targetHeight = 48;
const double _visualPadding = 20;

/// Espace entre l'étiquette et les boutons (`.gc-decision`, gap 14).
const double _gap = 14;

/// Couleur du texte d'un bouton : le ton quand il est actif, `ink-muted`
/// quand il est désactivé (jamais `ink-faint` sous 24 px, pdr-0088 F12).
Color _foreground(SceneTheme theme, String tone, {required bool disabled}) {
  if (disabled) return theme.textSecondary;
  return tone == _toneDanger ? theme.blockingForeground : theme.textPrimary;
}

/// Style du bouton interactif : seule la cible de 48 pt et l'anneau de focus
/// `signal` (pdr-0084 U4, `sceneTargetStyle`) ; l'apparence est celle du
/// visuel [_ButtonVisual].
ButtonStyle _style(SceneTheme theme) =>
    sceneTargetStyle(theme, height: _targetHeight);

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
    final String? busy = availability?.busyAction;
    final Set<String> done = availability?.doneActions ?? const <String>{};
    return CellFrame(
      // 12 + 48 + 12 = 72 : le bouton tient, centré, dans le bandeau.
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          // Étiquette du bandeau : le `title` de la surface, en capitales.
          Flexible(
            child: DsCaps(
              bar.title,
              key: const Key('actions-label'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          for (final _Action action in bar.actions) ...<Widget>[
            const SizedBox(width: _gap),
            Flexible(
              child: OutlinedButton(
                key: Key('action-${action.id}'),
                // Décision en place : inactif et sans rappel, quoi qu'il arrive.
                onPressed: enabled && !done.contains(action.id)
                    ? () => availability!.onAction(action.id, surfaceId)
                    : null,
                style: _style(theme),
                child: _ButtonVisual(
                  id: action.id,
                  label: action.label,
                  tone: action.tone,
                  disabled: !(enabled && !done.contains(action.id)),
                  done: done.contains(action.id),
                  busy: !done.contains(action.id) && busy == action.id,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Visuel d'un bouton (`.gc-btn`) : 44 px de haut, rayon `md`, fond
/// `surface-300`, bordure 1 px `ink-muted` ; en ton `danger`, texte et bordure
/// `nogo`, fond `nogo-ghost` et lueur ; désactivé, bordure en tirets et texte
/// `ink-muted`. Contient le libellé, précédé d'un indicateur quand l'action est
/// en cours, ou suivi de « fait ✓ » quand la décision est en place.
class _ButtonVisual extends StatelessWidget {
  const _ButtonVisual({
    required this.id,
    required this.label,
    required this.tone,
    required this.disabled,
    required this.done,
    required this.busy,
  });

  final String id;
  final String label;
  final String tone;
  final bool disabled;
  final bool done;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final bool danger = tone == _toneDanger;
    final Color color = _foreground(theme, tone, disabled: disabled);
    return Container(
      key: Key('action-$id-visual'),
      height: _visualHeight,
      padding: const EdgeInsets.symmetric(horizontal: _visualPadding),
      decoration: BoxDecoration(
        color: danger && !disabled
            ? theme.blockingBackground
            : theme.surface300,
        borderRadius: SceneRadius.borderMd,
        border: disabled
            ? null
            : Border.all(
                color: danger
                    ? theme.actionDangerBorder
                    : theme.actionNeutralBorder,
              ),
        boxShadow: danger && !disabled ? SceneShadow.glowNogo : null,
      ),
      child: CustomPaint(
        key: disabled ? Key('action-$id-dashes') : null,
        painter: disabled
            ? DashedOutlinePainter(
                color: theme.actionNeutralBorder,
                strokeWidth: 1,
                dash: 5,
                gap: 3,
                radius: SceneRadius.md,
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (busy) ...<Widget>[
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3, color: color),
              ),
              const SizedBox(width: 12),
            ],
            Flexible(
              child: Text(
                done ? '$label \u00B7 fait \u2713' : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.button.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
