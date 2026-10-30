# language: fr
# id: p-fn-feature-voice-screen-generation
# Source : product/sources/product-description.pdf § 4, p. 4-5 (repris fidèlement).
# Exigences : p-fn-requirements ; règles : p-fn-business-rules.
# Steps sans chiffre initial (E16 · Q-34, pdr-0022-gherkin-steps-no-leading-digit) : bdd_widget_test
#    échoue sur un step qui commence par un chiffre (knowledge:test-bdd-feature-syntax). Sens inchangé.

Fonctionnalité: Génération d'écran pilotée à la voix

  Contexte:
    Soit le canevas est vide
    Et la session vocale est ouverte
    Et les agents Qualité, Voix du client et Livraison sont disponibles

  @S-01 @FR-01 @FR-02 @FR-03 @FR-04 @NFR-02 @NFR-03
  Scénario: Acte 1 - créer le tableau de release
    Quand je dis "Prépare la release 3.4"
    Alors la transcription affiche "Prépare la release 3.4"
    Et les agents Qualité, Voix du client et Livraison s'allument dans le rail
    Et un squelette de surface apparaît en moins de 1,5 seconde
    Et quatre surfaces sont complètes en moins de 8 secondes

  @S-02 @FR-07
  Scénario: Acte 2 - transformer sans recréer
    Soit le tableau de la release 3.4 est affiché
    Quand je dis "Concentre-toi sur Android et compare avec la 3.3"
    Alors les surfaces existantes restent à leur place
    Et les données affichées concernent uniquement Android
    Et une comparaison avec la 3.3 apparaît

  # --- Scénarios complémentaires de la fonctionnalité 011 (hors des 9 de la fiche, pdr-0049) ---
  # Automatisés en Go : backend/orchestrator/acceptance/voice_focus_test.go (tag acceptance).

  # TestK01_CompareAfterFocusKeepsPlatform (pdr-0071, Q-74)
  @K-01 @FR-07
  Scénario: K-01 Compare avec la 3.3, dit après Android, garde la plateforme affichée
    Soit le tableau de la release 3.4 est affiché
    Et je dis "Concentre-toi sur Android"
    Quand je dis "Compare avec la 3.3"
    Alors les quatre surfaces affichent la comparaison avec la 3.3 pour Android

  # TestK01_CompareWithoutFocusOnEmptyCanvasIsRejected, TestK01_ResetErasesFocus
  @K-01 @FR-07
  Scénario: K-01 Sans plateforme affichée, la comparaison est refusée
    Quand je dis "Compare avec la 3.3"
    Alors aucune surface n'est créée
    Et les agents concernés sont marqués "hors périmètre"

  # TestK02_WordAtDelegationOffsetIsInRequest
  @K-02 @FR-07
  Scénario: K-02 Un mot dit au moment où l'IA lance la tâche reste dans la demande
    Quand je dis "Montre la qualité, la voix du client et livraison" et que l'IA lance la tâche au moment où le dernier mot commence
    Alors l'agent Livraison est sollicité
    Et la checklist est affichée

  @S-03 @FR-03 @FR-08
  Scénario: Acte 3 - interagir avec un composant généré
    Soit la checklist go/no-go est affichée
    Quand je clique sur "Bloquer la release"
    Alors l'agent Livraison s'allume dans le rail
    Et l'IA confirme à la voix
    Et le statut de la checklist passe à "Bloquée"

  # S-04 RETIRÉ par pdr-0032-obs-video-fallback-a2ui-replay-act (2026-10-29) : le mode secours
  # intégré à l'app disparaît (FR-10 et NFR-07 retirées) ; le secours est une vidéo OBS gérée
  # par le porteur. Texte de la fiche § 4 conservé en commentaire, non exécuté :
  # @S-04 @FR-10 @NFR-07
  # Scénario: Bascule en mode secours
  #   Soit la connexion réseau est perdue
  #   Quand j'appuie sur le raccourci de secours
  #   Alors la session enregistrée est rejouée sur le canevas
  #   Et un indicateur discret signale le mode rejeu
