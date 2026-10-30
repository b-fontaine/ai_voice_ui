---
id: p-ar-frontend-screen
title: Écran, catalogue genesis, remise à vide, action et rejeu côté app (réel après 007 à 010)
area: architecture
status: draft
updated: 2026-10-30
sources: [specs/010-j6-act4-replay/spec.md, specs/010-j6-act4-replay/plan.md, specs/010-j6-act4-replay/status.md, specs/009-j5-act3-interact/spec.md, specs/009-j5-act3-interact/plan.md, specs/009-j5-act3-interact/status.md, specs/008-j4-act2-transform/spec.md, specs/008-j4-act2-transform/plan.md, specs/008-j4-act2-transform/status.md, specs/007-j3-act1-frontend/spec.md, specs/007-j3-act1-frontend/plan.md, specs/007-j3-act1-frontend/status.md, contracts/a2ui/genesis/v1/README.md, product/sources/product-description.pdf#p7, product/sources/product-description.pdf#p10, knowledge:genui-custom-catalog-item, knowledge:genui-data-model, knowledge:genui-a2ui-security]
links: [pdr-0066-010-act4-replay-details-assistant-decided, pdr-0072-design-ergonomics-013, p-ar-replay, p-rm-roadmap, pdr-0065-009-act3-interact-details-assistant-decided, pdr-0064-008-act2-transform-details-assistant-decided, p-fn-dataset-acts, p-ar-frontend, di-micro-packages, p-ar-app-channel-contract, p-ar-agents-protocols, p-ar-security, p-ar-quality, p-ar-stage-runtime, p-fn-screen, p-fn-catalog, p-fn-business-rules, p-rm-open-questions, pdr-0007-closed-catalog-stage-theme, pdr-0008-single-screen-show-the-making, pdr-0015-app-held-canvas-layout, pdr-0033-optional-shortcuts-mouse-first, pdr-0053-client-side-a2ui-validation-from-007, pdr-0054-stage-screen-orb-acts-checklist, pdr-0055-genesis-catalog-id-versioned-uri, pdr-0057-getit-composition-root-exception, pdr-0058-backend-canvas-registry-survives-voice-sessions, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, pdr-0063-007-stage-ui-details-assistant-decided, genui-custom-catalog-item, genui-data-model, genui-a2ui-security, genui-multiple-surfaces, ds-a11y-wcag-contrast, ds-widgetbook-4-genui, test-golden-alchemist, bloc-event-transformers]
tags: [frontend, ecran, catalogue, genesis, validation, remise-a-vide, design-system]
---
# Écran, catalogue `genesis`, remise à vide, action et rejeu (réel après 007 à 010)

**En bref.** Détail de ce que la fonctionnalité 007 (J3-B, terminée le 2026-10-30) a livré côté app : l'écran à six zones, le catalogue fermé `genesis` rendu par genui 0.10.4, la validation A2UI côté client, la remise à vide et ses variables d'environnement. La fonctionnalité 008 (J4, 2026-10-30) y ajoute la ligne de comparaison, la légende des séries et la remise à vide de démarrage (§ Acte 2) ; la fonctionnalité 009 (J5, 2026-10-30) y ajoute la Barre d'actions, le bandeau sous la grille, le clic vers `POST /canvas/actions` et un nouveau budget des zones (§ Acte 3) ; la fonctionnalité 010 (J6, 2026-10-30) y ajoute la slice `replay`, la zone Rejeu active de 480 px et ses variables d'environnement (§ Acte 4). Vue d'ensemble, couches et Blocs : [p-ar-frontend](frontend.md) ; comportement visible : [p-fn-screen](../functional/screen.md), [p-fn-catalog](../functional/catalog.md).

## Zones livrées (widgets de l'app)

| Widget (`apps/genesis_canvas/lib/widgets/`) | Source d'état | Livré |
|---|---|---|
| `top_bar` (+ `stage_bar` empilé) | `VoiceSessionBloc`, `TranscriptBloc`, `StageBloc` | orbe, transcription, bouton Démarrer ; `act-indicator` « Acte n/3 · Créer / Transformer / Interagir » (un clic passe à l'acte suivant, cyclique) ; `reset-button` « Remettre à vide », inactif tant qu'un agent est `working` ou `pending` (`anyBusy`) |
| `agents_rail` | `AgentActivityBloc` | orchestrateur puis `selected` puis `idle` du dernier `plan`, aucun nom codé en dur (RG-29) ; états « orchestre », « en veille », « en attente », « en cours », « terminé », « échec », « hors périmètre », « interrompu » ; « aucun agent retenu » si `selected` vide ; vide jusqu'au premier `plan` (RG-01) |
| `CanvasBoard` (`features/canvas`) | `CanvasBloc` + `ProtocolFeedBloc.highlightedSurfaceId` | grille tenue par l'app ([pdr-0015](../decisions/pdr-0015-app-held-canvas-layout.md)) : emplacement déterministe kpi, trend, reviews, checklist puis surfaces inconnues ; 1 colonne pour 1 surface, 2×2 jusqu'à 4, 3×2 pour 5 ou 6 surfaces **de la grille** ; **bandeau `actions` de 72 px sous la grille** (009), hors de la grille ; contour pointillé `highlight-<id>` sur la surface du message en cours (D2) |
| `protocol_panel` | `ProtocolFeedBloc` | replié par défaut (460×140), déplié (780×620) il recouvre le canevas à droite sans le redimensionner ; 4 dernières entrées, JSON compact du corps de l'opération sans `version`, borné à 2 000 caractères, rétention 200 entrées, horodaté sur l'`AppClock` ([pdr-0038](../decisions/pdr-0038-latency-measured-on-app-clock.md)) ; message refusé marqué « refusé » + code ; JSON en `Text` brut, jamais en Markdown |
| `catalog_shelf` | `CatalogShelfBloc` | « CATALOGUE · n / 6 utilisés » sur `catalogComponents` (« 5 / 6 » quand `actions` est créée), pastilles « utilisé » / « inutilisé » (la couleur n'est qu'un renfort) ; libère un composant au `deleteSurface`, y compris de compensation |
| `replay_bar` | `ReplayBloc` | zone Rejeu active depuis 010 (§ Acte 4) : Lecture/Pause, Recommencer, curseur, cinq vitesses, « Direct » ; `stage_bar` affiche « Acte 4 · Rejeu » en rejeu |

Aucune zone « régie » séparée : indicateur d'acte et remise à vide sont dans la barre supérieure ([pdr-0063](../decisions/pdr-0063-007-stage-ui-details-assistant-decided.md), D1 et D4). Pas de raccourci `R` ([pdr-0033](../decisions/pdr-0033-optional-shortcuts-mouse-first.md)).

## Catalogue `genesis` côté client

- `entities/catalog` (Dart pur, sans `flutter` ni `genui`) : `GenesisContract` (5 `components`, 6 `catalogComponents`, `writableSubPaths`, propriétés admises `id`/`component`/`data`, champs requis, `catalogId` par défaut, chemin lié par surface), égal à `contracts/a2ui/genesis/v1/catalog.json` par test ; `GenesisMessageValidator` et ses verdicts.
- `features/canvas` : `genesisCatalog({catalogId})` (5 `CatalogItem` : `KeyIndicator`, `TrendChart` en `CustomPainter`, `ReviewSentiment`, `ReleaseChecklist`, `ActionBar`) ; `CrashList` hors catalogue (sans schéma). Chaque item lit son objet avec **`BoundObject`** (`ctx.data['data']`) ; `dataContext.subscribe` et `getValue<T>` sont interdits dans un `widgetBuilder` ([genui-custom-catalog-item], [genui-data-model]).
- **Trois états distincts** par composant : *squelette* (peint par `CanvasBoard`, `skeleton-<id>`, tant que la phase est `skeleton`), *sans données* (`nodata-<id>`, composants reçus mais objet absent), *neutre* (`neutral-<id>`, objet incomplet, de mauvais type ou statut hors enum, RG-10, jamais d'exception). Complet : le composant.
- **Squelette peint par `CanvasBoard`** : avec genui 0.10.4 le `defaultBuilder` de `Surface` ne s'affiche jamais après `createSurface` (définition sans `root`) ; `Surface` n'est montée qu'à partir de `updateComponents`. Le premier squelette se peint à la frame qui suit `createSurface`.
- `json_schema_builder` (0.1.7, version du lock) n'est pas ré-exporté par `genui` : il est **déclaré** dans le `pubspec` de `feature_canvas`.
- Thème : `shared/design_system` (`SceneTheme`, `ThemeExtension`) : couleurs de statut `ok|risk|blocking` par code fermé, jetons du rail et de l'indicateur d'acte, tous textes ≥ 24 px, contrastes ≥ 8,36:1 mesurés sur les paires texte/fond, paires graphiques 3:1 ; briques `DsSkeleton`, `DsNeutralState`, `DsStatusChip`. `genesisThemeData()` (app) applique un plancher de 24 px au thème Material. Aucune couleur ne dépend d'un libellé français.
- Débordement : `maxLines` + ellipse, jamais de `FittedBox` ni d'échelle sous 24 px ; la checklist annonce « + N autres critères » (priorité `blocking` puis `risk`) au lieu de rogner.

## Flux unique, validation et `A2uiGate`

Une seule instance de `A2uiGate` par page (`features/canvas`) possède l'unique `GenesisMessageValidator` (à état : surfaces actives, plafond 6) et reçoit le flux de `SessionEvent`, **en direct comme en rejeu** (`A2uiGate.replayEvents` rejoue la ligne brute `raw`, pas le message décodé). Depuis 009 il applique aussi `writableSubPaths` (code `path_not_allowed`, mêmes fixtures négatives que Go). `validatedBranch()` (abonné unique avec tampon) alimente le panneau et l'étagère avec **tous** les messages et leur verdict ; `accepted` n'alimente que `CanvasBloc` (messages acceptés plus `deleteSurface` locaux de compensation) ; le rail lit le flux brut. Refus : code fermé consigné par `errorSink` (« Message A2UI refusé : <code> »), jamais le contenu. Règles et codes : [p-ar-agents-protocols](agents-protocols.md) § Validation côté client ([pdr-0053](../decisions/pdr-0053-client-side-a2ui-validation-from-007.md)).

## Remise à vide (`_resetStage`, FR-11)

Unique coordinatrice dans `GenesisCanvasPage` ; `StageBar` n'expose que `onResetPressed`. Ordre : (1) `gate.reset()` synchrone ; (2) `CanvasResetRequested`, `ProtocolFeedCleared`, `CatalogShelfCleared`, `AgentActivityReset`, `StageResetRequested` ; (3) `unawaited(_requestBackendReset())` : `POST /canvas/reset` au mieux, réessayé tant que la réponse est `busy` (409) ; une nouvelle demande remplace la boucle en cours ; arrêt à la fermeture de la page. État cible = état initial (rail vide, acte 1). Contrat et route : [p-ar-app-channel-contract](app-channel-contract.md) ; depuis 008 le registre est partagé entre sessions (Q-73 résolue, [p-ar-stage-runtime](stage-runtime.md)).

## Acte 2 : comparaison, séries et démarrage (008, 2026-10-30)

Les quatre surfaces mutent par `updateDataModel` seul : aucun squelette n'est repeint, seul l'objet lié change ([pdr-0064](../decisions/pdr-0064-008-act2-transform-details-assistant-decided.md) D1). Valeurs : [p-fn-dataset-acts](../functional/dataset-acts.md).

- **Ligne `comparison-<surface>`** (`bound_item.dart`, `comparisonLine`) : un seul `Text` « <label> : <value> · <delta> » (« 3.3 : 99,71 % · −0,28 pt » ; « 3.3 : 14 % négatifs · +16 pts »), couleur secondaire neutre (jamais déduite du `delta`, RG-09), une ligne. Omise si `label`, `value` ou `delta` manque, sans état neutre global (D7). Clés `comparison-kpi` et `comparison-reviews`.
- **Courbe** (`trend_chart.dart`) : une entrée de légende par série, clé `trend-series-<nom>` (« Android 3.4 », « Android 3.3 », « iOS 3.4 »). Couleur **par plateforme** (préfixe du nom : iOS, Android), palette de graphique sans couleur de statut ; série 3.3 en pointillés ; le seuil garde la couleur « bloquant » (D8). Le titre passe seul sur sa ligne quand la légende ne tient pas (« Taux de crash du jour » jamais coupé).
- **Checklist** : colonnes calculées (`text_metrics.dart`) ; la valeur d'un critère prend sa largeur mesurée **avant** le seuil et le libellé, donc « 99,43 % (3.3 : 99,71 %) » et « 30 % (3.3 : 14 %) » ne sont jamais tronqués (NFR-05). Les extraits d'avis restent tronqués par l'ellipse (`maxLines`).
- **Remise à vide de démarrage** (D6) : en mode vivant, `GenesisCanvasPage` appelle une fois `_requestBackendReset()` avant la première session (le canevas est déjà vide : aucune remise à vide visuelle), car une mutation visant une surface inconnue de l'app est refusée (`unknown_surface`). Si elle réessaie encore (409) au premier passage à `Connecting`, elle est abandonnée (`_startupResetGeneration`) : elle viderait le tableau en pleine démo. Aucune requête en rejeu, même avec `GENESIS_BACKEND_URL`.
- **Rejeu de l'acte 2** : asset `assets/replays/act2-replay.jsonl` (16 messages en 008 ; **19 depuis 009** avec les trois messages de la Barre d'actions : acte 1, `act2-*`, `act2-actions` ; **artefact dérivé** des fixtures du contrat, relu par un test) ; `app-smoke.sh act2-replay` produit la capture 1920×1080, conforme à la vérification du 2026-10-30 : quatre surfaces à leur place, Android seul, comparaison visible, deux séries (3.3 en pointillés) et seuil, « NO-GO Android » et « En attente de décision », étagère « 4 / 6 », panneau « 16 messages » (19 avec la barre). Test de page 1920×1080 étendu à l'acte 2 (textes ≥ 24 px, deux entrées de légende, deux lignes de comparaison).
- **Essai réel avec micro : non fait** (voix non pilotable sans présence humaine) ; à faire en répétition avec le porteur.

## Acte 3 : Barre d'actions et clic (009, 2026-10-30)

Détails tranchés par la boucle sous [pdr-0062](../decisions/pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details.md) ([pdr-0065](../decisions/pdr-0065-009-act3-interact-details-assistant-decided.md)). Valeurs et libellés : [p-fn-dataset-acts](../functional/dataset-acts.md).

- **`ActionBar`** (`features/canvas`, `CatalogItem`) : lit `{title, actions[{id, label, tone}]}` avec `BoundObject` ; trois états (squelette, sans données, neutre : un `id` hors `block_release|validate_release` ou un champ de mauvais type donne l'état neutre, RG-10) ; deux boutons, texte ≥ 24 px, cible ≥ 48 px, libellé sur une ligne (`Row` + `Flexible`, ellipse : un libellé très long est tronqué) ; bordure et texte par ton, jetons `actionNeutralBorder` / `actionDangerBorder` du thème de scène (couleurs choisies par la boucle, contrastes mesurés ≥ 8,36:1 pour le texte et ≥ 3:1 pour la bordure). Aucune couleur ne dépend du libellé.
- **Bandeau** : `CanvasBoard` = une `Column` {grille 2×2 `Expanded`, bandeau `SizedBox(72)`}, le bandeau étant réservé dès la première surface ; les quatre cellules gardent position et `State` quand `actions` arrive (S-02, test dédié). `actions` n'entre jamais dans la grille.
- **Clic** : la `Surface` propose le clic à un `ActionDelegate` (`surfaceId` lu du contexte de rendu), qui envoie `ActionRequested` au **`CanvasActionBloc`** (`droppable`) ; `CanvasActionClient` (port) + `HttpCanvasActionClient` : un seul essai, résultat scellé ; le Bloc réessaie sur `busy` / `noSession` (défauts : délai 2 s, 6 réessais, intervalle 1 s, durée maximale 60 s). États `Idle | Sending | Running | Failed` ; `Running` dure jusqu'à la fin d'activité des agents (événement relayé par `GenesisCanvasPage` depuis `AgentActivityBloc` : les slices ne se lisent pas entre elles), la fermeture de session ou la durée maximale. Un `InheritedWidget` interne à la slice (`ActionAvailability`, non exporté par le barrel) désactive les boutons ; `_resetStage` réinitialise le Bloc ; aucune requête en rejeu (boutons désactivés).
- **Résultat** : le `updateDataModel` de `/checklist/decisionStatus` reconstruit le `BoundObject` de la checklist sans recréer le `State` de la `Surface` (sonde T05 sur genui 0.10.4) : « Bloquée » / « Validée » s'affiche, critères et recommandation inchangés.
- **Budget des zones à 1920×1080, modifié (D8)** : voir le tableau ci-dessous ; `ReviewSentiment` : écarts verticaux 6 → 4 px (le repli du glyphe ★ vers une autre police dépassait la cellule de 250 px de 2 px, invisible en police Ahem).
- **Rejeu de l'acte 3** : asset `assets/replays/act3-replay.jsonl` (20 lignes : acte 1, `act2-*`, `act2-actions`, `act3-block`), artefact dérivé relu par un test ; `app-smoke.sh act3-replay` : capture 1920×1080 **conforme** après correction du débordement (`.omc/state/loop/snapshots/20261030-164743-act3-replay.png`) : bandeau « Décision » avec les deux boutons sous la grille, « Bloquée » et « NO-GO Android », comparaison 3.3 intacte, « 5 / 6 utilisés », panneau « 20 messages ».
- **Essai réel** : actes 1 et 2 validés en réel ; le clic a reçu 409 `busy` (client d'essai trop pressé), la voix n'a pas été observée (Q-75, [p-ar-quality](quality.md)).

## Acte 4 : Rejeu (010, 2026-10-30)

Détails tranchés par la boucle sous [pdr-0062](../decisions/pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details.md) ([pdr-0066](../decisions/pdr-0066-010-act4-replay-details-assistant-decided.md) D1 à D8). Journal, lecteur, déterminisme et variables : [p-ar-replay](replay.md).

- **Slice `packages/features/replay`** (ajoutée au workspace racine) : `ReplayRouter` devant l'`A2uiGate` (la page lui branche `_source.events` ; `_gate.attach(router.events)`), `ReplayPlayer` à pas fixe, `ReplayBloc` (commandes `sequential`, abonnement au lecteur `restartable`), port `ReplayStage` réduit à `clear()` (étapes 1-2 de `_resetStage` + `ProtocolFeedEntriesCleared`) et `exit()` (`_resetStage` complet). La page relaie au Bloc l'occupation combinée (agents ou action en cours) ; `_scenarioMode` (rejeu scripté de 000) reste distinct du rejeu dynamique.
- **Zone Rejeu** (`replay_bar`) : **480 px** de large, deux rangées de 48 px (rangée 1 : libellé, Lecture/Pause, Recommencer, curseur, « Direct » ; rangée 2 : cinq pastilles 0,25× à 2×) ; l'étagère passe à **900 px** à 1920×1080 (panneau replié 460 px, intervalles 16 px). Le curseur ne positionne qu'au relâchement (`onChangeEnd`).
- **Isolation** : `CanvasActionScope.enabled` et `startEnabled` de la barre supérieure valent « ni mode scénario ni rejeu » ; aucune requête réseau en rejeu.
- **Panneau du protocole** (EP-05) : suit le message rejoué (contour pointillé sur sa surface) ; reste déplié pendant un positionnement.
- **Fermeture** : `dispose` de la page ferme d'abord le `ReplayBloc`, dont la partie synchrone détruit le lecteur (aucun minuteur actif après démontage) ; `_shutdown` ferme ensuite, dans l'ordre, session, source, **routeur**, gate, puis les autres Blocs.
- **Capture** : `GENESIS_REPLAY_AT=0.5 app-smoke.sh act3-replay` (1920×1080) **conforme** : indicateur « Acte 4 · Rejeu », « Démarrer » grisé, deux rangées lisibles, quatre surfaces de l'acte 1, panneau « 13 messages ». Pas d'essai avec micro : sans objet (aucun réseau ni LLM en rejeu).
- **Observations, non tranchées** : le titre du panneau reste « FLUX A2UI · live » pendant le rejeu (cosmétique) ; le rail des agents est vide en rejeu (seul le flux A2UI est rejoué, pdr-0032). Points à voir avec le porteur en répétition ([p-fn-screen](../functional/screen.md)).

## DI et fermeture de la page

- **État réel de la DI, écarts assumés** par rapport à « un module par package » ([di-micro-packages]) : modules injectable écrits **dans `app/di`** (les paquets ne dépendent pas d'`injectable`) ; graphe `live` **seul**, sans fake dans `lib/` (les tests ne remplacent que la fabrique de transport et pointent `GENESIS_BACKEND_URL` sur un faux backend local réel) ; **un `GetIt` par instance d'app** (`GetIt.asNewInstance()`), pas de scope par session ; fabriques `VoiceTransport Function()` et `EnvelopeLog Function()` enregistrées à la main (injectable ne sait pas enregistrer un type fonction) ; `VoiceSession` résolue **une seule fois** par la page racine de composition ; `getIt` n'est appelé nulle part ailleurs ([pdr-0057](../decisions/pdr-0057-getit-composition-root-exception.md)). **007** : le `CanvasResetClient` HTTP est enregistré dans `app/di` et fermé par `getIt.reset()` comme le relais ; les nouveaux Blocs sont créés par la page.
- **Fermeture** (`_shutdown`, ordre testé par `genesis_canvas_page_composition_test`) : `VoiceSessionBloc`, arrêt puis libération de la session, source d'événements, routeur du rejeu (010), **gate A2UI**, `TranscriptBloc`, `AgentActivityBloc`, `CanvasBloc`, `ProtocolFeedBloc`, `CatalogShelfBloc`, `StageBloc`, surveillance du moteur, `SurfaceController`. Les Blocs du panneau, de l'étagère et de la régie se ferment après le gate dont ils lisent le flux. Sortie de la fenêtre : `AppLifecycleListener(onExitRequested)` + `ExitGuard`.
- **Délais par défaut** : `relayDeleteTimeout` 7 s, `channelCloseTimeout` 2 s, `sessionCloseTimeout` 10 s, `exitCloseTimeout` 12 s (invariants testés : 10 s > 7 s + 2 s ; 12 s > 10 s + 1 s) ; réglages posés par l'assistant, à confirmer par le porteur, sans bloquer.
- Chaque nouveau Bloc : commandes `sealed` en `sequential`, source en `restartable` (`emit.onEach`), `PanelToggled` en `droppable` ([bloc-event-transformers]).

## Variables d'environnement de l'app (`GenesisConfig`)

| Variable | Rôle | Défaut / bornes |
|---|---|---|
| `GENESIS_BACKEND_URL` | origine du backend | `http://127.0.0.1:8080` |
| `GENESIS_CATALOG_ID` | `catalogId` du catalogue de l'app et du validateur | = défaut `A2UI_CATALOG_ID` de `docker-compose.yaml` ([pdr-0055](../decisions/pdr-0055-genesis-catalog-id-versioned-uri.md)), égalité testée |
| `GENESIS_CANVAS_RESET_TIMEOUT_MS` | délai du `POST /canvas/reset` | 2 000 ms ; 100 à 10 000 |
| `GENESIS_CANVAS_RESET_RETRIES` | réessais tant que la réponse est `busy` | 8 ; 0 à 30 |
| `GENESIS_CANVAS_RESET_RETRY_INTERVAL_MS` | intervalle entre deux réessais | 1 500 ms ; 100 à 10 000 |
| `GENESIS_CANVAS_ACTION_TIMEOUT_MS`, `GENESIS_CANVAS_ACTION_RETRIES`, `GENESIS_CANVAS_ACTION_RETRY_INTERVAL_MS`, `GENESIS_CANVAS_ACTION_MAX_DURATION_MS` (009) | délai du `POST /canvas/actions`, réessais sur `busy` / `noSession`, intervalle, durée maximale de `Running` | 2 000 ms ; 6 ; 1 000 ms ; 60 000 ms |
| `GENESIS_REPLAY_MAX_GAP_MS`, `GENESIS_REPLAY_TICK_MS`, `GENESIS_REPLAY_JOURNAL_MAX`, `GENESIS_REPLAY_SPEED`, `GENESIS_REPLAY_AT` (010) | écart maximal rejoué, pas du lecteur, plafond du journal, vitesse initiale, position de la capture (fraction 0 à 1) | 3 000 ms (100 à 60 000) ; 100 ms (10 à 1 000) ; 5 000 (1 à 100 000) ; 1× (0,25 / 0,5 / 1 / 1,5 / 2) ; absente. Détail : [p-ar-replay](replay.md) |
| `GENESIS_SCENARIO`, `GENESIS_SNAPSHOT`, `GENESIS_APP_LOG` | rejeu scripté, capture PNG, journal local des enveloppes | inactifs sans valeur |

## Budget des zones à 1920×1080 et fenêtre Linux

| Zone | Hauteur (007 → 009) |
|---|---|
| Barre supérieure (orbe, transcription, acte, remise à vide) | 160 → **128 px** |
| Rail des agents | ≤ 200 px (inchangé : cinq lignes possibles) |
| Canevas (grille 2×2, cellules ≈ 940×250, + bandeau de la Barre d'actions) | 520 → **572 px** (2 × 250 + 72) |
| Rangée du bas (étagère 900 px, Rejeu 480 px en deux rangées de 48 px, panneau replié 460 px) | ≤ 140 px |
| Marges et intervalles (marge verticale 18 → 8 px) | 60 → **40 px** |

Le runner Linux ouvre la fenêtre en **1920×1080** (`gtk_window_set_default_size`, `my_application.cc`) : la première capture `app-smoke` en 1280×720 débordait. ⚠️ **Limite assumée** : l'écran suppose 1920×1080 ; en dessous, les six zones débordent (texte ≥ 24 px, NFR-05) ; la machine de démo projette en 1080p ([pdr-0028](../decisions/pdr-0028-linux-demo-machine.md)).

## Écarts consignés

- **Stories Widgetbook et goldens par `CatalogItem` reportés** (prévus par [p-ar-frontend](frontend.md), [ds-widgetbook-4-genui], [test-golden-alchemist]) : coupes C1 et C3 de la roadmap ; les états sont couverts par des tests de widgets et la capture `app-smoke`.
- Le rail est une bande vide en rejeu : seul le flux A2UI est enregistré et rejoué (pdr-0032, 010), donc aucun `plan` ni `agent.activity` n'y repasse. Constat de 010, à voir avec le porteur.
- **Hors périmètre de 010, relèvent de 013** ([pdr-0072](../decisions/pdr-0072-design-ergonomics-013.md)) : panneau déplié qui déborde de 39 px, boutons d'acte et de remise à vide à 44 px (cibles < 48 px).
- **Polices de test versionnées (009)** : `cell_height_real_fonts_test.dart` rend les quatre cellules (936×250) en polices réelles Noto Sans et DejaVu Sans, versionnées comme fixtures de test (≈ 1,3 Mo ; copyright Debian ; ⚠️ le texte intégral de la licence OFL est à ajouter si le dépôt est redistribué) pour rester hermétique ; il rougit si l'on rétablit l'écart de 6 px.
- Détails d'interface tranchés par la boucle sous [pdr-0062](../decisions/pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details.md) : D1 à D6 de [pdr-0063](../decisions/pdr-0063-007-stage-ui-details-assistant-decided.md), le porteur peut les contester.
