---
id: test-bloc-mockbloc-whenlisten
title: MockBloc et whenListen pour les tests de widgets
tags: [bloc, bloc_test, widgets, mocktail]
status: verified
updated: 2026-10-28
sources: [https://pub.dev/packages/bloc_test]
links: [test-bloc-test, test-mocktail-vs-mockito, test-pyramid-flutter, bloc-providers-selector, bloc-no-cubit]
---
# Isoler un widget de son BLoC avec MockBloc et whenListen

Dans un test de widget, on remplace le bloc par un `MockBloc` (bâti sur mocktail ; `MockCubit` existe aussi, mais Cubit est exclu : `bloc-no-cubit`). `whenListen` lui fait émettre une séquence d'états figée et garde `state` synchronisé avec la dernière valeur.

```dart
class MockVoiceBloc extends MockBloc<VoiceSessionEvent, VoiceSessionState>
    implements VoiceSessionBloc {}

testWidgets('affiche l’onde quand l’IA parle', (tester) async {
  final bloc = MockVoiceBloc();
  whenListen(
    bloc,
    Stream.fromIterable([const VoiceSessionState.speaking()]),
    initialState: const VoiceSessionState.listening(),
  );
  await tester.pumpWidget(BlocProvider<VoiceSessionBloc>.value(
    value: bloc, child: const MaterialApp(home: VoicePanel())));
  await tester.pump();
  expect(find.byType(Waveform), findsOneWidget);
});
```

## Quand l'utiliser
- Le test porte sur le rendu d'un état, pas sur la logique du bloc.
- Pour un flux complet (BDD ou integration), injecter le vrai bloc avec des fakes aux frontières.

## ⚠️ Pièges
- Sans `initialState`, `bloc.state` n'est pas stubbé avant la première émission (mocktail renvoie `null` → `TypeError` pour un état non nullable). Déduit du fonctionnement de mocktail, non écrit dans le README.
- Les events ajoutés par le widget se vérifient avec `verify(() => bloc.add(...))`, avec `registerFallbackValue` si nécessaire.
