# 001 — Tâches (spike)

- [x] S1 Lire le code de `genui_a2a` 0.10.1 et de `a2a-go` v2 : méthodes JSON-RPC, agent card, en-têtes, format des parts · sortie : versions et noms de méthodes notés dans `status.md`
- [x] S2 Agent Go minimal (`spikes/sp03-a2a/agent/`) compilable et démarrable sur 127.0.0.1 · sortie : `go build` + `curl` de l'agent card
- [x] S3 Client Flutter jetable (`spikes/sp03-a2a/client/`) : `A2uiAgentConnector` ↔ agent, surface rendue · sortie : test vert ou échec expliqué
- [x] S4 Aller-retour d'une action utilisateur (bouton → agent → mise à jour) · sortie : test vert ou échec expliqué
- [x] S5 Consigner : `knowledge/` (kb-curate), `product/roadmap/spikes.md` (✅/❌/⚠️), Q-39 (product-decide), SP-01 (compat `genui_a2a`)
- [ ] S6 Clôture : `gate.sh --full`, fusion, `publish.sh`
