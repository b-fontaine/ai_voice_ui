# 001 — SP-03 : A2A en Go ↔ `genui_a2a`

> **En bref.** Spike (pas de Gherkin ni de revue d'architecte). Il établit, preuve à l'appui, si un agent Go `a2a-go` v2 peut streamer des parts A2UI v0.9 vers `genui_a2a` 0.10.1 de façon qu'une surface soit rendue côté Flutter, et si une action utilisateur revient à l'agent. Le résultat tranche **Q-39** (canal entre l'app et le backend, `genui_a2a` dans la stack ou non) et complète SP-01 (compatibilité `genui_a2a` / `genui` 0.10.4).

- **Jalon** : J1 (spikes réduits), prépare J2 (`product/roadmap/spikes.md`, ligne SP-03)
- **Exigences visées** : FR-03, FR-08 ; question Q-39 (et Q-46 pour la version de Go)
- **Décisions applicables** : pdr-0018 (A2UI v0.9, genui 0.10.4), pdr-0036 (agents A2A réels producteurs d'A2UI), pdr-0041 (backend dans ce dépôt, sans authentification, local), adr-0003-backend-go, pdr-0010 (versions figées)
- **Hors périmètre** : voix, orchestrateur, catalogue métier, authentification, intégration dans `apps/` ou `backend/` (le code du spike est jetable, sous `spikes/sp03-a2a/`)

## Question
Un agent Go minimal basé sur `github.com/a2aproject/a2a-go/v2` peut-il être appelé par `A2uiAgentConnector` de `genui_a2a` 0.10.1 (transport réel : JSON-RPC A2A `message/stream` sur SSE, en-tête `X-A2A-Extensions`) et renvoyer des messages A2UI v0.9 que `genui` 0.10.4 rend ?

## Critère de succès (spikes.md)
1. Un agent Go minimal renvoie une surface A2UI v0.9 (`createSurface`, `updateComponents`, `updateDataModel`) rendue par un client Flutter utilisant `genui_a2a` ;
2. une action utilisateur (clic sur un bouton) revient à l'agent, qui répond par une mise à jour ;
3. **la version A2A parlée par `genui_a2a` est établie** (v0.3 `message/stream` ou v1.0 `SendStreamingMessage`) ; `a2acompat` est vérifié si nécessaire.
Résultat ❌ : repli sur un canal maison (Q-39) et un jour de plus (RD-2) ; la cause exacte est consignée.

## Méthode
- Lecture du code source de `genui_a2a` 0.10.1 (`~/.pub-cache`) et de `a2a-go` v2 pour établir les méthodes JSON-RPC, l'agent card, les en-têtes et le format des parts ;
- agent Go (module sous `spikes/sp03-a2a/agent/`), client Flutter jetable sous `spikes/sp03-a2a/client/` rendu avec `flutter test` (pas de fenêtre) et, si possible, `flutter run`/capture sous Xvfb ;
- mesures notées : versions résolues, noms de méthodes, échecs rencontrés.

## Critères d'acceptation
- [ ] Question tranchée par une expérience reproductible (commande et sortie citées dans `status.md`)
- [ ] Faits vérifiés versés dans `knowledge/` (kb-curate), sans référence au produit
- [ ] Résultat ✅/❌/⚠️ inscrit dans `product/roadmap/spikes.md` ; Q-39 tranchée (ou proposition de décision à valider par le porteur : `product-decide`)
- [ ] `tools/loop/gate.sh --full` vert à la clôture (le code du spike est hors des piles testées par la porte)

## Questions ouvertes
- Q-39 est tranchée par le résultat de ce spike : c'est un arbitrage du porteur sauf si une seule réponse découle des faits (décision contrainte, `product-decide` § 0 bis).
