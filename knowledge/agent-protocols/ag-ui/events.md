---
id: proto-agui-events
title: AG-UI — catalogue des événements
tags: [ag-ui, events, streaming, state, tool-calling]
status: verified
updated: 2026-10-26
sources: [https://docs.ag-ui.com/concepts/events]
links: [proto-agui-overview, proto-agui-dart-sdk]
---
# Événements AG-UI (état au 2026-10-26)

Un *run* d'agent émet une suite typée d'événements. La plupart vont par triplets start / contenu / end, avec une variante `*Chunk` qui les compacte.

| Famille | Événements |
|---|---|
| Cycle de vie | `RunStarted`, `RunFinished`, `RunError`, `StepStarted`, `StepFinished` |
| Texte | `TextMessageStart`, `TextMessageContent`, `TextMessageEnd`, `TextMessageChunk` |
| Tool call | `ToolCallStart`, `ToolCallArgs`, `ToolCallEnd`, `ToolCallResult`, `ToolCallChunk` |
| État | `StateSnapshot`, `StateDelta` (JSON Patch), `MessagesSnapshot` |
| Activité | `ActivitySnapshot`, `ActivityDelta` |
| Raisonnement | `ReasoningStart`, `ReasoningMessageStart/Content/End/Chunk`, `ReasoningEnd`, `ReasoningEncryptedValue` |
| Sous-agents | `SubagentStarted`, `SubagentFinished`, `SubagentError` |
| Spéciaux | `Raw`, `Custom` |

- **Dépréciés** : les `THINKING_*`, remplacés par `REASONING_*`. Leur suppression est prévue en 1.0.0.
- **Brouillons** : `MetaEvent`, ainsi que les variantes « Extended » de RunStarted (`parentRunId`, `input`) et RunFinished (`outcome`, `result`). Ces champs apparaissent aussi sans label DRAFT dans les sections principales : statut ambigu dans la doc.
- Un `RunFinished` sans `outcome` est lu comme une fin normale émise par un producteur ancien.

## Mapping BLoC (opinion)
- Chaque événement AG-UI devient un event BLoC : un `sealed class AgentEvent` avec un sous-type par famille.
- `StateSnapshot` et `StateDelta` alimentent un état partagé immuable. Les patchs sont appliqués dans le bloc, pas dans les widgets.
- Les événements `Subagent*` permettent d'afficher quel agent travaille (vocal, GenUI, métier).

⚠️ **Pièges**
- Les événements en brouillon peuvent changer. Il faut les ignorer proprement s'ils sont inconnus, avec un default dans le switch.
