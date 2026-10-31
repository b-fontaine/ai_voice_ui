# 014 — J7-A : faire taire l'IA, couper le micro, corriger en vol

> **En bref.** Le speaker peut faire taire l'IA et couper son micro à la souris sans fermer la session (FR-20, FR-12, S-09), et corriger la demande en cours de génération (« Non, plutôt iOS », FR-17, S-07) sans mot d'arrêt : la génération en vol est annulée, la correction est traitée comme la consigne en vigueur.

- **Jalon** : J7 (durcissement), première moitié : ce que la boucle peut livrer et prouver sans micro ni enceinte. **Backlog** : EP-02, EP-06.
- **Exigences visées** : FR-12, FR-14 (chemin correction), FR-17 (second temps), FR-20 ; RG-12, RG-15, RG-21, RG-22 ; NFR-12 (assoupli, pdr-0033).
- **Décisions applicables** : [pdr-0033](../../product/decisions/pdr-0033-optional-shortcuts-mouse-first.md), [pdr-0062](../../product/decisions/pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details.md), [pdr-0069](../../product/decisions/pdr-0069-voice-interruption-hybrid-stop-011.md), [pdr-0073](../../product/decisions/pdr-0073-011-voice-interaction-details-assistant-decided.md), [pdr-0064](../../product/decisions/pdr-0064-008-act2-transform-details-assistant-decided.md) D4, [pdr-0076](../../product/decisions/pdr-0076-014-silence-mic-correction-assistant-decided.md) (détails tranchés par la boucle).
- **Hors périmètre (répétition avec le porteur, rien n'est prouvable sans humain)** : SP-06 (AEC sur enceinte, barge-in 10/10, FR-18), SP-11 / Q-79 (la coupure de piste est-elle audible sous Linux), mesure 60 i/s au profil `--profile` (NFR-04), mesure sur projecteur (NFR-05), réglage des instructions vocales (pdr-0037), Q-77 (déclencheur sur prise de parole : porteur), Q-78, Q-80. Le déclencheur de correction **par prise de parole sans mot** n'est pas fait (Q-77).

## Scénarios (Gherkin)
- S-09 — Faire taire l'IA (`product/functional/features/barge-in.feature`) : par le bouton « Faire taire » (raccourci facultatif, pdr-0033).
- S-07 — Corriger la demande en cours de génération (idem) : mot de correction en tête de phrase.
- Nouveaux, complémentaires (à ajouter à `voice-interaction-011.feature` ou à un fichier 014 via product-curate) :
  - M-01 — Couper puis rétablir le micro : l'orbe passe à « Micro coupé », la session reste ouverte, le transport ne reçoit plus de son ; rétablir ramène l'état d'avant.
  - M-02 — Le micro coupé ne ferme pas la session et un « Stop » vocal n'est pas détecté tant qu'il est coupé (rien n'est transcrit).
  - C-01 à C-04 (Go) — voir ci-dessous.

## Comportement

**Lot A — côté app (Flutter)**
- A1 **Faire taire** (FR-20, RG-22) : un bouton « Faire taire » dans la régie, actif seulement quand l'IA parle (orbe en `Parole`) ; il coupe la piste distante comme le fait `voice.interrupted` (même `RemoteAudioSwitch`) et fait passer l'orbe à « Interrompue » puis « Écoute » par le chemin de FR-19 (réplique tronquée là où elle a été coupée). **Il ne ferme pas la session et n'annule aucune génération** (« Stop » vocal le fait) ; aucun message au backend (pdr-0076 D1).
- A2 **Couper le micro** (FR-12, RG-22) : un bouton « Couper le micro » / « Rétablir le micro », actif tant qu'une session est ouverte ; il désactive la piste locale (`track.enabled = false`, aucun arrêt de capture : « une seule source de capture micro »), l'orbe affiche « Micro coupé » (grisé barré, `screen.md`) ; rétablir restitue la phase précédente. Le micro rétabli est **toujours** réarmé à la fermeture et au redémarrage de la session (un nouveau démarrage repart micro actif).
- A3 **Raccourcis facultatifs** (pdr-0033, pdr-0076 D2) : `M` bascule le micro ; `Échap` fait taire. Posés à la racine de la page ; sans effet si aucune session n'est ouverte ; jamais `Espace` (activerait le bouton focalisé). Coupe C-A3 : à retirer sans conséquence si un conflit de focus apparaît.

**Lot B — correction en vol (Go + app)**
- B1 **Mots de correction** (FR-17, RG-15, pdr-0076 D3) : liste injectée `VOICE_CORRECTION_WORDS` (compose : `non,plutôt,en fait` ; liste vide = détection coupée, défaut du code), jamais codée en dur. Même mécanique que le détecteur de mots d'arrêt (énoncé, premier mot significatif, confirmation par ponctuation ou `VOICE_STOP_SETTLE`), mais le **reste de l'énoncé est conservé** : une correction nue (« Non. ») sans contenu est ignorée (aucune annulation ni interruption).
- B2 **Effet** : sur correction confirmée *pendant qu'une exécution vocale est en vol ou en file*, publier `voice.interrupted {at_ms}` (la voix se tait, FR-19), annuler l'exécution en vol (`Interrupt` par époque, surfaces inachevées retirées par complétude, complètes conservées, actions `act-<n>` jamais annulées), et **conserver** les délégations dont l'offset est ≥ `at_ms` (la correction elle-même). La correction est alors planifiée normalement : avec la mémoire de focus (pdr-0071) et la correction de plateforme livrée par 008 (« Non, plutôt iOS » → vue iOS sur les surfaces existantes). Hors exécution en vol ou en file : mot de correction traité comme du texte ordinaire (aucune interruption).
- B3 **Pas de double annulation** : une correction n'annule jamais la demande qui la porte ; un mot d'arrêt dans la même phrase garde la priorité (chemin « Stop » inchangé).

## Critères d'acceptation
- [ ] S-09 (bouton) et S-07 (Go : agents scriptés bloquants ; Flutter : `voice.interrupted` → piste coupée) automatisés et verts ; M-01, M-02 verts ; C-01 à C-04 (Go) verts.
- [ ] Tests unitaires des unités nouvelles ; ordre et concurrence testés sous `-race` (Go).
- [ ] `tools/loop/gate.sh --full` vert ; revue d'architecte CONFORME ou refactorisations appliquées.
- [ ] Capture `app-smoke` 1920×1080 : boutons « Faire taire » et « Couper le micro » lisibles (≥ 24 px, cibles ≥ 48 px), sans débordement de la barre du haut.
- [ ] Aucune hypothèse du fournisseur n'est présentée comme prouvée : le comportement de GPT-Live à une correction en vol est tracé en **Q-87**.

## Scénarios Go (C-xx, build tag `acceptance`)
- C-01 : correction en vol (« Non, plutôt iOS » pendant une transformation scriptée bloquante) → exécution annulée, surfaces inachevées retirées, complètes conservées, correction planifiée dans l'époque suivante, jamais vue comme « Stop ».
- C-02 : correction nue (« Non. ») sans exécution en vol → aucun `voice.interrupted`, aucune annulation.
- C-03 : correction avec un mot d'arrêt (« Non, stop ») → chemin « Stop » (rien n'est planifié).
- C-04 : correction arrivée dans la file derrière l'exécution en vol (délégation reçue avant la confirmation du détecteur) → conservée, planifiée après l'annulation.

## Questions ouvertes
- **Q-87** (non bloquante, ajoutée par 014) : GPT-Live crée-t-il une délégation pour « Non, plutôt iOS » prononcé *pendant* qu'une délégation précédente est ouverte ? ⚠️ hypothèse non confirmée ; si non, la correction n'a pas de support côté fournisseur (S-07 reste partiel en réel). À observer en répétition (comme Q-78).
- Q-77 reste au porteur : la correction ne se déclenche que sur mot de correction, pas sur simple prise de parole.
