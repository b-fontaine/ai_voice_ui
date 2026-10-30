# 008 — Tâches

Format : `- [ ] Txx [P?] <pile> — <tâche> · test d'abord : <test qui doit échouer>`. `[P]` = parallélisable avec une tâche d'une **autre pile** sans fichier partagé. Les tâches d'une même pile se font **une à la fois**. Ordre à amender par la revue du plan.

## Contrat et jeu de données
- [ ] T01 Go — jeu de données : `dataset.json` reçoit les avis Android 3.3 (50 / 30 / 28 / 236 / 430) et les trois extraits de l'acte 2 (Android 3.4) ; `PlatformChecklist(version, platform)` ; écarts calculés (`Comparison`) ; chaînes `FormatPct/FormatPt` ; `ReviewSummary` 3.3 (le refus « avis 3.3 avant J4 » disparaît) · test d'abord : `dataset_test`/`sheet_test` étendus aux valeurs de l'acte 2 de `dataset.md` (99,43 / −0,54 / 99,71 / −0,28 / 792 / 30 % / 3,7 / 774 / 14 % / +16 pts / 2 bloquants / NO-GO Android), bords du seuil
- [ ] T02 contrat — `examples/act2-*.jsonl` (4 fichiers, `updateDataModel` seul), `catalog.json` (`comparison` des avis, séries nommées), `README.md` · test d'abord : test Go de contrat (chaque fixture valide `catalog.json`, rejouée après l'acte 1 sur le même `Registry` : acceptée, aucune création) ; `GenesisContract` Dart comparé au `catalog.json` (rouge tant que le champ manque)

## Gherkin (acceptation Flutter, `bdd_widget_test` ; Go avec le tag `acceptance`)
- [ ] T03 Go — acceptation sous `-race` : S-02 (vrais agents derrière l'orchestrateur : surfaces à leur place, Android seul, comparaison), B1 (registre partagé : session A puis session B, remise à vide), B2 (« Non, plutôt iOS »), B3 (refus honnêtes) · test d'abord : sortie rouge citée (agents refusent la comparaison ; la session B recrée les surfaces)
- [ ] T04 [P] Flutter — S-02 (`acte2_transformer.feature`, steps de la fiche), B2 côté app, B4 (comparaison rendue ; `comparison` incomplet → neutre) ; identité de rendu (même `State`) avant / après ; zéro `createSurface` entre l'acte 1 et la fin de l'acte 2 · test d'abord : rouge pour la bonne raison (faux backend sans acte 2, `comparison` ignoré)

## TDD
- [ ] T10 Go — `kit.Intent` / `ParseIntent` (remplace `InScope`) et tags communs dans les trois `profile.json` ; `SurfaceMessages` : mutation par `updateDataModel` seul · test d'abord : table (tous les cas de `InScope` conservés + Android, iOS, 3.3 avec / sans Android, deux plateformes, 3.2) ; planificateur : « Concentre-toi sur Android et compare avec la 3.3 » retient les trois agents, « les avis Android » seulement Voix du client
- [ ] T11 Go — composeur Qualité : vues globale / plateforme / comparaison (`kpi`, `trend`), résumé factuel · test d'abord : sortie égale à `act2-kpi.jsonl` et `act2-trend.jsonl` ; iOS sans 3.3
- [ ] T12 Go — composeur Voix du client : vues globale / plateforme / comparaison (`reviews`) · test d'abord : sortie égale à `act2-reviews.jsonl`
- [ ] T13 Go — composeur Livraison : checklist Android, recommandation **NO-GO Android** · test d'abord : sortie égale à `act2-checklist.jsonl`
- [ ] T14 Go — orchestrateur : registre partagé (fabrique), `Pipeline.Close` sans purge, `ResetCanvas` sans session, `activeSurfaces` lues sur le registre partagé · test d'abord : tests unitaires (deux sessions, concurrence `-race`, remise à vide sans session) puis T03 vert
- [ ] T15 [P] Flutter — `KeyIndicator` / `ReviewSentiment` : ligne `comparison` (24 px, couleur par code de statut) ; `TrendChart` : légende et deux séries nommées ; `GenesisContract` · test d'abord : un test par item sur la fixture de l'acte 2 + table « `comparison` sans `delta` → neutre » ; test de page 1920 × 1080 (aucun débordement, contraste des paires `blocking`)
- [ ] T16 [P] Flutter — faux backend : émission de l'acte 2 depuis `act2-*.jsonl` (plan + `agent.activity` + `updateDataModel`) ; asset de rejeu de l'acte 2 (`gen_replay.dart` étendu, artefact dérivé) · test d'abord : `fake_backend_test`, `replay_asset_is_derived_test` ; T04 vert

## Clôture
- [ ] T90 `tools/loop/gate.sh --full` vert (Flutter + Go)
- [ ] T91 Revue architect-reviewer (mode CODE) et refactorisations par lots
- [ ] T92 Vérification : `gate --full`, `app-smoke.sh` (capture de l'acte 2 à lire), essai réel unique si le budget le permet ; clôture : docs `product/` (catalogue, jeu de données, agents-protocols, app-channel-contract, backend, frontend-screen, security si besoin, roadmap, backlog, Q-73), note `knowledge/` si fait nouveau, fusion, `publish.sh`, `fresh_session`
