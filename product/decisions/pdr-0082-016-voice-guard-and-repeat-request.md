---
id: pdr-0082-016-voice-guard-and-repeat-request
title: "PDR-0082 — 016 : garde-fou des instructions vocales et reprise d'une demande mal comprise après un chevauchement"
area: decisions
status: validated
updated: 2026-10-31
sources: [specs/016-voice-guard-resume/spec.md, specs/016-voice-guard-resume/plan.md, p-sources, knowledge:rt-gpt-live-lifecycle, knowledge:rt-gpt-live-delegation]
links: [pdr-0081-rail-in-replay-and-ignore-stray-speech, pdr-0037-voice-brise-delegated-instructions, pdr-0077-011b-overlap-interrupt-delegation-link, pdr-0080-015-overlap-interrupt-delegation-link-assistant-decided, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, p-rm-open-questions, p-rm-backlog, p-rm-roadmap, p-ar-voice-overlap, p-ar-voice-interruption, rt-gpt-live-lifecycle, rt-gpt-live-delegation]
tags: [pdr, decision, voix, bruit-parasite, reprise, chevauchement, 016]
decision_status: acceptée
decided_on: 2026-10-31
decided_by: "Assistant (délégation du porteur, pdr-0062) ; exigence d'origine : parole du porteur citée au Contexte (conversation Claude Code, 2026-10-31)"
scope: mixte
supersedes: []
superseded_by: null
---
# PDR-0082 — 016 : garde-fou des instructions vocales et reprise d'une demande mal comprise après un chevauchement

> **En bref.** Le moyen de 016 est choisi par la boucle (pdr-0062, pdr-0081 D2 lui en laisse le choix). D1 : une consigne de silence dans `voice-instructions.fr.md` pour le bruit. D2 : filtre côté orchestrateur écarté. D3 : une demande « dégradée » (dite par-dessus l'IA) refusée par tous les agents, ou sans agent retenu, déclenche la phrase `repeat_request`. D4 : « Stop » non transcrit hors périmètre. La frontière bruit / demande n'est **pas** décidée ici : [Q-90](../roadmap/open-questions.md).

L'assistant a mis en forme et tranché le moyen technique sur la délégation de la règle permanente pdr-0062 (contestable par le porteur). Il ne décide pas la frontière entre bruit et demande hors sujet, qui reste au porteur (Q-90).

## Contexte
- **Exigence d'origine (sujet a).** [pdr-0081](pdr-0081-rail-in-replay-and-ignore-stray-speech.md) D2, parole du porteur, 2026-10-31 (conversation Claude Code) : « Elle ne doit pas la traiter. C'est un bruit parrasite » (cas « Papa Papa », voix dans la pièce, [répétition du 2026-10-31](../sources/2026-10-31-repetition-micro.md)). Le porteur a laissé le moyen à la boucle.
- **Accord sur la fonctionnalité.** Le porteur a répondu « oui, vas-y » à la proposition de 016 (2026-10-31, conversation Claude Code).
- **Sujet b.** Une demande dite par-dessus l'IA est mal transcrite, refusée par les trois agents (`scope_reason=version`), puis l'IA annonce une vue indisponible au lieu de redemander ; au calme la même phrase passe (journal du 2026-10-31, 87,21 s ; Q-80 d et e).
- **Faits.** GPT-Live répond de lui-même à toute parole ; seul le texte des `instructions` fixé à l'ouverture est un levier fiable avant la réponse ([rt-gpt-live-lifecycle], [rt-gpt-live-delegation]). Le texte est délégué à la boucle ([pdr-0037](pdr-0037-voice-brise-delegated-instructions.md)). Le chevauchement est publié par `voice.interrupted {cause: overlap}` ([pdr-0077](pdr-0077-011b-overlap-interrupt-delegation-link.md), [pdr-0080](pdr-0080-015-overlap-interrupt-delegation-link-assistant-decided.md)).

## Hypothèses
- ✅ L'IA ne doit pas traiter un bruit parasite (pdr-0081 D2, parole du porteur).
- ⚠️ Hypothèse non confirmée : frontière entre bruit (silence) et demande hors sujet (politesse isolée, question hors release sans demande d'affichage) → [p-rm-open-questions](../roadmap/open-questions.md) (Q-90). Retenu provisoirement : bruit et bribes sans lien avec la release → silence ; demandes d'affichage et questions sur la release → inchangé ; politesse isolée → comportement actuel.
- ⚠️ Hypothèse non confirmée : le modèle respecte la consigne de silence ; seul un essai réel le prouve (voir « Réexaminer si »).

## Options
1. **Consigne de silence dans les instructions vocales + reprise « répète » pour les demandes dégradées** (retenue).
2. Filtre de pertinence côté orchestrateur.
3. Accepter le risque (déjà refusé par le porteur, pdr-0081 D2).

## Décision
- **D1 — consigne de silence.** `backend/orchestrator/config/voice-instructions.fr.md` reçoit, **après** la consigne de délégation d'affichage, une consigne : bruit, voix dans la pièce, bribe sans sens ni lien avec la release → ne rien dire, ne pas demander « tu es là ? », ne pas déléguer. La consigne « toute demande d'affichage est déléguée » est précisée pour ne viser que de vraies demandes et reste explicite et antérieure. Aucune nouvelle variable (`VOICE_INSTRUCTIONS_FILE` existe). Frontière provisoire : voir Q-90 ; la politesse isolée n'est pas tranchée (comportement actuel).
- **D2 — filtre orchestrateur écarté.** Voir « Options écartées ».
- **D3 — reprise.** Une demande **dégradée** est une délégation vocale dont l'offset est ≥ `at_ms` d'un chevauchement et au plus `VOICE_RECOVERY_WINDOW` après lui (défaut du code `0` = reprise coupée, compose `8s`, bornes 0 à 30 s ; sans chevauchement actif la reprise est inerte, avec un avertissement au démarrage et jamais de refus : le retour arrière `VOICE_OVERLAP_INTERRUPT=false` reste possible). Si elle n'aboutit à aucun résultat parce que **tous les agents retenus la refusent** ou qu'**aucun agent n'est retenu**, la voix dit la phrase existante `no_request` (« … pouvez-vous répéter ? », aucune clé nouvelle) à la place du refus habituel. **Un seul passage** : la délégation vocale qui suit une phrase de reprise n'est jamais dégradée, et une marque de chevauchement sert une seule fois ; le refus habituel avec alternative (RG-08) est donc **différé d'un tour, jamais supprimé**. Échecs d'agent, réussites, actions et corrections en vol (014) inchangés ; une correction dite pendant que l'IA parle compte comme chevauchement. Détail technique : `specs/016-voice-guard-resume/plan.md`.
- **D4 — « Stop » non transcrit : hors périmètre.** Aucun signal observable côté backend ; le bouton « Faire taire » reste le recours (Q-80 e).

## Raisons
- Le texte des instructions est le seul levier avant la parole du modèle ([rt-gpt-live-lifecycle]) et sa rédaction est déléguée à la boucle (pdr-0037).
- La reprise réutilise le chevauchement déjà détecté (015) et ne touche ni au contrat de l'app-channel ni à Flutter.
- Elle est bornée (fenêtre, un seul passage) : une demande réellement hors périmètre reçoit « répétez » une fois, puis le refus habituel au calme.

## Options écartées
- **Filtre orchestrateur** (couper la voix si l'énoncé est sans rapport avec la release) : exige un juge de pertinence (mots-clés fragiles, ou LLM : latence, coût, faux rejets de demandes valides, NFR-02) et ne ferait que couper une réplique déjà commencée (réponse parasite ≈ 1,3 s après la parole, delta d'entrée 0,6 à 1 s après). À reprendre si l'essai réel montre que la consigne ne suffit pas.
- **Accepter le risque** : refusé par le porteur (pdr-0081 D2).

## Conséquences
- Fichiers touchés par 016 : `voice-instructions.fr.md`, `phrases.fr.json`, configuration `VOICE_RECOVERY_WINDOW`, port `SessionDelegations.NoteOverlap` (voir `plan.md`). Aucun changement Flutter.
- Scénarios G-01, G-02, R-01 à R-07 à ajouter à `product/functional/features/` à la clôture de 016.
- [p-rm-backlog](../roadmap/backlog.md) § 016 et [p-rm-roadmap](../roadmap/roadmap.md) : 016 en cours. Q-80 d et e traitées en partie (e hors périmètre) ; Q-90 ouverte, non bloquante.
- Preuve de comportement : un essai réel payant au plus (voix de synthèse « Papa Papa »), `openai-budget.sh` consulté ; sinon « à observer en répétition ».

## Réexaminer si
- L'essai réel ou la répétition montre que le modèle ne se tait pas : rouvrir le filtre orchestrateur (PDR de remplacement).
- Des demandes valides sont ignorées (consigne de silence trop large) ou reçoivent « répétez » à tort.
- ⚠️ Un bruit dit par-dessus l'IA et délégué malgré la consigne (« Papa Papa ») reçoit « pouvez-vous répéter ? » au lieu du silence : assumé (R-09), à reprendre par un filtre sur les mots significatifs si l'essai réel ou la répétition le montre.
- ⚠️ Tant qu'aucun essai réel n'a eu lieu, l'effet de la consigne de silence sur le modèle n'est **pas démontré** (Q-89, pdr-0081 D2).
- Le porteur précise la frontière bruit / demande (Q-90) dans un sens qui change D1.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-31 | Acceptée (moyen technique de 016, étape Définir), sur délégation de la règle permanente pdr-0062 ; exigence d'origine : pdr-0081 D2 ; frontière bruit / demande renvoyée à Q-90 | Assistant (délégation du porteur, pdr-0062) |

Pas d'archive brute.
