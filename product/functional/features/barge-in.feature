# language: fr
# id: p-fn-feature-barge-in
# Source : product/sources/product-description.pdf § 4, p. 5-6 (repris fidèlement).
# Exigences : p-fn-requirements ; règles : p-fn-business-rules (RG-11 à RG-17, RG-22).
# Steps sans chiffre initial (E16 · Q-34, pdr-0022-gherkin-steps-no-leading-digit) : bdd_widget_test
#    échoue sur un step qui commence par un chiffre (knowledge:test-bdd-feature-syntax). Sens inchangé.
# Couverture automatisée : S-05 complet depuis 015 (2026-10-31, pdr-0077 et pdr-0080 : couper la parole sans mot d'arrêt ;
#    Flutter acte_chevauchement_liaison.feature, Go O-01 à O-08 ; voir chevauchement-liaison-015.feature), après K-05 (011, Flutter),
#    S-06 (K-03, Go) depuis 011 (2026-10-30) ;
#    S-07 (C-01, C-04 en Go ; Flutter acte_silence_micro_correction.feature) et S-09 (bouton « Faire taire » et Échap,
#    Flutter) verts en BDD depuis 014 (2026-10-31, pdr-0076) ; S-08 toujours non automatisé (conforme à l'essai au micro, Q-41).
#    Hypothèses non confirmées en réel : coupure audible sous Linux (Q-79), délégation du fournisseur pour une correction (Q-87),
#    faux positifs d'écho sans AEC, latence ≈ 1 s et fenêtre de parole du chevauchement (Q-80, SP-06).
#    Les scénarios K-03 à K-07 (011) et M-01, M-02, S-07 bis, C-01 à C-05 (014), complémentaires et hors des 9 de la fiche,
#    sont dans voice-interaction-011.feature (p-fn-feature-voice-interaction-011) et
#    silence-micro-correction-014.feature (p-fn-feature-silence-micro-correction-014) ; O-01 à O-08 et L-01 à L-04 (015) dans
#    chevauchement-liaison-015.feature (p-fn-feature-chevauchement-liaison-015).

Fonctionnalité: Couper la parole à l'IA

  # Complet depuis 015 : K-05 (011, Flutter), puis S-05 et O-01 à O-08 (015) : voice.interrupted {cause: overlap} sur prise de parole,
  #    sans mot d'arrêt (Q-77 → pdr-0077). Hypothèses acoustiques non confirmées : Q-80.
  @S-05 @FR-13 @FR-15 @FR-19
  Scénario: Interrompre l'IA pendant qu'elle parle
    Soit l'IA est en train de commenter le tableau de release
    Quand je commence à parler
    Alors l'IA se tait immédiatement
    Et l'orbe passe à l'état "écoute"
    Et sa réplique est tronquée dans la transcription à l'endroit de l'interruption
    Et les surfaces déjà affichées restent en place

  # Vert en BDD depuis 011 : K-03 (Go, agents scriptés bloquants).
  @S-06 @FR-15 @FR-16
  Scénario: Annuler une génération en cours
    Soit deux surfaces sur quatre sont en cours de construction
    Quand je dis "Stop"
    Alors l'IA se tait
    Et les deux surfaces inachevées sont retirées
    Et les surfaces complètes restent affichées

  # Vert en BDD depuis 014 : C-01 et C-04 (Go, agents scriptés bloquants), S-07 et S-07 bis (Flutter). Mots de correction injectés
  #    (VOICE_CORRECTION_WORDS) ; « les surfaces passent sur les données iOS » : correction de plateforme de 008 (⚠️ côté fournisseur : Q-87).
  @S-07 @FR-14 @FR-17
  Scénario: Corriger la demande en cours de génération
    Soit le tableau Android est en cours de construction
    Quand je dis "Non, plutôt iOS"
    Alors l'IA se tait
    Et les surfaces déjà construites passent sur les données iOS
    Et la génération ne repart pas d'un canevas vide

  @S-08 @FR-18
  Scénario: Un bruit court n'interrompt pas l'IA
    Soit l'IA est en train de parler
    Quand la salle applaudit pendant une seconde
    Alors l'IA continue de parler

  # Vert en BDD depuis 014 (Flutter, deux scénarios : bouton « Faire taire » et touche Échap). Libellé amendé par 014 (pdr-0076,
  #    pdr-0033) : bouton d'abord, raccourci Échap facultatif ; Espace non retenu (écart à la fiche, pdr-0076 D2).
  @S-09 @FR-20 @NFR-12
  Scénario: Faire taire l'IA au clavier
    Soit l'IA est en train de parler
    Quand je fais taire l'IA par le bouton ou le raccourci "silence"
    Alors l'IA se tait immédiatement
    Et la session reste ouverte
