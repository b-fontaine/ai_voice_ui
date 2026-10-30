import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import 'stage_event.dart';
import 'stage_state.dart';

/// Régie de scène : tient l'acte courant (1 à 3, FR-11).
///
/// Le Bloc ne mute aucun autre Bloc et n'appelle pas le réseau : la page
/// coordonne la remise à vide (`_resetStage()`). L'avance est **cyclique**
/// (3 vers 1) : en régie, un clic sur l'indicateur doit toujours permettre de
/// revenir à l'acte 1 sans passer par la remise à vide.
class StageBloc extends Bloc<StageEvent, StageState> {
  StageBloc() : super(const StageState(act: 1)) {
    // Un seul gestionnaire séquentiel : deux `on` distincts ne garantissent
    // pas l'ordre entre types d'événements (avance puis remise à vide).
    on<StageEvent>((event, emit) {
      switch (event) {
        case StageActAdvanced():
          emit(StageState(act: state.act % StageState.actCount + 1));
        case StageResetRequested():
          emit(const StageState(act: 1));
      }
    }, transformer: sequential());
  }
}
