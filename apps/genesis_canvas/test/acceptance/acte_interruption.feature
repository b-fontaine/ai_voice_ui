# language: fr
Fonctionnalité: Interruption vocale, indicateur d'acte et retour au clic
  Pour garder la main pendant sa démo, le speaker coupe la parole à l'IA,
  voit l'indicateur d'acte suivre le tableau et lit sans ambiguïté la décision
  qu'il vient de prendre (spec 011 : pdr-0069, pdr-0071, pdr-0073).
  K-05 couvre S-05 de product/functional/features/barge-in.feature en partie :
  le message voice.interrupted n'est publié que sur un mot d'arrêt (Q-77).
  K-06 : l'acte 2 apparaît avec la surface actions, l'acte 3 au clic accepté.
  K-07 : le statut « Bloquée » est lisible en entier, le bouton passe à « fait ».

  Contexte:
    Étant donné les polices réelles de la scène sont chargées
    Et un faux backend local
    Et l'app lancée sur ce backend avec une horloge virtuelle

  After:
    Alors l'app est fermée, le faux backend arrêté et la sémantique libérée

  @S-05 @FR-13 @FR-15 @FR-19
  Scénario: K-05 Couper la parole à l'IA coupe la piste distante et tronque la réplique
    Soit le tableau de la release 3.4 est affiché
    Et le serveur émet une réplique de l'IA {'Le tableau Android est prêt'} commencée à {2000} ms
    Et la ligne {'ai'} de la transcription affiche {'Le tableau Android est prêt'}
    Et le serveur émet un niveau d'orbe de {'0.4'}
    Quand le serveur émet l'interruption à {2500} ms
    Alors la piste distante est coupée
    Et l'orbe est à l'état {'Interrompue'}
    Quand le serveur émet une réplique de l'IA {' et la décision attend'} commencée à {3000} ms
    Alors la ligne {'ai'} de la transcription n'affiche pas {'la décision attend'}
    Et les surfaces affichées sont {'kpi,trend,reviews,checklist'}

  @S-05 @FR-13 @FR-19
  Scénario: K-05 Après un silence l'orbe écoute et la piste distante est rétablie
    Soit le tableau de la release 3.4 est affiché
    Et le serveur émet un niveau d'orbe de {'0.4'}
    Et le serveur émet l'interruption à {2500} ms
    Et l'orbe est à l'état {'Interrompue'}
    Quand le serveur émet un niveau d'orbe de {'0'}
    Et {3} secondes s'écoulent sans parole de l'IA
    Alors l'orbe est à l'état {'Écoute'}
    Et la piste distante est rétablie
    Et les surfaces affichées sont {'kpi,trend,reviews,checklist'}

  @FR-15
  Scénario: K-05 Un agent annulé est montré interrompu et l'app n'est plus occupée
    Soit une session voix démarrée
    Et le serveur émet l'agent Qualité au travail
    Et l'agent {'Qualité'} est affiché {'en cours'}
    Quand le serveur émet l'annulation de l'agent Qualité
    Alors l'agent {'Qualité'} est affiché {'interrompu'}
    Et le bouton Remettre à vide est actif
    Et aucun message A2UI n'est refusé

  @FR-08
  Scénario: K-06 L'acte 2 s'affiche quand la Barre d'actions apparaît
    Soit le tableau de la release 3.4 est affiché
    Et l'indicateur d'acte affiche {'Acte 1/3'}
    Quand le serveur émet la Barre d'actions de la fin de l'acte 2
    Alors l'indicateur d'acte affiche {'Acte 2/3'}

  @FR-08
  Scénario: K-06 L'acte 3 s'affiche au clic accepté
    Soit la checklist go/no-go est affichée
    Et l'indicateur d'acte affiche {'Acte 2/3'}
    Quand je clique sur {'Bloquer la release'}
    Alors l'indicateur d'acte affiche {'Acte 3/3'}

  @FR-08
  Scénario: K-06 L'indicateur ne recule jamais tout seul
    Soit la checklist go/no-go est affichée
    Et je clique sur {'Bloquer la release'}
    Et l'indicateur d'acte affiche {'Acte 3/3'}
    Quand je dis {'Concentre-toi sur Android et compare avec la 3.3'}
    Alors l'indicateur d'acte affiche {'Acte 3/3'}

  @FR-08
  Scénario: K-06 Le clic manuel sur l'indicateur corrige l'acte
    Soit la checklist go/no-go est affichée
    Et l'indicateur d'acte affiche {'Acte 2/3'}
    Quand je clique sur l'indicateur d'acte
    Alors l'indicateur d'acte affiche {'Acte 3/3'}
    Quand je clique sur l'indicateur d'acte
    Alors l'indicateur d'acte affiche {'Acte 1/3'}

  @FR-08
  Scénario: K-06 La remise à vide ramène à l'acte 1
    Soit la checklist go/no-go est affichée
    Et l'indicateur d'acte affiche {'Acte 2/3'}
    Quand je clique sur Remettre à vide
    Alors l'indicateur d'acte affiche {'Acte 1/3'}

  @FR-08
  Scénario: K-07 Le statut Bloquée est visible en entier
    Soit la fenêtre de l'app fait {1366} sur {768} px
    Et la checklist go/no-go est affichée
    Quand je clique sur {'Bloquer la release'}
    Alors le statut de la checklist passe à {'Bloquée'}
    Et le statut de la checklist est visible en entier

  @FR-08
  Scénario: K-07 Le bouton passe à fait sans nouvelle requête
    Soit la checklist go/no-go est affichée
    Et je clique sur {'Bloquer la release'}
    Et le statut de la checklist passe à {'Bloquée'}
    Et je note le nombre de requêtes d'action reçues
    Alors le bouton {'block_release'} affiche {'fait'}
    Et le bouton {'block_release'} est inactif
    Quand je clique sur le bouton {'block_release'}
    Alors le faux backend n'a reçu aucune requête d'action depuis

  @FR-08
  Scénario: K-07 Une demande vocale qui réécrit la checklist réactive le bouton
    Soit la checklist go/no-go est affichée
    Et je clique sur {'Bloquer la release'}
    Et le statut de la checklist passe à {'Bloquée'}
    Et le bouton {'block_release'} est inactif
    Quand je dis {'Concentre-toi sur Android et compare avec la 3.3'}
    Alors le bouton {'block_release'} est actif
