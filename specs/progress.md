# Avancement de la boucle

État global des fonctionnalités (`specs/NNN-<slug>/`). L'ordre vient de `product/roadmap/roadmap.md`. Journal : la ligne la plus récente en haut.

## Fonctionnalités
| NNN | Fonctionnalité | Backlog | Jalon | Étape | Mise à jour |
|---|---|---|---|---|---|
| 000 | Outillage de boucle dans l'app (squelette, mode capture, rejeu scripté) | EP-01 (socle) | J2 | Terminée, publiée (`b9db83c`) | 2026-10-29 |
| 001 | SP-03 : A2A en Go ↔ `genui_a2a` (spike) | EP-03 | J1 | Terminée ✅, publiée (`529219a`) | 2026-10-29 |
| 002 | SP-02 : session GPT-Live par relais SDP (spike réduit) | EP-02 | J1 | Terminée ⚠️ (résultat partiel), publiée (`82465d5`) | 2026-10-29 |
| 003 | J2 : backend squelette (relais SDP, sideband, app-channel, compose, CI) | EP-01, EP-02 | J2 | Terminée ✅, publiée (`c193434`) | 2026-10-29 |

## Journal
| Date | Événement |
|---|---|
| 2026-10-29 | **003 terminée** (backend Go : relais SDP, sideband, app-channel WSS, journal, compose, CI minimale ; revue d'architecte BLOQUANTE R1 puis R1-R12 appliquées ; essai réel unique OK, 0,03 €). Prochaine : 004 (orchestrateur + agent A2A + surface, délégation `client`), puis 005 (app voix + orbe, `app/di`). **Pour le porteur, sans bloquer** : Q-68 (plafond de durée par session, reco 30 min, avant J7) ; reformuler AGENTS.md § 2 (« n'écoutent que sur 127.0.0.1 » alors que le conteneur écoute en interne sur 0.0.0.0 et que l'hôte publie sur 127.0.0.1, conforme à pdr-0041) ; Q-67 (délai d'arrêt de la voix, J7) ; ses impressions sur l'essai de barge-in sont recueillies (décalage perceptible). |
| 2026-10-29 | Décisions du porteur (« Tes recommandations me conviennent. ») : pdr-0050 (Q-47 mode `client`), pdr-0051 (Q-43 RMS sideband 5 Hz), pdr-0052 (Q-53 une session par acte) **acceptées** ; J2 (walking skeleton) n'attend plus rien. Retour du porteur sur l'essai réel : décalage perceptible entre son interruption et l'arrêt de la voix → mesuré ~0,6 à 1,0 s côté serveur (ma mention « bloc de 200 ms » était fausse, corrigée dans `rt-barge-in`, `spikes.md`, `agents-protocols.md`) ; son hypothèse d'un envoi en avance sur la lecture n'est pas confirmée (RTP et sideband à cadence réelle) ; **Q-67** ouverte (latence de lecture client, atténuation locale), échéance J7. |
| 2026-10-29 | 002 (SP-02) : essais réels faits (6 sessions, 0,26 €) et consignés ; résultat ⚠️ partiel (barge-in et absence d'auto-interruption OK en navigateur ; AEC flutter_webrtc sous Linux, sono de la salle et scénario complet restent à faire) ; PDR **proposées** pdr-0050 (Q-47), pdr-0051 (Q-43), pdr-0052 (Q-53) à décider par le porteur avant J2 (31/10) ; J2 attend Q-43 et Q-47. |
| 2026-10-29 | 002 (SP-02) : étape Définir faite ; clé disponible (`loop.local.env`, exportée), porteur présent, TTS OpenAI pour les phrases de test ; Q-25, Q-39, Q-46, Q-55, Q-63 tranchées (pdr-0045 acceptée, pdr-0046 à pdr-0049), J2 n'attend plus que Q-43 et Q-47 (issues de SP-02). |
| 2026-10-29 | **En attente du porteur** — rien de faisable par la boucle. SP-02 (GPT-Live réel) : pas de `OPENAI_API_KEY` dans l'environnement de la boucle (clé attendue côté backend, `.env` non versionné, pdr-0041) et essai de barge-in sur enceinte à faire avec le porteur. J2 (walking skeleton) : questions ouvertes **Q-25** (version de Flutter : 3.47.8 déjà figée par 000, reco assistant 3.47.8), **Q-39** (canal app ↔ backend : pdr-0045 proposée, reco WSS maison), **Q-43** (niveau audio de l'orbe), **Q-46** (versions Go et autres : Go 1.27.3 résout `a2a-go/v2` v2.7.0), **Q-47** (mode de délégation GPT-Live, à établir par SP-02), **Q-55**, **Q-63**. Réveil horaire ; reprise dès qu'une réponse ou la clé est disponible. |
| 2026-10-29 | 001 (SP-03) : consigné et clôturé (knowledge, spikes.md, stack) ; **Q-39 reste ouverte** (pdr-0045 proposée, à décider par le porteur avant J2). |
| 2026-10-29 | 001 (SP-03) : expérience terminée, résultat ✅ (`genui_a2a` 0.10.1 + agent `a2a-go` v2 via `a2acompat/a2av0` : surface rendue et action aller-retour, de bout en bout) ; reste à consigner (knowledge, spikes.md, Q-39). |
| 2026-10-29 | 001 (SP-03) : étape Définir faite (spec, plan, tâches) ; branche feat/001-sp-03-a2a-go-genui. |
| 2026-10-29 | 000 : publiée sur `origin/main` (`b9db83c`, `publish.sh` code 0, gate --full vert après fusion de `origin/main`). |
| 2026-10-29 | 000 : clôture — docs produit à jour (frontend.md, roadmap, backlog) ; fusion dans `loop` et publication par `publish.sh`. |
| 2026-10-29 | 000 : refactorisation terminée (R1 à R10, gate --full vert à `7a52729`) ; passage à la Vérification (gate + capture app-smoke). |
| 2026-10-29 | 000 : revue d'architecte rendue (1 bloquante, 5 importantes, 4 mineures) ; Q-66 ouverte (get_it/`app/di`, non bloquante) ; refactorisation en cours. |
| 2026-10-29 | 000 : TDD terminé (T01 à T14), gate --full vert ; passage à la Revue d'architecte. |
| 2026-10-29 | 000 : T13 faite (capture PNG, config, lecteur de scénario) ; H-01 à H-03 verts ; reste T14 (fixture alignée sur le jeu de données). |
| 2026-10-29 | 000 : T12 faite (`CanvasBloc` + `CanvasBoard`) ; `bloc_test` impossible (conflit analyzer), helper maison, note KB corrigée ; reste T13, T14. |
| 2026-10-29 | 000 : T11 faite (`A2uiReplaySource`) ; reste T12 à T14. |
| 2026-10-29 | 000 : T10 faite (H-01 vert) ; reste T11 à T14. |
| 2026-10-29 | 000 : Gherkin terminé (H-01 à H-03 rouges comme attendu, gate --unit vert) ; branche feat/000-loop-harness. |
| 2026-10-29 | Dispositif de boucle préparé ; boucle non lancée (en attente de validation du porteur). |
