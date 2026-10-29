# language: fr
# id: p-fn-feature-barge-in
# Source : product/sources/product-description.pdf § 4, p. 5-6 (repris fidèlement).
# Exigences : p-fn-requirements ; règles : p-fn-business-rules (RG-11 à RG-17, RG-22).
# Steps sans chiffre initial (E16 · Q-34, pdr-0022-gherkin-steps-no-leading-digit) : bdd_widget_test
#    échoue sur un step qui commence par un chiffre (knowledge:test-bdd-feature-syntax). Sens inchangé.

Fonctionnalité: Couper la parole à l'IA

  @S-05 @FR-13 @FR-15 @FR-19
  Scénario: Interrompre l'IA pendant qu'elle parle
    Soit l'IA est en train de commenter le tableau de release
    Quand je commence à parler
    Alors l'IA se tait immédiatement
    Et l'orbe passe à l'état "écoute"
    Et sa réplique est tronquée dans la transcription à l'endroit de l'interruption
    Et les surfaces déjà affichées restent en place

  @S-06 @FR-15 @FR-16
  Scénario: Annuler une génération en cours
    Soit deux surfaces sur quatre sont en cours de construction
    Quand je dis "Stop"
    Alors l'IA se tait
    Et les deux surfaces inachevées sont retirées
    Et les surfaces complètes restent affichées

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

  @S-09 @FR-20 @NFR-12
  Scénario: Faire taire l'IA au clavier
    Soit l'IA est en train de parler
    Quand j'appuie sur le raccourci "silence"
    Alors l'IA se tait immédiatement
    Et la session reste ouverte
