import 'dart:async';

import 'package:bloc/bloc.dart';

/// Joue [act] sur le [bloc], le ferme (les events déjà postés sont traités),
/// puis renvoie les états émis dans l'ordre.
///
/// Remplace `blocTest` : `bloc_test` 10.0.0 dépend de `test`, dont les versions
/// compatibles avec `test_api` 0.7.12 (Flutter 3.47.8) exigent `analyzer` < 14,
/// alors que `build_runner` 2.16.1 de l'app exige `analyzer` ^14.3.
Future<List<S>> statesAfter<B extends BlocBase<S>, S>(
  B bloc,
  FutureOr<void> Function(B bloc) act,
) async {
  final List<S> emitted = <S>[];
  final StreamSubscription<S> sub = bloc.stream.listen(emitted.add);
  await act(bloc);
  await Future<void>.delayed(Duration.zero);
  await bloc.close();
  await sub.cancel();
  return emitted;
}
