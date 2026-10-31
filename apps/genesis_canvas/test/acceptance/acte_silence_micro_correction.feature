# language: fr
Fonctionnalité: Faire taire l'IA, couper le micro et corriger en vol
  Pour garder la main pendant sa démo sans fermer la session, le speaker fait
  taire l'IA et coupe son micro à la souris (bouton ou raccourci facultatif),
  et corrige sa demande sans mot d'arrêt (spec 014 : pdr-0033, pdr-0076).
  S-09 : le bouton « Faire taire » et la touche Échap coupent la piste distante
  sans fermer la session ni annuler de génération.
  M-01 et M-02 : couper le micro désactive la piste locale (la capture n'est
  pas arrêtée) et pose un voile « Micro coupé » par-dessus l'orbe.
  S-07 (côté app) : avec voice.interrupted de cause « correction », la première
  délégation datée 1500 ms après la coupure rend la parole à l'IA.
  Que la coupure de piste soit audible sous Linux relève de Q-79 (hypothèse).

  Contexte:
    Étant donné les polices réelles de la scène sont chargées
    Et un faux backend local
    Et l'app lancée sur ce backend avec une horloge virtuelle

  After:
    Alors l'app est fermée, le faux backend arrêté et la sémantique libérée

  @S-09 @FR-20 @NFR-12
  Scénario: S-09 Faire taire l'IA par le bouton
    Soit une session voix démarrée
    Et le serveur émet un niveau d'orbe de {'0.4'}
    Et l'orbe est à l'état {'parole'}
    Quand je clique sur la commande {'silence-button'}
    Alors la piste distante est coupée
    Et l'orbe est à l'état {'Interrompue'}
    Et la session reste ouverte
    Quand le serveur émet un niveau d'orbe de {'0'}
    Et {3} secondes s'écoulent sans parole de l'IA
    Alors l'orbe est à l'état {'Écoute'}
    Et la piste distante est rétablie
    Et la session reste ouverte

  @S-09 @FR-20 @NFR-12
  Scénario: S-09 Faire taire l'IA par la touche Échap
    Soit une session voix démarrée
    Et le serveur émet un niveau d'orbe de {'0.4'}
    Et l'orbe est à l'état {'parole'}
    Quand j'appuie sur la touche Échap
    Alors la piste distante est coupée
    Et l'orbe est à l'état {'Interrompue'}
    Et la session reste ouverte

  @FR-12 @NFR-12
  Scénario: M-01 Couper puis rétablir le micro
    Soit une session voix démarrée
    Et je note l'état de l'orbe
    Quand je clique sur la commande {'mic-button'}
    Alors le voile {'Micro coupé'} est affiché
    Et la session reste ouverte
    Quand je clique sur la commande {'mic-button'}
    Alors le voile {'Micro coupé'} n'est plus affiché
    Et l'orbe est revenu à l'état noté
    Et la session reste ouverte

  @FR-12
  Scénario: M-02 Micro coupé, la piste est désactivée sans arrêter la capture
    Soit une session voix démarrée
    Quand je clique sur la commande {'mic-button'}
    Alors la piste du micro est désactivée
    Et la capture du micro n'est pas arrêtée
    Et la session reste ouverte
    Quand je clique sur la commande {'mic-button'}
    Alors la piste du micro est active

  @S-07 @FR-14 @FR-17
  Scénario: S-07 Une correction rend la parole à l'IA dès la réponse à la correction
    Soit le tableau de la release 3.4 est affiché
    Et le serveur émet un niveau d'orbe de {'0.4'}
    Et le serveur émet l'interruption de cause correction à {2500} ms
    Et l'orbe est à l'état {'Interrompue'}
    Et la piste distante est coupée
    Quand le serveur émet un niveau d'orbe de {'0'}
    Et le serveur émet la délégation de la correction à {4000} ms
    Alors l'orbe est à l'état {'Écoute'}
    Et la piste distante est rétablie
    Et les surfaces affichées sont {'kpi,trend,reviews,checklist'}
