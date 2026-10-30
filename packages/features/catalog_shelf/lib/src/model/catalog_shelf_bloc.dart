import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:entity_catalog/entity_catalog.dart';

import 'catalog_shelf_event.dart';
import 'catalog_shelf_state.dart';

/// Étagère du catalogue (FR-06) : un composant est « utilisé » tant qu'une
/// surface acceptée le porte. Seuls les messages `accepted` comptent.
class CatalogShelfBloc extends Bloc<CatalogShelfEvent, CatalogShelfState> {
  CatalogShelfBloc() : super(const CatalogShelfState.empty()) {
    on<CatalogShelfSourceSubscribed>(_onSubscribed, transformer: restartable());
    on<CatalogShelfCleared>((event, emit) {
      _bySurface.clear();
      _emitIfChanged(const CatalogShelfState.empty(), emit);
    }, transformer: sequential());
  }

  /// Types de composants portés, par surface.
  final Map<String, Set<String>> _bySurface = <String, Set<String>>{};

  Future<void> _onSubscribed(
    CatalogShelfSourceSubscribed event,
    Emitter<CatalogShelfState> emit,
  ) => emit.onEach<ValidatedEnvelope>(
    event.envelopes,
    onData: (ValidatedEnvelope envelope) => _apply(envelope, emit),
    // Une erreur du flux est ignorée.
    onError: (Object error, StackTrace stackTrace) {},
  );

  void _apply(ValidatedEnvelope envelope, Emitter<CatalogShelfState> emit) {
    if (envelope.verdict is! ValidationAccepted) return;
    final Object? update = envelope.raw['updateComponents'];
    final Object? delete = envelope.raw['deleteSurface'];
    if (update is Map) {
      final Object? surface = update['surfaceId'];
      final Object? components = update['components'];
      if (surface is! String || components is! List) return;
      for (final Object? c in components) {
        final Object? type = c is Map ? c['component'] : null;
        if (type is String &&
            GenesisContract.catalogComponents.contains(type)) {
          (_bySurface[surface] ??= <String>{}).add(type);
        }
      }
    } else if (delete is Map) {
      final Object? surface = delete['surfaceId'];
      if (surface is String) _bySurface.remove(surface);
    } else {
      return;
    }
    _emitIfChanged(
      CatalogShelfState.fromUsed(_bySurface.values.expand((s) => s).toSet()),
      emit,
    );
  }

  void _emitIfChanged(CatalogShelfState next, Emitter<CatalogShelfState> emit) {
    if (next != state) emit(next);
  }
}
