---
id: ma-backend-sdk-dart
title: SDK Dart côté serveur — faits vérifiés (2026-10-27)
tags: [backend, dart, sdk, gpt-live, mcp, a2a, a2ui]
status: verified
updated: 2026-10-27
sources: [https://pub.dev/packages/openai_dart, https://pub.dev/packages/googleai_dart, https://pub.dev/packages/mcp_dart, https://pub.dev/packages/a2a, https://pub.dev/packages/a2ui_core, https://pub.dev/packages/genui, https://pub.dev/packages/genui_a2a, https://ai.google.dev/api/live#AuthToken, https://docs.temporal.io/encyclopedia/temporal-sdks, https://pub.dev/packages/dartastic_opentelemetry]
links: [ma-backend-sdk-landscape, proto-mcp-dart-sdks, proto-a2a-dart-sdk, genui-a2a-connector]
---
# Écosystème Dart serveur (archives pub.dev inspectées le 2026-10-27)

**GPT-Live — `openai_dart` 11.0.1 (communautaire, non affilié à OpenAI)** : le code type `LiveDelegationCreated`, `session.thinking/commentary.appended`, l'attach `/live/sessions/{id}/attach`, `delegation.type` (`client` par défaut), limite de 500 tokens. Aucun modèle Live figé : `gpt-live-1` se passe en paramètre.

**Gemini — `googleai_dart` 13.0.0 (communautaire)** : Live (`createLiveClient`) et Auth Tokens. En REST, le champ s'appelle `bidiGenerateContentSetup` (+ `fieldMask`) ; `liveConnectConstraints` est le nom des SDK google-genai.

**MCP — `mcp_dart` 2.4.3** : préfère 2026-07-28 avec repli, Streamable HTTP, OAuth + PKCE ; conformité auto-déclarée.

**A2A** : pas de SDK officiel Dart. `a2a` 4.3.1 = spec v0.3, JSON-RPC seul, serveur toujours bloquant, sans auth §4. `genui_a2a` 0.10.1 parle aussi la forme v0.3 (`message/send`).

**A2UI — `a2ui_core` 0.3.0 (labs.flutter.dev)** : Dart pur, enveloppes v0.9 / v0.9.1 / v1.0, `PayloadValidator` (JSON Schema 2020-12). La 0.2.x n'acceptait que v0.9. **genui 0.10.4 épingle `a2ui_core ^0.1.0`.**

**Manques** : aucun SDK Temporal Dart ; aucun framework d'agents ; `dartastic_opentelemetry` 0.12 pas encore CNCF ; `opentelemetry` déprécié au profit d'`opentelemetry_wk` ; dart_frog sans release depuis ~12 mois.

⚠️ Pièges
- Partager a2ui_core entre l'app et un serveur n'est cohérent que si les deux épinglent la même version (0.1.x tant que genui n'a pas migré).
