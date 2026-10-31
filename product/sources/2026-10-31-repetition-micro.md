# Répétition au micro sur enceinte du 2026-10-31 (chronologie)

Source datée, matière brute : pas de frontmatter (le dossier `sources/` n'est documenté que par [README.md](README.md)). Statut : **observation de l'assistant**, mesures tirées du journal de session `live_u1_Ef1QQp3oN96GfiTZR7ZnprkjEOFxfWzm.jsonl` (volume `genesis-demo_journal`, pile `tools/demo/run.sh --keep`, `genesis-demo`). Temps en secondes depuis l'ouverture de session. Les 1199 lignes brutes ne sont pas conservées ici.

**Conditions** : porteur au micro, enceinte, vers 11 h 20 UTC. **Ressenti du porteur** (conversation Claude Code, 2026-10-31) : « Pour mon ressenti, tout va mieux. Il y a un très légers délai quand j'ai dit stop mais c'est acceptable ».

## Chronologie utile

| t (s) | Événement | Observation |
|---|---|---|
| 20,03 | Utilisateur : « Prépare la release 3.4 » | délégation `offset_ms` 20600 ; accusé « Ok, » à 22,11 (≈ 1,5 s après la fin de la phrase) ; squelette à 22,20 ; chiffres à 25,86 (composeur LLM 3,66 s) |
| 22,29 → 35 | Commentaire de l'IA (≈ 15 s) | aucune auto-interruption, pas de faux positif d'écho (un échantillon) |
| 48,62 | « Explique-moi la checklist » | l'IA dit « … Oui, je m'arrête » à 49,70 ; **aucune transcription d'entrée, aucun `voice.interrupted`** |
| 64,02 et 83,52 | « Explique-moi la checklist » (2 fois) | réponses normales |
| 86,00 (`at_ms`) | Parole par-dessus l'IA | `voice.interrupted {cause: overlap}` à 87,62 (1,6 s après le début) |
| 87,21 → 87,82 | Transcrit « Ne rentre pas / trop sur Android et prépare avec la 3.3 » | dit : « Concentre-toi sur Android et compare avec la 3.3 » ; 3 agents `rejected` « hors périmètre » (`scope_reason=version`) ; l'IA : « Cette vue n'est pas encore disponible… » |
| 105,75 | « Non, arrête » | `voice.interrupted` (cause stop) à 106,28 (`at_ms` 104800) ; « D'accord, j'arrête. » ; aucune délégation |
| 109,53 | « Concentre-toi sur Android et compare avec la 3.3 » (au calme) | bien comprise ; 99,43 %, 30 %, NO-GO Android, surface `actions` à 113,31 |
| 132,33 → 132,98 | Clic « Bloquer la release » | « C'est fait. La release 3.4 est bloquée. » 0,65 s après le clic |
| 159,69 | Remise à vide / « Direct » | cinq `deleteSurface`, écran vidé |
| 167,08 | Voix dans la pièce : « Papa Papa » | l'IA : « Je suis là. Tu es en sécurité ? » (168,42) ; `voice.interrupted {cause: overlap}` à 170,43 |
| 180,87 | Fin de session | `close_requested` |

## Non observé

Correction en vol (Q-87) ; Échap, `M` (Q-79) et Q-88 : côté app, sans trace serveur (aucune transcription pendant les 20 premières secondes, compatible avec un micro coupé, non prouvé).

## Exploitation

[Q-67](../roadmap/open-questions.md), Q-75, Q-78, Q-79, Q-80, Q-89 ; reconfirmation de « Direct » dans [pdr-0066](../decisions/pdr-0066-010-act4-replay-details-assistant-decided.md) ; fonctionnalité 016 ([backlog](../roadmap/backlog.md)).
