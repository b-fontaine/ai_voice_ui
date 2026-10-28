---
id: arch-official-components
title: Guide officiel — rôle des Views, ViewModels, Repositories, Services
tags: [flutter, architecture, mvvm, repository, official]
status: verified
updated: 2026-10-28
sources: [https://docs.flutter.dev/app-architecture/guide]
links: [arch-official-layers, arch-command-pattern, arch-result-pattern, di-no-service-locator, bloc-no-cubit]
---
# Responsabilités de chaque composant (doc officielle)

**View** : une composition de widgets, souvent un écran avec `Scaffold`, mais « une view n'équivaut pas à un widget » (c'est un terme abstrait : plusieurs widgets composent une view).
- Elle ne contient **aucune logique métier**.
- Seules sont tolérées : les conditions d'affichage simples, l'animation, le layout selon l'appareil et le routing simple.

**ViewModel** : il convertit les données de l'app en *UI state*.
- Il lit les repositories, puis filtre, trie et agrège.
- Il conserve l'état pour les rebuilds et expose des **commands**.
- « La plupart de la logique vit dans les view models. » Il se teste sans widgets.

**Repository** : la source de vérité des données du modèle.
- Il transforme les données des services en **modèles de domaine**.
- Il gère le cache, les erreurs, le retry, le refresh et le polling.
- Il porte l'**état de cycle de vie global** : session utilisateur, cache mémoire.
- Exemple : `Stream<UserProfile?>`.

**Service** : il enveloppe une source externe (REST, plateforme, fichiers) et expose des `Future`/`Stream`.
- Il est **sans état**, généralement un service par source de données.

**Transposition à une app multi-agents avec agent vocal (opinion) :**
- `OpenAiRealtimeService` / `GeminiLiveService` : services sans état (transport WebRTC/WebSocket).
- `VoiceSessionRepository` : état de la session, flux d'événements, tool calls.
- `VoiceSessionBloc` : le rôle de ViewModel (Bloc, pas Cubit : `bloc-no-cubit`).

⚠️ Pièges
- Dans ai_voice_widget, le runner (le service) porte de l'état et des StreamControllers en singleton, ce qui empêche le redémarrage (`proj-avw-risks`). L'état doit vivre dans le repository.
