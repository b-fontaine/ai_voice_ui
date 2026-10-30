# 007 — J3-B : acte 1 côté app (catalogue `genesis`, rail, panneau protocole, étagère, remise à vide)

> **En bref.** L'app rend enfin ce que le backend de 006 émet : les quatre surfaces de l'acte 1 avec le **catalogue fermé `genesis`** (squelette → composants → données), validées côté client (pdr-0053). L'écran montre la fabrication (pdr-0008) : rail des quatre acteurs avec le choix de l'orchestrateur, panneau du protocole (replié par défaut) relié à la surface en cours, étagère « n / 6 utilisés », indicateur « Acte n/3 », zone Rejeu (emplacement), et une commande de **remise à vide**. Seconde moitié de J3 ; l'essai vocal de bout en bout redevient cohérent (RD-9).

- **Jalon** : J3 « Acte 1 Créer » (`product/roadmap/roadmap.md`), backlog EP-03 (rail), EP-04 (catalogue côté client, étagère), EP-05 (panneau protocole), EP-08 (remise à vide).
- **Exigences visées** : FR-01, FR-02 (déjà 005), FR-03, FR-04, FR-05, FR-06, FR-11 ; RG-02, RG-03, RG-07 à RG-10, RG-23, RG-25, RG-29 ; NFR-02, NFR-03 (mesure indicative dans le journal), NFR-05 (texte ≥ 24 px, contraste AA), NFR-06 (≤ 6 surfaces), NFR-08.
- **Décisions applicables** : pdr-0007, pdr-0008, pdr-0014, pdr-0015, pdr-0017, pdr-0019, pdr-0020, pdr-0033, pdr-0053, pdr-0054, pdr-0055, pdr-0057, pdr-0058, pdr-0059, pdr-0062 ; ADR hérités (Bloc, get_it, FSD).
- **Hors périmètre** : mutation en place et actes 2 et 3 (J4, J5) ; `ActionBar` et `CrashList` (pas de schéma : l'étagère les montre, jamais utilisés) ; rejeu A2UI et sa zone fonctionnelle (J6) ; barge-in, « Stop », AEC (J7) ; réglage des instructions vocales (J7) ; survie du canevas d'une session voix à l'autre (J4, pdr-0058 : le registre reste **par session** ici) ; LLM de composition (Q-17, mesure pdr-0060 en J3 côté backend).

## Décisions d'interface prises par la boucle (pdr-0062, signalées dans `progress.md`)
Fiche muette sur ces détails : la boucle tranche, le porteur peut contester.
- **D1 — Indicateur d'acte (pdr-0054)** : « Acte n/3 · Créer | Transformer | Interagir » dans la barre du haut ; en J3 il vaut 1 par défaut, se règle d'un clic sur l'indicateur (régie, souris d'abord, pdr-0033) et revient à 1 à la remise à vide. L'avance automatique des actes est de la mise en scène : porteur.
- **D2 — Relation message ↔ composant (FR-05)** : le message en cours est mis en évidence dans le panneau, et sa surface reçoit un **contour pointillé** (le « pointillé » de la fiche, sans tracé de ligne entre zones).
- **D3 — Zone Rejeu** : emplacement visible avec libellé « REJEU », commandes inactives jusqu'à J6.
- **D4 — Remise à vide** : bouton « Remettre à vide » dans la régie ; efface le canevas, le panneau, l'étagère et les agents, remet l'acte à 1, et demande au backend de retirer les surfaces actives (`POST /canvas/reset`, au mieux). Raccourci `R` facultatif : non fourni (pdr-0033, souris d'abord).
- **D5 — Rail** : l'orchestrateur et les trois agents sont toujours visibles ; un agent absent du `plan` est « en veille » ; un `plan` vide affiche « aucun agent retenu » (RG-08, la voix refuse et propose une alternative, côté 006).
- **D6 — Rendu des composants** : le catalogue `genesis` est un ensemble de `CatalogItem` qui n'utilisent que le **thème de scène** (RG-09) ; aucune couleur ne dépend d'un libellé français (codes `ok|risk|blocking`) ; la courbe est dessinée par `CustomPainter` (aucune nouvelle dépendance).

## Scénarios (Gherkin)
- **S-01 — Acte 1 « Créer le tableau de release »** (`product/functional/features/voice-screen-generation.feature`) : automatisé côté Flutter sur le **faux backend** qui rejoue les fixtures `contracts/a2ui/genesis/v1/examples` (le même contrat que 006) : la transcription affiche la phrase ; les trois agents s'allument dans le rail ; un squelette apparaît avant les données ; quatre surfaces complètes (kpi, trend, reviews, checklist). Les seuils 1,5 s et 8 s sont lus dans le journal horodaté (mesure indicative, p90 en J8), pas assertés en test.
- **Scénarios d'acceptation propres à 007** (fichiers `.feature` sous `apps/genesis_canvas/test/acceptance/`, hors les 9 de la fiche, qui restent inchangés, pdr-0049 ; ils vérifient FR-03, FR-05, FR-06, FR-11 qui n'ont pas de scénario dans la fiche) :
  - **A1 — rail et choix** : « Montre-moi les avis » → `plan` à un agent : Voix du client allumé, Qualité et Livraison « en veille » ; hors catalogue → « aucun agent retenu ».
  - **A2 — panneau et étagère** : replié par défaut, déplié au clic ; le message en cours est mis en évidence et la surface correspondante est cerclée en pointillé ; l'étagère affiche « 4 / 6 utilisés » en fin d'acte 1, `ActionBar` et `CrashList` éteints.
  - **A3 — validation côté client (pdr-0053)** : un composant `Column` (hors catalogue) ou une propriété inconnue est refusé : aucune surface, comptage et journal ; le flux continue.
  - **A4 — remise à vide (FR-11)** : après l'acte 1, « Remettre à vide » → canevas vide, panneau, étagère et rail remis à zéro, acte 1/3, une requête `POST /canvas/reset` reçue.
  - **A5 — état neutre (RG-10)** : un `updateDataModel` incomplet affiche l'état neutre du composant, sans erreur, et la démo continue.
- Les scénarios de 005 (V1 à V5bis) et de 000 (H-01 à H-03) restent **verts sans affaiblir d'assertion** : leurs données passent du catalogue de base (`Text`) aux fixtures `genesis` (le catalogue de l'app devient fermé, pdr-0053).

## Critères d'acceptation
- [ ] S-01 et A1 à A5 automatisés et verts ; V1 à V5bis et H-01 à H-03 toujours verts
- [ ] Tests unitaires de chaque unité nouvelle (validateur, `CatalogItem` par composant avec squelette et état neutre, Blocs, entités, client de remise à vide, route Go de remise à vide)
- [ ] Les fixtures `contracts/a2ui/genesis/v1/examples/*.jsonl` passent le validateur client et le moteur genui du catalogue de l'app (contrat exécutable des deux côtés)
- [ ] `tools/loop/gate.sh --full` vert (Flutter et Go)
- [ ] Revue d'architecte : CONFORME (ou refactorisations appliquées)
- [ ] `app-smoke.sh` : capture d'un tableau à quatre surfaces (rejeu des fixtures) lisible, texte ≥ 24 px
- [ ] Essai réel (une seule fois, budget) : « Prépare la release 3.4 » → quatre surfaces `genesis` rendues par l'app ; si indisponible (pas de micro), note dans `status.md`

## Questions ouvertes
Aucune ne bloque : Q-71, Q-22, Q-30, Q-31, Q-35, Q-44, Q-69, Q-72, Q-70 sont tranchées (pdr-0053 à pdr-0058). Q-17 (LLM) reste côté backend ; Q-40 à Q-42, Q-67, Q-68 sont de J7.
