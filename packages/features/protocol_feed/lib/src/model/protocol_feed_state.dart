/// Opération A2UI d'un message.
enum ProtocolOperation {
  createSurface,
  updateComponents,
  updateDataModel,
  deleteSurface,
  unknown,
}

/// Une ligne du flux du protocole.
class ProtocolEntry {
  const ProtocolEntry({
    required this.index,
    required this.timestampMs,
    required this.operation,
    required this.accepted,
    required this.json,
    required this.truncated,
    this.agent,
    this.task,
    this.surfaceId,
    this.rejectionCode,
  });

  /// Marque ajoutée à la fin d'un JSON tronqué.
  static const String truncationMark = '\n… (tronqué)';

  /// Rang croissant depuis la dernière remise à vide (jamais réutilisé).
  final int index;

  /// Horodatage unix en ms, lu sur l'horloge injectée.
  final int timestampMs;
  final String? agent;
  final String? task;
  final ProtocolOperation operation;
  final String? surfaceId;

  /// `false` : message refusé, voir [rejectionCode].
  final bool accepted;
  final String? rejectionCode;

  /// JSON brut mis en forme et borné. Texte brut : à afficher sans Markdown.
  final String json;
  final bool truncated;

  @override
  bool operator ==(Object other) =>
      other is ProtocolEntry &&
      other.index == index &&
      other.timestampMs == timestampMs &&
      other.agent == agent &&
      other.task == task &&
      other.operation == operation &&
      other.surfaceId == surfaceId &&
      other.accepted == accepted &&
      other.rejectionCode == rejectionCode &&
      other.json == json &&
      other.truncated == truncated;

  @override
  int get hashCode => Object.hash(
    index,
    timestampMs,
    agent,
    task,
    operation,
    surfaceId,
    accepted,
    rejectionCode,
    json,
    truncated,
  );
}

/// État du panneau du protocole.
class ProtocolFeedState {
  const ProtocolFeedState({
    required this.entries,
    required this.expanded,
    required this.totalCount,
    this.highlightedIndex,
  });

  /// État initial : replié, vide.
  const ProtocolFeedState.empty()
    : entries = const <ProtocolEntry>[],
      expanded = false,
      totalCount = 0,
      highlightedIndex = null;

  /// Entrées retenues, de la plus ancienne à la plus récente.
  final List<ProtocolEntry> entries;
  final bool expanded;

  /// Nombre de messages affichables reçus, évincés compris.
  final int totalCount;

  /// [ProtocolEntry.index] du message en évidence (par défaut le dernier).
  final int? highlightedIndex;

  ProtocolEntry? get _highlighted {
    for (final ProtocolEntry e in entries) {
      if (e.index == highlightedIndex) return e;
    }
    return null;
  }

  /// Surface du message en évidence (contour pointillé), `null` sans surface
  /// lisible ou si le message a été évincé.
  String? get highlightedSurfaceId => _highlighted?.surfaceId;

  ProtocolFeedState copyWith({
    List<ProtocolEntry>? entries,
    bool? expanded,
    int? totalCount,
    int? Function()? highlightedIndex,
  }) => ProtocolFeedState(
    entries: entries ?? this.entries,
    expanded: expanded ?? this.expanded,
    totalCount: totalCount ?? this.totalCount,
    highlightedIndex: highlightedIndex != null
        ? highlightedIndex()
        : this.highlightedIndex,
  );

  @override
  bool operator ==(Object other) =>
      other is ProtocolFeedState &&
      other.expanded == expanded &&
      other.totalCount == totalCount &&
      other.highlightedIndex == highlightedIndex &&
      _sameEntries(other.entries, entries);

  @override
  int get hashCode => Object.hash(
    expanded,
    totalCount,
    highlightedIndex,
    Object.hashAll(entries),
  );
}

bool _sameEntries(List<ProtocolEntry> a, List<ProtocolEntry> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
