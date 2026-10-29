---
id: pdr-0028-linux-demo-machine
title: "PDR-0028 — La démo tourne en Flutter desktop sur la machine Linux du porteur ; macOS et Windows ne sont plus des cibles"
area: decisions
status: validated
updated: 2026-10-29
sources: [conversation porteur 2026-10-29, knowledge:rt-flutter-webrtc-overview, knowledge:genui-overview, knowledge:rt-flutter-webrtc-permissions, knowledge:rt-echo-cancellation]
links: [pdr-0002-desktop-platform, pdr-0026-desktop-only-target, pdr-0012-voice-provider-openai, pdr-0010-pinned-experimental-versions, pdr-0018-a2ui-v09-genui-0-10-4, pdr-0027-talk-context-meetup-flutter-nantes, pdr-0032-obs-video-fallback-a2ui-replay-act, p-ar-stage-runtime, p-ar-stack, p-ar-frontend, p-ar-quality, p-rm-spikes, p-rm-roadmap, p-rm-open-questions, p-fn-vision, rt-flutter-webrtc-overview, genui-overview, rt-flutter-webrtc-permissions, rt-echo-cancellation, rt-provider-abstraction]
tags: [pdr, decision, platform, desktop, linux]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-29"
scope: mixte
supersedes: [pdr-0002-desktop-platform]
superseded_by: null
---
# PDR-0028 — Machine de démo Linux

> **En bref.** La démo tourne en **Flutter desktop sous Linux**, sur la machine du porteur, projetée en 1920×1080. macOS et Windows ne sont plus des cibles : le secours Windows (Q-45, SP-09) est sans objet. `flutter_webrtc` fonctionne sur cette machine ; `genui` exige les en-têtes GStreamer et son rendu Linux reste à confirmer par un spike court (**SP-10**). Remplace [pdr-0002](pdr-0002-desktop-platform.md). Tranche Q-07.

Part de l'assistant : consignation, vérification technique sur la machine et ouverture du spike SP-10.

## Contexte
- [pdr-0002](pdr-0002-desktop-platform.md) (fiche § 1) : macOS prioritaire, Windows en secours, OS de démo non fixé (Q-07).
- Le porteur demande si Linux est bloquant, pour trouver au besoin un MacBook de secours.

## Hypothèses
- ✅ `flutter_webrtc` 1.6.3 sur cette machine (Ubuntu x86_64, Flutter 3.47.8, Impeller OpenGLES), vérifié le 2026-10-29 : compilation et exécution Linux, `enumerateDevices` = 15 (6 entrées, 6 sorties audio), `getUserMedia` audio = 1 piste, `createOffer` produit un SDP Opus [rt-flutter-webrtc-overview].
- ✅ `genui` 0.10.4 (+ `genui_a2a` 0.10.1, `a2ui_core` 0.1.1) : `flutter pub get` OK ; `flutter build linux` échoue car `audioplayers_linux` (dépendance de genui via `audioplayers` 6.8.1) exige les en-têtes GStreamer [genui-overview]. Correctif attendu : `sudo apt install libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev` (pas encore exécuté).
- ⚠️ Hypothèse non confirmée : `genui` rend correctement une surface A2UI v0.9 sous Linux → spike **SP-10** ([spikes.md](../roadmap/spikes.md)).
- Fournisseur voix : GPT-Live en WebRTC ([pdr-0012](pdr-0012-voice-provider-openai.md)) ; la voie Firebase n'a pas Linux [rt-provider-abstraction], sans effet ici.

## Options
1. **Linux, machine du porteur** (retenue)
2. macOS (MacBook de secours à trouver)

## Décision
- Cible unique de la démo : **Flutter desktop Linux** (x86_64), projection 1920×1080. La cible « desktop seul » de [pdr-0026](pdr-0026-desktop-only-target.md) est conservée ; seul l'OS change.
- macOS et Windows ne sont plus des cibles. Q-45 et SP-09 (secours Windows) sont sans objet.
- Réseau de secours : partage de connexion mobile du porteur en Wi-Fi (Q-14, géré par le porteur).
- Son (micro du PC en entrée, sortie vers la sono, micro cravate) : géré par le porteur, hors périmètre de l'assistant (Q-57).
- **Réponse de l'assistant au porteur** : Linux n'est pas bloquant à ce stade. La voix est vérifiée ; le seul point ouvert est le rendu `genui` après installation de GStreamer (SP-10). Si SP-10 échoue, le MacBook de secours redevient une option (voir « Réexaminer si »).

## Raisons
- Parole du porteur (2026-10-29) : « La machine de démo sera celle-ci, une machine Linux. Dis-moi tout de suite si c'est bloquant que je trouve une Macbook de secours ou autre, J'aurais du WiFi avec ma connexion mobile au cas où ».
- La chaîne voix est vérifiée sur la machine ; le blocage `genui` observé a une cause système connue.

## Options écartées
- **macOS** : pas nécessaire tant que SP-10 n'échoue pas.
- **Windows en secours** : sans objet, la machine est connue.

## Conséquences
- [p-ar-stage-runtime](../architecture/stage-runtime.md), [p-ar-stack](../architecture/stack.md), [p-ar-frontend](../architecture/frontend.md) : OS Linux, dépendances système GStreamer, plus d'entitlements macOS.
- [p-rm-spikes](../roadmap/spikes.md) : SP-09 sans objet ; SP-10 « genui sur Linux » ajouté (critère : `flutter build linux` OK et une surface A2UI v0.9 rendue) ; SP-06 se fait sous Linux.
- [p-ar-quality](../architecture/quality.md) : build Linux en CI ([pdr-0031](pdr-0031-github-actions-ci-linux.md)).
- [p-rm-open-questions](../roadmap/open-questions.md) : Q-07 tranchée ; Q-45 sans objet ; Q-14 et Q-57 gérées par le porteur.

## Réexaminer si
- SP-10 montre que `genui` ne rend pas sous Linux, même avec GStreamer : retour à macOS (MacBook de secours du porteur).
- Le porteur change de machine.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Acceptée : « La machine de démo sera celle-ci, une machine Linux » (conversation) | Benoît FONTAINE (porteur) |
| 2026-10-29 | Vérification `flutter_webrtc` et `genui` sur la machine ; SP-10 ouvert | Assistant |

Pas d'archive brute.
