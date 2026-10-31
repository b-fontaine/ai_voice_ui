# 016 — Plan technique

Pile unique : **Go** (`backend/orchestrator`). Aucun changement Flutter ni du contrat de l'app-channel (`voice.interrupted` et ses causes restent ceux de 015).

## Sujet (a) — garde-fou des instructions vocales
### Constat
GPT-Live répond de lui-même à toute parole : l'application ne contrôle ni la création de la réponse ni un « tour terminé » ([rt-gpt-live-lifecycle], [rt-gpt-live-delegation]). Le seul levier fiable avant la parole du modèle est le texte des `instructions` fixé à l'ouverture (`session.instructions.append` n'a pas d'effet démontré, [rt-gpt-live-lifecycle]). Les instructions actuelles ne cadrent pas le cas : elles disent même de déléguer toute demande « même hors sujet ».
### Moyen retenu (pdr-0037 : texte délégué à la boucle)
1. `backend/orchestrator/config/voice-instructions.fr.md` : une consigne de silence fondée sur la **forme** et non sur le sujet (rien d'intelligible adressé à l'assistant : bruit, voix dans la pièce ou lointaine, bribe sans demande → ne rien dire, ne pas demander « tu es là ? », ne pas déléguer), placée **après** les consignes de délégation, avec l'exception explicite « une demande d'affichage, même hors sujet, reste déléguée ». Les lignes existantes ne changent pas : `voice_instructions_test.go` exige déjà mot pour mot « même hors sujet ou impossible » et « ne la refuses jamais toi-même » (garde-fou de 012).
2. Aucune nouvelle variable : le fichier est déjà injecté par `VOICE_INSTRUCTIONS_FILE` (compose). **G-01** : test de contrat du fichier (présence, forme, exception explicite, ordre). **G-02** : `port.LiveProvider` ne transporte pas les instructions (elles vont dans `openailive.Options`, `bootstrap/app.go`) : test de `newOpenAI` avec le vrai fichier et un serveur `httptest` qui lit `session.instructions` (patron de `provider_test.go`).
3. **Honnêteté de la preuve** : G-01 et G-02 prouvent que le texte est livré, pas que le modèle se tait. Seul un essai réel le prouve : un essai payant au plus, en Vérification, avec une voix de synthèse ([rt-tts-test-audio]) disant « Papa Papa » ; sinon **Q-89 et pdr-0081 D2 restent « non démontrés »** (statut, PDR, `progress.md`) et l'intitulé du `.feature` ne dit pas « l'IA ignore un bruit ».
### Options écartées
- **Filtre côté orchestrateur** (couper la voix quand l'énoncé n'a pas de rapport avec la release) : exige un juge de pertinence (mots-clés fragiles, ou LLM = latence, coût, faux rejets de demandes valides, NFR-02) et ne ferait que couper une réplique déjà commencée (la réponse parasite part ≈ 1,3 s après la parole, le delta d'entrée arrive 0,6 à 1 s après). À reprendre si l'essai réel montre que la consigne ne suffit pas.
- **Accepter le risque** : refusé par le porteur (pdr-0081 D2).

## Sujet (b) — reprise d'une demande mal comprise après un chevauchement
### Constat (journal du 2026-10-31, 87,21 s)
Une demande dite par-dessus l'IA est mal transcrite (« Ne rentre pas trop sur Android et prépare avec la 3.3 »), refusée par les trois agents (`scope_reason=version`), puis l'IA annonce une vue indisponible au lieu de redemander. Au calme la même phrase passe.
### Moyen retenu
Une demande **dégradée** est une délégation vocale dont l'offset est ≥ `at_ms` d'un chevauchement et au plus `VOICE_RECOVERY_WINDOW` après lui. Si elle n'aboutit à aucun résultat parce que **tous les agents retenus la refusent** ou qu'**aucun agent n'est retenu**, la voix dit la phrase existante **`no_request`** (« Je n'ai pas bien saisi la demande, pouvez-vous répéter ? ») à la place de `failure_rejected_view`, `failure_rejected` ou `out_of_catalog`. Aucune clé de phrase nouvelle (aucune incompatibilité avec un `VOICE_PHRASES_FILE` existant, vouvoiement conservé). Inchangés : `Failure` (agent injoignable, délai), mélange refus + échec, réussites partielle et totale, actions de l'interface. Le refus de vue du composeur LLM (`view_unavailable`) remonte comme refus : couvert.

**Un seul passage (RG-08 différé d'un tour, jamais supprimé).** Sans garde-fou, le speaker qui répète par-dessus la phrase de reprise provoquerait un nouveau chevauchement et une boucle de « répétez ». Donc : (1) une marque de chevauchement n'est jamais qu'à usage unique (consommée quand une demande en est jugée dégradée) ; (2) la délégation vocale qui suit une phrase de reprise n'est **jamais** dégradée (drapeau `repeatPending` de session, posé quand la reprise est dite, lu puis remis à faux au début du `run` de la délégation vocale suivante). Le refus habituel avec alternative (RG-08) est donc dit au second refus (R-08).

| Élément | Contrat |
|---|---|
| Port `SessionDelegations` | `NoteOverlap(atMs int64)` non bloquant, documenté dans le commentaire du port ; **ne publie rien** ; sans effet si la session est fermée ; ne prend que `session.mu` (ordre Canvas.mu → m.mu → session.mu respecté) ; mémorise le **plus grand** `atMs` (`hasOverlap bool` + `overlapAt`, comme `hasStop`) |
| Appel | **par le forwarder**, jamais directement par `supervise` : `Service.overlap` appelle `fw.noteOverlap(atMs)` **puis** `fw.supersede(atMs, nil)` (ordre garanti par la file FIFO) ; `"noteOverlap"` ajouté aux éléments jamais abandonnés de `forward.go` ; une correction dite pendant que l'IA parle (`overlap(…, CauseCorrection)`) l'appelle aussi |
| Évaluation | **au point de refus**, pas après `settle` (la détection d'un énoncé d'un mot peut arriver après la fin de `settle`, qui compte depuis `queuedAt` et peut être nul) : `session.run` pose dans `Delegation` une fonction non exportée `recovery func() (degraded bool, overlapAtMs int64)` qui lit `overlapAt` sous `session.mu` ; `degraded = window > 0 && hasOverlap && !afterRepeat && overlapAt ≤ d.OffsetMs ≤ overlapAt + window` ; jamais pour une action ; au constat « dégradé » la marque est consommée et `repeatPending` posé |
| Pipeline | appelle `recovery()` seulement aux trois points de refus ; si dégradé, dit `Phrases.NoRequest` ; sinon le comportement actuel |
| Configuration | `VOICE_RECOVERY_WINDOW` (durée ; code `0` = reprise coupée ; compose `8s` ; bornes 0 à 30 s) → `orchestrate.Options.RecoveryWindow`, validée ≥ 0 par `NewManager`, câblage couvert par `wiring_test.go`. **Pas de refus au démarrage** si > 0 sans chevauchement actif (le retour arrière documenté `VOICE_OVERLAP_INTERRUPT=false` doit rester possible) : la reprise est alors inerte (`NoteOverlap` n'est jamais appelé) ; un `Warn` est journalisé au démarrage, testé dans `config_test.go` |
| Compose | `backend/check-compose.sh` ne contrôle aucune variable `VOICE_*` : un test d'acceptation lit `VOICE_RECOVERY_WINDOW` dans `docker-compose.yaml` **sans repli silencieux** (patron de `overlap_compose_defaults_test.go` et `overlapVars`), et R-01 à R-11 utilisent cette valeur |
| Journal | slog `demande dégradée refusée : reprise demandée` avec `delegation`, `offset_ms`, `overlap_at_ms` (jamais le texte de la demande) |

### Interaction (a)/(b) : le bruit délégué malgré la consigne
« Papa Papa » dit par-dessus l'IA déclenche un chevauchement (`papa` a 4 runes, longueur minimale 3). Si le modèle le délègue malgré la consigne (a), la reprise remplace `out_of_catalog` par « pouvez-vous répéter ? » : l'IA engage alors la conversation sur un bruit, ce qui n'est pas le silence voulu par pdr-0081 D2. **Assumé** (la parade est la consigne (a) ; un filtre par mots significatifs reste une option si l'essai réel montre le cas) ; consigné dans pdr-0082 (« Réexaminer si ») et couvert par R-09.

### Cas limites
- Une demande réellement hors périmètre dite juste après un chevauchement reçoit « répétez » une fois ; répétée, elle reçoit le refus habituel (R-07, R-08).
- Deux chevauchements : seul le plus grand `atMs` compte.
- Chevauchement noté **après** le refus (course perdue) : non dégradé, comportement de 015, documenté.
- Correction en vol (014, `Supersede` sans chevauchement) : non concernée.
- « Stop » non transcrit : hors périmètre (spec).

## Références
- `product/architecture/voice-interruption.md`, `voice-overlap.md`, `llm-composer.md` ; `backend/orchestrator/config/README.md`
- Notes `knowledge/` : [rt-gpt-live-lifecycle], [rt-gpt-live-delegation], [rt-barge-in], [rt-transcription], [rt-tts-test-audio]
- Décisions : pdr-0037, pdr-0081, pdr-0077, pdr-0080 ; nouvelle PDR de 016 (assistant, pdr-0062)

## Risques
- La consigne de silence fait taire l'IA sur une vraie demande courte → G-01 fixe l'ordre, la forme et l'exception explicite ; essai réel et répétition.
- Le modèle ne respecte pas la consigne → essai réel unique ; si non, rouvrir l'option filtre (PDR de remplacement).
- Phrase « répétez » dite à tort (demande refusée pour de bon) → bornée à la fenêtre et à un seul passage (R-07, R-08).
- Course entre `NoteOverlap` et l'évaluation → évaluation au point de refus ; tests déterministes (fausse `WaitClock`, sans `sleep`) : chevauchement noté avant `Delegate`, entre `Delegate` et la fin de `settle`, après le refus (non dégradé).
