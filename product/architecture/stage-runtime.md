---
id: p-ar-stage-runtime
title: Environnement de scène et répétitions
area: architecture
status: draft
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p1, product/sources/product-description.pdf#p2, product/sources/product-description.pdf#p9, product/sources/product-description.pdf#p11, product/sources/product-description.pdf#p12, knowledge:rt-echo-cancellation, knowledge:rt-flutter-webrtc-overview, knowledge:rt-flutter-webrtc-permissions, knowledge:rt-flutter-webrtc-audio-routing, knowledge:genui-overview, knowledge:rt-latency]
links: [p-rm-spikes, p-ar-overview, p-ar-replay, p-ar-quality, p-ar-security, p-ar-backend, p-ar-frontend, p-fn-risks-acceptance, p-fn-nfr, p-fn-screen, p-rm-open-questions, p-rm-roadmap, pdr-0002-desktop-platform, pdr-0006-replay-fallback-must, pdr-0027-talk-context-meetup-flutter-nantes, pdr-0028-linux-demo-machine, pdr-0029-local-docker-compose-hosting, pdr-0032-obs-video-fallback-a2ui-replay-act, pdr-0033-optional-shortcuts-mouse-first, rt-echo-cancellation, rt-barge-in, rt-flutter-webrtc-overview, rt-flutter-webrtc-permissions, rt-flutter-webrtc-audio-routing, rt-latency, rt-gpt-live-overview, rt-gpt-live-lifecycle, perf-desktop-specifics, ux-desktop-shortcuts, ux-desktop-focus, genui-overview]
tags: [scene, demo, machine, reseau, audio, linux, repetition]
---
# Environnement de scène et répétitions

**En bref.** Le talk dure 45 min au Meetup Flutter Nantes, le 2026-11-12 ([pdr-0027](../decisions/pdr-0027-talk-context-meetup-flutter-nantes.md)). La démo tourne sur la **machine Linux du porteur** ([pdr-0028](../decisions/pdr-0028-linux-demo-machine.md)), tout en local ([pdr-0029](../decisions/pdr-0029-local-docker-compose-hosting.md)). Cette page décrit les **contraintes techniques** de la machine, du réseau et de la chaîne audio. La logistique et les supports (salle, son, répétitions, vidéo de secours, slides) sont **gérés par le porteur, hors périmètre de l'assistant**.

> Statut : **draft**.

## Machine de démo

| Élément | Valeur | Statut / source |
|---|---|---|
| OS | Linux Ubuntu x86_64 (machine du porteur) | [pdr-0028](../decisions/pdr-0028-linux-demo-machine.md) ; remplace macOS / Windows ([pdr-0002](../decisions/pdr-0002-desktop-platform.md)) |
| Flutter | 3.47.8, rendu Impeller OpenGLES (observé le 2026-10-29) | [rt-flutter-webrtc-overview] |
| Voix | `flutter_webrtc` 1.6.3 vérifié : build Linux, 6 entrées et 6 sorties audio, `getUserMedia`, offre SDP Opus | [rt-flutter-webrtc-overview] |
| genui | build Linux bloqué sans les en-têtes GStreamer (`libgstreamer1.0-dev`, `libgstreamer-plugins-base1.0-dev`) ; rendu Linux à confirmer par SP-10 | [genui-overview], [p-rm-spikes](../roadmap/spikes.md) |
| Permissions | pas de manifeste micro spécifique relevé sous Linux | [rt-flutter-webrtc-permissions] |
| Sortie vidéo | projection 1920×1080, 16:9 | fiche § 1 |
| Lancement | backend et agents par `docker compose` ; app Flutter en debug | [pdr-0029](../decisions/pdr-0029-local-docker-compose-hosting.md) |

## Réseau

| Mesure | Origine |
|---|---|
| Backend et agents en local (`127.0.0.1`) : seuls GPT-Live et le LLM texte passent par le réseau | [pdr-0029](../decisions/pdr-0029-local-docker-compose-hosting.md) |
| Connexion de secours : partage de connexion mobile du porteur en Wi-Fi — géré par le porteur | [pdr-0028](../decisions/pdr-0028-linux-demo-machine.md) (Q-14) |
| WebRTC (UDP) pour la voix ; du backend vers OpenAI : HTTPS (relais SDP) et WSS (sideband) | [rt-latency], [p-ar-agents-protocols](agents-protocols.md) |
| Secours si le direct échoue : vidéo OBS — géré par le porteur | [pdr-0032](../decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md) |

## Chaîne audio

Matériel, réglage de la sono et test sur place : gérés par le porteur (micro du PC en entrée, sortie vers la sono). Règles techniques côté app :

| Règle | Source |
|---|---|
| Une seule capture : `getUserMedia` de `flutter_webrtc`, contraintes `echoCancellation`, `noiseSuppression`, `autoGainControl` | [rt-echo-cancellation] |
| Ne jamais activer `bypassVoiceProcessing` (casse l'AEC) | [rt-echo-cancellation] |
| Sortie audio choisie par `selectAudioOutput(deviceId)` | [rt-flutter-webrtc-audio-routing] |
| Bruits courts : seuil réglé en répétition ; commande « silence » en secours | fiche § 8 ; FR-18, FR-20 |

⚠️ Risque technique d'écho : la sortie sono captée par le micro du PC peut faire s'auto-interrompre l'IA (R2, déjà couvert par la fiche § 8 et [rt-echo-cancellation]).

## Régie

- Toute action critique est faisable à la souris ; raccourcis facultatifs ([pdr-0033](../decisions/pdr-0033-optional-shortcuts-mouse-first.md)).
- Si des raccourcis sont ajoutés, le focus doit rester dans l'arbre des `Shortcuts` ([ux-desktop-shortcuts], [ux-desktop-focus]).

## Avant le talk : repères techniques

Repères pour le porteur, pas des tâches de l'assistant :

1. Dépendances système installées (GStreamer), build depuis le dépôt et le `pubspec.lock` (NFR-10).
2. `docker compose up` : backend et agents démarrés ; `.env` avec la clé OpenAI présent ([p-ar-security](security.md)).
3. Session voix ouverte **juste avant** la démo (15 s facturées à l'initialisation, [rt-gpt-live-overview]) et pré-chauffage WebRTC ([rt-latency]).

## Protocole de répétition (fiche § 8)

Critères de la DoD ([p-fn-risks-acceptance](../functional/risks-acceptance.md)) ; leur organisation est gérée par le porteur.

| Critère | Seuil |
|---|---|
| Répétitions complètes consécutives sans intervention manuelle | 10, dont 2 sur réseau mobile |
| NFR-01 à NFR-03 | tenus au p90 sur ces 10 répétitions |
| ~~Bascule secours Wi-Fi coupé~~ | retiré (pdr-0032) |
| Coupure de parole, sono allumée | 10/10, sans interruption spontanée de l'IA |
| Lisibilité | validée depuis le fond d'une salle réelle ou équivalente |

Chaque répétition produit un journal ; le script de mesure calcule les p90 ([p-ar-quality](quality.md)).

## Points ouverts (registre : [p-rm-open-questions](../roadmap/open-questions.md))

- **Rendu genui sous Linux** : ✅ confirmé par SP-10 le 2026-10-29 (en-têtes GStreamer requis).
- **Durée maximale** d'une session GPT-Live ; une session par acte ou une seule → Q-53.
