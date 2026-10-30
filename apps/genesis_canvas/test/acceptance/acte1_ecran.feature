# language: fr
Fonctionnalité: Acte 1 - écran de fabrication (rail, panneau, étagère, remise à vide)
  Scénarios d'acceptation propres à la spec 007 (A1 à A5) : ils vérifient
  FR-03, FR-05, FR-06 et FR-11, qui n'ont pas de scénario dans la fiche.

  Contexte:
    Étant donné un faux backend local
    Et l'app lancée sur ce backend

  After:
    Alors l'app est fermée et le faux backend arrêté

  Scénario: A1 Un plan à un agent allume cet agent et met les autres en veille
    Étant donné une session voix démarrée
    Quand le serveur émet la phrase {'Montre-moi les avis'}
    Et le serveur émet un plan qui retient seulement l'agent {'Voix du client'}
    Et le serveur émet l'activité au travail de l'agent {'Voix du client'}
    Alors l'agent {'Voix du client'} est affiché {'en cours'}
    Et l'agent {'Qualité'} est affiché {'en veille'}
    Et l'agent {'Livraison'} est affiché {'en veille'}

  Scénario: A1 Un plan vide affiche aucun agent retenu
    Étant donné une session voix démarrée
    Quand le serveur émet un plan vide
    Alors le rail affiche {'aucun agent retenu'}

  Scénario: A2 Le panneau du protocole est replié par défaut et se déplie au clic
    Étant donné une session voix démarrée
    Quand le serveur émet la surface {'kpi'} en trois temps
    Alors le panneau protocole est replié
    Quand je clique sur le bouton du panneau protocole
    Alors le panneau protocole est déplié

  Scénario: A2 Le message en cours est relié à sa surface par un contour pointillé
    Étant donné une session voix démarrée
    Quand le serveur émet la surface {'kpi'} en trois temps
    Et le serveur émet la surface {'trend'} en trois temps
    Et je clique sur le bouton du panneau protocole
    Alors le message en cours est mis en évidence dans le panneau
    Et la surface {'trend'} porte le contour pointillé
    Et la surface {'kpi'} ne porte pas le contour pointillé

  Scénario: A2 L'étagère affiche quatre composants utilisés sur six
    Étant donné une session voix démarrée
    Quand le serveur émet toute la session de l'acte 1 du contrat
    Alors l'étagère affiche {'4 / 6 utilisés'}
    Et le composant {'KeyIndicator'} de l'étagère est {'utilisé'}
    Et le composant {'TrendChart'} de l'étagère est {'utilisé'}
    Et le composant {'ReviewSentiment'} de l'étagère est {'utilisé'}
    Et le composant {'ReleaseChecklist'} de l'étagère est {'utilisé'}
    Et le composant {'ActionBar'} de l'étagère est {'inutilisé'}
    Et le composant {'CrashList'} de l'étagère est {'inutilisé'}

  Scénario: A3 Un composant hors catalogue est refusé et le flux continue
    Étant donné une session voix démarrée
    Et je clique sur le bouton du panneau protocole
    Quand le serveur émet la fixture refusée {'component_not_allowed'}
    Alors le panneau protocole affiche un message {'refusé'}
    Et aucune surface n'est affichée
    Quand le serveur émet la surface {'kpi'} en trois temps
    Alors la surface {'kpi'} affiche {'99,57 %'}

  Scénario: A4 La remise à vide efface l'acte 1 et le panneau reste vide
    Étant donné une session voix démarrée
    Et le serveur émet toute la session de l'acte 1 du contrat
    Et l'agent {'Livraison'} est affiché {'terminé'}
    Et l'étagère affiche {'4 / 6 utilisés'}
    Et je clique sur le bouton du panneau protocole
    Et je clique sur l'indicateur d'acte
    Et l'indicateur d'acte affiche {'Acte 2/3'}
    Quand je clique sur Remettre à vide
    Alors le faux backend a reçu exactement une requête de remise à vide
    Et le canevas est vide
    Et aucune surface n'est affichée
    Et le panneau protocole est vide
    Et l'étagère affiche {'0 / 6 utilisés'}
    Et le rail ne contient plus aucun agent du plan
    Et l'indicateur d'acte affiche {'Acte 1/3'}

  Scénario: A5 Des données incomplètes donnent l'état neutre sans casser la démo
    Étant donné une session voix démarrée
    Quand le serveur émet l'indicateur clé sans sa valeur
    Alors la surface {'kpi'} affiche l'état neutre {'Données indisponibles'}
    Et aucune erreur n'est signalée
    Quand le serveur émet la surface {'trend'} en trois temps
    Alors la surface {'trend'} affiche {'Taux de crash du jour'}
