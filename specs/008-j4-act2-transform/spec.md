# 008 — J4 : acte 2 « Transformer » (mutation sur place, filtre Android, comparaison 3.3, registre de canevas partagé)

> **En bref.** Le speaker dit « Concentre-toi sur Android et compare avec la 3.3 » : les quatre surfaces de l'acte 1 **restent à leur place** et passent sur les données Android, avec la 3.3 en regard (écart de l'indicateur, deuxième série de la courbe, avis négatifs 14 % → 30 %, checklist **NO-GO Android**). Aucune surface n'est recréée ni retirée. Le canevas vit côté backend et **survit aux sessions voix** (pdr-0058), ce qui clôt Q-73. Une correction de plateforme (« non, plutôt iOS ») repasse les surfaces existantes sur les données iOS.

- **Jalon** : J4 « Acte 2 Transformer » (`product/roadmap/roadmap.md`), backlog EP-04 (mutation), EP-03 (agents), EP-09 (jeu de données).
- **Exigences visées** : FR-07 (Must), FR-17 (Should, premier temps seulement, D4) ; RG-06, RG-15 (premier temps), RG-10, RG-02 ; NFR-06, NFR-08 (valeurs recalculées depuis les lignes brutes).
- **Décisions applicables** : pdr-0014, pdr-0015, pdr-0017, pdr-0018, pdr-0024, pdr-0036, pdr-0053, pdr-0055, pdr-0056, pdr-0058, pdr-0059, pdr-0061, pdr-0062, pdr-0064 (créée par cette étape) ; ADR hérités (hexagonal Go, Bloc, FSD).
- **Hors périmètre** : `ActionBar` et acte 3 (J5, FR-08) ; arrêt de la voix et annulation de la génération en vol (S-07, FR-14, FR-16 : J7) ; rejeu (J6) ; instructions vocales de GPT-Live (J7, pdr-0037) ; composeur par LLM (Q-17) ; `CrashList` ; filtres à l'écran (pdr-0059) ; suppression de surface en acte 2 (pdr-0059).

## Décisions prises par la boucle (pdr-0062 → pdr-0064, à signaler au porteur)
Voir `product/decisions/pdr-0064-008-act2-transform-details-assistant-decided.md`.
- **D1** mutation par `updateDataModel` seul (chemin entier) sur surface active ; **D2** comparaison dans les composants existants (`comparison`, deuxième série, valeurs de la checklist) ; **D3** grammaire des demandes (une plateforme, 3.3 seulement avec Android) ; **D4** FR-17 en deux temps (correction de plateforme en J4 ; « l'IA se tait » et l'annulation en vol en J7) ; **D5** `ActionBar` reste à J5.
- **Q-73** (canevas entre deux sessions voix) : résolue par construction, pdr-0058 livré (registre partagé). La consigne de régie « remettre à vide avant toute nouvelle session voix » devient inutile côté backend ; au redémarrage de l'**app seule** (backend resté actif), l'app est vide alors que le registre ne l'est pas → consigne conservée : « remettre à vide au démarrage de l'app » (à traiter à la clôture : doc `product/` et note au porteur).

## Scénarios (Gherkin)
- **S-02 — Acte 2 « transformer sans recréer »** (`product/functional/features/voice-screen-generation.feature`, repris tel quel) : automatisé en Flutter sur le faux backend (acte 1 puis acte 2 depuis les fixtures du contrat) **et** en Go (`acceptance`, vrais agents Qualité, Voix du client et Livraison derrière l'orchestrateur) :
  - « les surfaces existantes restent à leur place » : mêmes `surfaceId`, **aucun** `createSurface`/`deleteSurface` entre l'acte 1 et la fin de l'acte 2 ; côté app, le même `State` de rendu avant et après (pas de recréation) ;
  - « les données affichées concernent uniquement Android » : aucune chaîne « iOS » dans les data models émis ni dans le texte affiché ;
  - « une comparaison avec la 3.3 apparaît » : `comparison` du KPI et des avis, série « Android 3.3 », valeurs de la checklist.
- **Scénarios propres à 008** (fichiers `.feature` hors les 9 de la fiche, pdr-0049) :
  - **B1 — registre partagé (Q-73, pdr-0058)** : session A crée les quatre surfaces et se ferme ; session B dit la demande d'acte 2 : mutation sans `createSurface` ; « Remettre à vide » vide le registre (une nouvelle session recrée les quatre surfaces).
  - **B2 — correction de plateforme (FR-17, premier temps)** : après l'acte 2, « Non, plutôt iOS » : les quatre surfaces passent sur iOS (aucune 3.3 : absente du jeu), sans recréation.
  - **B3 — refus honnêtes (D3)** : « compare avec la 3.3 » sans plateforme, « Android et iOS », « la 3.2 » → état `rejected`, aucune surface modifiée, phrase de refus.
  - **B4 — rendu de la comparaison (app)** : l'Indicateur clé affiche « 3.3 : 99,71 % · −0,28 pt » ; le Sentiment des avis « 3.3 : 14 % négatifs · +16 pts » ; la Courbe a deux séries nommées avec légende ; un `comparison` incomplet donne l'état neutre sans erreur (RG-10).
- Les scénarios de 000, 005, 007 (H-01…H-03, V1…V5bis, S-01, A1…A5) restent **verts sans affaiblir d'assertion**.

## Critères d'acceptation
- [ ] S-02 (Flutter et Go), B1 à B4 automatisés et verts ; scénarios antérieurs toujours verts
- [ ] Toutes les valeurs de l'acte 2 recalculées depuis les lignes brutes du jeu (tests Go) et égales à `product/functional/dataset.md` (99,43 % ; −0,54 pt ; 99,71 % ; −0,28 pt ; 792 avis ; 30 % ; 3,7 ; 774 avis 3.3 ; 14 % ; +16 pts ; 118 mentions du thème n° 1 non affichées ; 2 critères bloquants ; **NO-GO Android**)
- [ ] Fixtures `contracts/a2ui/genesis/v1/examples/act2-*.jsonl` : produites à l'identique par les composeurs Go et rejouées par le validateur client et le moteur genui (contrat exécutable des deux côtés)
- [ ] Tests unitaires de chaque unité nouvelle (jeu de données, grammaire des demandes, trois composeurs, registre partagé, `CatalogItem` avec `comparison`, courbe à deux séries)
- [ ] `tools/loop/gate.sh --full` vert (Flutter et Go)
- [ ] Revue d'architecte : CONFORME (ou refactorisations appliquées)
- [ ] `app-smoke.sh` : capture de l'acte 2 (rejeu des fixtures acte 1 + acte 2), texte ≥ 24 px, comparaison lisible
- [ ] Essai réel (une seule fois, budget, `openai-budget.sh check`) : « Prépare la release 3.4 » puis « Concentre-toi sur Android et compare avec la 3.3 » ; si indisponible (pas de micro), noté dans `status.md`

## Questions ouvertes
Aucune ne bloque. Q-73 est résolue par pdr-0058 une fois 008 livrée. Q-40 à Q-42, Q-67, Q-68 restent à J7. ⚠️ Hypothèse non confirmée (pdr-0064) : la délégation vocale transmet la plateforme et la version à chaque tour.
