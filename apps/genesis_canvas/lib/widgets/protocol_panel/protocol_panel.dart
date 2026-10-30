import 'package:feature_protocol_feed/feature_protocol_feed.dart'
    show
        PanelToggled,
        ProtocolEntry,
        ProtocolFeedBloc,
        ProtocolFeedState,
        ProtocolOperation;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_design_system/shared_design_system.dart' show SceneTheme;

/// Panneau « FLUX A2UI · live » (FR-05) : les messages A2UI en cours de
/// fabrication, avec le dernier en évidence.
///
/// Replié par défaut : seul le titre, le nombre de messages et le bouton
/// `protocol-toggle` sont visibles. Déplié, il montre les dernières entrées
/// (`protocol-entry-<n>`, `n` = rang du Bloc) ; la page le pose à droite, en
/// recouvrement du canevas, sans redimensionner celui-ci : le panneau se
/// dimensionne lui-même ([collapsedSize], [expandedSize]).
///
/// Le JSON vient d'un modèle de langage : il est affiché en `Text` brut, borné
/// (`maxLines` et ellipse), jamais interprété en Markdown. Un message refusé
/// porte la marque « refusé » et le code fermé du refus.
class ProtocolPanel extends StatelessWidget {
  const ProtocolPanel({super.key = const Key('protocol-panel')});

  /// Taille repliée : tient dans la rangée du bas (140 px du budget des zones).
  static const Size collapsedSize = Size(460, 140);

  /// Taille dépliée : recouvre le canevas à droite.
  static const Size expandedSize = Size(780, 620);

  /// Nombre d'entrées montrées (les plus récentes).
  static const int visibleEntries = 4;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: BlocBuilder<ProtocolFeedBloc, ProtocolFeedState>(
        builder: (BuildContext context, ProtocolFeedState state) {
          final Size size = state.expanded ? expandedSize : collapsedSize;
          return SizedBox.fromSize(
            size: size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.neutralBackground, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _Header(state: state),
                    if (state.expanded)
                      Expanded(child: _Entries(state: state))
                    else
                      Text(
                        _countText(state.totalCount),
                        style: theme.body.copyWith(color: theme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _countText(int count) =>
      count == 1 ? '1 message' : '$count messages';
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final ProtocolFeedState state;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'FLUX A2UI · live',
            style: theme.label.copyWith(color: theme.accent),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          key: const Key('protocol-toggle'),
          onPressed: () =>
              context.read<ProtocolFeedBloc>().add(const PanelToggled()),
          style: TextButton.styleFrom(
            foregroundColor: theme.textPrimary,
            textStyle: theme.label,
          ),
          child: Text(state.expanded ? 'Replier' : 'Déplier'),
        ),
      ],
    );
  }
}

class _Entries extends StatelessWidget {
  const _Entries({required this.state});

  final ProtocolFeedState state;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    if (state.entries.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: Text(
          "Aucun message pour l'instant",
          style: theme.body.copyWith(color: theme.textSecondary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    final List<ProtocolEntry> shown =
        state.entries.length > ProtocolPanel.visibleEntries
        ? state.entries.sublist(
            state.entries.length - ProtocolPanel.visibleEntries,
          )
        : state.entries;
    return ClipRect(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final ProtocolEntry entry in shown)
            _EntryTile(
              entry: entry,
              current: entry.index == state.highlightedIndex,
            ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.current});

  final ProtocolEntry entry;
  final bool current;

  static String _operationName(ProtocolOperation operation) =>
      switch (operation) {
        ProtocolOperation.createSurface => 'createSurface',
        ProtocolOperation.updateComponents => 'updateComponents',
        ProtocolOperation.updateDataModel => 'updateDataModel',
        ProtocolOperation.deleteSurface => 'deleteSurface',
        ProtocolOperation.unknown => 'inconnu',
      };

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _time(int unixMs) {
    final DateTime t = DateTime.fromMillisecondsSinceEpoch(unixMs);
    return '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final String? surface = entry.surfaceId;
    final String? agent = entry.agent;
    final TextStyle body = theme.body.copyWith(color: theme.textSecondary);
    return Padding(
      key: Key('protocol-entry-${entry.index}'),
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
        // Le message en cours : fond de scène et contour d'accent.
        key: current ? const Key('protocol-current') : null,
        decoration: BoxDecoration(
          color: current ? theme.background : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: current ? theme.accent : theme.neutralBackground,
            width: current ? 3 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(_time(entry.timestampMs), style: body, maxLines: 1),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      surface == null
                          ? _operationName(entry.operation)
                          : '${_operationName(entry.operation)} · $surface',
                      style: theme.label.copyWith(color: theme.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (agent != null) ...<Widget>[
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        agent,
                        style: body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  if (!entry.accepted) ...<Widget>[
                    const SizedBox(width: 12),
                    Flexible(
                      flex: 2,
                      child: _RefusedMark(code: entry.rejectionCode),
                    ),
                  ],
                ],
              ),
              Text(
                entry.json,
                key: Key('protocol-json-${entry.index}'),
                style: body.copyWith(fontFamily: 'monospace', height: 1.2),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RefusedMark extends StatelessWidget {
  const _RefusedMark({required this.code});

  final String? code;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final TextStyle style = theme.label.copyWith(
      color: theme.blockingForeground,
    );
    final String? shownCode = code;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.blockingBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('refusé', style: style, maxLines: 1),
            if (shownCode != null) ...<Widget>[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  shownCode,
                  style: style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
