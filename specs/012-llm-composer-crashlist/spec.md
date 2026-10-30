# 012 — Compositeur LLM puis CrashList réel

**Backlog** : EP-03, EP-04, EP-09 (corrections après J6). **Jalon** : avant J7 (ordre du porteur : 011 → 012 → 013 → J7).
**Décisions** : [pdr-0070](../../product/decisions/pdr-0070-llm-composer-and-crashlist-012.md) (fonctionnalité), [pdr-0060](../../product/decisions/pdr-0060-small-openai-text-model-guided-a2ui.md) et [pdr-0023](../../product/decisions/pdr-0023-example-guided-composition.md) (composition par modèle guidé par exemples, repli), [pdr-0036](../../product/decisions/pdr-0036-real-a2a-agents-produce-a2ui.md) (les agents produisent l'A2UI), [pdr-0014](../../product/decisions/pdr-0014-six-component-catalog.md) (catalogue à six composants), [pdr-0074](../../product/decisions/pdr-0074-012-llm-composer-gateway-crashlist-details.md) (mécanisme).
**Sources** : [diagnostic de l'essai au micro](../../product/decisions/_archive/2026-10-30-essai-micro-diagnostic.md) (sections « crashlist » et « pdr-0060 »).

## Objectif
Faire composer l'écran par un petit modèle texte OpenAI guidé par les écrans d'exemple (jamais construit jusqu'ici : la composition est déterministe), avec mesure de latence et repli déterministe (012-a) ; rendre le composant `CrashList` réel de bout en bout et l'afficher quand le speaker le demande (012-b). Une demande de vue que le catalogue ne sait pas produire reçoit un refus honnête au lieu d'une réponse à côté.

## Périmètre
1. **Passerelle LLM interne** (pdr-0074 D1) : port `out.LlmText`, adaptateur OpenAI texte, écouteur interne joignable des seuls agents, bornes (modèle, jetons, taille, délai, débit), compose et `check-compose.sh`.
2. **Compositeur LLM des agents** (D2, D3, D4) : plan de composition structuré validé, data models construits depuis le jeu de données, écrans d'exemple dans le prompt, repli déterministe avec motif fermé journalisé, modèle et délais par configuration. Qualité, Voix du client et Livraison (demandes vocales ; l'acte 3 reste déterministe).
3. **Mesure** (D4, D8) : p50/p90 de latence, validité des plans et coût sur un jeu court de demandes ; choix de `COMPOSER_MODEL` consigné dans `knowledge/` ; squelette anticipé seulement si NFR-02 échoue.
4. **CrashList réel** (D5) : données `crashes` dans le jeu figé, schéma du catalogue (`components` à 6), fixtures et négatives, `Intent.View` + filtre de plateforme, widget Flutter à trois états, cinquième cellule de la grille, étagère « utilisée ».
5. **Refus honnête** (D6, D7) : `ScopeError` `view_unavailable`, tags du planificateur, consignes vocales (la liste des crashs existe ; une vue inconnue est refusée avec une alternative).
6. **Documentation** à la clôture : corriger [pdr-0014](../../product/decisions/pdr-0014-six-component-catalog.md) / `catalog.md` (hypothèse « données à écrire » périmée, « jamais utilisé » devenu faux), `backend.md` (état réel de pdr-0060).

## Hors périmètre
- Choix de l'agent par le modèle (le `TagPlanner` reste, D7) ; modèle pour l'orchestrateur ou la voix (GPT-Live reste le seul modèle vocal).
- Valeurs rédigées par le modèle, texte libre, couleurs ou tailles (RG-09 : thème de scène).
- Design et ergonomie de la liste (013) ; durcissement (J7).
- Les actions de l'interface (acte 3) : composition déterministe, comme avant.

## Scénarios d'acceptation (à automatiser)
Nouveaux, ajoutés à `product/functional/features/` à la clôture (pdr-0062 pour l'écart) :
- **C-01** (Go, agents, passerelle simulée) « Prépare la release 3.4 » avec un plan valide donne les mêmes surfaces et les mêmes data models que la composition déterministe (NFR-08).
- **C-02** (Go) plan invalide (composant hors profil, paramètre hors liste, JSON cassé, plan vide) → repli déterministe, un seul appel, motif fermé journalisé.
- **C-03** (Go) délai de la passerelle dépassé → repli avant `COMPOSER_TIMEOUT` + marge ; erreur HTTP et plafond de débit idem.
- **C-04** (Go) « Affiche la liste des crashs » → surface `crashes` (`createSurface`, `updateComponents`, `updateDataModel`) dont `/crashes` égale le top 5 du jeu ; « … sur Android » filtre par plateforme.
- **C-05** (Go) même demande, passerelle indisponible : le repli déterministe produit la même surface (la démo tient sans modèle).
- **C-06** (Go) demande de vue inconnue → `rejected` de motif `view_unavailable`, aucun résumé d'une autre vue.
- **C-07** (Go, orchestrateur) la passerelle refuse : corps trop grand, schéma absent, méthode ou chemin inconnus, dépassement de débit, requête hors réseau interne ; aucune clé ni contenu dans les journaux ; `check-compose.sh` rouge si un agent reçoit la clé ou un port publié.
- **C-08** (Go, bout en bout simulé) voix « Affiche la liste des crashs » → plan `[Qualité]` → message `crashes` relayé et validé par la liste blanche à 6 composants.
- **F-01** (Flutter) `crashes` arrive : cinquième cellule de la grille 3×2, les cellules existantes gardent position et `State`, l'étagère montre CrashList « utilisée ».
- **F-02** (Flutter) CrashList en squelette, sans données et en état neutre (champ de mauvais type, ligne incomplète) ; texte ≥ 24 px, aucune troncature.

## Critères d'acceptation
- [ ] Scénarios C-01 à C-08 et F-01, F-02 automatisés et verts
- [ ] Tests unitaires des unités nouvelles ; parité Go/Dart du contrat (fixtures positives et négatives)
- [ ] `tools/loop/gate.sh --full` vert
- [ ] Revue d'architecte : CONFORME (ou refactorisations appliquées)
- [ ] Mesure consignée : p50/p90, taux de plans valides, coût ; `COMPOSER_MODEL` fixé ou repli définitif déclaré (pdr-0060)
- [ ] Un essai réel unique sous budget (`openai-budget.sh`) : « Affiche la liste des crashs » choisit CrashList par le modèle

## Questions ouvertes
Aucune bloquante. Hypothèse non confirmée héritée de pdr-0060 : un petit modèle texte tient NFR-02 et NFR-03 (objet de la mesure ; repli sinon).
