# 016 — Plan technique

Pile unique : **Go** (`backend/orchestrator`). Aucun changement Flutter ni du contrat de l'app-channel (`voice.interrupted` et ses causes restent ceux de 015).

## Sujet (a) — garde-fou des instructions vocales
### Constat
GPT-Live répond de lui-même à toute parole : l'application ne contrôle ni la création de la réponse ni un « tour terminé » ([rt-gpt-live-lifecycle], [rt-gpt-live-delegation]). Le seul levier fiable avant la parole du modèle est le texte des `instructions` fixé à l'ouverture (`session.instructions.append` n'a pas d'effet démontré, [rt-gpt-live-lifecycle]). Les instructions actuelles ne cadrent pas le cas : elles disent même de déléguer toute demande « même hors sujet ».
### Moyen retenu (pdr-0037 : texte délégué à la boucle)
1. `backend/orchestrator/config/voice-instructions.fr.md` : une consigne de silence placée **après** la consigne de délégation d'affichage, formulée sur la frontière de `spec.md` : bruit, voix dans la pièce, bribe sans sens ni lien avec la release → ne rien dire, ne pas demander « tu es là ? », ne pas déléguer ; la consigne « toute demande d'affichage… est déléguée » est précisée pour ne viser que de **vraies demandes**.
2. Aucune nouvelle variable : le fichier est déjà injecté par `VOICE_INSTRUCTIONS_FILE` (compose). Un test de contrat (G-01) fixe la présence et l'ordre des consignes ; la session de test (G-02) vérifie que le texte configuré arrive au fournisseur.
3. **Preuve de comportement** : seul un essai réel prouve que le modèle se tait. Un essai payant au plus, en Vérification, avec une voix de synthèse ([rt-tts-test-audio]) disant « Papa Papa » ; sinon consigné « à observer en répétition » (Q-89 reste à clore par l'observation).
### Options écartées
- **Filtre côté orchestrateur** (couper la voix quand l'énoncé n'a pas de rapport avec la release) : exige un juge de pertinence (mots-clés fragiles, ou LLM = latence, coût, faux rejets de demandes valides, NFR-02) et ne ferait que couper une réplique déjà commencée (la réponse parasite part ≈ 1,3 s après la parole, le delta d'entrée arrive 0,6 à 1 s après). À reprendre si l'essai réel montre que la consigne ne suffit pas.
- **Accepter le risque** : refusé par le porteur (pdr-0081 D2).

## Sujet (b) — reprise d'une demande mal comprise après un chevauchement
### Constat (journal du 2026-10-31, 87,21 s)
Une demande dite par-dessus l'IA est mal transcrite (« Ne rentre pas trop sur Android et prépare avec la 3.3 »), refusée par les trois agents (`scope_reason=version`), puis l'IA annonce une vue indisponible au lieu de redemander. Au calme la même phrase passe.
### Moyen retenu
Une demande **dégradée** est une délégation vocale dont l'offset est ≥ `at_ms` d'un chevauchement (`voice.interrupted {cause: overlap}`) et au plus `VOICE_RECOVERY_WINDOW` après lui. Si une demande dégradée n'aboutit à aucun résultat parce que **tous les agents retenus la refusent** ou qu'**aucun agent n'est retenu**, la voix dit la phrase `repeat_request` (« Je n'ai pas bien compris, peux-tu répéter ? ») à la place de `failure_rejected_view`, `failure_rejected` ou `out_of_catalog`. Les échecs d'agent (`Failure`), les réussites partielles et totales, les actions de l'interface sont inchangés.

| Élément | Contrat |
|---|---|
| Port `SessionDelegations` | méthode non bloquante `NoteOverlap(atMs int64)` ; appelée par `Service.overlap` après `voice.interrupted` ; ne publie rien ; mémorise le plus grand `atMs` sous `session.mu` |
| Marquage | dans `session.run`, **après `settle`** (et non à `Delegate`, pour ne pas dépendre de l'ordre entre détection et création de la délégation) : `d.Degraded = window > 0 && lastOverlap ≥ 0 && lastOverlap ≤ d.OffsetMs ≤ lastOverlap + window` ; jamais pour une action |
| Pipeline | `Delegation.Degraded` ; aux trois points d'échec de refus, `Phrases.RepeatRequest` si `Degraded` |
| Configuration | `VOICE_RECOVERY_WINDOW` (durée, défaut du code `0` = reprise coupée, compose `8s`, bornes 0 à 30 s) ; refusée si > 0 sans `VOICE_OVERLAP_INTERRUPT` actif (sans chevauchement il n'y a rien à marquer) |
| Phrases | clé `repeat_request` **obligatoire** dans `phrases.fr.json` (même validation : non vide, ≤ 1 000 runes) |
| Journal | slog `demande dégradée refusée : reprise demandée` avec `delegation`, `offset_ms`, `overlap_at_ms` (jamais le texte de la demande) |

### Cas limites
- Une demande valide mais réellement hors périmètre, dite juste après un chevauchement, reçoit « répète » une fois ; répétée au calme elle reçoit le refus habituel (R-07).
- Deux chevauchements : seul le plus récent compte.
- Correction en vol (014) : non concernée (`Supersede`, pas `NoteOverlap`) ; une correction dite pendant que l'IA parle passe par `overlap(…, CauseCorrection)` et **appelle aussi** `NoteOverlap` (c'est une demande potentiellement dégradée).
- « Stop » non transcrit : hors périmètre (spec).

## Références
- `product/architecture/voice-interruption.md`, `voice-overlap.md`, `llm-composer.md` ; `backend/orchestrator/config/README.md`
- Notes `knowledge/` : [rt-gpt-live-lifecycle], [rt-gpt-live-delegation], [rt-barge-in], [rt-transcription], [rt-tts-test-audio]
- Décisions : pdr-0037, pdr-0081, pdr-0077, pdr-0080 ; nouvelle PDR de 016 (assistant, pdr-0062)

## Risques
- La consigne de silence fait taire l'IA sur une vraie demande courte → G-01 fixe l'ordre des consignes et la consigne de délégation d'affichage reste explicite ; essai réel et répétition.
- Le modèle ne respecte pas la consigne → essai réel unique ; si non, rouvrir l'option filtre (PDR de remplacement).
- Phrase « répète » dite à tort (demande refusée pour de bon) → bornée à la fenêtre et à un seul passage (R-07).
- Course entre `NoteOverlap` et le marquage → le marquage se fait après `settle` (≥ 300 ms après l'offset) ; test de course sous `-race`.
