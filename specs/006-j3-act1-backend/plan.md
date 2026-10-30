# 006 — Plan technique

> **Revue du plan (2026-10-30, architect-reviewer mode PLAN) : À AMENDER** (1 bloquant, 6 importants, mineurs). Les amendements A1-A8 ci-dessous sont intégrés et **priment** sur toute formulation antérieure contradictoire de ce plan (en particulier : « aucun changement de pipeline attendu » et « portée par mots-clés côté agent » sont **faux** ; `ActionBar` et `CrashList` ne sont plus dans la liste blanche J3).

## Amendements de la revue
- **A1 [bloquant] — l'orchestrateur choisit les agents** (pdr-0013, RG-29, `backend.md` règle 1). Constat vérifié : `pipeline.go:204-217` lance tous les agents ; un refus (`executor.go` : `submitted` puis `rejected`) devient `working` puis `failed`.
  - `port.AgentCard` gagne `Tags []string` (union des `skills[].tags` de la carte A2A). La carte est lue **une fois** par délégation, avant la planification, et réutilisée par `Send`.
  - Port `orchestrate.Planner` : `Plan(request string, cards []port.AgentCard) []int`. Implémentation déterministe `TagPlanner` (minuscules, 1 000 runes, **mots entiers**) ; un LLM pourra la remplacer derrière le même port (Q-17).
  - Les mots déclencheurs vivent dans un **profil JSON embarqué par agent** (alimente `skills[].tags` et `examples` de sa carte), jamais dans l'orchestrateur. Les agents ne portent **plus** de portée par mots-clés ; ils gardent un refus défensif (version ≠ 3.4, comparaison, plateforme : acte 2 = J4).
  - Message `plan {delegation, selected[], idle[]}` sur l'app-channel et dans le journal (pdr-0013 : trace des agents choisis et non choisis ; 007 en a besoin pour le rail). Un agent non retenu ne reçoit **aucun** `agent.activity`.
  - Aucun agent retenu : aucun appel, la voix dit la nouvelle phrase `out_of_catalog` (RG-08, avec alternative). Carte injoignable : l'agent compte comme retenu et passe en `failed` « injoignable » (G3 reste vrai). Agent retenu qui refuse (`AgentRejected`) : nouvel état `agent.activity rejected`, détail fermé « hors périmètre », ni `failed` ni compensation ; `allRejected` se calcule sur les seuls agents retenus ; phrase `failure_rejected`, distincte de `out_of_catalog`.
- **A2 [importante] — mémoire de composition** : le registre de l'orchestrateur devient la source de vérité. `port.AgentRequest` gagne `ActiveSurfaces []string` (surfaces actives de cet agent, lues sous le verrou), transmises dans les `metadata` du message A2A (clé `genesis/activeSurfaces`, `[]any` de chaînes). Le composeur n'émet `createSurface` que pour une surface qu'il produit et qui manque à cette liste. Suppression de `compose.Rememberer`, `MaxContexts`, `renewals`, `contextFor` ; `ContextID` redevient l'id de session. Table « demande → surfaces produites » par agent dans les tests.
- **A3 [importante] — contrat exécutable** : fixtures **avant le code** dans `contracts/a2ui/genesis/v1/` (`catalog.json` : noms, propriétés admises, forme de `data` ; `examples/act1-{kpi,trend,reviews,checklist}.jsonl` : les trois temps ; ce sont aussi les « exemples d'écrans » de pdr-0023). Utilisées par les tests des agents (comparaison exacte, `catalogId` remplacé), par un test de l'orchestrateur (chaque exemple passe le validateur configuré comme dans le compose) et par 007. Corrections du contrat :
  - (a) `status` = code fermé `ok|risk|blocking` + `statusLabel` ; checklist : `items[].level`, `recommendation {level, label}`, `decisionStatus` (libellé de Q-35, donné) ; aucune couleur côté client ne dépend d'un libellé français (RG-09).
  - (b) `points` = nombres JSON en pourcentage (`0.22`), plus `thresholdPct: 0.5` et `yMaxPct: 1.0`.
  - (c) champs facultatifs réservés pour l'acte 2 (`comparison {label, value, delta}` pour le KPI et les avis, tolérés par le client) : FR-07 sera un `updateDataModel` du **chemin entier** (jamais un sous-chemin : genui 0.10 lève sur une écriture à travers une valeur non map/liste [genui-data-model]).
  - (d) `sendDataModel: false`.
  - (e) le backend ne garantit que l'**ordre** des messages ; rendre le squelette visible (RG-02) est à 007 (durée minimale côté client) ; jamais de pause ajoutée dans un agent.
- **A4 [importante] — validateur** : `a2ui.Options.AllowedProps []string` et `BindingProps []string`, injectés par configuration (vides : rien n'est contrôlé, tests de 004 intacts). Pour `genesis` : seules `id`, `component`, `data` ; `data` = `{path: <JSON Pointer>}` ; nouveau code `bad_property`. **Liste blanche J3 = les 4 composants qui ont un schéma** (`KeyIndicator`, `TrendChart`, `ReviewSentiment`, `ReleaseChecklist`) ; `ActionBar` en J5, `CrashList` avec sa fonctionnalité.
- **A5 [importante] — tâches** : voir `tasks.md` (déplacement pur d'abord, puis Gherkin ; kit générique séparé ; ajouts T06, T15a-c). Test d'architecture en Go dans le module (`go list -deps ./cmd/agent-*`), pas dans la porte de qualité ; port d'écoute par défaut distinct par binaire (8090, 8091, 8092).
- **A6 [importante] — échec partiel honnête** : phrase JSON `partial_failure` (un seul `%s` : noms des agents en échec, nettoyés), ajoutée après le résultat ; un agent `rejected` n'est pas mentionné. Chaque résumé d'agent ≤ 200 runes, chiffres en tête (limite = 600 / agents retenus).
- **A7 [importante] — bout en bout avec les vrais agents** : G1-G3 (tag `acceptance`) : `TestMain` compile `../agents/cmd/agent-*` (`go build`, `cmd.Dir`) dans un dossier temporaire, lance chaque binaire (`AGENT_LISTEN_ADDR=127.0.0.1:<port libre>`, `AGENT_PUBLIC_URL`, `A2UI_CATALOG_ID` de test), attend `healthcheck`, arrête au nettoyage. G3 : Livraison n'est pas lancé (port fermé). Les faux agents restent pour les scénarios B de 004. **Instructions vocales v1** (pdr-0037) : `voice-instructions.fr.md` délègue toute demande d'affichage, de graphique ou d'écran, même hors sujet ; le modèle ne refuse jamais lui-même (à vérifier à l'essai réel).
- **A8 [mineure]** : (a) latence = `delegation` → 4ᵉ `updateDataModel` (NFR-03) et → 1er `createSurface` (NFR-02) ; (b) mots entiers (`go` trop court, « tableau » et « notes » trop larges), « Où en est la 3.4 ? » mène à l'acte 1, table de paraphrases dans le profil ; (c) statuts calculés sur les valeurs non arrondies, arrondi au formatage seulement, `FormatPct(v, décimales)` explicite (99,57 % mais 24 %), tests de bord à 0,10 pt et 2 pts ; (d) Dockerfile `ARG AGENT` sans défaut + `RUN test -n "$AGENT"`, binaire `/agent`, healthcheck `/agent healthcheck` ; (e) `check-compose.sh` boucle sur tous les `agent-*` (aucun port publié, réseau `agents` seul, ancre de catalogue identique, `depends_on` `service_healthy`, `AGENTS` à trois cartes, `A2UI_COMPONENTS` par défaut = fixture) ; (f) le rejet de `Column` dans le catalogue `genesis` est un test de **configuration** (bootstrap ou `check-compose.sh`), pas du validateur.
- **Contrat app-channel étendu dès maintenant** (007 le consomme) : type `plan`, état `agent.activity rejected`, détail « hors périmètre » ; à écrire dans `product/architecture/app-channel-contract.md` au plus tard à la clôture de 006 (ligne 37 : `state` ∈ working/completed/failed).
- **Conflits avec une décision, remontés au porteur** (pas de refactorisation) : pdr-0023 (LLM guidé par exemples) contre la composition déterministe provisoire (Q-17 ouverte ; les fixtures de A3 préparent le passage au LLM) ; remise à vide (007) : recommandation = fermer la session voix (pdr-0052), à confirmer ; sinon le hub rejoue les surfaces et la demande suivante envoie des mises à jour sans `createSurface` (lié à Q-70).

## Où
| Pile | Module | Couche | Contenu |
|---|---|---|---|
| Go | `backend/agents` (le module `backend/agents/quality` y est **fusionné**, `git mv`, chemin de module `…/backend/agents`) | domaine / application / adaptateurs | `internal/kit` (serveur A2A, exécuteur, env, durcissement : repris de `quality/internal/agent`, rendus génériques par une `Skill` + un `Composer`), `internal/dataset` (jeu brut + calculs : sans-crash, séries, avis, checklist), `internal/quality`, `internal/voice`, `internal/delivery` (composeurs + portée de chaque agent), `cmd/agent-quality`, `cmd/agent-voice`, `cmd/agent-delivery` |
| Go | `backend/orchestrator` | application / bootstrap | liste blanche `A2UI_COMPONENTS` = les 6 noms du catalogue ; phrases (`failure_rejected` avec alternative, RG-08) ; aucun changement de pipeline attendu (déjà N agents en parallèle) — à confirmer par G1/G3 |
| Infra | racine | — | `docker-compose.yaml` : `agent-voice`, `agent-delivery` ; `AGENTS` à trois cartes ; `A2UI_COMPONENTS` ; `A2UI_CATALOG_ID` provisoire (Q-44) ; Dockerfile unique paramétré (`ARG AGENT`) ; `backend/check-compose.sh` et CI (matrice : un module de moins ou autant) |
| Docs | `product/` | — | Au Clôture seulement : contrat du catalogue `genesis` (`architecture/app-channel-contract.md` § Catalogue), `backend.md`, `dataset.md` (valeurs recalculées), `roadmap/backlog.md`, `specs/progress.md` |

## Contrats
### Catalogue fermé `genesis` (nom des types A2UI : conception de l'assistant, pdr-0017 : jamais calqués sur les maquettes)
Six types, tous **plats** (une surface = un composant racine `root` qui porte ses données par liaison de chemin, sans `Column` ni `Text` intermédiaire) ; couleurs et tailles viennent du thème de scène, jamais des messages (RG-09). Chaque composant a un **état squelette** (RG-02) quand son chemin n'est pas encore résolu et un **état neutre** si les données sont incomplètes (RG-10) — côté client (007).

| Type | Surface (id) | Agent | Liaison | Forme de `/<surface>` dans le data model |
|---|---|---|---|---|
| `KeyIndicator` | `kpi` | Qualité | `data: {path: "/kpi"}` | `{label, value, trend, threshold, status}` (chaînes déjà formatées à la française : « 99,57 % », « −0,36 pt », « ≥ 99,50 % » ; `status` ∈ validé / à risque / bloquant) |
| `TrendChart` | `trend` | Qualité | `data: {path: "/trend"}` | `{title, thresholdPct, days:["J1".."J7"], series:[{name, points:[0,22,…]}]}` (taux de crash du jour en %, nombres JSON) |
| `ReviewSentiment` | `reviews` | Voix du client | `data: {path: "/reviews"}` | `{title, count, positivePct, negativePct, average, excerpts:[{stars, platform, text}×3]}` |
| `ReleaseChecklist` | `checklist` | Livraison | `data: {path: "/checklist"}` | `{title, items:[{label, threshold, value, status}], recommendation, status}` |
| `ActionBar` | — (J5) | Livraison | — | schéma défini en J5 |
| `CrashList` | — (hors scénario) | Qualité | — | schéma défini avec sa fonctionnalité |

- Ordre de messages par surface (RG-02, trois temps) : `createSurface` → `updateComponents` (le composant, `data` lié, **donnée absente** donc squelette) → `updateDataModel` (le chemin complet) ; sur contexte déjà connu, pas de nouveau `createSurface` (mémoire par contexte, comme en 004).
- Un `updateDataModel` par surface, chemin racine de la surface (jamais de chemin partiel en J3).
- La limite « 6 » porte sur les **surfaces** (pdr-0019) ; l'acte 1 en ouvre 4.

### Portée de chaque agent (déterministe, testée en table ; refuse ce qui n'est pas à lui avec `AgentRejected`)
Une demande est lue en minuscules, tronquée à 1 000 runes, comme en 004. Mots déclencheurs (français, jamais d'identifiant de maquette) :
- *release / prépare / version 3.4 / tableau* → les trois agents répondent ;
- *crash / stabilité / sessions / tendance / courbe* → Qualité seule ; *avis / notes / sentiment / store* → Voix du client seule ; *checklist / go / no-go / décision* → Livraison seule ;
- une autre version que la 3.4, une comparaison ou une plateforme précise → refus (acte 2 = J4) ;
- tout le reste (« camembert », « ventes », « météo »…) → refus des trois agents → **RG-08** : phrase `failure_rejected` redite avec alternative (JSON, jamais en dur).
- Tout refus est un `AgentRejected` côté orchestrateur (déjà géré en 004) ; un refus partiel (une partie des agents seulement) n'est pas un échec du plan.

### Jeu de données (`internal/dataset`)
- Lignes brutes embarquées (`go:embed`), aucune valeur dérivée stockée : sessions et crashs par jour / plateforme / version (existant), **avis** (comptes 1★…5★ par plateforme et version, 3 extraits par acte), **changelog** (PR par type, total 37).
- Calculs purs et testés contre `product/functional/dataset.md` : sans-crash pondéré, tendance J1→J7, séries quotidiennes, répartition positifs/négatifs, statuts de critère (marges 0,10 pt et 2 pts), recommandation (GO / À RISQUE / NO-GO).
- Formatage à la française centralisé (`FormatPct`, `FormatMargin`, `FormatPt`).

### Orchestrateur
- `A2UI_COMPONENTS=KeyIndicator,TrendChart,ReviewSentiment,ReleaseChecklist,ActionBar,CrashList` ; le validateur refuse tout autre type (`Column`/`Text` de 004 ne sont **plus** autorisés dans l'environnement compose ; les tests de 004 gardent leurs listes propres).
- `AGENTS` : trois URL de carte ; `AGENT_TIMEOUT` inchangé ; commentaire final = `ResultTemplate` + résumés des trois agents (≤ 600 runes, nettoyés) : « 99,57 % » (Qualité) et « 24 % » (Voix du client) y figurent.
- Aucune phrase en dur (pdr-0009) : `phrases.fr.json` gagne l'alternative de `failure_rejected`.

### Configuration (jamais en dur)
`A2UI_CATALOG_ID` (Q-44, provisoire) ; `A2UI_COMPONENTS` ; `AGENTS` ; `AGENT_TIMEOUT` ; `AGENT_LISTEN_ADDR`, `AGENT_PUBLIC_URL` (existants) ; le profil d'agent est le binaire (`cmd/agent-*`), pas une variable.

## Références
- `product/architecture/backend.md` § Orchestrateur : règles de comportement ; `agents-protocols.md` ; `app-channel-contract.md`
- `product/functional/catalog.md`, `dataset.md`, `business-rules.md` (RG-02, RG-04, RG-07 à RG-10)
- Notes `knowledge/` : [genui-catalog-ids], [genui-a2ui-messages], [genui-a2ui-security], [genui-custom-catalog-item], [proto-a2a-task-lifecycle], [proto-a2a-agent-card], [ma-real-tool-results], [ma-filler-acknowledgements]
- 004 : `specs/004-j2-orchestrator-quality-agent/plan.md` (A2A natif v1.0, uniquement `map[string]any` / `[]any` dans les `parts`, validateur A2UI, retrait provisoire)

## Risques
- **Fusion des modules** (`quality` → `agents`) : régression silencieuse du durcissement HTTP → T10 est un déplacement pur, tests de 004 inchangés et verts avant toute nouveauté ; Dockerfile et `check-compose.sh` mis à jour dans la même tâche.
- **Une seule `go.mod` pour trois binaires** : couplage entre agents → ils ne s'importent jamais entre eux (`internal/quality`, `voice`, `delivery` ne dépendent que de `kit` et `dataset`) ; test d'architecture simple par `go list` dans `gate`.
- **Livraison calcule la checklist depuis les mêmes lignes brutes que Qualité et Voix du client** : pas d'appel agent → agent ; cohérence garantie par le module `dataset` partagé (test G5).
- **Latence** : agents déterministes → mesure triviale ; le vrai risque (Q-17, LLM) est reporté, le journal l'instrumente déjà.
- **Refus partiel** : un agent qui refuse alors que d'autres répondent ne doit pas fabriquer d'échec → test G1bis (« avis » seuls : une seule surface, aucun `failed`).
- **Valeur provisoire du `catalogId`** : changer Q-44 plus tard = variable d'environnement, aucun code.
