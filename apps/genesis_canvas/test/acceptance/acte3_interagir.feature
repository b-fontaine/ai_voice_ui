# language: fr
Fonctionnalité: Acte 3 - interagir avec un composant généré
  Pour montrer qu'un clic sur un composant généré déclenche un vrai travail
  d'agent, le speaker clique sur « Bloquer la release » dans la Barre d'actions :
  l'app transmet l'action au backend (POST /canvas/actions), l'agent Livraison
  s'allume dans le rail, puis le statut de la checklist change ; les critères,
  la recommandation et la comparaison 3.3 ne bougent pas (pdr-0065, D1 à D7).
  S-03 de product/functional/features/voice-screen-generation.feature ; C1, C3,
  C6 et A1 viennent de la spec 009. « L'IA confirme à la voix » de la fiche est
  vérifié côté backend (scénario Go S-03, un seul Announce après completed) : le
  faux backend de l'app n'a pas de voix à écouter.

  Contexte:
    Étant donné un faux backend local
    Et l'app lancée sur ce backend en relevant ses erreurs

  After:
    Alors l'app est fermée et le faux backend arrêté

  @S-03 @FR-03 @FR-08
  Scénario: S-03 Acte 3 - interagir avec un composant généré
    Soit la checklist go/no-go est affichée
    Quand je clique sur {'Bloquer la release'}
    Alors le faux backend a reçu l'action {'block_release'} de la surface {'actions'}
    Et l'agent Livraison s'allume dans le rail
    Et l'agent {'Qualité'} est affiché {'en veille'}
    Et l'agent {'Voix du client'} est affiché {'en veille'}
    Et l'agent {'Livraison'} est affiché {'terminé'}
    Et le statut de la checklist passe à {'Bloquée'}
    Et les critères, la recommandation et la comparaison sont inchangés
    Et aucun message A2UI n'est refusé

  @FR-08
  Scénario: C1 Valider la release affiche Validée
    Soit la checklist go/no-go est affichée
    Quand je clique sur {'Valider la release'}
    Alors le faux backend a reçu l'action {'validate_release'} de la surface {'actions'}
    Et le statut de la checklist passe à {'Validée'}
    Et les critères, la recommandation et la comparaison sont inchangés

  @FR-08
  Scénario: C1 La décision humaine la plus récente prime
    Soit la checklist go/no-go est affichée
    Et je clique sur {'Bloquer la release'}
    Et le statut de la checklist passe à {'Bloquée'}
    Quand je clique sur {'Valider la release'}
    Alors le faux backend a reçu l'action {'validate_release'} de la surface {'actions'}
    Et le statut de la checklist passe à {'Validée'}

  Scénario: C3 Un 409 occupé est réessayé puis l'action aboutit
    Soit la checklist go/no-go est affichée
    Et le faux backend répond occupé {1} fois aux actions puis les accepte
    Quand je clique sur {'Bloquer la release'}
    Alors le faux backend a reçu {2} requêtes d'action
    Et le statut de la checklist passe à {'Bloquée'}

  Scénario: C3 Les réessais sont bornés puis les boutons redeviennent actifs
    Soit la checklist go/no-go est affichée
    Et le faux backend répond occupé {50} fois aux actions puis les accepte
    Quand je clique sur {'Bloquer la release'}
    Alors le faux backend n'a pas reçu plus de {10} requêtes d'action après le délai des réessais
    Et les boutons de la Barre d'actions sont actifs
    Et le statut de la checklist ne passe pas à {'Bloquée'}

  Scénario: C3 Les boutons sont inactifs de l'envoi jusqu'à la fin de l'action
    Soit la checklist go/no-go est affichée
    Et le faux backend suspend l'action après l'avoir acceptée
    Et les boutons de la Barre d'actions sont actifs
    Quand je clique sur {'Bloquer la release'}
    Alors le faux backend a reçu l'action {'block_release'} de la surface {'actions'}
    Et les boutons de la Barre d'actions sont inactifs
    Quand le serveur émet le début de l'action
    Alors l'agent {'Livraison'} est affiché {'en cours'}
    Et les boutons de la Barre d'actions sont inactifs
    Quand le serveur émet le résultat de l'action
    Alors le statut de la checklist passe à {'Bloquée'}
    Et les boutons de la Barre d'actions sont actifs

  Scénario: C6 La Barre d'actions passe par le squelette puis les composants puis les données
    Soit le tableau de la release 3.4 est affiché
    Quand le serveur émet la Barre d'actions jusqu'au temps {'skeleton'}
    Alors un squelette est visible pour la surface {'actions'}
    Quand le serveur émet la Barre d'actions jusqu'au temps {'components'}
    Alors aucun bouton d'action n'est affiché
    Et aucun squelette n'est visible pour la surface {'actions'}
    Quand le serveur émet la Barre d'actions jusqu'au temps {'data'}
    Alors la surface {'actions'} affiche {'Décision'}
    Et la surface {'actions'} affiche {'Bloquer la release'}
    Et la surface {'actions'} affiche {'Valider la release'}
    Et les boutons de la Barre d'actions sont actifs

  Scénario: C6 Une action hors contrat donne l'état neutre
    Soit le tableau de la release 3.4 est affiché
    Quand le serveur émet la Barre d'actions avec l'action inconnue {'delete_release'}
    Alors la surface {'actions'} affiche l'état neutre {'Données indisponibles'}
    Et aucun bouton d'action n'est affiché

  Scénario: C6 Les boutons sont lisibles et atteignables
    Soit la checklist go/no-go est affichée
    Alors les boutons de la Barre d'actions sont actifs
    Et les boutons de la Barre d'actions ont un texte d'au moins {24} px et une cible d'au moins {48} px

  Scénario: A1 La Barre d'actions arrive sous la grille sans bouger les quatre surfaces
    Soit le tableau de la release 3.4 est affiché
    Quand je dis {'Concentre-toi sur Android et compare avec la 3.3'}
    Et le serveur émet la Barre d'actions de la fin de l'acte 2
    Alors la surface {'actions'} affiche {'Bloquer la release'}
    Et la Barre d'actions est affichée sous la grille
    Et les surfaces existantes restent à leur place
    Et l'étagère affiche {'5 / 6 utilisés'}
    Et aucun squelette n'est réapparu
