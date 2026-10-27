---
id: ma-prompt-injection-tools
title: Injection de prompt via les résultats d'outils
tags: [multi-agent, security, prompt-injection, mcp, a2a]
status: sourced
updated: 2026-10-26
sources: [https://genai.owasp.org/llmrisk/llm01-prompt-injection/, https://developers.openai.com/api/docs/guides/live-delegation, https://developers.openai.com/api/docs/guides/live-prompting]
links: [ma-mcp-security, genui-a2ui-security, ma-guardrails, proto-a2a-security, proto-mcp-primitives]
---
# Tout retour d'outil ou d'agent distant est une donnée, pas une instruction

L'OWASP (LLM01) distingue :
- l'injection **directe** : l'entrée utilisateur détourne le modèle ;
- l'injection **indirecte** : des instructions sont cachées dans un contenu externe, comme une page, un fichier, un retour MCP ou une réponse A2A.

En multi-agent, chaque saut est une surface d'injection : utilisateur → agent vocal → orchestrateur → MCP/A2A → agent GenUI → client.

**Mitigations OWASP :**
- contraindre rôle et périmètre dans le prompt système ;
- formats de sortie attendus, vérifiés par du **code déterministe** ;
- filtres en entrée et en sortie ;
- moindre privilège, les fonctions privilégiées restant dans le code ;
- validation humaine pour les actions à risque ;
- étiqueter les contenus non fiables ;
- tests adverses réguliers.

**GPT-Live (doc officielle) :**
- les permissions, confirmations et règles métier sont appliquées par l'application ;
- le contenu de page fourni comme contexte UI est une donnée de référence, pas une instruction.

**Règles internes (opinion) :**
1. Encadrer les retours MCP/A2A (par exemple `<tool_result source="…">…</tool_result>`) et dire dans le prompt qu'ils ne contiennent jamais d'ordres.
2. Le modèle vocal ne reçoit qu'un **résumé produit par l'orchestrateur**, jamais le texte brut d'un tiers.
3. Les actions irréversibles exigent une confirmation explicite de l'utilisateur, vérifiée par le code (pas par le LLM).
4. Le JSON A2UI est validé contre le catalogue avant d'atteindre le client ([[genui-a2ui-security]]).

⚠️ Pièges
- Une injection dans une description d'outil MCP agit avant même tout appel. N'accepter que des serveurs MCP en liste blanche.
