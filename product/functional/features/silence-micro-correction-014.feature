# language: fr
# id: p-fn-feature-silence-micro-correction-014
# Scénarios complémentaires de la fonctionnalité 014 (livrée le 2026-10-31), hors des 9 scénarios de la fiche
#    (la DoD reste S-01 à S-09, pdr-0049) : M-01, M-02, S-07 bis, C-01 à C-05. S-09 et S-07 (côté app) y sont aussi verts :
#    voir barge-in.feature. Ne pas confondre C-01..C-05 avec C-01..C-08 de 012 (llm-composer-012.feature).
# Décisions : pdr-0033, pdr-0076 (D1 à D6). Exigences : p-fn-requirements (FR-12, FR-14, FR-17, FR-20) ; règles : RG-15, RG-22 ; NFR-12.
# Automatisation : Flutter = apps/genesis_canvas/test/acceptance/acte_silence_micro_correction.feature (S-09 bouton et Échap, M-01, M-02, S-07, S-07 bis) ;
#    Go (tag acceptance) = backend/orchestrator/acceptance/voice_correction_test.go (C-01 à C-05) et voice_correction_regression_test.go
#    (TestR01 à TestR03, non-régression de Q-74 / RD-10 ; à ne pas confondre avec R-01..R-09 du rejeu, 010).
# Hypothèses non confirmées en réel : coupure audible de la piste sous flutter_webrtc Linux (Q-79) ; délégation du fournisseur pour une correction en vol (Q-87).
# Steps sans chiffre initial (pdr-0022-gherkin-steps-no-leading-digit).

Fonctionnalité: Couper le micro, faire taire l'IA et corriger en vol

  # Automatisé (Flutter) : M-01 (faux micro). Le micro réel n'est pas observé (Q-79).
  @M-01 @FR-12 @RG-22 @NFR-12
  Scénario: M-01 Couper puis rétablir le micro sans fermer la session
    Soit une session vocale est ouverte
    Quand je clique sur "Couper le micro"
    Alors l'orbe affiche le voile "Micro coupé" par-dessus son état
    Et la session vocale reste ouverte
    Quand je clique sur "Rétablir le micro"
    Alors le voile "Micro coupé" disparaît
    Et l'orbe revient à l'état d'avant
    Et la session vocale reste ouverte

  # Automatisé (Flutter) : M-02 (faux micro). Que rien ne soit transcrit micro coupé en réel relève de Q-79.
  @M-02 @FR-12 @RG-22
  Scénario: M-02 Micro coupé, la piste locale est désactivée et la capture continue
    Soit une session vocale est ouverte
    Quand je coupe le micro
    Alors la piste du micro est désactivée
    Et la capture du micro n'est pas arrêtée
    Et la session vocale reste ouverte
    Quand je rétablis le micro
    Alors la piste du micro est active

  # Automatisé (Flutter) : S-07 bis. La délégation de la correction peut précéder voice.interrupted (C-04 côté Go).
  @S-07 @FR-14 @FR-17
  Scénario: S-07 bis La délégation de la correction arrive avant l'interruption
    Soit le tableau de la release 3.4 est affiché
    Et l'IA parle
    Quand la délégation de la correction est reçue
    Et l'interruption de cause correction est reçue ensuite
    Alors l'orbe repasse aussitôt à l'état "Écoute"
    Et le son de l'IA est rétabli
    Et les quatre surfaces restent affichées

  # Automatisé (Go) : TestC01_CorrectionInFlightCancelsAndReplans
  @C-01 @S-07 @FR-14 @FR-17 @RG-15
  Scénario: C-01 Une correction en vol annule la génération et la replanifie
    Soit une génération est en cours avec deux surfaces complètes et deux inachevées
    Quand je dis "Non, plutôt iOS"
    Alors l'interruption de cause correction est signalée une seule fois, avant toute compensation
    Et les deux surfaces inachevées sont retirées
    Et les deux surfaces complètes restent affichées
    Et la correction est planifiée sans le texte antérieur
    Et la correction n'est jamais traitée comme un arrêt
    Et la session vocale reste ouverte

  # Automatisé (Go) : TestC02_BareCorrectionWithoutRunDoesNothing
  @C-02 @FR-17 @RG-15
  Scénario: C-02 Une correction nue sans génération en vol ne fait rien
    Soit aucune génération n'est en cours
    Quand je dis "Non."
    Alors aucune interruption n'est signalée
    Et rien n'est annulé

  # Automatisé (Go) : TestC03_CorrectionWithStopWordIsStop
  @C-03 @FR-16 @FR-17 @RG-14
  Scénario: C-03 Une correction qui contient un mot d'arrêt est un arrêt
    Soit une génération est en cours
    Quand je dis "Non, stop"
    Alors l'interruption est signalée comme un arrêt, jamais comme une correction
    Et les surfaces inachevées sont retirées
    Et rien n'est planifié pour cette demande

  # Automatisé (Go) : TestC04_QueuedCorrectionIsKeptAndPlannedAfterCancel (passe par la file, ordre contrôlé)
  @C-04 @S-07 @FR-14 @FR-17 @RG-15
  Scénario: C-04 Une correction arrivée dans la file est conservée et exécutée après l'annulation
    Soit une génération est en cours et un texte antérieur n'a pas été délégué
    Et la délégation de la correction attend dans la file derrière la génération
    Quand le détecteur confirme la correction
    Alors la délégation de la correction est publiée avant l'interruption
    Et l'interruption de cause correction précède toute compensation
    Et la génération en vol est annulée
    Et la correction est planifiée puis exécutée sans le texte antérieur

  # Automatisé (Go) : TestC05_CorrectionDuringSingleActionPublishesNothing
  @C-05 @FR-08 @FR-17 @RG-14
  Scénario: C-05 Une correction pendant une seule action ne l'annule pas
    Soit une action de la Barre d'actions est en cours et aucune demande vocale n'est en vol
    Quand je dis "Non, plutôt iOS"
    Alors aucune interruption n'est signalée
    Et l'action n'est pas annulée et se termine d'elle-même
