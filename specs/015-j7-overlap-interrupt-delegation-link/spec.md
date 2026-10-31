# 015 — 011b : couper la parole à l'IA en parlant, et liaison animée de délégation

> **En bref.** Le speaker interrompt l'IA simplement en prenant la parole (sans dire « Stop ») : tout mot significatif qui n'est pas l'écho de l'IA, prononcé pendant qu'elle parle, coupe sa voix (Q-77, option B). Dans le rail, une liaison animée relie l'orchestrateur à chaque agent sollicité (Q-85). Ces deux ajouts sont les deux moitiés de la « 011b » décidée par le porteur ([pdr-0077](../../product/decisions/pdr-0077-011b-overlap-interrupt-delegation-link.md)).

- **Jalon** : J7 (durcissement), **à faire avant le reste de J7**. **Backlog** : EP-02, EP-06 (interruption), EP-04, EP-01 (rail).
- **Exigences visées** : FR-13, FR-15, FR-19 (S-05 complet), FR-03 (liaison du rail), FR-18 (écho, côté logiciel seulement) ; RG-14, RG-17.
- **Décisions applicables** : [pdr-0077](../../product/decisions/pdr-0077-011b-overlap-interrupt-delegation-link.md) (porteur), [pdr-0069](../../product/decisions/pdr-0069-voice-interruption-hybrid-stop-011.md), [pdr-0073](../../product/decisions/pdr-0073-011-voice-interaction-details-assistant-decided.md), [pdr-0075](../../product/decisions/pdr-0075-013-design-ergonomics-details-assistant-decided.md) D1 et D3 (rail 96 px, mouvement), [pdr-0076](../../product/decisions/pdr-0076-014-silence-mic-correction-assistant-decided.md) (`Supersede`, `cause`), [pdr-0062](../../product/decisions/pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details.md), **[pdr-0080](../../product/decisions/pdr-0080-015-overlap-interrupt-delegation-link-assistant-decided.md)** (détails tranchés par la boucle).
- **Notes `knowledge/`** : [rt-barge-in], [rt-transcription], [rt-gpt-live-delegation], [rt-gpt-live-sideband], [rt-echo-cancellation], [ux-voice-multimodal].
- **Hors périmètre (répétition avec le porteur)** : AEC sur enceinte et faux positifs réels (SP-06, Q-80), latence mesurée (≈ 1 s attendue), Q-78, Q-79, Q-87. Rien de ce qui suit ne remplace une écoute réelle : les seuils sont des réglages, pas des preuves.

## Scénarios (Gherkin)
Ajoutés à `barge-in.feature` (S-05 passe de « en partie » à complet) et à un fichier 015 (via product-curate à la clôture) :
- **S-05** — Interrompre l'IA pendant qu'elle parle, **sans mot d'arrêt** (le scénario de la fiche, enfin automatisé en entier).
- **O-01** — Une phrase du speaker pendant que l'IA parle : `voice.interrupted {cause: overlap}`, piste distante coupée, orbe « Interrompue » puis « Écoute ».
- **O-02** — Écho : les mots d'entrée présents dans la transcription de sortie récente de l'IA ne déclenchent rien.
- **O-03** — Mots vides, mots trop courts, bruits (« euh », « hum ») : rien.
- **O-04** — `VOICE_OVERLAP_INTERRUPT=false` : comportement de 014 inchangé.
- **O-05** — Une exécution est en vol quand le speaker parle par-dessus la voix de l'IA : l'exécution antérieure est annulée (surfaces inachevées retirées, complètes conservées), la nouvelle demande du speaker est planifiée.
- **O-06** — « Stop » et les mots de correction restent des déclencheurs à part : un seul `voice.interrupted` par énoncé, de la cause du mot (`stop` ou `correction`), jamais deux.
- **O-07** — L'IA ne parle pas (silence depuis plus de la fenêtre de parole) : une phrase du speaker ne publie rien (c'est un tour de parole ordinaire).
- **L-01** — Liaison : un plan retient deux agents ; tant qu'un agent est « en attente » ou « en cours », une liaison relie l'orchestrateur à sa tuile.
- **L-02** — La liaison disparaît dès que l'agent est « terminé », « échec », « hors périmètre » ou « interrompu » ; « aucun agent retenu » n'en montre aucune.
- **L-03** — Animations coupées (`SceneMotionScope.disabled`) : la liaison reste, fixe.
- **L-04** — Rejeu : le rail reste vide, aucune liaison.

## Comportement

**Lot B — déclencheur sur chevauchement (Go, puis contrat)**
- B1 **Garde « l'IA parle »** : la session retient l'instant (horloge injectée) de la dernière sortie de l'IA (`EventOutputAudio` ou delta de transcription de sortie). L'IA « parle » si cet instant date de moins de `VOICE_OVERLAP_SPEAKING_WINDOW`. Sinon rien n'est déclenché (O-07).
- B2 **Mot significatif** : un mot du delta d'entrée est significatif si sa longueur est d'au moins `VOICE_OVERLAP_MIN_WORD_LEN` runes, s'il n'est pas dans `VOICE_OVERLAP_IGNORE_WORDS` (mots vides, interjections ; liste injectée, au plus 64 mots de 32 runes) et s'il n'est pas dans l'**écho** : l'ensemble des mots normalisés des transcriptions de **sortie** des `VOICE_OVERLAP_ECHO_WINDOW` dernières millisecondes (horloge média). Le déclencheur exige `VOICE_OVERLAP_MIN_WORDS` mots significatifs distincts dans l'énoncé courant (1 par défaut dans le compose).
- B3 **Un seul classifieur** : le déclencheur est un troisième genre de `Detection` (`KindOverlap`) du classifieur d'énoncé unique de 014 : même minuteur, même énoncé, anti-rebond partagé. **Priorité** : un énoncé dont la tête est un mot d'arrêt (ou le début d'un mot d'arrêt), ou un mot de correction, relève de `Stop` ou `Correction` ; `Overlap` ne se déclenche jamais sur ces énoncés et ne double jamais leur `voice.interrupted` (O-06). Une fois un énoncé tranché (déclenché ou écarté), il n'est plus réévalué.
- B4 **Effet** : (1) publier `voice.interrupted {at_ms, cause: overlap}` **toujours** quand la détection est confirmée (le son se coupe même sans exécution en vol) ; (2) puis `Supersede(atMs, no-op)` : si une demande antérieure à `at_ms` est en vol ou en file, elle est annulée avec les effets de 014 (surfaces inachevées retirées, complètes conservées, actions jamais annulées) et les délégations d'offset ≥ `at_ms` — la demande du speaker — sont conservées et planifiées. Jamais `Interrupt` (qui exempterait la demande du speaker de la planification). `at_ms` = `start_ms` du delta qui porte le premier mot significatif.
- B5 **Contrat** : `voice.interrupted.cause` gagne la valeur `overlap` (additif, v1 inchangée ; l'app traite une valeur inconnue comme `stop`).
- B6 **Configuration** (jamais codée en dur ; compose = défauts) : `VOICE_OVERLAP_INTERRUPT` (**activé par défaut**), `VOICE_OVERLAP_SPEAKING_WINDOW`, `VOICE_OVERLAP_ECHO_WINDOW`, `VOICE_OVERLAP_MIN_WORDS`, `VOICE_OVERLAP_MIN_WORD_LEN`, `VOICE_OVERLAP_IGNORE_WORDS`. Valeurs bornées et validées au démarrage, message d'erreur sans recopier de mot.

**Lot A — app (Flutter)**
- A1 **`cause = overlap`** : `InterruptionCause.overlap` ; le convertisseur l'accepte (valeur inconnue = `stop`). `OrbPhaseBloc` traite `overlap` comme `correction` : l'interruption prend fin à la première délégation d'offset ≥ `at_ms` (la demande du speaker), ou aussitôt si cette délégation a précédé `voice.interrupted`, ou au silence de reprise / à la durée maximale s'il n'y en a pas (le speaker a seulement commenté). La piste distante est coupée puis rétablie par la page, comme pour les autres causes ; la réplique de l'IA est tronquée à `at_ms`.
- A2 **Liaison de délégation** (Q-85, FR-03) : dans le rail de 96 px, un trait pointillé animé relie la tuile de l'orchestrateur à la tuile de chaque agent dont l'état est « en attente » ou « en cours » ; il passe sous les tuiles intermédiaires et ne masque aucun texte ; clé `delegation-link-<agent>`, présent seulement dans ces deux états. Les pointillés défilent de l'orchestrateur vers l'agent ; sous `SceneMotionScope.disabled` le trait est fixe ; la vitesse de rejeu s'applique comme aux autres mouvements (pdr-0075 D3). Couleur du thème de scène (jamais codée), épaisseur ≥ 3 px, contraste AA avec le fond. Aucun libellé ajouté (RG-09 n'est pas touché). Repeinture isolée (`RepaintBoundary`) : le reste de la scène ne se reconstruit pas à chaque image (NFR-04).

## Critères d'acceptation
- [ ] S-05, O-01 à O-07 (Go : faux fournisseur ; Flutter : `voice.interrupted {overlap}` → piste coupée puis rétablie) et L-01 à L-04 automatisés et verts.
- [ ] Tests unitaires de chaque unité nouvelle ; ordre et concurrence sous `-race` (Go).
- [ ] `tools/loop/gate.sh --full` vert ; revue d'architecte CONFORME ou refactorisations appliquées.
- [ ] Capture `app-smoke` 1920×1080 : la liaison est visible, sans masquer un libellé du rail.
- [ ] Aucune hypothèse du fournisseur ni de l'acoustique n'est présentée comme prouvée : faux positifs d'écho, latence ≈ 1 s et seuils sont tracés en Q-80 (à observer) et dans pdr-0080 « Réexaminer si ».

## Questions ouvertes
- Aucune bloquante. Les réglages du lot B (fenêtres, longueur minimale, liste de mots ignorés) sont des valeurs de départ, **à régler en répétition** sur enceinte avec le porteur (Q-80).
