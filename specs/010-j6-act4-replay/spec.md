# 010 — J6 : acte 4 « Rejouer » (journal du flux A2UI, lecture de 0,25× à 2×)

> **En bref.** Tout ce que l'app a reçu du flux A2UI pendant la session est gardé dans un journal en mémoire. Dans la zone « Rejeu », le speaker lance la **lecture** : le canevas se vide, puis la construction repasse **à l'identique du direct**, à la vitesse choisie (0,25×, 0,5×, 1×, 1,5×, 2×), avec le panneau du protocole synchronisé sur le message rejoué. Aucun réseau, aucun LLM, aucune voix. « Direct » rend la main à la démo (remise à vide).

- **Jalon** : J6 « Rejeu A2UI (acte 4) » (`product/roadmap/roadmap.md`), backlog EP-07 (rejeu) et EP-05 (synchronisation du panneau).
- **Exigences visées** : FR-09 (Must), RG-19, NFR-08 (déterminisme) ; FR-05 (panneau relié au composant) ; FR-11 (indicateur d'acte).
- **Décisions applicables** : pdr-0032 (flux A2UI seul, acte 4), pdr-0059 (pas de pas-à-pas), pdr-0033 (souris d'abord), pdr-0038 (horloge de l'app), pdr-0053 (validation côté client), pdr-0054 (écran), pdr-0062, **pdr-0066** (D1 à D7) ; ADR hérités (Clean + FSD, Bloc sans Cubit, DI par constructeur, TDD/BDD).
- **Hors périmètre** : rejeu de la voix ou de la transcription (Q-18) ; secours intégré (vidéo OBS du porteur, pdr-0032) ; pas-à-pas ←/→ (pdr-0059) ; raccourcis clavier (pdr-0033) ; marqueurs de mesure NFR-02/03 (J8) ; écriture du journal sur disque (fiche § 3) ; barge-in et « stop » (J7) ; backend Go (aucun changement).

## Décisions prises par la boucle (pdr-0062 → pdr-0066, à signaler au porteur)
Voir `product/decisions/pdr-0066-010-act4-replay-details-assistant-decided.md`.
- **D1** journal client en mémoire (flux brut, refus compris) ; **D2** rejeu par le même `A2uiGate` ; **D3** entrée par « Lecture » (sans appel backend), sortie par « Direct » (remise à vide complète), indicateur « Acte 4 · Rejeu » ; **D4** commandes : Lecture/Pause, Recommencer, curseur, cinq vitesses, Direct ; **D5** curseur = remise à vide puis réinjection ; **D6** écarts plafonnés à 3 s (réglage injecté) ; **D7** le rejeu couvre tout le journal, qui commence par l'acte 1.

## Scénarios (Gherkin)
La fiche n'a pas de scénario pour FR-09 (vérifié par revue, pdr-0049) ; les scénarios ci-dessous sont propres à 010, dans `apps/genesis_canvas/test/acceptance/acte4_rejouer.feature` (faux backend et horloge virtuelle, comme les actes 1 à 3) :
- **R-01 — Rejeu identique au direct (critère de sortie J6)** : après l'acte 1 en direct, « Lecture » à 2× vide le canevas puis reconstruit les mêmes surfaces, les mêmes textes, les mêmes phases, les mêmes entrées du panneau ; **le faux backend n'a reçu aucune requête** pendant le rejeu (réseau coupé).
- **R-02 — Vitesse** : la durée du rejeu est proportionnelle à 1/vitesse (0,25× dure 8 fois 2×, mesuré sur l'horloge virtuelle) ; changer de vitesse en cours de lecture n'interrompt ni ne saute.
- **R-03 — Curseur** : déplacer le curseur au milieu (avant, puis arrière) laisse exactement les surfaces et le panneau de ce point ; la lecture reprend de là.
- **R-04 — Pause, reprise, fin** : pause fige le canevas ; reprise continue ; à la fin le rejeu s'arrête sur la dernière image, « Lecture » repart de zéro.
- **R-05 — Isolation** : pendant le rejeu, un message A2UI vivant n'est ni appliqué ni enregistré ; boutons du canevas et « Démarrer » inactifs ; la session voix n'est pas touchée.
- **R-06 — Direct** : « Direct » vide le canevas, le panneau, l'étagère, demande la remise à vide du backend, vide le journal ; « Lecture » est de nouveau inactif.
- **R-07 — Sans journal / agents occupés** : sans message enregistré, ou pendant qu'un agent travaille, « Lecture » est inactif.
- **R-08 — Écarts** : un silence de plus de `replayMaxGap` entre deux messages est plafonné ; le curseur couvre la durée comprimée.

## Critères d'acceptation
- [ ] R-01 à R-08 automatisés (Flutter) et verts
- [ ] Tests unitaires : journal (ajout, JSONL aller-retour, ordre), lecteur (vitesses, pause, seek, plafond), Bloc, routeur vivant/rejeu, barre Rejeu, indicateur d'acte
- [ ] `tools/loop/gate.sh --full` vert
- [ ] Capture `app-smoke` d'un rejeu à mi-parcours : zone Rejeu lisible (boutons ≥ 48 px, texte ≥ 24 px, pas de débordement), indicateur « Acte 4 · Rejeu »
- [ ] Revue d'architecte : CONFORME (ou refactorisations appliquées)
- [ ] Les scénarios scriptés de la boucle (`GENESIS_SCENARIO`, 000) fonctionnent toujours

## Questions ouvertes
- Aucune bloquante. À observer en répétition avec le porteur : le plafond d'écart de 3 s (D6) et la place de la zone Rejeu dans la rangée du bas.
