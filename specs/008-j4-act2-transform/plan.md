# 008 — Plan technique

## Où
| Pile | Paquet / module | Couche ou slice | Fichiers créés ou modifiés |
|---|---|---|---|
| contrat | `contracts/a2ui/genesis/v1/` | fixtures + `catalog.json` | `examples/act2-{kpi,trend,reviews,checklist}.jsonl` (un `updateDataModel` chacun) ; `catalog.json` : `comparison` déclaré aussi pour `ReviewSentiment`, séries nommées de `TrendChart` ; `README.md` |
| Go agents | `backend/agents/internal/dataset` | domaine | avis 3.3 Android et extraits de l'acte 2 dans `dataset.json` ; `PlatformChecklist(version, platform)` ; `Comparison` (écarts calculés, jamais stockés) |
| Go agents | `backend/agents/internal/kit` | noyau | `Intent` + `ParseIntent` (remplace `InScope`) ; `SurfaceMessages` : mutation = `updateDataModel` seul si la surface est active (D1) |
| Go agents | `internal/{quality,voice,delivery}` | composeurs + `profile.json` | un composeur par agent : vue globale (acte 1), vue plateforme, vue comparaison ; tags communs `android`, `ios`, `compare`, `comparer`, `comparaison`, `3.3` (génériques : les trois agents sont retenus) |
| Go orchestrateur | `backend/orchestrator/internal/app/{a2ui,orchestrate}`, `bootstrap` | application | **registre de canevas partagé** entre sessions (pdr-0058) ; `ResetCanvas` sans session ouverte ; métadonnée `genesis/activeSurfaces` lue sur le registre partagé |
| Flutter | `packages/entities/catalog`, `packages/features/canvas` | modèle / ui | `GenesisContract` (`comparison`) ; `KeyIndicator`, `ReviewSentiment` : ligne de comparaison ; `TrendChart` : légende et deux séries ; `ReleaseChecklist` : inchangée sauf valeurs ; état neutre si `comparison` incomplet |
| Flutter | `testing/backend_fakes`, `apps/genesis_canvas/test/acceptance/` | tests | faux backend : émission de l'acte 2 depuis les fixtures ; S-02, B1 (côté app), B2, B4 |

## Contrats
- **Messages** (A2UI v0.9, catalogue `genesis` v1, `catalogId` inchangé : champs ajoutés facultatifs, pdr-0055) : acte 2 = pour chaque surface active, un `updateDataModel {surfaceId, path:"/<surface>", value:<objet entier>}`. Aucun `createSurface`, aucun `deleteSurface`, aucun `updateComponents` (D1).
- **Data models de l'acte 2** (valeurs : `product/functional/dataset.md`, § Acte 2) :
  - `/kpi` : `label` « Sessions sans crash · Android », `value` « 99,43 % », `trend` « −0,54 pt », `threshold` « ≥ 99,50 % », `status: blocking`, `statusLabel`, `comparison {label:"3.3", value:"99,71 %", delta:"−0,28 pt"}`.
  - `/trend` : `series` [« Android 3.4 », « Android 3.3 »], 7 points chacune ; `thresholdPct` 0,5 ; `yMaxPct` 1,0.
  - `/reviews` : Android 3.4 (792 avis, 30 % négatifs, 70 % positifs, 3,7, 3 extraits de l'acte 2) + `comparison {label:"3.3", value:"14 % négatifs", delta:"+16 pts"}`.
  - `/checklist` : 3 critères Android (« 99,43 % (3.3 : 99,71 %) » bloquant ; « 30 % (3.3 : 14 %) » bloquant ; « 37 PR » validé), `recommendation {level:"blocking", label:"NO-GO Android"}`, `decisionStatus` « En attente de décision ».
- **Grammaire d'une demande d'agent** (`kit.Intent`) : `{Version:"3.4", Platform:""|"android"|"ios", CompareTo:""|"3.3"}`. Règles : une seule plateforme ; `CompareTo` exige `Platform == android` ; version autre que 3.4 (ou 3.3 hors comparaison) → `ErrOutOfScope` → état A2A `rejected`. Un agent retenu qui ne peut pas servir l'intention refuse ; l'orchestrateur ne change pas.
- **Registre partagé** : une seule instance de `a2ui.Registry` possédée par la fabrique de pipelines, injectée dans chaque `Pipeline` ; durée de vie = celle du processus (la démo). Les `taskID` A2A sont uniques, donc sans collision. `Pipeline.Close` ne vide plus le registre (la session ne porte que la conversation). `POST /canvas/reset` : si aucune session n'est ouverte, il vide le registre (204) ; sinon comportement 007 (409 pendant une délégation, `deleteSurface` publiés dans la session ouverte).
- **Configuration injectée** : aucune nouvelle valeur codée en dur (version cible, plateformes connues et version de comparaison lues du jeu de données).
- **Flutter** : aucun nouveau Bloc ; `CanvasBloc` et `CanvasBoard` reçoivent déjà `updateDataModel` sur une surface active (trois temps de 007) ; le travail est de rendu (`comparison`, séries) et de preuve (identité de rendu conservée).

## Références
- `product/architecture/agents-protocols.md` § Acte 2 ; `app-channel-contract.md` ; `backend.md` ; `frontend-screen.md`.
- Notes `knowledge/` : [genui-data-model] (écrire le chemin entier), [genui-custom-catalog-item] (`BoundObject`), [genui-a2ui-messages], [proto-a2a-agent-card], [proto-a2a-task-lifecycle].
- Décisions : pdr-0058 (registre), pdr-0024 / pdr-0059 (Android seul, pas de suppression), pdr-0064.

## Risques
- **Registre partagé et concurrence entre sessions** (une session se ferme pendant que la suivante s'ouvre) : le verrou du registre est interne, mais le comptage atomique « surface créée / limite » et la compensation d'une tâche vivent aujourd'hui sous `Pipeline.mu` d'une session → à faire relire par l'architecte (mode PLAN) ; test sous `-race` avec deux sessions.
- **Fuite entre démos** : le canevas survit jusqu'à la remise à vide. Parade : `POST /canvas/reset` (007) ; consigne de régie au démarrage de l'app (l'app vide, le registre non).
- **Surface connue du registre mais absente de l'app** (app relancée, backend actif) : une mutation viserait une surface que l'app ne connaît pas (`unknown_surface`, en attente 1 min côté moteur genui). Parade : consigne de régie ; la revue du plan dira si l'app doit remettre à vide à la connexion (changement de mise en scène : porteur).
- **Demande vocale sans plateforme** (« compare avec la 3.3 » seul) : refus honnête (D3). Hypothèse non confirmée ; à observer à l'essai réel.
- **Garde `InScope` existante** : son remplacement par `ParseIntent` ne doit pas affaiblir les refus de l'acte 1 (versions, mesures « 99,5 % »). Parade : reprendre tous les cas du test de `InScope` en cas de table de `ParseIntent`.
- **Rendu** : la courbe à deux séries et la ligne de comparaison doivent tenir à 24 px en 1920 × 1080 sans débordement (NFR-05). Parade : test de page à 1920 × 1080 et capture `app-smoke`.
- **Statut `blocking`** : la couleur de la checklist et du KPI vient des codes `ok|risk|blocking` (RG-09), jamais du libellé ; le test de contraste couvre les paires `blocking`.
