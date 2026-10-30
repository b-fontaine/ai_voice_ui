---
name: product-decide
description: Enregistre une décision produit de Genesis Canvas (PDR, product/decisions/pdr-NNNN-*.md) — créer, proposer, accepter, remplacer, reconfirmer ou abandonner une décision fonctionnelle ou technique propre au produit. À utiliser dès que le porteur tranche un choix (« on part sur… », « validé », « non, plutôt… »), qu'une question ouverte Q-xx est résolue, qu'un écart entre sources est arbitré, que l'assistant veut proposer une option à décider, ou qu'une décision existante est remise en cause. Pour une décision technologique réutilisable sur d'autres projets, utiliser kb-curate (knowledge/decisions/adr-*).
---

# product-decide

Référence : `product/_conventions.md` § 5 et le gabarit `product/decisions/_template.md`.

**Règle d'or : l'assistant recommande, le porteur décide les vrais arbitrages ; l'assistant tranche seul les décisions contraintes.** Une parole explicite du porteur (citée dans l'Historique) est nécessaire pour accepter, remplacer ou abandonner un arbitrage. `decided_by` est toujours renseigné.

**Hiérarchie des sources ([pdr-0017](../../../product/decisions/pdr-0017-source-hierarchy-sheet-over-mockups.md)) :** la fiche produit fait foi. Les maquettes illustrent la vision : jamais suivies à la lettre, jamais pour un point technique. Une simple différence avec la maquette n'est pas une question.

## 0. Produit ou réutilisable ?
- Choix valable pour d'autres projets (techno, pattern, outil) → ADR dans `knowledge/decisions/` via `kb-curate`. Si le produit l'applique, l'ajouter à la section `inherited` de `product/decisions/index.yaml` (et à `pdr-0011-adopt-knowledge-adrs`).
- Choix propre à Genesis Canvas (périmètre, écran, données, plateforme, fournisseur pour la démo…) → PDR, ci-dessous.
- Avant tout : `product-lookup` (lire `decisions/index.yaml`, `inherited` compris, et les `Q-xx` liées) pour éviter un doublon ou une contradiction.

## 0 bis. Contrainte ou arbitrage ?
- **Décision contrainte** : une seule réponse correcte découle de faits vérifiés (notes `knowledge/` `status: verified`, doc officielle) et/ou de décisions acceptées (`pdr-*`, ADR hérités, AGENTS.md § 2, exigences de la fiche). L'assistant la tranche **sans demander** : PDR `acceptée`, `decided_by: "Assistant (décision contrainte), sur délégation du porteur du 2026-10-29"`, champ `constraint_basis` (ids qui imposent la réponse), puis il la **signale** au porteur dans son compte rendu. Le porteur peut la contester : elle est alors remplacée (§ 3) par une PDR de sa main. Exemple : [pdr-0018](../../../product/decisions/pdr-0018-a2ui-v09-genui-0-10-4.md).
- **Arbitrage** (porteur) : plusieurs options valables ; goût, priorité, mise en scène, budget, calendrier, matériel, hypothèse sur l'équipe ou l'hébergement. L'assistant recommande, le porteur tranche.
- **Fait à établir** : la réponse dépend d'un spike ou d'une mesure ; rattacher la `Q-xx` au spike.
- **Règle permanente (pdr-0062, 2026-10-30)** : écart fiche/maquette → la fiche s'applique ; fiche muette sur un détail d'interface → l'assistant tranche (PDR `acceptée`, `decided_by` « Assistant (délégation du porteur, pdr-0062) »), le signale dans son compte rendu et `specs/progress.md` ; périmètre, mise en scène des actes, budget et fournisseurs restent au porteur.
- En cas de doute, c'est un arbitrage.

## 1. Créer une PDR (proposée ou acceptée)
1. Prendre `next_id` dans `product/decisions/index.yaml` (format `pdr-NNNN`, ex. `pdr-0013`), puis l'**incrémenter** en gardant ce format (`pdr-0014`).
2. Copier `_template.md` en `pdr-NNNN-<slug>.md` (slug anglais en kebab-case). `id` = nom du fichier.
3. Renseigner :
   - `decision_status: proposée` + `status: proposed`, ou `acceptée` + `status: validated` si le porteur a tranché ;
   - `decided_on`, `decided_by` (« Benoît FONTAINE (porteur), <canal> », ou pour une proposition « à décider par … ») ;
   - `scope` (`fonctionnel` | `technique` | `mixte`), `supersedes: []`, `superseded_by: null` ;
   - `sources`, `links` (docs impactés, `Q-xx` d'origine via `p-rm-open-questions`, ADR liés).
4. Corps : En bref, part de l'assistant, Contexte (avec sources), Hypothèses (⚠️ non confirmées → `Q-xx`), Options réellement envisagées, Décision vérifiable, Raisons, Options écartées, Conséquences (ids `p-*`, `FR-xx`, `NFR-xx`), Réexaminer si, Historique.
5. Ajouter l'entrée dans `docs` de `decisions/index.yaml` (summary : « AAAA-MM-JJ acceptée|proposée — … ») avec `decision_status` identique à celui du fichier.

## 2. Accepter une PDR proposée
- Seulement sur parole explicite du porteur. Passer `decision_status: acceptée`, `status: validated`, mettre à jour `decided_on`, `decided_by`, `updated`, et ajouter une ligne d'Historique citant le porteur. Mettre à jour `decision_status` et le summary de l'entrée dans `decisions/index.yaml`.

## 3. Remplacer
1. Créer une **nouvelle** PDR (étape 1) avec `supersedes: [pdr-ancienne]`.
2. Dans l'ancienne : `decision_status: remplacée par pdr-NNNN-<slug>`, `status: superseded`, `superseded_by: pdr-NNNN-<slug>`, ligne d'Historique. **Ne jamais la supprimer ni réécrire son contenu.**
3. Dans `decisions/index.yaml` : mettre à jour `decision_status` et le summary de l'ancienne entrée (« remplacée par pdr-NNNN-<slug> ») et ajouter la nouvelle.

## 4. Reconfirmer
- Décision réévaluée et maintenue : **pas de nouveau numéro**. Ajouter une ligne au tableau Historique (date, motif, qui) et mettre à jour `updated`.

## 5. Abandonner
- `decision_status: abandonnée`, `status: superseded`, ligne d'Historique expliquant pourquoi. Le fichier reste. Mettre à jour `decision_status` et le summary de l'entrée dans `decisions/index.yaml`.

## 6. Propager (toujours)
1. **Questions ouvertes** : dans `product/roadmap/open-questions.md`, passer la `Q-xx` concernée à « tranchée → pdr-NNNN » (ou y rattacher la PDR proposée en gardant la question ouverte).
2. **Documents impactés** (section Conséquences) : mettre à jour exigences, écran, catalogue, architecture, roadmap ; retirer les « ⚠️ Hypothèse non confirmée » devenues confirmées ; ajouter l'id de la PDR dans leurs `links` (liens dans les deux sens).
3. Si un fait technique réutilisable a émergé : `kb-curate`.
4. `python3 -I product/_tools/product_lint.py` → **0 erreur** (cohérence `decision_status`/`status`, `decision_status` index ↔ fichier, numérotation sans trou, `next_id` au format `pdr-NNNN`, `superseded_by`).

## Garde-fous
- Ne jamais trancher un arbitrage à la place du porteur, ni présenter une PDR `proposée` comme acquise. Une décision contrainte cite toujours son `constraint_basis` et n'est jamais fondée sur la maquette.
- Ne jamais supprimer, renuméroter ou réutiliser un numéro de PDR.
- Signaler explicitement toute hypothèse non confirmée et la faire confirmer avant de l'inscrire comme décision.
