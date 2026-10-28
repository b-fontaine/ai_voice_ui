---
id: bloc-naming
title: Conventions de nommage bloc (events, states)
tags: [bloc, naming, convention]
status: verified
updated: 2026-10-28
sources: [https://bloclibrary.dev/naming-conventions/]
links: [bloc-sealed-freezed, bloc-state-modeling]
---
# Nommage des events et des states

Conventions officielles de bloclibrary.dev. Elles sont « optional » mais « strongly recommended » pour les grands projets à plusieurs développeurs. Elles sont retenues ici comme convention d'équipe.

**Events :** au **passé**, car du point de vue du Bloc, l'événement a déjà eu lieu.
- Forme : `BlocSubject` + `Nom` (optionnel) + `Verbe`.
- Événement de chargement initial : `BlocSubject` + `Started`.
- Classe de base : `BlocSubject` + `Event`.
- ✅ `VoiceSessionStarted`, `VoiceMicTogglePressed`, `VoiceToolCallReceived`
- ❌ `StartVoice`, `Initial`, `DoToggle`, `VoiceInitialized`

**States :** des noms, car un état est un instantané.
- Avec des sous-classes : `BlocSubject` + `Action` + `Initial|InProgress|Success|Failure`.
  - ✅ `VoiceConnectInProgress`, `VoiceConnectFailure`
- Avec une classe unique : `VoiceState` + enum `VoiceStatus { initial, loading, success, failure }`.
- ❌ `Loading`, `Loaded`, `Succeeded`, `Failed`

**Ajouts recommandés (opinion) :**
- Les événements venant d'un agent (et non de l'UI) se terminent par `Received` (`VoiceToolCallReceived`, `GenUiSurfaceReceived`). Cela les distingue des actions utilisateur (`...Pressed`, `...Requested`) dans les logs du BlocObserver.
- Les événements internes (abonnement à un flux) restent privés (`_VoiceAudioLevelChanged`) ou sont remplacés par `emit.forEach` (→ [[bloc-emit-foreach]]).
