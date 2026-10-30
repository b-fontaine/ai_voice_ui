---
id: p-fn-risks-acceptance
title: Risques, plan B, DoD et métriques
area: functional
status: validated
updated: 2026-10-30
sources: [specs/008-j4-act2-transform/status.md, product/sources/product-description.pdf#p11, product/sources/product-description.pdf#p12]
links: [p-rm-roadmap, p-ar-frontend, p-ar-backend, p-ar-agents-protocols, p-rm-open-questions, p-fn-nfr, p-fn-requirements, p-fn-business-rules, p-ar-stage-runtime, p-ar-replay, p-ar-quality, pdr-0006-replay-fallback-must, pdr-0010-pinned-experimental-versions, rt-echo-cancellation, rt-barge-in, proj-avw-risks, ds-a11y-wcag-contrast, pdr-0022-gherkin-steps-no-leading-digit, pdr-0023-example-guided-composition, pdr-0032-obs-video-fallback-a2ui-replay-act, pdr-0033-optional-shortcuts-mouse-first, pdr-0027-talk-context-meetup-flutter-nantes, pdr-0049-sheet-gherkin-scenarios-only]
tags: [risques, plan-b, dod, metriques, repetition]
---
# Risques, plan B et critères d'acceptation

**En bref.** Le risque principal n'est pas technique, il est **scénique** : une démo vocale en direct sur le Wi-Fi d'une conférence. Le mode rejeu est donc une exigence **Must**, pas un bonus (fiche § 8, p. 11 ; [pdr-0006](../decisions/pdr-0006-replay-fallback-must.md)). Depuis le 2026-10-29 ([pdr-0032](../decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md)) : le rejeu du flux A2UI reste Must et devient l'acte 4 ; le secours est une **vidéo OBS gérée par le porteur**, qui choisit sur place entre direct et vidéo.

## Registre des risques (fiche § 8)

| # | Risque | Probabilité | Impact | Parade (fiche) | Liens | Porteur technique · jalon |
|---|---|---|---|---|---|---|
| R1 | Réseau de la salle instable | Haute | Bloquant | Connexion mobile dédiée ; mode secours en un raccourci | ~~FR-10, NFR-07, RG-20~~ retirés (pdr-0032) | Connexion mobile et vidéo de secours : gérées par le porteur, hors périmètre de l'assistant |
| R2 | L'IA s'entend dans la sono et se coupe elle-même | Haute | Fort | Micro-casque proche de la bouche ; voix de l'IA renvoyée dans la sono sans repasser par le micro ; test sur place | [rt-echo-cancellation], [p-ar-stage-runtime](../architecture/stage-runtime.md) | [stage-runtime](../architecture/stage-runtime.md) · SP-06, J7 ; alerte précoce RD-6 : aucune auto-interruption observée en SP-02 (voir ci-dessous) |
| R3 | Interruptions intempestives (rires, applaudissements) | Moyenne | Moyen | Seuil de déclenchement réglé en répétition ; raccourci « silence » en secours | FR-18, FR-20, RG-16 | [stage-runtime](../architecture/stage-runtime.md), [agents-protocols](../architecture/agents-protocols.md) · J7 (Q-41) |
| R4 | L'IA ne s'arrête pas quand le speaker la coupe | Moyenne | Fort | Raccourci « silence » ; répliques de l'IA courtes par consigne | FR-20, RG-27, [rt-barge-in] | [agents-protocols](../architecture/agents-protocols.md) (interruption) · J7 |
| R5 | Bruit de salle et mauvaise compréhension | Moyenne | Fort | Phrases clés courtes et rodées ; transcription visible pour reformuler | FR-02 | [frontend](../architecture/frontend.md) (transcription) · J7 (phrases de test des scénarios BDD ; script du speaker : sur demande du porteur) |
| R6 | L'IA produit un écran incohérent | Moyenne | Fort | Catalogue restreint ; exemples d'écrans attendus fournis à l'IA ; rejeu si besoin | RG-07, [pdr-0007](../decisions/pdr-0007-closed-catalog-stage-theme.md) | [backend](../architecture/backend.md) (catalogue, exemples d'écrans : [pdr-0023](../decisions/pdr-0023-example-guided-composition.md)), [replay](../architecture/replay.md) · J3, J6 |
| R7 | Attente trop longue entre la demande et l'écran | Haute | Moyen | L'IA commente pendant la construction ; squelettes immédiats | RG-03, RG-04 | [agents-protocols](../architecture/agents-protocols.md) (commentaire), [frontend](../architecture/frontend.md) (squelettes) · J3 |
| R8 | Texte illisible au projecteur | Moyenne | Moyen | Thème de scène en 24 px minimum ; test sur un vrai projecteur | NFR-05, RG-09, [ds-a11y-wcag-contrast] | [frontend](../architecture/frontend.md) (thème de scène), [stage-runtime](../architecture/stage-runtime.md) · SP-07, J7 |

**Alerte précoce SP-02 (2026-10-29, R2 et R4)** : essai réel avec le porteur dans un navigateur (AEC activée, enceintes du PC) : décalage perceptible de la coupure (~0,6 à 1,0 s mesuré côté serveur, Q-67) puis 60 s de parole continue **sans auto-interruption ni transcript parasite** ([rt-barge-in], [rt-echo-cancellation], [p-rm-spikes](../roadmap/spikes.md)). **Limites** : une machine, un essai, AEC du navigateur ; `flutter_webrtc` sous Linux (SP-06, J7) et le test avec la sono de la salle (porteur) **non testés** ; le risque R2 n'est donc pas levé.

**Constats de 008 (acte 2, 2026-10-30, lecture de l'assistant ; risques de délai RD-10 et RD-11 de [roadmap](../roadmap/roadmap.md))** : (1) une délégation pourrait couper « Concentre-toi sur Android et compare avec la 3.3 » en deux et faire refuser la seconde moitié (R5 : phrases clés courtes et rodées ; hypothèse non confirmée → Q-74, à observer en répétition) ; (2) app relancée alors que le backend tourne : remise à vide automatique au démarrage en mode vivant, sinon bouton « Remettre à vide » ([stage-runtime](../architecture/stage-runtime.md)) ; (3) la comparaison de l'acte 2 doit se lire au projecteur (R8) : valeurs de la checklist et titre de la courbe affichés en entier à 1920×1080, à confirmer sur un vrai projecteur.

Les ids R1..R8 et la colonne « Porteur technique · jalon » sont une lecture de l'assistant ([p-rm-roadmap](../roadmap/roadmap.md)). Les risques **techniques** déjà connus sur le code voix (projet de référence) sont dans [proj-avw-risks].

## Plan B

| Niveau | Déclencheur | Action | Exigence |
|---|---|---|---|
| 1 | L'IA parle trop ou n'entend pas l'interruption | Commande « silence » (bouton ; raccourci s'il ne pose pas de problème) | FR-20 |
| 2 | Micro qui capte mal | Commande « silence » (bouton ; raccourci s'il ne pose pas de problème) | FR-20 |
| 3 | Écran incohérent | Rejeu si besoin (parade de la fiche § 8, R6) | FR-09 (FR-10 retirée, pdr-0032) |
| 4 | Réseau perdu ou chaîne bloquée | Vidéo de secours OBS, lancée par le porteur (géré par le porteur, hors périmètre de l'assistant) | — (pdr-0032) |

Raccourcis facultatifs, actions critiques à la souris (E5 · Q-05 tranché, [pdr-0033](../decisions/pdr-0033-optional-shortcuts-mouse-first.md)). La gradation en niveaux est une lecture de l'assistant ; les actions reprennent les parades de la fiche § 8.

## Definition of Done de la démo (fiche § 8)

| # | Critère | Lié à |
|---|---|---|
| D1 | Les 9 scénarios de la section 4 sont vérifiés, en automatique **et** en répétition | S-01..S-09 ([features](features/)) ; S-04 retiré (pdr-0032) : 8 scénarios actifs |
| D2 | 10 répétitions complètes consécutives sans intervention manuelle, dont 2 sur réseau mobile | R1 |
| D3 | Les seuils NFR-01 à NFR-03 sont tenus au p90 sur ces 10 répétitions | [p-fn-nfr](nfr.md) |
| D4 | ~~La bascule en mode secours est testée Wi-Fi coupé, en moins de 2 s~~ — **retiré par pdr-0032** | ~~NFR-07~~ |
| D5 | La coupure de parole fonctionne 10 fois sur 10 en répétition, sono de la salle allumée, sans aucune interruption spontanée de l'IA | FR-13, R2, R3 |
| D6 | Lisibilité validée depuis le fond d'une salle réelle ou équivalente | NFR-05 |
| D7 | Build propre sur machine vierge à partir du dépôt et du `pubspec.lock` | NFR-10, [pdr-0010](../decisions/pdr-0010-pinned-experimental-versions.md) |
| D8 | Une répétition générale devant au moins 3 développeurs Flutter, avec ce test : peuvent-ils réexpliquer le rôle du catalogue en une phrase ? | Message du talk ([p-fn-vision](vision.md)) |

Mise en œuvre des mesures : [p-ar-quality](../architecture/quality.md) ; conditions de scène : [p-ar-stage-runtime](../architecture/stage-runtime.md). Organisation des répétitions (D2, D5, D6, D8) : gérée par le porteur, hors périmètre de l'assistant ([pdr-0027](../decisions/pdr-0027-talk-context-meetup-flutter-nantes.md)).

## Métriques de succès du talk (fiche § 8)

| Métrique | Objectif |
|---|---|
| Taux de réussite de la démo en direct **sans rejeu** | 100 % des 3 actes |
| Nature des questions du public | Portent sur l'adoption (« comment je l'intègre ? ») plutôt que sur le fonctionnement |
| Note de feedback de la conférence | Si elle existe |

## Remarque

D1 vise « les 9 scénarios » ; plusieurs Must n'ont pas de scénario dédié (voir [p-fn-requirements](requirements.md), couverture BDD) : la DoD s'en tient aux scénarios de la fiche, plus une revue pour ces exigences ([pdr-0049](../decisions/pdr-0049-sheet-gherkin-scenarios-only.md), Q-63 tranchée). Les steps qui commençaient par un chiffre (incompatibles avec `bdd_widget_test`) sont reformulés en toutes lettres (E16 · Q-34, [pdr-0022](../decisions/pdr-0022-gherkin-steps-no-leading-digit.md)).
