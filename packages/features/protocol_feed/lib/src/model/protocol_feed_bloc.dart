import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:entity_catalog/entity_catalog.dart';
import 'package:shared_core/shared_core.dart';

import 'protocol_feed_event.dart';
import 'protocol_feed_state.dart';

/// Journal du protocole A2UI (FR-05) : une entrée par message validé, hors
/// `ignored`. Le dernier message reçu est mis en évidence.
class ProtocolFeedBloc extends Bloc<ProtocolFeedEvent, ProtocolFeedState> {
  ProtocolFeedBloc({
    required this.clock,
    this.maxJsonChars = 2000,
    this.retention = 200,
  }) : super(const ProtocolFeedState.empty()) {
    on<ProtocolSourceSubscribed>(_onSubscribed, transformer: restartable());
    on<ProtocolFeedCleared>((event, emit) {
      _nextIndex = 0;
      emit(const ProtocolFeedState.empty());
    }, transformer: sequential());
    on<ProtocolFeedEntriesCleared>((event, emit) {
      _nextIndex = 0;
      emit(ProtocolFeedState.empty().copyWith(expanded: state.expanded));
    }, transformer: sequential());
    on<PanelToggled>(
      (event, emit) => emit(state.copyWith(expanded: !state.expanded)),
      transformer: droppable(),
    );
  }

  /// Taille maximale du JSON affiché par entrée.
  final int maxJsonChars;

  /// Nombre maximal d'entrées conservées.
  final int retention;

  /// Horloge injectée (horodatage des entrées).
  final AppClock clock;
  int _nextIndex = 0;

  Future<void> _onSubscribed(
    ProtocolSourceSubscribed event,
    Emitter<ProtocolFeedState> emit,
  ) => emit.onEach<ValidatedEnvelope>(
    event.envelopes,
    onData: (ValidatedEnvelope envelope) => _append(envelope, emit),
    // Une erreur du flux est ignorée.
    onError: (Object error, StackTrace stackTrace) {},
  );

  void _append(ValidatedEnvelope envelope, Emitter<ProtocolFeedState> emit) {
    final ValidationVerdict verdict = envelope.verdict;
    if (verdict is ValidationIgnored) return;
    final (ProtocolOperation operation, String? surfaceId) = _read(
      envelope.raw,
    );
    final String full = _compactJson(envelope.raw);
    final bool truncated = full.length > maxJsonChars;
    final ProtocolEntry entry = ProtocolEntry(
      index: _nextIndex++,
      timestampMs: clock.nowUnixMs(),
      agent: envelope.agent,
      task: envelope.task,
      operation: operation,
      surfaceId: surfaceId,
      accepted: verdict is ValidationAccepted,
      rejectionCode: verdict is ValidationRejected ? verdict.code : null,
      json: truncated
          ? full.substring(0, maxJsonChars) + ProtocolEntry.truncationMark
          : full,
      truncated: truncated,
    );
    final List<ProtocolEntry> entries = <ProtocolEntry>[
      ...state.entries,
      entry,
    ];
    if (entries.length > retention) {
      entries.removeRange(0, entries.length - retention);
    }
    emit(
      state.copyWith(
        entries: entries,
        totalCount: state.totalCount + 1,
        highlightedIndex: () => entry.index,
      ),
    );
  }

  /// JSON compact du corps de l'opération (sans la clé `version`, constante
  /// qui ne dit rien du message) ; pour une opération inconnue, du message
  /// entier. Le message brut n'est jamais modifié.
  String _compactJson(Map<String, Object?> raw) {
    for (final String key in _operationKeys) {
      if (raw.containsKey(key)) return jsonEncode(raw[key]);
    }
    return jsonEncode(raw);
  }

  static const List<String> _operationKeys = <String>[
    'createSurface',
    'updateComponents',
    'updateDataModel',
    'deleteSurface',
  ];

  /// Lit au mieux l'opération et la surface d'un message brut.
  (ProtocolOperation, String?) _read(Map<String, Object?> raw) {
    for (final MapEntry<String, Object?> e in raw.entries) {
      final ProtocolOperation? operation = switch (e.key) {
        'createSurface' => ProtocolOperation.createSurface,
        'updateComponents' => ProtocolOperation.updateComponents,
        'updateDataModel' => ProtocolOperation.updateDataModel,
        'deleteSurface' => ProtocolOperation.deleteSurface,
        _ => null,
      };
      if (operation == null) continue;
      final Object? body = e.value;
      final Object? id = body is Map ? body['surfaceId'] : null;
      return (operation, id is String ? id : null);
    }
    return (ProtocolOperation.unknown, null);
  }
}
