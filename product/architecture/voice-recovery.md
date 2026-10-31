---
id: p-ar-voice-recovery
title: Consigne de silence et reprise d'une demande mal comprise après un chevauchement (016)
area: architecture
status: draft
updated: 2026-10-31
sources: [specs/016-voice-guard-resume/spec.md, specs/016-voice-guard-resume/plan.md, specs/016-voice-guard-resume/status.md, product/sources/2026-10-31-repetition-micro.md, knowledge:rt-gpt-live-lifecycle, knowledge:rt-gpt-live-delegation]
links: [p-ar-voice-overlap, p-ar-voice-interruption, p-fn-feature-garde-fou-reprise-016, p-fn-feature-chevauchement-liaison-015, p-rm-open-questions, p-rm-backlog, pdr-0082-016-voice-guard-and-repeat-request, pdr-0081-rail-in-replay-and-ignore-stray-speech, pdr-0037-voice-brise-delegated-instructions, pdr-0080-015-overlap-interrupt-delegation-link-assistant-decided, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, rt-gpt-live-lifecycle, rt-gpt-live-delegation]
tags: [voix, bruit-parasite, reprise, chevauchement, instructions, 016]
---
# Consigne de silence et reprise après un chevauchement (016)

**En bref.** Livré par 016 (2026-10-31, `gate --full` vert, 67 contrôles ; [pdr-0082](../decisions/pdr-0082-016-voice-guard-and-repeat-request.md), boucle sous pdr-0062). (a) Une **consigne de silence** dans `voice-instructions.fr.md` demande à l'IA de ne pas répondre à un bruit. (b) Une demande dite par-dessus l'IA, mal transcrite puis **refusée**, fait dire « pouvez-vous répéter ? » au lieu d'annoncer qu'une vue n'existe pas. Aucun changement Flutter ni du contrat de l'app-channel. **Le texte de la consigne est livré et testé ; qu'elle fasse taire le modèle n'est pas démontré** (Q-89, Q-90).

## (a) Consigne de silence

| Point | Contenu |
|---|---|
| Fichier | `backend/orchestrator/config/voice-instructions.fr.md` (variable `VOICE_INSTRUCTIONS_FILE`, aucune variable nouvelle ; texte délégué à la boucle, [pdr-0037](../decisions/pdr-0037-voice-brise-delegated-instructions.md)) |
| Forme | **une seule ligne**, **après** les lignes de délégation, qui gardent leurs textes exacts (« même hors sujet ou impossible », « ne la refuses jamais toi-même ») |
| Critère | la **forme** de l'énoncé, pas son sujet : ce qui n'est pas une parole intelligible adressée à l'assistant (bruit, voix lointaine ou dans la pièce, bribe ou mot isolé sans demande) → ne pas répondre, rester silencieux, ne pas demander « tu es là ? », ne pas déléguer |
| Exception | « une demande d'affichage, même hors sujet, ou une question sur la release reste déléguée » (RG-08 : l'orchestrateur répond) |
| Levier | seul le texte des `instructions` fixé à l'ouverture agit avant la réponse du modèle ; `session.instructions.append` n'a pas d'effet démontré ([rt-gpt-live-lifecycle], [rt-gpt-live-delegation]) |
| Preuves | G-01 (contrat du fichier, marqueur stable, ordre, exception après la directive) et G-02 (`newOpenAI` avec le vrai fichier et un serveur `httptest` qui lit `session.instructions`) : **le texte est livré** |
| Option écartée | filtre de pertinence côté orchestrateur (juge fragile ou coûteux, coupe une réplique déjà commencée) ; à rouvrir si la répétition montre que la consigne ne suffit pas |

## (b) Reprise d'une demande dégradée

Une demande **dégradée** est une délégation vocale d'offset ≥ `at_ms` d'un chevauchement, au plus `VOICE_RECOVERY_WINDOW` après lui. Si **tous les agents retenus la refusent** ou si **aucun agent n'est retenu**, la voix dit la phrase existante **`no_request`** (« Je n'ai pas bien saisi la demande, pouvez-vous répéter ? », aucune clé nouvelle, vouvoiement conservé) à la place de `failure_rejected_view`, `failure_rejected` ou `out_of_catalog`. Inchangés : échec d'agent et mélange refus + échec (R-11), réussites, actions (`act-<n>`).

| Élément | Contrat |
|---|---|
| `NoteOverlap(atMs)` | port `SessionDelegations`, non bloquant, ne publie rien, mémorise le plus grand `atMs` sous `session.mu` ; appelé par le forwarder (file FIFO, jamais abandonné) **avant** `Supersede`, aussi pour une correction dite pendant que l'IA parle (R-10) |
| Marque à usage unique | `claimOverlap(offsetMs)` : la marque appartient à la **première délégation vocale qui la suit** (`claimedUpTo`) ; une demande réussie ou refusée sans reprise l'épuise, une marque notée après le `run` ne sert plus à une demande dite au calme |
| `repeatPending` | posé quand la reprise est dite, lu puis remis à faux par la **délégation vocale suivante** : **un seul passage**. Évalué après `settle`, pour qu'une délégation vide ou « Stop » seul ne le consomme pas |
| Évaluation | **au point de refus** (`claimRecovery` du pipeline), non à la création : la détection d'un énoncé court peut arriver après `settle` ; une marque notée après le refus n'est pas rattrapée |
| RG-08 | **différé d'un tour, jamais supprimé** : la répétition dite par-dessus la phrase de reprise et refusée de nouveau reçoit le refus habituel avec alternative (R-08) |
| Journal | slog `demande dégradée refusée : reprise demandée` (`delegation`, `offset_ms`, `overlap_at_ms`), jamais le texte de la demande |

## Configuration

| Variable | Rôle | Code ; compose | Bornes |
|---|---|---|---|
| `VOICE_RECOVERY_WINDOW` | durée après `at_ms` pendant laquelle une demande refusée est jugée mal comprise | `0` (reprise coupée, comportement de 015) ; `8s` | 0 à 30 s |

**Jamais de refus de démarrage** : si la fenêtre est > 0 sans chevauchement actif (`VOICE_OVERLAP_INTERRUPT=false`, retour arrière de 014), la reprise est inerte et un `Warn` est journalisé. Câblage : `bootstrap/config.go` (`parseBoundedDuration`), `Options.RecoveryWindow`, `wiring_test.go`. Un test d'acceptation lit la valeur dans `docker-compose.yaml` sans repli silencieux (R-00).

## Hypothèses non confirmées

| Hypothèse | Renvoi |
|---|---|
| ⚠️ **Le modèle respecte la consigne de silence.** Essai réel payant d'**un échantillon** (client jetable, 28 s de session, 0,04 €) : « Papa, papa » transcrit exactement, aucune délégation, aucune sortie de l'IA (niveau de sortie 0,000) ; « Explique-moi la checklist » transcrit et déléguée. **Ne démontre pas** la tenue de la consigne à chaque fois ni face à une voix réelle dans la pièce | Q-89 (à confirmer en répétition) |
| ⚠️ La frontière bruit / demande retenue (forme ; politesse isolée et question hors release non tranchées) | Q-90 |
| ⚠️ La fenêtre de 8 s est une valeur de départ non mesurée (réglable) ; la reprise n'a **pas d'essai réel** (la transcription dégradée dépend du chevauchement réel) | Q-80 d |
| ⚠️ Un bruit dit par-dessus l'IA et **délégué malgré la consigne** (« Papa Papa », `papa` a 4 runes) reçoit « pouvez-vous répéter ? » au lieu du silence : assumé (R-09) ; piste : filtre sur les mots significatifs | Q-89, [pdr-0082](../decisions/pdr-0082-016-voice-guard-and-repeat-request.md) « Réexaminer si » |
| « Stop » non transcrit : **non traité**, aucun signal observable côté backend ; le bouton « Faire taire » reste le recours | Q-80 e |

Tests : `backend/orchestrator/acceptance/recovery_test.go`, `recovery_helpers_test.go`, `bootstrap/voice_instructions_guard_test.go` ; scénarios : [p-fn-feature-garde-fou-reprise-016](../functional/features/garde-fou-reprise-016.feature). Chevauchement lui-même : [p-ar-voice-overlap](voice-overlap.md).
