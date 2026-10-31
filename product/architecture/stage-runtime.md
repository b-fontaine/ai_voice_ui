---
id: p-ar-stage-runtime
title: Environnement de scène et répétitions
area: architecture
status: draft
updated: 2026-10-31
sources: [specs/014-j7-silence-micro-correction/spec.md, specs/014-j7-silence-micro-correction/status.md, specs/013-design-ergonomie/status.md, specs/011-voice-interaction/status.md, specs/009-j5-act3-interact/status.md, specs/008-j4-act2-transform/status.md, specs/007-j3-act1-frontend/status.md, product/sources/product-description.pdf#p1, product/sources/product-description.pdf#p2, product/sources/product-description.pdf#p9, product/sources/product-description.pdf#p11, product/sources/product-description.pdf#p12, knowledge:rt-echo-cancellation, knowledge:rt-flutter-webrtc-overview, knowledge:rt-flutter-webrtc-permissions, knowledge:rt-flutter-webrtc-audio-routing, knowledge:genui-overview, knowledge:rt-latency]
links: [pdr-0076-014-silence-mic-correction-assistant-decided, p-fn-feature-silence-micro-correction-014, p-ar-design-system, pdr-0075-013-design-ergonomics-details-assistant-decided, p-ar-voice-interruption, pdr-0073-011-voice-interaction-details-assistant-decided, pdr-0069-voice-interruption-hybrid-stop-011, pdr-0071-act2-focus-memory-act-indicator-click-feedback, pdr-0065-009-act3-interact-details-assistant-decided, pdr-0064-008-act2-transform-details-assistant-decided, p-ar-frontend-screen, p-ar-app-channel-contract, pdr-0058-backend-canvas-registry-survives-voice-sessions, pdr-0063-007-stage-ui-details-assistant-decided, p-rm-spikes, p-ar-overview, p-ar-replay, p-ar-quality, p-ar-security, p-ar-backend, p-ar-frontend, p-fn-risks-acceptance, p-fn-nfr, p-fn-screen, p-rm-open-questions, p-rm-roadmap, pdr-0002-desktop-platform, pdr-0006-replay-fallback-must, pdr-0027-talk-context-meetup-flutter-nantes, pdr-0028-linux-demo-machine, pdr-0029-local-docker-compose-hosting, pdr-0032-obs-video-fallback-a2ui-replay-act, pdr-0033-optional-shortcuts-mouse-first, rt-echo-cancellation, rt-barge-in, rt-flutter-webrtc-overview, rt-flutter-webrtc-permissions, rt-flutter-webrtc-audio-routing, rt-latency, rt-gpt-live-overview, rt-gpt-live-lifecycle, perf-desktop-specifics, ux-desktop-shortcuts, ux-desktop-focus, genui-overview, pdr-0052-one-gpt-live-session-per-act-recommended, pdr-0067-gpt-live-session-cap-30-min, pdr-0068-act3-decision-not-kept-after-new-request]
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
| Bruits courts : conforme à l'essai au micro (Q-41) ; commande « Faire taire » en secours (FR-20, livrée par 014) | fiche § 8 ; FR-18, FR-20 |
| Couper la parole : « Stop » vocal coupe la piste distante (011) ; « Faire taire » aussi, sans rien annuler (014) ; micro coupé = piste locale désactivée, capture non arrêtée (014) ; ⚠️ aucun des trois non vérifié sous `flutter_webrtc` Linux (Q-79) | [p-ar-voice-interruption](voice-interruption.md) |

⚠️ Risque technique d'écho : la sortie sono captée par le micro du PC peut faire s'auto-interrompre l'IA (R2, déjà couvert par la fiche § 8 et [rt-echo-cancellation]).

## Régie

- Toute action critique est faisable à la souris ; raccourcis facultatifs ([pdr-0033](../decisions/pdr-0033-optional-shortcuts-mouse-first.md)).
- Si des raccourcis sont ajoutés, le focus doit rester dans l'arbre des `Shortcuts` ([ux-desktop-shortcuts], [ux-desktop-focus]).
- **Régie livrée par 014** ([pdr-0076](../decisions/pdr-0076-014-silence-mic-correction-assistant-decided.md) D2, D5), à deux colonnes de 480 px dans la barre du haut : « Couper le micro » / « Rétablir le micro » et « Faire taire » (colonne gauche), indicateur d'acte et « Remettre à vide » (colonne droite). Raccourcis facultatifs : `M` (micro) et `Échap` (silence), sans effet hors session, jamais `Espace`. « Faire taire » ne coupe que la voix de l'IA : la génération continue (dire « Stop » pour l'annuler) ; le micro coupé reste coupé jusqu'au bouton ; une fermeture de session et tout nouveau démarrage repartent micro actif.

## Remise à vide en répétition (007, FR-11)

Le bouton **« Remettre à vide »** (barre supérieure, souris d'abord, [pdr-0033](../decisions/pdr-0033-optional-shortcuts-mouse-first.md)) ramène l'écran à l'état initial entre deux répétitions, sans relancer l'app.

1. Attendre la fin du tour : le bouton est inactif tant qu'un agent est « en cours » ou « en attente » (le backend refuserait, 409).
2. Cliquer : canevas vide, panneau du protocole vide, étagère « 0 / 6 utilisés », rail vide, indicateur d'acte à « Acte 1/3 » (011 : la remise à vide le ramène à 1), aussitôt. La session voix n'est ni ouverte ni fermée, le journal n'est pas touché.
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

## Régie après l'acte 3

Pas de nouvelle demande vocale après le clic de l'acte 3 : la décision « Bloquée » / « Validée » ne serait pas conservée ([pdr-0068](../decisions/pdr-0068-act3-decision-not-kept-after-new-request.md)). Plafond de session GPT-Live : 30 min par défaut ([pdr-0067](../decisions/pdr-0067-gpt-live-session-cap-30-min.md)).

## Points ouverts (registre : [p-rm-open-questions](../roadmap/open-questions.md))

- **Rendu genui sous Linux** : ✅ confirmé par SP-10 le 2026-10-29 (en-têtes GStreamer requis).
- **Durée d'une session** GPT-Live : `expires_at` = +2 h, contexte extrapolé ~94 % à 45 min en cas pessimiste (mesuré en SP-02, [rt-gpt-live-lifecycle]) ; une session par acte (Q-53 tranchée : [pdr-0052](../decisions/pdr-0052-one-gpt-live-session-per-act-recommended.md)) ; transitions d'acte = ouverture d'une session (~1 s), à tester en répétition ; ⚠️ Hypothèse non confirmée : l'usage réel du contexte sur un scénario complet reste à mesurer (réexamen prévu par la PDR).

- **Indicateur d'acte automatique (pdr-0071, complète pdr-0063 D1, livré par 011)** : acte 2 à l'apparition de la surface `actions` (barre d'actions), acte 3 au clic accepté, jamais en arrière ; le clic manuel sur l'indicateur corrige (cyclique 1 → 2 → 3 → 1) ; sans effet en rejeu ni en mode scénario ([p-ar-frontend-screen](frontend-screen.md) § 011). Au clic, la pastille de décision est entière et le bouton passe à « fait » ; la voix confirme après sa phrase en cours (Q-75 tranchée).
- **Orbe « Interrompue »** (pdr-0069, livré par 011) : à `voice.interrupted` le son distant est coupé, l'orbe passe à « Interrompue » puis « Écoute » après 3 s de silence (`GENESIS_INTERRUPT_RESUME_SILENCE_MS`) ou 15 s au plus.

## À observer en répétition (interaction vocale, 011)

Aucune de ces vérifications n'a été faite en réel ; chacune est une ⚠️ hypothèse non confirmée, avec le porteur :

| À observer | Renvoi |
|---|---|
| Dire « Stop » pendant que l'IA parle : le son s'arrête-t-il réellement (spike T03, piste distante sous Linux) ? la session reste-t-elle ouverte, l'orbe repasse-t-elle à « Écoute » ? | Q-79 |
| GPT-Live crée-t-il une délégation pour « Stop » ? Un double accusé vocal (« D'accord. » puis l'accusé du modèle) est-il audible ? | Q-78 |
| Couper la parole sans dire « Stop » (015, [p-ar-voice-overlap](voice-overlap.md)) : faux positifs d'écho sur enceinte, latence ≈ 1 s, fenêtre de parole de 2 s, seuils `VOICE_OVERLAP_*` | Q-80 (Q-77 livrée par 015) |
| Horloges de `start_ms` et de `at_ms` alignées ? deltas d'entrée jamais révisés ? « Stop » transcrit de façon fiable ? NFR-02 avec la fenêtre de +300 ms (à remesurer) ? | Q-80 |
| « Compare avec la 3.3 » dit en second tour hérite-t-il bien d'Android ? | Q-74 tranchée, à confirmer en réel |

## À observer en répétition (silence, micro et correction, 014)

Tests, captures 1920×1080 et `gate --full` sont verts ; aucune de ces vérifications n'a été faite en réel (chacune est une ⚠️ hypothèse non confirmée, avec le porteur) :

| À observer | Renvoi |
|---|---|
| « Faire taire » et « Stop » : la voix s'arrête-t-elle réellement sous `flutter_webrtc` Linux ? Micro coupé : plus aucun son capté (à l'oreille, ou au compteur de capture) ? | Q-79 |
| Après « Faire taire », si l'IA marque une pause d'au moins `GENESIS_INTERRUPT_RESUME_SILENCE_MS`, sa voix revient au milieu de la réplique : acceptable, ou faut-il annuler la génération ? | pdr-0076 « Réexaminer si » |
| « Non, plutôt iOS » dit pendant une génération : GPT-Live crée-t-il une délégation ? (sinon l'app annule et fait taire, sans replanifier) | Q-87 |
| Un « non » ordinaire en tête de phrase déclenche-t-il des annulations indues ? (`VOICE_CORRECTION_WORDS=non,plutôt,en fait`, réduire ou vider la liste sinon) | pdr-0076 « Réexaminer si » |
| `M` et `Échap` répondent-ils sans conflit de focus à la machine de démo ? | NFR-12 |
| Barge-in 10/10 sur enceinte (AEC, réglage des seuils du chevauchement) | SP-06, FR-18, Q-80 |

## À observer en répétition (design et ergonomie, 013)

Tests et captures 1920×1080 sont verts ; ce qui suit ne se vérifie qu'en salle ou sur la machine de démo ([p-ar-quality](quality.md) § 013, [p-ar-design-system](design-system.md)) :

| À observer | Renvoi |
|---|---|
| Les 60 i/s pendant l'acte 1, la liste des crashs et un rejeu à 2× (DevTools Performance, profil `--profile` sur la machine de démo) | NFR-04 |
| Lisibilité depuis le fond de salle sur le vidéoprojecteur réel (texte ≥ 24 px, contraste) ; logistique de la salle : gérée par le porteur | NFR-05 |
| En 3×2 avec l'acte 2 : « Changelog validé » masqué derrière « + 1 autres critères », un seul avis, sixième cellule vide : acceptable en salle ? | Q-83 (tranchée → pdr-0075 D2, contestable) |
| Le rail de 96 px (au lieu de la colonne de la maquette) et la liaison animée de délégation (livrée par 015, Q-85 → pdr-0077) : la lisibilité à la projection et les 60 i/s avec la liaison animée restent à observer | Q-85, NFR-04 |
