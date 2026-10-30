# 006 — J3-A : acte 1 côté backend (catalogue `genesis`, trois agents, quatre surfaces)

> **En bref.** Quand le speaker dit « Prépare la release 3.4 », l'orchestrateur sollicite **en parallèle** les trois agents A2A réels (Qualité, Voix du client, Livraison) ; chacun produit l'A2UI v0.9 de ses surfaces avec le **catalogue fermé `genesis`** : Indicateur clé, Courbe de tendance, Sentiment des avis, Checklist go/no-go (4 surfaces, pdr-0020), à partir du jeu de données figé. L'orchestrateur **choisit** les agents utiles à la demande (pdr-0013) ; une demande qui sort du catalogue est refusée à la voix, avec une alternative (RG-08). Première des deux moitiés de J3 ; la moitié Flutter (catalogue côté client, étagère, rail complet, panneau protocole, remise à vide) est la fonctionnalité suivante (007).

- **Jalon** : J3 « Acte 1 Créer » (`product/roadmap/roadmap.md`), backlog EP-03 (agents Voix du client et Livraison), EP-04 (côté contrat du catalogue), EP-09 (jeu de données).
- **Exigences visées** : FR-03 et FR-04 (côté données : activité des agents, surface en trois temps), RG-02 (squelette → composants → données), RG-04, RG-07, RG-08, RG-10 (données incomplètes : état neutre), NFR-02/NFR-03 (instrumentation par le journal, mesure indicative), NFR-06 (≤ 6 surfaces), NFR-08 (jeu de données figé, seule la composition varie).
- **Décisions applicables** : pdr-0005, pdr-0007, pdr-0013, pdr-0014, pdr-0015, pdr-0017, pdr-0018, pdr-0019, pdr-0020, pdr-0021, pdr-0023, pdr-0036, pdr-0037, pdr-0040, adr-0003-backend-go.
- **Hors périmètre** : tout le code Flutter (007) ; LLM de composition (Q-17 ouverte : les agents composent de façon déterministe derrière le port `Composer`, comme en 004) ; mutation en place (J4) ; actions et Barre d'actions (J5) ; Liste des crashs (dans le catalogue, hors scénario principal) ; annulation « Stop » (J7).

## Scénarios (Gherkin)
Le scénario de la fiche « Acte 1 » (`product/functional/features/voice-screen-generation.feature`, S-01) est automatisé côté Flutter par 007. Ici, des tests d'acceptation Go (build tag `acceptance`, Live simulé), avec les **vrais** binaires d'agent, compilés et lancés par le test :
- **G1 — acte 1 en parallèle** : après `delegation.created` (« Prépare la release 3.4 »), l'app-channel reçoit `agent.activity working` des trois agents, quatre `createSurface` (`kpi`, `trend`, `reviews`, `checklist`) avant tout `updateDataModel` de la même surface, puis les données, puis `agent.activity completed` ×3 ; chaque message `a2ui` est attribué à son agent ; le catalogue des quatre surfaces est le `catalogId` configuré ; la voix reçoit un commentaire générique immédiat puis un commentaire fondé sur les vrais résultats (contient « 99,57 % » et « 24 % »).
- **G2 — refus hors catalogue (RG-07, RG-08)** : « Fais-moi un camembert des ventes » → l'orchestrateur ne retient aucun agent (`plan` vide journalisé), aucun appel d'agent, aucun `createSurface`, la voix dit qu'elle ne peut pas et **propose une alternative** (indicateurs, courbes, avis, checklist). **G2bis** : un agent retenu qui refuse passe en `rejected`, jamais `failed`.
- **G3 — un agent échoue** : l'agent Livraison est injoignable → les trois autres surfaces restent affichées, `agent.activity failed` pour Livraison, aucune surface `checklist` inventée, le commentaire vocal est honnête ; la session reste ouverte (retrait provisoire des seules surfaces de l'agent en échec, Q-69).
- **G4 — agents (module `backend/agents`, un binaire par agent)** : chacun des trois agents publie sa carte, répond en flux (`submitted` → messages A2UI v0.9 → artefact texte → `completed`) et refuse une demande qui n'est pas la sienne ou qui sort de la 3.4 sans comparaison (« pas supporté en J3 »).
- **G5 — jeu de données** : les valeurs de `product/functional/dataset.md` (99,57 % ; 99,80 % ; 99,43 % ; 1 164 avis ; 24 % ; 37 PR ; statuts « à risque » ×2 et « validé » ; recommandation À RISQUE) sont recalculées à partir des lignes brutes (test unitaire de cohérence, pas seulement acceptation).

## Critères d'acceptation
- [ ] G1 à G4 automatisés et verts ; G5 vert en test unitaire
- [ ] Tests unitaires de chaque unité nouvelle (module `dataset`, composeurs, portées des agents, configuration, phrases)
- [ ] `tools/loop/gate.sh --full` vert (tous modules Go compris)
- [ ] Revue d'architecte : CONFORME (ou refactorisations appliquées)
- [ ] Délais lus dans le journal : `delegation.created` → 1er `createSurface` (NFR-02) et → 4ᵉ `updateDataModel` (NFR-03), indicatifs
- [ ] `docker compose config` valide (`backend/check-compose.sh`) avec les trois services d'agent ; essai réel unique du modèle vocal si le budget le permet (`openai-budget.sh check`)

## Questions ouvertes
Aucune ne bloque cette fonctionnalité ; ce qui en dépend est reporté.
- **Q-44** (`catalogId` définitif) : l'identifiant reste un **paramètre** (`A2UI_CATALOG_ID`) ; valeur par défaut **provisoire** du compose : `https://genesis-canvas.example/a2ui/catalogs/genesis/v1` (convention [genui-catalog-ids]). Changer la valeur ne touche aucun code.
- **Q-17** (LLM de composition) : composition déterministe en J3-A ; le port `Composer` ne change pas.
- **Q-35** (libellés du statut global) : les statuts des **critères** suivent la fiche § 7 (`dataset.md`) ; les libellés du statut global (« En attente de décision », « À RISQUE ») sont un ⚠️ hypothèse du jeu de données, injectée comme données (`status`, `recommendation`), jamais en dur côté client.
- **Q-69** (surface partielle d'un agent en échec) : comportement provisoire de 004 conservé (retrait).
- **Q-71**, **Q-22**, **Q-30**, **Q-31** : concernent le client et l'écran (007).
