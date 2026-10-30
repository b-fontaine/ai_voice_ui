---
id: p-fn-business-rules
title: Règles de fonctionnement RG-01 à RG-30
area: functional
status: draft
updated: 2026-10-30
sources: [specs/011-voice-interaction/status.md, specs/010-j6-act4-replay/status.md, specs/009-j5-act3-interact/status.md, specs/008-j4-act2-transform/status.md, product/sources/product-description.pdf#p3, product/sources/product-description.pdf#p7, product/sources/product-description.pdf#p9, product/sources/product-description.pdf#p11, product/sources/product-description.pdf#p12]
links: [p-ar-voice-interruption, pdr-0069-voice-interruption-hybrid-stop-011, pdr-0073-011-voice-interaction-details-assistant-decided, pdr-0066-010-act4-replay-details-assistant-decided, p-ar-replay, pdr-0065-009-act3-interact-details-assistant-decided, p-fn-dataset-acts, pdr-0064-008-act2-transform-details-assistant-decided, p-fn-requirements, p-fn-nfr, p-fn-catalog, p-fn-screen, p-fn-risks-acceptance, pdr-0005-frozen-fictional-dataset, pdr-0006-replay-fallback-must, pdr-0007-closed-catalog-stage-theme, pdr-0009-french-only, rt-barge-in, genui-multiple-surfaces, ux-genui-streaming-loading, ux-genui-errors-validation, ma-filler-acknowledgements, pdr-0013-orchestrator-visible-agent-selection, pdr-0015-app-held-canvas-layout, pdr-0016-validate-release-action, pdr-0019-six-limit-applies-to-surfaces, pdr-0024-act2-android-only, pdr-0025-top-bar-speaker-and-ai-lines, pdr-0032-obs-video-fallback-a2ui-replay-act, pdr-0033-optional-shortcuts-mouse-first, pdr-0039-component-voice-interactions-via-fr07]
tags: [regles, fonctionnement, interruption, catalogue, rejeu]
---
# Règles de fonctionnement

**En bref.** Les règles qui gouvernent le comportement de Genesis Canvas, dégagées de la fiche. Certaines y sont explicites, d'autres découlent d'une exigence ou d'une parade. Chaque règle cite sa source. Le **libellé** est une synthèse de l'assistant (statut `draft`) ; le **fond** vient de la fiche.

## Construction de l'écran

| RG | Règle | Source |
|---|---|---|
| RG-01 | Au démarrage, et après une remise à zéro, le canevas est vide : seul l'orbe vocal animé est visible. | FR-01, § 6 (canevas « vide au départ ») |
| RG-02 | Toute surface passe par trois temps visibles : squelette, puis composants, puis données. Chaque composant du catalogue possède un état squelette. | FR-04, § 7 (règles du catalogue) |
| RG-03 | Le premier squelette apparaît en moins de 1,5 s après la fin de la phrase, avant toute donnée. | NFR-02, § 8 (« squelettes immédiats ») |
| RG-04 | L'IA commente pendant la construction (« je lance l'analyse des crashs... ») : l'attente devient du spectacle. | § 5 (point délicat), § 8 (risque « attente trop longue ») |
| RG-05 | Au maximum 6 surfaces sont visibles en même temps. | § 3, § 6, NFR-06 ; portée tranchée (E4 · Q-04, [pdr-0019](../decisions/pdr-0019-six-limit-applies-to-surfaces.md)) : surfaces visibles, pas de compteur de composants |
| RG-06 | Une demande de modification transforme les surfaces existantes **sur place** : elles restent à leur place et ne sont pas recréées. | FR-07, § 2 acte 2, S-02 ; aucune suppression en acte 2 (E8 · Q-21 → pdr-0059) ; **livrée par 008** (`updateDataModel` seul, [pdr-0064](../decisions/pdr-0064-008-act2-transform-details-assistant-decided.md)) ; acte 2 uniquement Android, checklist comprise (E19 · Q-58 tranché, [pdr-0024](../decisions/pdr-0024-act2-android-only.md)) |
| RG-25 | La fabrication est montrée en continu : l'agent sollicité s'allume avec sa tâche, le message de protocole en cours est mis en évidence et relié à son composant, le composant utilisé s'allume dans l'étagère, la transcription est affichée en direct. | FR-02, FR-03, FR-05, FR-06, § 6 |
| RG-29 | L'orchestrateur choisit à chaque demande les agents qu'il active, et le rail le montre : agents sollicités allumés avec leur tâche, agents non sollicités visiblement en veille. Les agents portent un nom de rôle métier (Qualité, Voix du client, Livraison). | FR-03, [pdr-0013](../decisions/pdr-0013-orchestrator-visible-agent-selection.md) |

## Catalogue et apparence

| RG | Règle | Source |
|---|---|---|
| RG-07 | L'IA ne compose qu'avec les composants du catalogue ; elle ne peut pas en inventer. | § 3 (hors périmètre), § 7 |
| RG-08 | Une demande impossible avec le catalogue est **refusée à la voix, avec une alternative**. | § 7 |
| RG-09 | Couleurs et tailles de texte viennent du **thème de scène**, jamais de l'IA ; texte ≥ 24 px, contraste WCAG AA. | § 7, NFR-05, § 8 |
| RG-10 | Un composant qui reçoit des données incomplètes affiche un **état neutre** plutôt qu'une erreur ; la démo continue. | § 7 |

## Interruption, annulation, correction

| RG | Règle | Source |
|---|---|---|
| RG-11 | Quand le speaker parle pendant que l'IA parle, l'IA se tait immédiatement et écoute. | FR-13, S-05 ; **011** : appliquée sur mot d'arrêt (`voice.interrupted`) et par consigne au modèle ; sans mot d'arrêt, repose sur le modèle (Q-77) |
| RG-12 | Après une interruption, la nouvelle phrase devient la consigne en vigueur. | FR-14 ; **011** : chemin « Stop » seulement |
| RG-13 | Une interruption ne détruit jamais les surfaces déjà construites. | FR-15, S-05 ; **011** : K-03, K-05 |
| RG-14 | « Stop » ou « annule » arrête la voix **et** la génération en cours ; les surfaces inachevées sont retirées proprement ; les surfaces complètes restent. | FR-16, S-06 ; **011** : livrée (surfaces inachevées par complétude, K-03) |
| RG-15 | Une correction en cours de génération (« non, plutôt iOS ») réoriente la génération : les surfaces déjà construites passent sur les nouvelles données, sans repartir d'un canevas vide. | FR-17, S-07 ; **partielle** : correction de plateforme livrée (008), annulation en vol : J7 |
| RG-16 | Un bruit court (toux, applaudissements d'une seconde, rire) n'interrompt pas l'IA. | FR-18, S-08, § 8 (seuil réglé en répétition) |
| RG-17 | Une interruption est visible : l'orbe passe par « Interrompue » (arrêt net, bref flash) puis « Écoute » ; la réplique de l'IA est tronquée dans la transcription là où elle a été coupée. | FR-19, § 6 (états de l'orbe) ; **011** : livrée sur `voice.interrupted` (K-05) |
| RG-27 | Les répliques de l'IA sont **courtes**, par consigne. | § 8 (parade « l'IA ne s'arrête pas ») |

Repère technique : couper la voix n'annule pas d'elle-même les outils en cours ; RG-14 impose donc une annulation explicite de la génération ([rt-barge-in]).

## Interaction avec l'UI générée

| RG | Règle | Source |
|---|---|---|
| RG-18 | Un clic sur un composant généré est transmis à l'agent concerné, qui s'allume dans le rail et répond à la voix **et** dans l'interface. | FR-08, § 6 (modes), S-03 ; **livrée par 009 (2026-10-30)** : le clic part en `POST /canvas/actions`, Livraison s'allume seul dans le rail (`plan` Livraison seul), la voix confirme **après** `completed` ([pdr-0065](../decisions/pdr-0065-009-act3-interact-details-assistant-decided.md)) ; ⚠️ la voix hors délégation n'a pas été observée en réel (Q-75) |
| RG-28 | Le statut de la checklist go/no-go évolue après une action (ex. « Bloquer la release » → statut « Bloquée »). | § 7 (checklist), S-03 ; statuts de la fiche § 7 : validé / à risque / bloquant (E17 · Q-35 → pdr-0054) ; **livrée par 009** : `updateDataModel` du seul sous-chemin `/checklist/decisionStatus`, libellé lu dans le jeu de données ([p-fn-dataset-acts](dataset-acts.md)) ; critères, recommandation et comparaison inchangés ; limite connue : une demande vocale ultérieure réécrit la checklist et efface la décision (Q-76) |
| RG-30 | « Valider la release » se comporte comme « Bloquer la release » (RG-18, RG-28) : clic transmis à Livraison, confirmation vocale, statut de la checklist mis à jour (par exemple « Validée »). | § 7 (Barre d'actions) ; [pdr-0016](../decisions/pdr-0016-validate-release-action.md) (Q-62) ; **livrée par 009** : « Bloquer » puis « Valider » donne « Validée » (la décision humaine prime sur la recommandation) |

## Régie de scène et rejeu

| RG | Règle | Source |
|---|---|---|
| RG-19 | Toute la génération est enregistrée et rejouable de 0,25× à 2×. Seul le **flux A2UI** est enregistré (ni voix ni transcription) ; le rejeu est l'**acte 4** et n'appelle ni réseau ni LLM. | FR-09, § 6 (zone rejeu) ; [pdr-0032](../decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md) ; **respectée par 010 (2026-10-30)** : journal client en mémoire (jamais sur disque), faux backend sans requête pendant le rejeu (R-01), messages vivants écartés pendant le rejeu (R-05) ([pdr-0066](../decisions/pdr-0066-010-act4-replay-details-assistant-decided.md), [p-ar-replay](../architecture/replay.md)) |
| RG-20 | ~~Le mode secours rejoue une session enregistrée ; il s'active par un seul raccourci, en moins de 2 s, sans redémarrer l'app, et un indicateur discret le signale.~~ **Retirée (pdr-0032)** : le secours est une vidéo OBS gérée par le porteur. | ~~FR-10, NFR-07, S-04~~, § 8 ; [pdr-0032](../decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md) |
| RG-21 | Toute action critique est faisable **à la souris** (contrôle visible) ; un raccourci clavier s'y ajoute s'il ne pose pas de problème ; le clavier est réservé au speaker. | NFR-12, § 6 ; assouplie par [pdr-0033](../decisions/pdr-0033-optional-shortcuts-mouse-first.md) |
| RG-22 | Couper le micro (FR-12) ou faire taire l'IA au clavier (FR-20) **ne ferme pas** la session. | FR-12, FR-20, S-09 |
| RG-23 | Une commande (bouton, et raccourci s'il ne pose pas de problème) remet le canevas à l'état vide (retour à RG-01). | FR-11 ; [pdr-0033](../decisions/pdr-0033-optional-shortcuts-mouse-first.md) |

## Données et langue

| RG | Règle | Source |
|---|---|---|
| RG-24 | Les données sont fictives et figées : seule la composition de l'UI varie d'une exécution à l'autre. | NFR-08, § 3 ; [pdr-0005](../decisions/pdr-0005-frozen-fictional-dataset.md) |
| RG-26 | La conversation et l'interface sont en français uniquement. | § 3 ; [pdr-0009](../decisions/pdr-0009-french-only.md) |

## Numérotation

Les RG sont numérotées dans l'ordre de rédaction, puis regroupées par thème. On ne renumérote jamais une règle : une règle abandonnée est barrée et garde son numéro. Prochaine règle libre : **RG-31**.

## Points ouverts

- RG-06 : la maquette de l'acte 2 retire une surface et en crée une nouvelle (E8 · Q-21 tranché : aucune suppression, pdr-0059). Son critère iOS est sans portée : uniquement Android (E19 · Q-58 tranché, [pdr-0024](../decisions/pdr-0024-act2-android-only.md)).
- RG-17 : tranché (E20 · Q-59, [pdr-0025](../decisions/pdr-0025-top-bar-speaker-and-ai-lines.md)) : répliques du speaker et de l'IA, réplique coupée tronquée ; la détection de l'interruption est tranchée (Q-40 → pdr-0069) et livrée par 011.
- Interactions vocales propres à chaque composant (fiche § 7) : tranché (Q-61, [pdr-0039](../decisions/pdr-0039-component-voice-interactions-via-fr07.md)) : couvertes par FR-07 / RG-06 uniquement, sans règle dédiée.
- RG-14 / RG-15 : modèle de surfaces tranché (E11 · Q-29, [pdr-0015](../decisions/pdr-0015-app-held-canvas-layout.md)) : N surfaces dans une grille de l'app ([genui-multiple-surfaces]).

Tous renvoient à [p-rm-open-questions](../roadmap/open-questions.md).
