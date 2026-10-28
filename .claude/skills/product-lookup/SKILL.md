---
name: product-lookup
description: Consulte la documentation produit product/ de Genesis Canvas (Release Copilot) AVANT toute tâche qui touche le produit. À utiliser au début de chaque tâche de code, de plan, de revue ou de question portant sur le fonctionnel (vision, personas, périmètre, exigences FR-xx/NFR-xx, règles RG-xx, écran en 6 zones, orbe, barge-in, catalogue de composants, jeu de données, maquettes, scénarios Gherkin), sur la roadmap (jalons, backlog, spikes, questions ouvertes Q-xx, après le talk), sur l'architecture du produit (front Flutter desktop, backend Go, agents A2A, A2UI/GenUI, rejeu, sécurité, qualité, machine de scène) ou sur une décision produit (pdr-*). À combiner avec kb-lookup pour les faits techniques réutilisables.
---

# product-lookup

Objectif : trouver les documents produit pertinents en lisant le moins de fichiers possible, vérifier les décisions et questions ouvertes liées, puis agir en citant les ids.

## Étapes

1. **Router.** Lire `product/index.yaml`.
   - Si la tâche correspond à une entrée de `tasks`, prendre ses `docs` (et ses ids `knowledge`).
   - Sinon, choisir 1 à 3 zones (`functional`, `architecture`, `roadmap`, `decisions`) selon leurs `keywords`.
2. **Sélectionner.** Lire le `index.yaml` de chaque zone retenue et garder les documents dont le `summary` ou les `tags` correspondent. Viser 2 à 6 documents.
3. **Chercher par identifiant ou par texte** si l'index ne suffit pas :
   - exigence, règle ou question : `grep -rn "FR-07\|NFR-02\|RG-03\|Q-04" product --include=*.md --include=*.feature`
   - scénarios d'une exigence : `grep -rn "@FR-07" product/functional/features`
   - texte libre : `grep -ril "<terme>" product --include=*.md | head`
4. **Lire les décisions AVANT tout choix.** Lire `product/decisions/index.yaml`, y compris la section `inherited` (ADR génériques de `knowledge/decisions/` qui s'appliquent au produit). Ouvrir les PDR concernées.
   - `acceptée` : contrainte à respecter.
   - `proposée` : pas encore une contrainte ; le signaler et ne pas la présenter comme acquise.
   - `remplacée par …` / `abandonnée` : suivre le remplaçant, ignorer l'ancienne.
5. **Vérifier les questions ouvertes** liées dans `product/roadmap/open-questions.md` (`Q-xx`). Une question ouverte n'est **jamais** tranchée par l'agent : présenter les options et la laisser au porteur.
6. **Faits techniques** : suivre les ids `knowledge` cités (`rt-*`, `genui-*`, `ma-*`, `adr-*`…) avec le skill `kb-lookup`. `product/` décrit le produit ; `knowledge/` porte les faits vérifiés.
7. **Évaluer la fiabilité** grâce au `status` :
   - `validated` : repris de la fiche produit validée par le porteur ;
   - `draft` : synthèse de l'assistant, à relire ;
   - `proposed` : en attente de décision ;
   - `superseded` : historique seulement.
   Les passages « ⚠️ Hypothèse non confirmée » ne sont pas des faits.
8. **Agir en citant** les ids, par exemple : « D'après [p-fn-screen] et [pdr-0008-single-screen-show-the-making], … ; question ouverte Q-03. »
9. **Combler les trous.** Si une information produit manque, est fausse ou contradictoire, la noter. En fin de tâche, utiliser `product-curate` pour la documenter, ou `product-decide` si une décision a été prise par le porteur.

## Garde-fous
- Ne pas charger tout `product/` d'un coup : passer par les index.
- Ne pas confondre les sources : la fiche (`product/sources/product-description.pdf`) prime pour le fonctionnel validé ; les écarts avec les maquettes restent ouverts (voir `Q-xx`).
- Ne rien inventer qui ne soit pas dans une source, une PDR ou une note `knowledge/`.
