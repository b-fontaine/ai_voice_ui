# 004 — Orchestrateur, agent A2A Qualité et première surface

> **En bref.** Quand le speaker dit une phrase sur la release, le modèle vocal délègue (`delegation.created`, mode `client`) ; l'orchestrateur Go interroge l'agent Qualité en A2A, valide l'A2UI v0.9 qu'il produit, la diffuse sur l'app-channel avec l'activité de l'agent, puis renvoie à la voix un commentaire fondé sur le **vrai** résultat. Deuxième des trois fonctionnalités de J2 (003 backend, 004 orchestrateur + agent + surface, 005 app voix + orbe).

- **Jalon** : J2 « Walking skeleton » (`product/roadmap/roadmap.md`), backlog EP-03 (orchestrateur et agents), EP-02.
- **Exigences visées** : FR-03 (agent allumé avec sa tâche, côté données), FR-04 (1 surface), NFR-02/NFR-03 (instrumentation par le journal), RG-02 (squelette avant les données), RG-04 (commentaire générique puis vrai résumé), RG-10 (état neutre si données incomplètes, côté agent), NFR-08 (jeu de données figé).
- **Décisions applicables** : adr-0003-backend-go, pdr-0005, pdr-0013, pdr-0018 (A2UI v0.9), pdr-0023, pdr-0036 (les agents A2A produisent l'A2UI), pdr-0040, pdr-0045, pdr-0050 (délégation `client`), pdr-0052.
- **Hors périmètre** : catalogue fermé `genesis` à 6 composants et agents Voix du client / Livraison (J3), LLM de composition (Q-17 ouverte : l'agent de J2 compose de façon déterministe à partir du jeu figé, derrière un port), modification de surface en place et correction en cours de génération (J4), action utilisateur routée vers un agent (J5), annulation `stop` (J7), app Flutter (005), `genui_a2a`.

## Scénarios (Gherkin)
Le scénario de la fiche « Acte 1 – créer le tableau de release » (`product/functional/features/voice-screen-generation.feature`, S-01) est automatisé côté Flutter par 005 ; ici, des tests d'acceptation Go (build tag `acceptance`) avec LLM/Live simulés et un vrai agent A2A en processus de test :
- B1 — une phrase → une surface : après `delegation.created`, l'app-channel reçoit `agent.activity` (Qualité « en cours »), puis `a2ui` (`createSurface`, `updateComponents`, `updateDataModel` v0.9, dans cet ordre), puis `agent.activity` (terminé) ; la voix reçoit un commentaire générique immédiat, puis un commentaire fondé sur le résultat de l'agent (contient « 99,57 % »).
- B2 — agent injoignable ou en erreur : `agent.activity` « échec », aucune surface inventée, la voix reçoit un commentaire honnête d'échec ; la session reste ouverte.
- B3 — A2UI invalide produit par l'agent : rejeté (jamais relayé), traité comme un échec de l'agent (B2).

## Critères d'acceptation
- [ ] B1 à B3 automatisés et verts
- [ ] Tests unitaires de chaque unité (validateur A2UI, orchestrateur, client A2A, agent Qualité, traduction des événements de délégation)
- [ ] `tools/loop/gate.sh --full` vert (deux modules Go compris)
- [ ] Revue d'architecte : CONFORME (ou refactorisations appliquées)
- [ ] Essai réel unique (budget vérifié) : le modèle délègue, la surface « Sessions sans crash 99,57 % » arrive sur le WSS, la voix dit un résumé fondé sur ce résultat ; `docker compose up` démarre orchestrateur + agent ; délai `delegation.created` → premier message `a2ui` mesuré dans le journal (NFR-02, indicatif)

## Questions ouvertes
Aucune bloquante. Le type de message `a2ui` et `agent.activity` de l'app-channel sont de conception de l'assistant (contrat v1 étendu), à consolider avec 005. Q-17 (LLM de composition) et Q-44 (URI du catalogue) restent ouvertes : l'identifiant de catalogue est un paramètre (`A2UI_CATALOG_ID`).
