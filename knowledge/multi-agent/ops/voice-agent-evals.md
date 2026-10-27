---
id: ma-voice-agent-evals
title: Évaluer un agent vocal délégant (crawl / walk / run)
tags: [multi-agent, evaluation, realtime-voice, gpt-live, testing]
status: verified
updated: 2026-10-26
sources: [https://developers.openai.com/cookbook/examples/audio/voice_agent_evaluation]
links: [ma-otel-genai-spans, ma-real-tool-results, test-realtime-fake-runner, test-pyramid-flutter]
---
# Évaluer chaque frontière, pas seulement la transcription

Une confirmation qui « sonne bien » ne prouve pas que la bonne action backend a été faite. Le cookbook OpenAI (GPT-Live) évalue trois choses séparément :
- la délégation ;
- l'action backend ;
- la restitution du résultat vérifié.

**Paliers :**
- **CRAWL** : une requête unique générée par TTS. C'est la base reproductible pour les régressions.
- **WALK** : les mêmes tâches avec de vrais enregistrements, plus des dégradations (bruit, filtre téléphonique, écho, perte de paquets).
- **RUN** : un appelant simulé, full duplex, sur plusieurs tours (corrections, interruptions, reprise).

**Graders :**
- checks **déterministes** : noms et arguments d'outils, autorisation, état applicatif, timing audio ;
- **LLM juge** indépendant, avec crédit partiel ;
- revue humaine optionnelle (prosodie).

**Métriques :**
- tâche :
  - complétion (gate principal) ;
  - précision des outils ;
  - précision de la délégation ;
- interaction :
  - latence jusqu'au **premier audio qualifiant** ;
  - taux d'interruption ;
  - silence pendant la délégation ;
- consommation front et back, séparément.

Comme le modèle est non déterministe, répéter les runs et rapporter P50 et P90 avec la taille d'échantillon.

**Recommandations :**
- Scénarios dans `scenarios.json` : id, comportements requis et interdits, preuves attendues, fixture stable.
- Marquer les étapes obligatoires `critical: true` pour qu'elles bloquent la complétion en RUN.
- Ne changer qu'une variable à la fois.
- Transformer chaque échec de production en scénario de régression.

**Pour nous (opinion) :**
- CRAWL en CI sur l'orchestrateur, avec un faux runner côté Flutter ([[test-realtime-fake-runner]]).
- WALK et RUN en nightly.
