---
id: ma-guardrails
title: Guardrails pour agents vocaux et délégués
tags: [multi-agent, guardrails, security, realtime-voice, openai-agents-sdk]
status: verified
updated: 2026-10-28
sources: [https://openai.github.io/openai-agents-js/guides/voice-agents/build/, https://developers.openai.com/api/docs/guides/live-delegation]
links: [ma-prompt-injection-tools, ma-real-tool-results, genui-a2ui-security]
---
# Guardrails : sortie parlée, appels d'outils, actions

**Guardrails de sortie** (OpenAI Agents SDK JS, `RealtimeSession`) :
- `outputGuardrails: RealtimeOutputGuardrail[]` s'exécute de façon asynchrone sur le **transcript** de la sortie audio. Il faut donc que les transcriptions soient disponibles.
- Par défaut, l'évaluation a lieu tous les **100 caractères** et sur le transcript final. Réglage : `outputGuardrailSettings: { debounceTextLength }`. La valeur `-1` évalue seulement la fin.
- Comme parler prend plus de temps que générer, la réponse est souvent coupée avant que l'utilisateur ne l'entende. Un déclenchement émet `guardrail_tripped` (avec `itemId`).

**Approbation d'outil :**
- Un outil `needsApproval: true` émet `tool_approval_requested`. On répond par `session.approve(item)` ou `session.reject(item, {message})`.
- `toolExecution: { preApprovalInputGuardrails: true }` exécute les guardrails d'entrée **avant** la demande d'approbation.
- Timeouts d'outil : `timeoutMs`, `timeoutBehavior` (`error_as_result` par défaut).

**GPT-Live :**
- L'application applique elle-même permissions, confirmations et règles métier.
- `session.instructions.append` change ce que dit le modèle, mais **n'annule pas** le travail backend.

**Couches recommandées (opinion) :**
1. Le prompt vocal décrit le périmètre et la politique de délégation.
2. L'orchestrateur applique :
   - une liste blanche d'outils par rôle utilisateur ;
   - la validation des arguments par schéma ;
   - une confirmation codée pour les actions irréversibles.
3. Sortie A2UI : validation contre le catalogue.
4. Sortie parlée : guardrail asynchrone sur transcript (mots interdits, données sensibles), si le SDK ou le runner le permet.

⚠️ Pièges
- Le guardrail sur transcript arrive après coup : il ne remplace pas un contrôle **avant** l'action.
