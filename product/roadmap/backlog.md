---
id: p-rm-backlog
title: Backlog par epics et couverture des exigences
area: roadmap
status: draft
updated: 2026-10-28
sources: [product/sources/product-description.pdf#p3-p7, product/sources/product-description.pdf#p11-p12]
links: [p-fn-business-rules, pdr-0012-voice-provider-openai, rt-ephemeral-keys, p-rm-roadmap, p-rm-open-questions, p-fn-requirements, p-fn-nfr, p-fn-risks-acceptance, p-fn-dataset, p-ar-overview, p-ar-replay, p-ar-quality, pdr-0004-mvp-three-acts, pdr-0006-replay-fallback-must]
tags: [backlog, epics, moscow, couverture, exigences]
---
# Backlog : epics → exigences → jalons

**En bref.** Dix epics regroupent les 20 exigences fonctionnelles et les 12 exigences non fonctionnelles de la fiche. Chaque exigence a **un** epic porteur. Les priorités MoSCoW des FR sont celles de la fiche (§ 4) ; la fiche ne priorise pas les NFR (« cibles de conception à valider en répétition », § 5). La matrice finale relie chaque exigence au jalon de [roadmap.md](roadmap.md) qui la livre.

## Epics

| Epic | Intitulé | Exigences portées | Jalons |
|---|---|---|---|
| EP-01 | Socle, sécurité et reproductibilité (app desktop, backend Go, session voix créée par relais SDP backend sans clé dans l'app, versions figées) | NFR-09, NFR-10 | J2, J8 |
| EP-02 | Conversation vocale et coupure de parole | FR-02, FR-13, FR-14, FR-16, FR-18, FR-19, NFR-01 | J2, J7 |
| EP-03 | Orchestrateur, agents A2A et rail des agents | FR-03, FR-17, NFR-02, NFR-03 | J2, J3, J4 |
| EP-04 | Canevas génératif et catalogue (surfaces, squelettes, mutation, étagère) | FR-01, FR-04, FR-06, FR-07, FR-15, NFR-04, NFR-05, NFR-06 | J2, J3, J4, J7 |
| EP-05 | Flux du protocole (panneau JSON relié au composant) | FR-05 | J3 |
| EP-06 | Interaction avec un composant généré | FR-08 | J5 |
| EP-07 | Enregistrement, rejeu et mode secours | FR-09, FR-10, NFR-07 | J6 |
| EP-08 | Régie de scène au clavier | FR-11, FR-12, FR-20, NFR-12 | J3, J7 |
| EP-09 | Jeu de données fictif et figé | NFR-08 | J3 |
| EP-10 | Coût, mesures et répétitions (DoD) | NFR-11 + vérification de toutes les exigences | J2, J8 |

Questions qui conditionnent les epics : EP-03 (Q-01, Q-15, Q-16, Q-17), EP-04 (Q-02, Q-03, Q-04, Q-21, Q-58, Q-60, Q-61), EP-06 (Q-20, Q-49, Q-62), EP-07 (Q-18, Q-19), EP-08 (Q-05), EP-09 (Q-08, Q-23), EP-10 (Q-13, Q-14, Q-24). Voir [open-questions.md](open-questions.md).

## Exigences fonctionnelles (fiche § 4)

| ID | Exigence (résumé) | MoSCoW | Epic | Jalon | Scénario BDD |
|---|---|---|---|---|---|
| FR-01 | Canevas vide au démarrage, orbe animé | Must | EP-04 | J2 | Contexte « le canevas est vide » |
| FR-02 | Transcription du speaker en direct | Must | EP-02 | J2 (partiel), J3 | Acte 1 |
| FR-03 | Agent sollicité allumé dans le rail, avec sa tâche | Must | EP-03 | J3 | Acte 1, Acte 3 |
| FR-04 | Surface en 3 temps : squelette, composants, données | Must | EP-04 | J2 (1 surface), J3 | Acte 1 |
| FR-05 | Message du protocole mis en évidence avec son composant | Must | EP-05 | J3 | — (revue visuelle ; Q-63) |
| FR-06 | Composant utilisé allumé dans l'étagère | Should | EP-04 | J3 | — (Q-63) |
| FR-07 | Modification sur place, sans recréer | Must | EP-04 | J4 | Acte 2 |
| FR-08 | Clic transmis à l'agent, réponse vocale | Must | EP-06 | J5 | Acte 3 |
| FR-09 | Génération enregistrée, rejouable de 0,25× à 2× | Must | EP-07 | J6 | — (Q-63) |
| FR-10 | Raccourci de bascule en mode secours | Must | EP-07 | J6 | Bascule en mode secours |
| FR-11 | Raccourci de remise à vide | Must | EP-08 | J3 | — (Q-63) |
| FR-12 | Couper le micro sans fermer la session | Should | EP-08 | J7 | — (Q-63) |
| FR-13 | Couper la parole à l'IA en parlant | Must | EP-02 | J7 | Interrompre l'IA |
| FR-14 | Nouvelle phrase = consigne en vigueur | Must | EP-02 | J7 | Interrompre l'IA, Corriger la demande |
| FR-15 | Une interruption ne détruit pas les surfaces | Must | EP-04 | J7 | Interrompre l'IA, Annuler une génération |
| FR-16 | « Stop » arrête voix et génération, retire l'inachevé | Must | EP-02 | J7 | Annuler une génération |
| FR-17 | Correction en cours de génération, sans repartir de zéro | Should | EP-03 | J4 | Corriger la demande |
| FR-18 | Un bruit court n'interrompt pas l'IA | Should | EP-02 | J7 | Un bruit court |
| FR-19 | Interruption visible (orbe, réplique tronquée) | Must | EP-02 | J7 | Interrompre l'IA |
| FR-20 | Raccourci « silence » | Must | EP-08 | J7 | Faire taire l'IA au clavier |

Bilan MoSCoW : 16 Must, 4 Should (FR-06, FR-12, FR-17, FR-18), aucun Could ni Won't dans la fiche. Le hors-périmètre de la fiche § 3 tient lieu de « Won't » ([pdr-0004](../decisions/pdr-0004-mvp-three-acts.md), [beyond.md](beyond.md)).

## Exigences non fonctionnelles (fiche § 5)

| ID | Catégorie | Seuil | Epic | Jalon de livraison | Jalon de mesure |
|---|---|---|---|---|---|
| NFR-01 | Latence voix | < 1 s après la fin de phrase, p90 | EP-02 | J7 | instrumenté J2, p90 J8 |
| NFR-02 | Latence UI | 1er squelette < 1,5 s | EP-03 | J3 | J3 indicatif, p90 J8 |
| NFR-03 | Latence UI | Acte 1 complet < 8 s | EP-03 | J3 | J3 indicatif, p90 J8 |
| NFR-04 | Fluidité | 60 i/s pendant les apparitions | EP-04 | J7 | J7 (DevTools) |
| NFR-05 | Lisibilité | ≥ 24 px, contraste WCAG AA | EP-04 | J7 | J7 projecteur, J8 fond de salle |
| NFR-06 | Lisibilité | ≤ 6 surfaces visibles | EP-04 | J3 | J3 (cf. Q-04) |
| NFR-07 | Résilience | Bascule secours < 2 s, sans redémarrer | EP-07 | J6 | J6, J8 Wi-Fi coupé |
| NFR-08 | Déterminisme | Données figées, seule la composition varie | EP-09 | J3 | J3 (snapshot des réponses d'agents) |
| NFR-09 | Sécurité | Aucune clé OpenAI dans l'app (fiche : « jeton éphémère » ; GPT-Live : relais SDP backend, aucun client secret, cf. écart de vocabulaire dans [pdr-0012](../decisions/pdr-0012-voice-provider-openai.md), [rt-ephemeral-keys]) | EP-01 | J2 | J2 revue de code |
| NFR-10 | Reproductibilité | Flutter, genui, genui_a2a figés, `pubspec.lock` committé | EP-01 | J2 | J8 machine vierge |
| NFR-11 | Coût | Coût d'une répétition connu et plafonné | EP-10 | J2 (suivi) | J8 (plafond, cf. Q-13) |
| NFR-12 | Accessibilité scène | Raccourci pour chaque action critique | EP-08 | J7 | J7 checklist |

## Matrice de couverture exigence → jalon

`●` = jalon qui livre l'exigence ; `○` = jalon qui la prépare ou la mesure.

| Exigence | J1 | J2 | J3 | J4 | J5 | J6 | J7 | J8 |
|---|---|---|---|---|---|---|---|---|
| FR-01 |  | ● |  |  |  |  |  | ○ |
| FR-02 |  | ○ | ● |  |  |  |  | ○ |
| FR-03 |  |  | ● |  |  |  |  | ○ |
| FR-04 |  | ○ | ● |  |  |  |  | ○ |
| FR-05 |  |  | ● |  |  |  |  | ○ |
| FR-06 |  |  | ● |  |  |  |  | ○ |
| FR-07 |  |  |  | ● |  |  |  | ○ |
| FR-08 |  |  |  |  | ● |  |  | ○ |
| FR-09 | ○ |  |  |  |  | ● |  | ○ |
| FR-10 |  |  |  |  |  | ● |  | ○ |
| FR-11 |  |  | ● |  |  |  |  | ○ |
| FR-12 |  |  |  |  |  |  | ● | ○ |
| FR-13 | ○ |  |  |  |  |  | ● | ○ |
| FR-14 |  |  |  |  |  |  | ● | ○ |
| FR-15 |  |  |  |  |  |  | ● | ○ |
| FR-16 |  |  |  |  |  |  | ● | ○ |
| FR-17 |  |  |  | ● |  |  |  | ○ |
| FR-18 | ○ |  |  |  |  |  | ● | ○ |
| FR-19 |  |  |  |  |  |  | ● | ○ |
| FR-20 |  |  |  |  |  |  | ● | ○ |
| NFR-01 | ○ | ○ |  |  |  |  | ● | ○ |
| NFR-02 | ○ | ○ | ● |  |  |  |  | ○ |
| NFR-03 | ○ |  | ● |  |  |  |  | ○ |
| NFR-04 | ○ |  |  |  |  |  | ● | ○ |
| NFR-05 | ○ |  |  |  |  |  | ● | ○ |
| NFR-06 |  |  | ● |  |  |  |  | ○ |
| NFR-07 | ○ |  |  |  |  | ● |  | ○ |
| NFR-08 |  |  | ● |  |  |  |  | ○ |
| NFR-09 |  | ● |  |  |  |  |  | ○ |
| NFR-10 | ○ | ● |  |  |  |  |  | ○ |
| NFR-11 |  | ○ |  |  |  |  |  | ● |
| NFR-12 |  |  |  |  |  |  | ● | ○ |

Contrôle : chaque ligne a exactement un `●`. J8 vérifie tout (DoD, fiche § 8).

## Règles de fonctionnement → epic → jalon

Lecture de l'assistant ; les règles viennent de [p-fn-business-rules](../functional/business-rules.md).

| RG | Epic | Jalon | RG | Epic | Jalon |
|---|---|---|---|---|---|
| RG-01 | EP-04 | J2 | RG-15 | EP-03 | J4 |
| RG-02 | EP-04 | J2, J3 | RG-16 | EP-02 | J7 |
| RG-03 | EP-03 | J3 | RG-17 | EP-02 | J7 (E20 · Q-59) |
| RG-04 | EP-03 | J3 (commentaire pendant la construction) | RG-18 | EP-06 | J5 |
| RG-05 | EP-04 | J3 (Q-04) | RG-19 | EP-07 | J6 |
| RG-06 | EP-04 | J4 (Q-21, Q-58) | RG-20 | EP-07 | J6 |
| RG-07 | EP-04 | J3 | RG-21 | EP-08 | J7 |
| RG-08 | EP-03 | J3 (refus à la voix, alternative) | RG-22 | EP-08 | J7 |
| RG-09 | EP-04 | J3 (thème), J7 (projecteur) | RG-23 | EP-08 | J3 |
| RG-10 | EP-04 | J3 (état neutre) | RG-24 | EP-09 | J3 |
| RG-11 | EP-02 | J7 | RG-25 | EP-03, EP-05 | J3 |
| RG-12 | EP-02 | J7 | RG-26 | EP-02 | J2 |
| RG-13 | EP-04 | J7 | RG-27 | EP-02 | J7 (consigne de répliques courtes) |
| RG-14 | EP-02 | J7 | RG-28 | EP-06 | J5 (Q-35) |
