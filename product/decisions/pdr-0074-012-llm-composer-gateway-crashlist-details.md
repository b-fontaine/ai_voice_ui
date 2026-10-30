---
id: pdr-0074-012-llm-composer-gateway-crashlist-details
title: "PDR-0074 — 012 : passerelle LLM interne, plan de composition structuré, repli et CrashList"
area: decisions
status: validated
updated: 2026-10-30
sources: [specs/012-llm-composer-crashlist/spec.md, specs/012-llm-composer-crashlist/plan.md, product/decisions/_archive/2026-10-30-essai-micro-diagnostic.md]
links: [p-rm-open-questions, p-ar-backend, p-ar-security, p-ar-agents-protocols, p-ar-quality, p-fn-catalog, p-fn-dataset, p-fn-business-rules, pdr-0070-llm-composer-and-crashlist-012, pdr-0060-small-openai-text-model-guided-a2ui, pdr-0023-example-guided-composition, pdr-0036-real-a2a-agents-produce-a2ui, pdr-0014-six-component-catalog, pdr-0030-llm-budget-20-eur, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, rt-ephemeral-keys]
tags: [pdr, decision, llm, composition, crashlist, 012]
decision_status: acceptée
decided_on: 2026-10-30
decided_by: "Assistant (décision contrainte), sur délégation du porteur du 2026-10-29 ; détails d'interface sous pdr-0062"
constraint_basis: [pdr-0060-small-openai-text-model-guided-a2ui, pdr-0023-example-guided-composition, pdr-0036-real-a2a-agents-produce-a2ui, pdr-0005-frozen-fictional-dataset, p-ar-security]
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0074 — 012 : passerelle LLM interne, plan de composition structuré, repli et CrashList

> **En bref.** pdr-0060 et pdr-0070 fixent le résultat (un petit modèle texte OpenAI compose, repli déterministe, puis CrashList réel) ; ils sont muets sur le mécanisme. Les agents n'ont ni clé ni sortie réseau (sécurité) : l'appel au modèle passe donc par une **passerelle interne de l'orchestrateur**. Le modèle choisit les composants et leurs paramètres fermés ; les **valeurs viennent du jeu de données**. Aucune de ces décisions ne touche le périmètre, la mise en scène, le budget ni le fournisseur.

Part de l'assistant : décision contrainte (D1 à D4, D6) et détails sous pdr-0062 (D5, D7, D8), contestables par le porteur.

## Contexte
- pdr-0060 : un petit modèle texte OpenAI (même clé, même budget) compose derrière le port `Composer`, repli déterministe si NFR-02/03 échouent. pdr-0023 : « le LLM choisit les composants et leurs données ». pdr-0036 : ce sont les agents A2A qui produisent l'A2UI.
- Sécurité en vigueur ([p-ar-security](../architecture/security.md)) : agents sur le réseau compose `agents` (`internal: true`), sans `env_file`, sans clé OpenAI ; `check-compose.sh` le vérifie.
- RG-24 / NFR-08 / pdr-0005 : données fictives figées, « seule la composition varie ».
- Diagnostic de l'essai au micro : composition déterministe en 0 à 3 ms ; CrashList absent partout ; aucun motif de refus pour une vue inconnue.

## Options
1. Donner la clé et une sortie réseau aux agents : contredit la sécurité en vigueur.
2. **Passerelle LLM interne dans l'orchestrateur** (retenue) : seul détenteur de la clé, seul à sortir.
3. Faire composer par l'orchestrateur : contredit pdr-0036.

## Décision
| Id | Décision |
|---|---|
| **D1** | **Passerelle LLM interne.** Port `out.LlmText` de l'orchestrateur (déjà nommé dans [p-ar-backend](../architecture/backend.md)), adaptateur OpenAI texte, exposé aux agents par un **second écouteur HTTP joignable seulement depuis le réseau `agents`** (port non publié). Les agents restent sans clé ni `env_file`. La passerelle impose le modèle, un plafond de jetons de sortie, une taille maximale de requête, un délai et un plafond de débit (configuration) ; elle ne journalise ni clé ni contenu. |
| **D2** | **Rôle du modèle : un plan de composition structuré.** Sortie JSON à schéma imposé : liste ordonnée de surfaces `{surface, component, params}` (composants du profil de l'agent, paramètres de listes fermées : plateforme, comparaison, nombre d'éléments) ou un refus à motif fermé. Le modèle ne rédige **aucune valeur** : les data models sont construits par l'agent depuis le jeu de données (NFR-08, RG-24, « les résultats d'outils sont les vrais résultats »). Les écrans d'exemple (`contracts/a2ui/genesis/v1/examples/`) sont présentés au modèle sous forme de couples demande → plan. |
| **D3** | **Repli déterministe.** Toute erreur (délai `COMPOSER_TIMEOUT`, HTTP, JSON invalide, composant hors profil ou hors liste blanche, paramètre hors liste fermée, plan vide ou trop long, plafond de débit) bascule sur le composeur déterministe actuel, **sans second appel**, avec un motif fermé journalisé (`composer.fallback{reason}`) ; le repli est assumé devant le public (pdr-0060). Les demandes à action (acte 3) restent déterministes. |
| **D4** | **Modèle par configuration.** `COMPOSER_MODEL`, `COMPOSER_TIMEOUT`, `COMPOSER_MAX_OUTPUT_TOKENS`, `COMPOSER_RATE_*` : jamais codés en dur. Le choix du modèle est le **résultat d'une mesure courte** (T-mesure : p50/p90 de latence, validité des plans, coût) consignée dans `knowledge/` ; tant qu'elle n'est pas faite, `COMPOSER_MODEL` vide désactive le modèle et le repli s'applique. |
| **D5** | **CrashList réel.** Surface `crashes`, data model `/crashes` `{title, items[{rank, label, platform, volume, sessions}]}` recopié du tableau de [p-fn-dataset](../functional/dataset.md) (top 5 de la 3.4) ; filtre par plateforme (`Intent.Platform`) ; liste blanche `A2UI_COMPONENTS` à 6 composants ; widget à trois états (squelette, sans données, neutre) ; cinquième surface de la grille (3×2 déjà prévue pour 5 ou 6 surfaces). |
| **D6** | **Vue inconnue : refus honnête.** `kit.Intent` reçoit un champ fermé `View` ; une demande de vue qu'aucun composant du profil ne sait produire donne une `ScopeError` de motif `view_unavailable` (état A2A `rejected`, alternative proposée par le texte du profil), jamais le résumé d'une autre vue. |
| **D7** | **Planificateur inchangé.** `TagPlanner` garde le choix des agents par tags ; Qualité reçoit les tags « liste », « list », « top ». Le modèle ne choisit pas l'agent. |
| **D8** | **Anticipation du squelette conditionnelle.** Le squelette part avec la composition, après l'appel au modèle. Si la mesure donne un p90 du premier squelette > 1,5 s (NFR-02), la tâche conditionnelle T-skel émet d'abord le squelette de la composition déterministe. |

## Raisons
- D1 : seule voie qui ne relâche ni « agents sans clé ni sortie réseau » ni « composition par les agents » ; la clé reste dans un seul conteneur.
- D2 : seule voie compatible avec pdr-0023 (le modèle choisit composants et paramètres) et NFR-08 (valeurs figées) ; elle borne aussi la latence (sortie de quelques dizaines de jetons).
- D3 : exigé par pdr-0060 ; un seul essai évite de cumuler les délais.

## Options écartées
- Valeurs rédigées par le modèle (risque de chiffres faux, sortie longue, latence) ; modèle libre sans plan (pdr-0023).
- Écran « tuile » ou composant dédié « refus » pour la vue inconnue : le refus passe déjà par la voix (RG-08).

## Conséquences
- [p-ar-backend](../architecture/backend.md), [p-ar-security](../architecture/security.md), [p-ar-agents-protocols](../architecture/agents-protocols.md), [p-ar-quality](../architecture/quality.md), [p-fn-catalog](../functional/catalog.md), [p-fn-dataset](../functional/dataset.md) à la clôture de 012. `docker-compose.yaml` et `check-compose.sh` évoluent (écouteur interne, variables `COMPOSER_*`).
- Nouvelle surface d'attaque : une route interne qui dépense du budget ; bornes de D1 et absence de publication de port.

## Réexaminer si
- La mesure (T-mesure) donne un p90 > 8 s pour l'acte 1 ou > 1,5 s au premier squelette malgré D8 : repli définitif, assumé (pdr-0060).
- Le budget de 20 € est menacé.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-30 | Acceptée (décision contrainte D1 à D4, D6 ; détails D5, D7, D8 sous pdr-0062). | Assistant |
