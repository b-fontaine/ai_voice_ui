# language: fr
Fonctionnalité: Acte 1 - créer le tableau de release
  Pour montrer la fabrication de l'interface, le speaker dit une phrase : le
  rail allume les agents retenus, un squelette apparaît pour chaque surface,
  puis les données complètent les quatre surfaces du catalogue genesis.
  S-01 de product/functional/features/voice-screen-generation.feature ; les
  seuils de 1,5 s et de 8 s sont lus dans le journal horodaté, pas assertés.

  Contexte:
    Étant donné un faux backend local
    Et l'app lancée sur ce backend

  After:
    Alors l'app est fermée et le faux backend arrêté

  @S-01
  Scénario: S-01 Acte 1 - créer le tableau de release
    Étant donné le canevas est vide
    Et une session voix démarrée
    Quand le serveur émet la phrase du speaker et la délégation
    Alors la ligne {'user'} de la transcription affiche {'Prépare la release 3.4'}
    Quand le serveur émet le plan à trois agents et leur activité au travail
    Alors l'agent {'Qualité'} est affiché {'en cours'}
    Et l'agent {'Voix du client'} est affiché {'en cours'}
    Et l'agent {'Livraison'} est affiché {'en cours'}
    Quand le serveur émet la création des quatre surfaces
    Alors un squelette est visible pour chaque surface
    Quand le serveur émet les composants des quatre surfaces
    Alors aucune valeur n'est encore affichée
    Quand le serveur émet les données des quatre surfaces
    Alors la surface {'kpi'} affiche {'99,57 %'}
    Et la surface {'trend'} affiche {'Taux de crash du jour'}
    Et la surface {'reviews'} affiche {'24 %'}
    Et la surface {'checklist'} affiche {'Checklist go/no-go'}
