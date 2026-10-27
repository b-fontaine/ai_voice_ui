---
id: ma-backend-stack-options
title: Backend orchestrateur — comparatif des 5 stacks (panel du 2026-10-27)
tags: [multi-agent, backend, decision, go, python, typescript, dart, rust]
status: opinion
updated: 2026-10-27
sources: [https://github.com/openai/openai-go/tree/main/live, https://crates.io/crates/oai-rt-rs, https://github.com/modelcontextprotocol/rust-sdk, https://github.com/a2ui-project/a2ui, https://github.com/modelcontextprotocol/go-sdk/releases, https://pypi.org/pypi/a2ui-agent-sdk/json, https://registry.npmjs.org/@a2ui/agent, https://pub.dev/packages/a2ui_core]
links: [adr-0003-backend-go, ma-backend-stack-recommendation, ma-backend-sdk-landscape, ma-backend-sdk-rust, proj-sk-backend, ma-where-to-run-agents, ma-target-architecture, proto-stack-recommendation]
---
# Comparatif des stacks backend (panel du 2026-10-27, scores /10 après fact-check)

> ⚠️ **Hypothèse corrigée le 2026-10-27.** La lentille « Équipe » du premier panel supposait, sans confirmation, une « équipe Flutter + Go ». Le porteur a ensuite confirmé que l'équipe maîtrise tous les langages : le scénario A du tableau Rust est le plus représentatif, et Go y reste premier ([[adr-0003-backend-go]]).

Cinq propositions ont été vérifiées sur le code des SDK puis notées sous trois lentilles. Le cumul désigne **Go** ; l'hybride arrive deuxième.

| Option | Équipe & exploitation | Temps réel & protocoles | Risque & évolutivité | Total /30 |
|---|---|---|---|---|
| **Go** (tout-Go, continuité saaster kit) | **9** | **8,5** | 7 | **24,5** |
| Hybride Go (gateway) + Python (agents, A2A interne) | 6 | 7 | **8** | 21 |
| Python (FastAPI + ADK + a2ui-agent-sdk) | 4 | 6 | 6 | 16 |
| TypeScript (Node + SDK MCP v2 + @a2ui/agent) | 3 | 6,5 | 5 | 14,5 |
| Dart (shelf + SDK communautaires) | 5 | 4 | 3 | 12 |

**Ce qui a fait la différence (faits vérifiés, voir [[ma-backend-sdk-landscape]]) :**
- Go a des SDK officiels pour toute la plomberie : sideband GPT-Live typé, MCP 2026-07-28, A2A v1.0, jetons Gemini. Seul manque : un SDK A2UI côté agent.
- Python a le seul SDK A2UI agent officiel mûr (a2ui-agent-sdk 0.9) et ADK 2.13, mais la stack proposée **ne s'installe pas** telle quelle (conflits `mcp<2` et `openai<3`).
- TS : l'avantage MCP sur Go est réfuté ; `@a2ui/agent` est en 0.0.2 ; zod 3 et zod 4 cohabitent ; 3ᵉ langage pour l'équipe.
- Dart : SDK OpenAI/Gemini communautaires à mainteneur unique, ni A2A v1.0, ni Temporal ; la « double validation a2ui_core identique » est fausse avec genui 0.10.4.

**Désaccord entre juges.** La lentille « risque & évolutivité » préfère l'hybride : la couche qui bouge le plus (ADK, A2UI) reste dans l'écosystème Python, la double validation A2UI est native, la frontière A2A est réversible. Les deux autres lentilles préfèrent Go : un seul langage, aucun saut réseau dans la boucle vocale, et l'argument structurant de l'hybride (« sideband à écrire à la main en Go ») est réfuté. La recommandation retient Go et **greffe** la frontière de l'hybride sous forme de port ([[ma-backend-stack-recommendation]]).

**Affirmations des propositions réfutées par les fact-checks :**
- « openai-go n'a pas de helper sideband » (hybride) : faux, `SidebandService.Connect` existe.
- « go-sdk MCP en transition » (TS) : faux, 2026-07-28 est la version la plus récente depuis v1.7.0.
- `openai.live.sessions.create` (TS) : n'existe pas, c'est `client.live.create`.
- Planchers Go : Go ≥ 1.26.10 (adk/v2) et OTel ≥ v1.47 (adk/v2), pas 1.26.x / v1.45.
- Node 24 n'est plus en Active LTS (maintenance depuis le 2026-10-20).

## Option Rust (évaluée le 2026-10-27)

Même méthode (proposition, deux fact-checks, trois lentilles), mais notée dans deux scénarios, car les compétences de l'équipe ne sont pas connues. Faits : [[ma-backend-sdk-rust]].

| Scénario | Option | Équipe & exploit. | Temps réel & protocoles | Risque & évolutivité | Total /30 |
|---|---|---|---|---|---|
| A : l'équipe maîtrise Rust | Rust | 7 | 6,5 | 6 | 19,5 |
| | Go | **8** | **8,5** | 6,5 | **23** |
| | Hybride Go + Python | 5,5 | 7 | **7** | 19,5 |
| B : l'équipe ne connaît pas Rust | Rust | 3 | 4 | 3 | 10 |
| | Go | **8,5** | **8** | 7 | **23,5** |
| | Hybride Go + Python | 6 | 6,5 | **7,5** | 20 |

- Rust n'est premier dans **aucune** lentille. Ses atouts (rmcp 3.8, a2a-rs, Temporal GA, enums exhaustives, pas de GC) portent sur des couches que Go couvre déjà avec des SDK officiels ; la performance n'est pas un goulot (latence LLM et réseau).
- Le trou est sur le chemin critique : pas de SDK OpenAI ni Gemini officiel ; seule `oai-rt-rs` 0.5.1 (un mainteneur, spec du 2026-09-11) couvre `/live` et la délégation. Surcoût de plomberie estimé à 3,5–7 semaines-personne de plus qu'en Go, hors apprentissage.
- Affirmation de la proposition réfutée : « aucune crate Rust ne gère `/live` » (`oai-rt-rs` existe).
- Variantes défendables : Rust plus tard, composant par composant derrière un port (`LiveProvider`, sideband-supervisor) sur un goulot mesuré ; ou, si l'équipe maîtrise Rust, un spike de 1–2 semaines (`oai-rt-rs` contre client généré par typify, délégation de bout en bout avec les événements d'octobre) avant tout engagement. Rust + sidecar Python GenUI est la moins risquée des variantes Rust.

⚠️ Pièges
- Les scores sont une appréciation interne, pas une mesure. Aucun chiffre de latence ni de mémoire n'a été mesuré.
- Depuis le 2026-10-27, la maîtrise de tous les langages (Go, Rust, Python…) est confirmée par le porteur : le scénario A est celui qui s'applique.
