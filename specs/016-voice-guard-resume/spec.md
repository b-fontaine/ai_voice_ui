# 016 — Garde-fou des instructions vocales et reprise d'une demande mal comprise

> **En bref.** L'IA ne répond plus à un bruit parasite ni à une parole sans rapport avec la release (sujet a, [pdr-0081](../../product/decisions/pdr-0081-rail-in-replay-and-ignore-stray-speech.md) D2). Quand une demande dite par-dessus l'IA est mal transcrite et refusée, elle invite à répéter (une fois) au lieu d'annoncer qu'une vue n'existe pas (sujet b).

- **Jalon** : J7 (hors lots 014 et 015 ; issu de la répétition au micro du 2026-10-31)
- **Epics** : EP-02, EP-06
- **Exigences visées** : FR-13, FR-14, FR-17, FR-19 ; RG-11, RG-12, RG-15, RG-17, RG-26, RG-27 ; NFR-02 (ne pas dégrader l'accusé)
- **Décisions applicables** : [pdr-0037](../../product/decisions/pdr-0037-voice-brise-delegated-instructions.md) (texte des instructions délégué), [pdr-0081](../../product/decisions/pdr-0081-rail-in-replay-and-ignore-stray-speech.md) D2 (exigence du porteur), [pdr-0077](../../product/decisions/pdr-0077-011b-overlap-interrupt-delegation-link.md) et [pdr-0080](../../product/decisions/pdr-0080-015-overlap-interrupt-delegation-link-assistant-decided.md) (chevauchement), [pdr-0062](../../product/decisions/pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details.md) (détails tranchés par la boucle) ; décision de cette fonctionnalité : voir `plan.md` (PDR à créer à la clôture de Définir)
- **Hors périmètre** :
  - Q-79 (coupure locale de la piste, spike SP-11), Q-87 (correction en vol non jouée), seuils `VOICE_OVERLAP_*` et AEC (SP-06) ;
  - « Stop » non transcrit (Q-80 e) : aucun signal observable côté backend (ni transcription d'entrée, ni `voice.interrupted`) ; le bouton « Faire taire » reste le recours ; consigné, pas résolu ;
  - un filtre de pertinence côté orchestrateur (option écartée, voir `plan.md`) ;
  - tout changement côté Flutter : le contrat de l'app-channel est inchangé.

## Frontière « bruit » et « demande » (⚠️ non précisée par le porteur)
Le porteur a dit : « Elle ne doit pas la traiter. C'est un bruit parasite » (cas « Papa Papa »). La boucle retient, sous réserve de confirmation (**Q-90**, non bloquante) :
- **ignorée (silence)** : bruit, voix lointaine ou dans la pièce, mot ou bribe isolé sans sens ni lien avec la release ;
- **inchangé** : toute demande d'affichage, de graphique, d'écran ou de composant, même hors sujet ou impossible, reste déléguée (l'orchestrateur répond, RG-08) ; toute question sur la release reste déléguée ; les mots d'arrêt, de correction et le chevauchement (014, 015) ne changent pas ;
- ⚠️ **non tranché** : une formule de politesse isolée (« merci », « bonjour ») : le texte ne la couvre pas, le comportement actuel est conservé.

## Scénarios (Gherkin)
Nouveaux, à ajouter à `product/functional/features/` à la clôture (fichier `garde-fou-reprise-016.feature`, intitulé « consigne de silence livrée » : les tests prouvent la livraison du texte, pas que le modèle se tait) :
- **G-01** — Le fichier d'instructions contient la consigne de silence, fondée sur la **forme** (rien d'intelligible adressé à l'assistant : bruit, voix lointaine, bribe sans demande), avec l'exception explicite « une demande d'affichage, même hors sujet, reste déléguée », placée après les consignes de délégation, qui gardent leurs textes exacts (`voice_instructions_test.go`).
- **G-02** — Le texte du vrai fichier arrive au fournisseur : test de `newOpenAI` avec un serveur `httptest` qui lit `session.instructions`.
- **R-01** — Demande dite par-dessus l'IA (délégation d'offset ≥ `at_ms` d'un chevauchement, dans `VOICE_RECOVERY_WINDOW`) et refusée par tous les agents : la voix dit la phrase `no_request` (« … pouvez-vous répéter ? »), pas le refus de vue.
- **R-02** — Même demande au calme : refus habituel (`failure_rejected_view` ou `failure_rejected`), inchangé.
- **R-03** — Demande dite par-dessus l'IA et réussie : résultat habituel, aucune phrase de reprise.
- **R-04** — Demande dite par-dessus l'IA : borne incluse (offset = `at_ms` + fenêtre → reprise) et hors fenêtre (offset > `at_ms` + fenêtre → refus habituel).
- **R-05** — Demande dite par-dessus l'IA, aucun agent retenu : phrase `no_request`.
- **R-06** — `VOICE_RECOVERY_WINDOW=0` (défaut du code) : comportement de 015, inchangé. Fenêtre > 0 avec chevauchement coupé : le démarrage réussit, comportement de 014.
- **R-07** — Après la reprise, la même demande répétée au calme est planifiée normalement.
- **R-08** — **Un seul passage** : demande refusée → reprise ; la répétition dite **par-dessus la phrase de reprise** (nouveau chevauchement) et refusée de nouveau reçoit le **refus habituel** (RG-08 différé d'un tour, jamais supprimé).
- **R-09** — Bribe sans sens (« Papa Papa ») dite par-dessus l'IA et que le modèle délègue malgré la consigne : phrase `no_request` (comportement assumé, voir `plan.md` § Interaction (a)/(b)).
- **R-10** — Correction dite pendant que l'IA parle, puis refusée : reprise.
- **R-11** — Échec d'agent (`Failure`) ou mélange refus + échec après un chevauchement : phrase d'échec habituelle.

## Critères d'acceptation
- [ ] Scénarios G-01, G-02, R-01 à R-11 automatisés (Go, build tag `acceptance`) et verts
- [ ] Tests unitaires des unités nouvelles (marquage de délégation dégradée, choix de la phrase, configuration)
- [ ] Aucune régression : acceptation 011, 014, 015 rejouée avec le compose
- [ ] `tools/loop/gate.sh --full` vert
- [ ] Revue d'architecte : CONFORME (ou refactorisations appliquées)
- [ ] Un essai réel payant au plus (voix de synthèse « Papa Papa » : l'IA ne répond pas), `openai-budget.sh` consulté ; sinon consigné « à observer en répétition »

## Questions ouvertes
- **Q-90** (non bloquante) : confirmer la frontière bruit / demande (politesse isolée, question hors release).
