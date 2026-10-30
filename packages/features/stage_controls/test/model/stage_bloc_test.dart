import 'package:feature_stage_controls/feature_stage_controls.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testing_bloc_harness/testing_bloc_harness.dart';

void main() {
  test("l'état initial est l'acte 1", () {
    final bloc = StageBloc();
    addTearDown(bloc.close);

    expect(bloc.state, const StageState(act: 1));
    expect(bloc.state.actName, 'Créer');
  });

  test('noms des actes exposés comme constantes', () {
    expect(StageState.actNames, <String>['Créer', 'Transformer', 'Interagir']);
    expect(StageState.actCount, 3);
  });

  test('StageActAdvanced : 1, 2, 3 puis retour cyclique à 1', () async {
    final states = await statesAfter(StageBloc(), (bloc) {
      for (var i = 0; i < 4; i++) {
        bloc.add(const StageActAdvanced());
      }
    });

    expect(states.map((s) => s.act), <int>[2, 3, 1, 2]);
    expect(states.map((s) => s.actName), <String>[
      'Transformer',
      'Interagir',
      'Créer',
      'Transformer',
    ]);
  });

  test("StageResetRequested ramène à l'acte 1", () async {
    final states = await statesAfter(StageBloc(), (bloc) {
      bloc
        ..add(const StageActAdvanced())
        ..add(const StageActAdvanced())
        ..add(const StageResetRequested());
    });

    expect(states.map((s) => s.act), <int>[2, 3, 1]);
  });

  test("StageResetRequested à l'acte 1 laisse l'acte 1", () async {
    final bloc = StageBloc();
    await statesAfter(bloc, (bloc) => bloc.add(const StageResetRequested()));

    expect(bloc.state.act, 1);
  });

  test('StageActReached : 1 puis 2 puis 3, monotone', () async {
    final bloc = StageBloc();
    final states = await statesAfter(bloc, (bloc) {
      bloc
        ..add(const StageActReached(1))
        ..add(const StageActReached(2))
        ..add(const StageActReached(3));
    });

    expect(states.map((s) => s.act), <int>[2, 3]);
    expect(bloc.state.act, 3);
  });

  test('StageActReached ne recule jamais : 3 puis 2 reste 3', () async {
    final bloc = StageBloc();
    await statesAfter(bloc, (bloc) {
      bloc
        ..add(const StageActReached(3))
        ..add(const StageActReached(2));
    });

    expect(bloc.state.act, 3);
  });

  test('StageActReached saute directement à l\'acte demandé', () async {
    final bloc = StageBloc();
    await statesAfter(bloc, (bloc) => bloc.add(const StageActReached(3)));

    expect(bloc.state.act, 3);
  });

  test('StageResetRequested après StageActReached ramène à 1', () async {
    final bloc = StageBloc();
    await statesAfter(bloc, (bloc) {
      bloc
        ..add(const StageActReached(3))
        ..add(const StageResetRequested());
    });

    expect(bloc.state.act, 1);
  });

  test('un clic manuel corrige une avance automatique', () async {
    final bloc = StageBloc();
    await statesAfter(bloc, (bloc) {
      bloc
        ..add(const StageActReached(3))
        ..add(const StageActAdvanced());
    });

    expect(bloc.state.act, 1);
  });

  test('StageActReached hors 1..3 est ignoré', () async {
    final bloc = StageBloc();
    final states = await statesAfter(bloc, (bloc) {
      bloc
        ..add(const StageActReached(2))
        ..add(const StageActReached(0))
        ..add(const StageActReached(4))
        ..add(const StageActReached(-1));
    });

    expect(states.map((s) => s.act), <int>[2]);
    expect(bloc.state.act, 2);
  });

  test('StageState est une valeur et refuse un acte hors 1..3', () {
    expect(const StageState(act: 2), const StageState(act: 2));
    expect(
      const StageState(act: 2).hashCode,
      const StageState(act: 2).hashCode,
    );
    expect(const StageState(act: 2), isNot(const StageState(act: 3)));
    expect(() => StageState(act: 0), throwsA(isA<AssertionError>()));
    expect(() => StageState(act: 4), throwsA(isA<AssertionError>()));
  });
}
