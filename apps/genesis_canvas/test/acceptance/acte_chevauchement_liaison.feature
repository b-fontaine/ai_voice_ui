# language: fr
Fonctionnalité: Couper la parole à l'IA en parlant, et liaison animée de délégation
  Pour garder la main sans prononcer de mot d'arrêt, le speaker interrompt l'IA
  en prenant simplement la parole, et voit dans le rail quel agent travaille
  pour l'orchestrateur (spec 015 : pdr-0077, pdr-0080).
  S-05 et O-01 (côté app) : voice.interrupted de cause « overlap » coupe la
  piste distante comme les autres causes. L'orbe passe par « Interrompue » ;
  reçue alors que l'orbe écoute déjà (le fournisseur coupe sa voix avant le
  message), l'interruption rend aussitôt l'écoute et la piste.
  L-01 à L-04 (FR-03, Q-85) : une liaison `delegation-link-<agent>` relie
  l'orchestrateur à chaque agent « en attente » ou « en cours ».
  Le détecteur côté serveur est couvert par les scénarios Go O-01 à O-08.

  Contexte:
    Étant donné les polices réelles de la scène sont chargées
    Et un faux backend local
    Et l'app lancée sur ce backend avec une horloge virtuelle

  After:
    Alors l'app est fermée, le faux backend arrêté et la sémantique libérée

  @S-05 @FR-13 @FR-15 @FR-19
  Scénario: S-05 Couper la parole à l'IA sans mot d'arrêt coupe la piste distante et tronque la réplique
    Soit le tableau de la release 3.4 est affiché
    Et le serveur émet une réplique de l'IA {'Le tableau Android est prêt'} commencée à {2000} ms
    Et la ligne {'ai'} de la transcription affiche {'Le tableau Android est prêt'}
    Et le serveur émet un niveau d'orbe de {'0.4'}
    Et l'orbe est à l'état {'parole'}
    Quand le serveur émet l'interruption de cause overlap à {2500} ms
    Alors la piste distante est coupée
    Et l'orbe est à l'état {'Interrompue'}
    Quand le serveur émet une réplique de l'IA {' et la décision attend'} commencée à {3000} ms
    Alors la ligne {'ai'} de la transcription n'affiche pas {'la décision attend'}
    Et les surfaces affichées sont {'kpi,trend,reviews,checklist'}
    Quand le serveur émet un niveau d'orbe de {'0'}
    Et le serveur émet la délégation de la correction à {4000} ms
    Alors l'orbe est à l'état {'Écoute'}
    Et la piste distante est rétablie

  @S-05 @FR-13 @FR-19
  Scénario: S-05 Pendant le chevauchement la demande du speaker rend la parole à l'IA
    Soit le tableau de la release 3.4 est affiché
    Et le serveur émet un niveau d'orbe de {'0.4'}
    Et le serveur émet l'interruption de cause overlap à {2500} ms
    Et l'orbe est à l'état {'Interrompue'}
    Et la piste distante est coupée
    Quand le serveur émet un niveau d'orbe de {'0'}
    Et le serveur émet la délégation de la correction à {4000} ms
    Alors l'orbe est à l'état {'Écoute'}
    Et la piste distante est rétablie
    Et les surfaces affichées sont {'kpi,trend,reviews,checklist'}

  @S-05 @FR-13 @FR-19
  Scénario: S-05 bis La délégation du speaker arrive avant l'interruption de cause overlap
    Soit le tableau de la release 3.4 est affiché
    Et le serveur émet un niveau d'orbe de {'0.4'}
    Quand le serveur émet la délégation de la correction à {4000} ms
    Et le serveur émet l'interruption de cause overlap à {2500} ms
    Alors l'orbe est à l'état {'Écoute'}
    Et la piste distante est rétablie
    Et les surfaces affichées sont {'kpi,trend,reviews,checklist'}

  @S-05 @FR-13 @FR-19
  Scénario: O-01 Sans délégation, le silence de reprise rend l'écoute et la piste
    Soit le tableau de la release 3.4 est affiché
    Et le serveur émet un niveau d'orbe de {'0.4'}
    Et le serveur émet l'interruption de cause overlap à {2500} ms
    Et l'orbe est à l'état {'Interrompue'}
    Quand le serveur émet un niveau d'orbe de {'0'}
    Et {3} secondes s'écoulent sans parole de l'IA
    Alors l'orbe est à l'état {'Écoute'}
    Et la piste distante est rétablie
    Et les surfaces affichées sont {'kpi,trend,reviews,checklist'}

  @S-05 @FR-13 @FR-19
  Scénario: O-01 Une délégation antérieure à l'interruption ne met pas fin à l'interruption
    Soit le tableau de la release 3.4 est affiché
    Et le serveur émet un niveau d'orbe de {'0.4'}
    Et le serveur émet la délégation de la correction à {1000} ms
    Et le serveur émet un niveau d'orbe de {'0.4'}
    Quand le serveur émet l'interruption de cause overlap à {2500} ms
    Alors l'orbe est à l'état {'Interrompue'}
    Et la piste distante est coupée

  @S-05 @FR-13 @FR-19
  Scénario: O-01 Reçue alors que l'orbe écoute déjà, l'interruption rend aussitôt l'écoute et la piste
    Soit le tableau de la release 3.4 est affiché
    Et l'orbe est à l'état {'Écoute'}
    Quand le serveur émet l'interruption de cause overlap à {2500} ms
    Alors l'orbe est à l'état {'Écoute'}
    Et la piste distante est rétablie
    Et les surfaces affichées sont {'kpi,trend,reviews,checklist'}

  @FR-03 @NFR-04
  Scénario: L-01 Une liaison relie l'orchestrateur à chaque agent en attente ou en cours
    Soit une session voix démarrée
    Quand le serveur émet le plan à trois agents
    Et le serveur émet l'activité au travail de l'agent {'Qualité'}
    Et le serveur émet l'activité au travail de l'agent {'Voix du client'}
    Alors l'agent {'Qualité'} est affiché {'en cours'}
    Et l'agent {'Voix du client'} est affiché {'en cours'}
    Et l'agent {'Livraison'} est affiché {'en attente'}
    Et la liaison de délégation de l'agent {'Qualité'} est affichée
    Et la liaison de délégation de l'agent {'Voix du client'} est affichée
    Et la liaison de délégation de l'agent {'Livraison'} est affichée

  @FR-03 @NFR-04
  Scénario: L-02 La liaison disparaît quand l'agent est terminé
    Soit une session voix démarrée
    Et le serveur émet le plan à trois agents
    Et le serveur émet l'activité au travail de l'agent {'Qualité'}
    Et la liaison de délégation de l'agent {'Qualité'} est affichée
    Quand le serveur émet l'état {'terminé'} de l'agent {'Qualité'}
    Alors l'agent {'Qualité'} est affiché {'terminé'}
    Et la liaison de délégation de l'agent {'Qualité'} n'est plus affichée
    Et la liaison de délégation de l'agent {'Voix du client'} est affichée

  @FR-03 @NFR-04
  Scénario: L-02 La liaison disparaît quand l'agent est en échec
    Soit une session voix démarrée
    Et le serveur émet le plan à trois agents
    Et le serveur émet l'activité au travail de l'agent {'Qualité'}
    Et la liaison de délégation de l'agent {'Qualité'} est affichée
    Quand le serveur émet l'état {'échec'} de l'agent {'Qualité'}
    Alors l'agent {'Qualité'} est affiché {'échec'}
    Et la liaison de délégation de l'agent {'Qualité'} n'est plus affichée
    Et la liaison de délégation de l'agent {'Voix du client'} est affichée

  @FR-03 @NFR-04
  Scénario: L-02 La liaison disparaît quand l'agent est hors périmètre
    Soit une session voix démarrée
    Et le serveur émet le plan à trois agents
    Et le serveur émet l'activité au travail de l'agent {'Qualité'}
    Et la liaison de délégation de l'agent {'Qualité'} est affichée
    Quand le serveur émet l'état {'hors périmètre'} de l'agent {'Qualité'}
    Alors l'agent {'Qualité'} est affiché {'hors périmètre'}
    Et la liaison de délégation de l'agent {'Qualité'} n'est plus affichée
    Et la liaison de délégation de l'agent {'Voix du client'} est affichée

  @FR-03 @NFR-04
  Scénario: L-02 La liaison disparaît quand l'agent est interrompu
    Soit une session voix démarrée
    Et le serveur émet le plan à trois agents
    Et le serveur émet l'activité au travail de l'agent {'Qualité'}
    Et la liaison de délégation de l'agent {'Qualité'} est affichée
    Quand le serveur émet l'annulation de l'agent Qualité
    Alors l'agent {'Qualité'} est affiché {'interrompu'}
    Et la liaison de délégation de l'agent {'Qualité'} n'est plus affichée
    Et la liaison de délégation de l'agent {'Voix du client'} est affichée

  @FR-03 @NFR-04
  Scénario: L-02 Aucun agent retenu, aucune liaison
    Soit une session voix démarrée
    Et le serveur émet le plan à trois agents
    Et la liaison de délégation de l'agent {'Qualité'} est affichée
    Quand le serveur émet un plan vide
    Alors le rail affiche {'aucun agent retenu'}
    Et aucune liaison de délégation n'est affichée

  @FR-03 @NFR-04
  Scénario: L-03 Animations du système coupées, la liaison reste et ne bouge plus
    Soit une session voix démarrée
    Et les animations du système sont désactivées
    Et le serveur émet le plan à trois agents
    Et le serveur émet l'activité au travail de l'agent {'Qualité'}
    Et la liaison de délégation de l'agent {'Qualité'} est affichée
    Quand je note l'image de la liaison de délégation de l'agent {'Qualité'}
    Et {130} millisecondes s'écoulent
    Alors la liaison de délégation de l'agent {'Qualité'} est identique à l'image notée
    Quand {130} millisecondes s'écoulent
    Alors la liaison de délégation de l'agent {'Qualité'} est identique à l'image notée

  @FR-03 @NFR-04
  Scénario: L-03 Témoin, animations actives, les pointillés défilent
    Soit une session voix démarrée
    Et le serveur émet le plan à trois agents
    Et le serveur émet l'activité au travail de l'agent {'Qualité'}
    Et la liaison de délégation de l'agent {'Qualité'} est affichée
    Quand je note l'image de la liaison de délégation de l'agent {'Qualité'}
    Et {130} millisecondes s'écoulent
    Alors la liaison de délégation de l'agent {'Qualité'} diffère de l'image notée

  @FR-03 @FR-09
  Scénario: L-04 Pendant le rejeu, aucune liaison n'est affichée
    Soit une session voix démarrée
    Et le serveur émet le plan à trois agents et leur activité au travail
    Et la liaison de délégation de l'agent {'Qualité'} est affichée
    Et le serveur émet la surface {'kpi'} en trois temps
    Et le serveur émet la fin de l'activité des trois agents
    Et la liaison de délégation de l'agent {'Qualité'} n'est plus affichée
    Quand je clique sur Lecture
    Et le rejeu avance de {1.5} secondes
    Alors aucune liaison de délégation n'est affichée
