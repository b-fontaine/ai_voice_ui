---
id: p-ar-stage-runtime
title: Environnement de scène et répétitions
area: architecture
status: draft
updated: 2026-10-30
sources: [specs/009-j5-act3-interact/status.md, specs/008-j4-act2-transform/status.md, specs/007-j3-act1-frontend/status.md, product/sources/product-description.pdf#p1, product/sources/product-description.pdf#p2, product/sources/product-description.pdf#p9, product/sources/product-description.pdf#p11, product/sources/product-description.pdf#p12, knowledge:rt-echo-cancellation, knowledge:rt-flutter-webrtc-overview, knowledge:rt-flutter-webrtc-permissions, knowledge:rt-flutter-webrtc-audio-routing, knowledge:genui-overview, knowledge:rt-latency]
links: [pdr-0065-009-act3-interact-details-assistant-decided, pdr-0064-008-act2-transform-details-assistant-decided, p-ar-frontend-screen, p-ar-app-channel-contract, pdr-0058-backend-canvas-registry-survives-voice-sessions, pdr-0063-007-stage-ui-details-assistant-decided, p-rm-spikes, p-ar-overview, p-ar-replay, p-ar-quality, p-ar-security, p-ar-backend, p-ar-frontend, p-fn-risks-acceptance, p-fn-nfr, p-fn-screen, p-rm-open-questions, p-rm-roadmap, pdr-0002-desktop-platform, pdr-0006-replay-fallback-must, pdr-0027-talk-context-meetup-flutter-nantes, pdr-0028-linux-demo-machine, pdr-0029-local-docker-compose-hosting, pdr-0032-obs-video-fallback-a2ui-replay-act, pdr-0033-optional-shortcuts-mouse-first, rt-echo-cancellation, rt-barge-in, rt-flutter-webrtc-overview, rt-flutter-webrtc-permissions, rt-flutter-webrtc-audio-routing, rt-latency, rt-gpt-live-overview, rt-gpt-live-lifecycle, perf-desktop-specifics, ux-desktop-shortcuts, ux-desktop-focus, genui-overview, pdr-0052-one-gpt-live-session-per-act-recommended]
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
| Sortie vidéo | projection 1920×1080, 16:9 ; la fenêtre Linux de l'app s'ouvre en **1920×1080** (007) et l'écran **suppose** cette taille : en dessous, les six zones débordent (texte ≥ 24 px) | fiche § 1 ; [p-ar-frontend-screen](frontend-screen.md) |
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

## Remise à vide en répétition (007, FR-11)

Le bouton **« Remettre à vide »** (barre supérieure, souris d'abord, [pdr-0033](../decisions/pdr-0033-optional-shortcuts-mouse-first.md)) ramène l'écran à l'état initial entre deux répétitions, sans relancer l'app.

1. Attendre la fin du tour : le bouton est inactif tant qu'un agent est « en cours » ou « en attente » (le backend refuserait, 409).
2. Cliquer : canevas vide, panneau du protocole vide, étagère « 0 / 6 utilisés », rail vide, « Acte 1/3 », aussitôt. La session voix n'est ni ouverte ni fermée, le journal n'est pas touché.
3. L'app demande ensuite au backend de retirer ses surfaces (`POST /canvas/reset` : [contrat](app-channel-contract.md)) ; sur 409 elle réessaie (8 fois, 1,5 s d'intervalle par défaut, réglables : [p-ar-frontend-screen](frontend-screen.md)). En cas d'échec, une ligne « Remise à vide : le backend ne l'a pas appliquée (…) » est écrite sur `stderr`.
4. **Plus de consigne de régie depuis 008** (Q-73 résolue par construction, [pdr-0058](../decisions/pdr-0058-backend-canvas-registry-survives-voice-sessions.md)) : le registre de surfaces du backend est partagé entre les sessions voix, l'app garde ses surfaces d'une session à l'autre et l'acte 2 les mute sur place. **App relancée alors que le backend tourne encore** : en mode vivant, l'app demande d'elle-même une remise à vide avant la première session (D6 de [pdr-0064](../decisions/pdr-0064-008-act2-transform-details-assistant-decided.md)) ; si elle échoue (ligne sur `stderr`), cliquer « Remettre à vide » avant de parler. **Limite** : la rétention du hub reste par session (une session fermée n'est plus rejouée à la suivante) ; le registre backend fait foi.

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

**À observer en répétition (acte 3, 009)** : (1) la voix dit-elle la confirmation après le clic, hors de toute délégation ? (⚠️ Q-75, non observée à l'essai réel de 009 ; le journal de l'orchestrateur consigne la stratégie utilisée et si la parole a été observée, `VOICE_ANNOUNCE_TIMEOUT`) ; (2) un clic juste après la fin des agents de l'acte 2 peut recevoir 409 `busy` tant que le commentaire vocal de la délégation n'est pas acquitté : l'app réessaie (6 fois, 1 s) ; (3) la bande vide de 72 px en bas du canevas aux actes 1 et 2 est-elle acceptable à la projection ? ([p-fn-screen](../functional/screen.md)).

## Points ouverts (registre : [p-rm-open-questions](../roadmap/open-questions.md))

- **Rendu genui sous Linux** : ✅ confirmé par SP-10 le 2026-10-29 (en-têtes GStreamer requis).
- **Durée d'une session** GPT-Live : `expires_at` = +2 h, contexte extrapolé ~94 % à 45 min en cas pessimiste (mesuré en SP-02, [rt-gpt-live-lifecycle]) ; une session par acte (Q-53 tranchée : [pdr-0052](../decisions/pdr-0052-one-gpt-live-session-per-act-recommended.md)) ; transitions d'acte = ouverture d'une session (~1 s), à tester en répétition ; ⚠️ Hypothèse non confirmée : l'usage réel du contexte sur un scénario complet reste à mesurer (réexamen prévu par la PDR).
