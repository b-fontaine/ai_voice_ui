# 006 — Plan technique

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
