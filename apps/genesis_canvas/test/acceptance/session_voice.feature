# language: fr
Fonctionnalité: Session voix, orbe et rendu du flux vivant
  Pour mener sa démo à la voix, le speaker démarre une session par le relais
  du backend, voit l'orbe suivre la voix de l'IA et la surface de l'agent
  Qualité apparaître. Les échecs sont annoncés honnêtement, sans plantage.

  Contexte:
    Étant donné un faux backend local
    Et l'app lancée sur ce backend

  After:
    Alors l'app est fermée et le faux backend arrêté

  Scénario: V1 Une phrase donne une surface
    Étant donné une session voix démarrée
    Quand le serveur émet la phrase du speaker et la délégation
    Alors la ligne {'user'} de la transcription affiche {'Prépare la release 3.4'}
    Quand le serveur émet l'agent Qualité au travail
    Alors l'agent {'Qualité'} est affiché {'en cours'}
    Quand le serveur émet les trois temps de la surface
    Alors une surface affiche le texte {'Sessions sans crash'}
    Et la valeur liée au modèle de données est affichée
    Quand le serveur émet la fin de l'activité de l'agent Qualité
    Alors l'agent {'Qualité'} est affiché {'terminé'}
    Et la ligne {'ai'} de la transcription affiche {'analyse de la release'}

  Scénario: V2 L'orbe suit la voix
    Étant donné une session voix démarrée
    Quand le serveur émet un niveau d'orbe de {'0.1'}
    Alors le niveau lissé de l'orbe monte
    Quand le serveur émet un niveau d'orbe de {'0'}
    Alors le niveau lissé de l'orbe retombe à zéro
    Et l'orbe est au repos

  Scénario: V3 L'offre part au relais
    Quand je clique sur Démarrer
    Alors le relais a reçu l'offre du transport
    Et le transport a appliqué l'answer du relais
    Et l'app ouvre ensuite le canal temps réel de cette session
    Et le bouton Arrêter est affiché

  Scénario: V3 Arrêter libère la session
    Étant donné une session voix démarrée
    Quand je clique sur Arrêter
    Alors le relais a reçu un DELETE de cette session
    Et le transport est libéré dans l'ordre après le DELETE
    Et le bouton Démarrer est affiché

  Scénario: V3 Redémarrer ouvre un transport neuf
    Étant donné une session voix démarrée
    Et je clique sur Arrêter
    Quand je clique sur Démarrer
    Alors deux transports distincts ont été créés
    Et le relais a reçu une offre par transport
    Et la session active est la seconde du relais

  Scénario: V3 Un double Démarrer, une session
    Quand je clique deux fois sur Démarrer
    Alors une session voix est active
    Et un seul transport a été créé
    Et le relais a reçu une seule offre

  Scénario: V4 Backend injoignable
    Étant donné le faux backend en mode {'unreachable'}
    Quand je clique sur Démarrer
    Alors le message d'état contient {'injoignable'}
    Et l'orbe est au repos
    Et le transport est libéré
    Et le bouton Démarrer est affiché

  Scénario: V4 Relais saturé (429)
    Étant donné le faux backend en mode {'rate-limited'}
    Quand je clique sur Démarrer
    Alors le message d'état contient {'Trop de demandes'}
    Et l'orbe est au repos
    Et le transport est libéré
    Et le bouton Démarrer est affiché

  Scénario: V4 Relais en erreur (502)
    Étant donné le faux backend en mode {'bad-gateway'}
    Quand je clique sur Démarrer
    Alors le message d'état contient {'relais'}
    Et l'orbe est au repos
    Et le transport est libéré
    Et le bouton Démarrer est affiché

  Scénario: V4 Nouvel essai après un échec
    Étant donné le faux backend en mode {'unreachable'}
    Et je clique sur Démarrer
    Et le message d'état contient {'injoignable'}
    Quand le faux backend redevient joignable
    Et je clique sur Démarrer
    Alors une session voix est active
    Et aucun message d'état n'est affiché
    Et deux transports distincts ont été créés

  Scénario: V5 Connexion perdue en pleine session
    Étant donné une session voix démarrée
    Et le serveur a émis toute la session enregistrée
    Quand la connexion temps réel est coupée par le réseau
    Alors le message d'état contient {'Connexion perdue'}
    Et une surface affiche le texte {'Sessions sans crash'}
    Et le relais a reçu un DELETE de cette session
    Et le transport est libéré
    Et l'orbe est au repos
    Et le bouton Démarrer est affiché

  Scénario: V5bis Fermeture décidée par le backend
    Étant donné une session voix démarrée
    Quand le backend ferme la session pour la raison {'expired'}
    Alors le message d'état contient {'expirée'}
    Et le transport est libéré
    Et le relais n'a reçu aucun DELETE
    Et le bouton Démarrer est affiché
