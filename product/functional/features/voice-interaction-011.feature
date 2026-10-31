# language: fr
# id: p-fn-feature-voice-interaction-011
# Scénarios complémentaires de la fonctionnalité 011 (2026-10-30), hors des 9 scénarios de la fiche
#    (la DoD reste S-01 à S-09, pdr-0049) : K-03 à K-07 (K-01 et K-02 : voice-screen-generation.feature).
# Décisions : pdr-0069, pdr-0071, pdr-0073. Exigences : p-fn-requirements ; règles : p-fn-business-rules (RG-11 à RG-17).
# Automatisation : Go = backend/orchestrator/acceptance/voice_stop_test.go (tag acceptance) ;
#    Flutter = apps/genesis_canvas/test/acceptance/acte_interruption.feature.
# Steps sans chiffre initial (pdr-0022-gherkin-steps-no-leading-digit).

Fonctionnalité: Interruption vocale, indicateur d'acte et retour au clic


  # Automatisé (Go) : TestK03_StopCancelsInFlightGenerationKeepsSession
  @K-03 @S-06 @FR-15 @FR-16
  Scénario: K-03 Stop retire seulement les surfaces inachevées
    Soit deux surfaces sur quatre sont complètes et deux sont en cours de construction
    Quand je dis "Stop"
    Alors les deux surfaces inachevées sont retirées
    Et les deux surfaces complètes restent affichées
    Et l'interruption est signalée à l'application
    Et la session vocale reste ouverte

  # Automatisé (Go) : TestK04_StopInsideWordOrLongSentenceDoesNotTrigger, TestK04_WordByWordLongUtteranceDoesNotTrigger
  @K-04 @FR-16
  Plan du Scénario: K-04 Un mot qui contient stop, ou une longue phrase, n'arrête rien
    Soit une génération est en cours
    Quand je dis "<phrase>"
    Alors la génération se poursuit
    Et aucune interruption n'est signalée

    Exemples:
      | phrase                          |
      | Il a stoppé la voiture          |
      | Le bus stop est juste là devant |

  # Automatisé (Go) : TestK04_StopWordsAloneTrigger, TestK04_WordByWordStopStillTriggers
  @K-04 @FR-16
  Scénario: K-04 Un mot d'arrêt dit seul arrête la génération
    Soit une génération est en cours
    Quand je dis "Stop"
    Alors la génération est annulée
    Et l'interruption est signalée à l'application

  # Automatisé (Flutter) : K-05, deux scénarios. Couvre S-05 en partie seulement (sur mot d'arrêt) ; complété par 015 (S-05 complet, chevauchement-liaison-015.feature).
  @K-05 @S-05 @FR-13 @FR-15 @FR-19
  Scénario: K-05 Une interruption coupe le son, passe l'orbe à Interrompue et tronque la réplique
    Soit le tableau de la release 3.4 est affiché
    Et l'IA est en train de commenter le tableau
    Quand l'application reçoit l'interruption
    Alors le son de l'IA est coupé
    Et l'orbe passe à l'état "Interrompue"
    Et la suite de la réplique n'apparaît pas dans la transcription
    Et les surfaces déjà affichées restent en place

  @K-05 @S-05 @FR-13 @FR-19
  Scénario: K-05 Après un silence, l'orbe écoute et le son revient
    Soit l'orbe est à l'état "Interrompue"
    Quand trois secondes s'écoulent sans parole de l'IA
    Alors l'orbe passe à l'état "Écoute"
    Et le son de l'IA est rétabli

  # Automatisé (Flutter) : K-05 (annulation affichée) ; mêmes réserves de vérification en répétition (Q-79).
  @K-05 @FR-15
  Scénario: K-05 Un agent annulé est montré interrompu et l'application n'est plus occupée
    Soit un agent travaille dans le rail
    Quand l'agent est annulé
    Alors l'agent est affiché "interrompu"
    Et le bouton "Remettre à vide" est actif

  # Automatisé (Flutter) : K-06, cinq scénarios (trois ci-dessous les regroupent) ; « sans effet en rejeu » : test de page
  # (genesis_canvas_page_act_test.dart), sans scénario BDD.
  @K-06 @FR-08
  Scénario: K-06 L'indicateur passe à l'acte 2 quand la Barre d'actions apparaît
    Soit le tableau de la release 3.4 est affiché
    Et l'indicateur d'acte affiche "Acte 1/3"
    Quand la Barre d'actions apparaît
    Alors l'indicateur d'acte affiche "Acte 2/3"

  @K-06 @FR-08
  Scénario: K-06 L'indicateur passe à l'acte 3 au clic accepté et ne recule jamais tout seul
    Soit la checklist go/no-go est affichée
    Quand je clique sur "Bloquer la release"
    Alors l'indicateur d'acte affiche "Acte 3/3"
    Quand je dis "Concentre-toi sur Android et compare avec la 3.3"
    Alors l'indicateur d'acte affiche "Acte 3/3"

  @K-06 @FR-08 @FR-11
  Scénario: K-06 Le clic manuel corrige l'acte et la remise à vide revient à l'acte 1
    Soit la checklist go/no-go est affichée
    Quand je clique sur l'indicateur d'acte
    Alors l'indicateur d'acte affiche "Acte 3/3"
    Quand je clique sur "Remettre à vide"
    Alors l'indicateur d'acte affiche "Acte 1/3"

  # Automatisé (Flutter) : K-07, trois scénarios (fenêtre de 1366 sur 768 px).
  @K-07 @FR-08
  Scénario: K-07 Le statut de décision est lisible en entier
    Soit la checklist go/no-go est affichée
    Quand je clique sur "Bloquer la release"
    Alors le statut de la checklist passe à "Bloquée"
    Et le statut est visible en entier, sans troncature

  @K-07 @FR-08
  Scénario: K-07 Le bouton passe à fait et un second clic n'envoie rien
    Soit la checklist go/no-go est affichée
    Et je clique sur "Bloquer la release"
    Alors le bouton "Bloquer la release" affiche "fait" et est inactif
    Quand je clique de nouveau sur ce bouton
    Alors aucune nouvelle demande n'est envoyée

  @K-07 @FR-08
  Scénario: K-07 Une demande vocale qui réécrit la checklist réactive le bouton
    Soit le bouton "Bloquer la release" affiche "fait"
    Quand je dis "Concentre-toi sur Android et compare avec la 3.3"
    Alors le bouton "Bloquer la release" est actif
