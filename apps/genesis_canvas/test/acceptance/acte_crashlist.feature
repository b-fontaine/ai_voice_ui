# language: fr
Fonctionnalité: Liste des crashs - cinquième surface du canevas
  Pour montrer que la liste des crashs de la 3.4 s'ajoute au tableau sans le
  refabriquer, le serveur émet la surface `crashes` (composant `CrashList`,
  données `/crashes`) après les quatre surfaces de l'acte 1 : la grille passe
  de 2 × 2 à 3 × 2, la liste prend la cinquième cellule (rang de lecture) et
  les quatre moteurs de rendu gardent leur `State` (spec 012, F-01 et F-02 ;
  pdr-0074 D5 et D9, A7 et A8 du plan). Les messages sont définis par le test
  (les exemples `crashlist-*` du contrat arrivent avec T11). L'état neutre
  (champ de mauvais type, ligne sans libellé) est un test de rendu, pas une
  fixture de refus (A8, RG-10).

  Contexte:
    Étant donné un faux backend local
    Et l'app lancée sur ce backend en relevant ses erreurs

  After:
    Alors l'app est fermée et le faux backend arrêté

  @F-01 @FR-01 @FR-06
  Scénario: F-01 La liste des crashs devient la cinquième cellule sans recréer les quatre autres
    Soit le tableau de la release 3.4 est affiché
    Quand le serveur émet la liste des crashs jusqu'au temps {'data'}
    Alors la surface {'crashes'} affiche {'Principaux crashs · 3.4'}
    Et le canevas affiche une grille de {3} colonnes sur {2} lignes
    Et les surfaces du canevas se lisent dans l'ordre {'kpi, trend, reviews, checklist, crashes'}
    Et les surfaces de l'acte 1 gardent leur State
    Et l'étagère affiche {'5 / 6 utilisés'}
    Et le composant {'CrashList'} de l'étagère est {'utilisé'}
    Et aucun squelette n'est réapparu
    Et aucun message A2UI n'est refusé

  @F-02 @FR-01 @RG-10
  Scénario: F-02 La liste des crashs passe par le squelette, l'absence de données puis les données
    Soit le tableau de la release 3.4 est affiché
    Quand le serveur émet la liste des crashs jusqu'au temps {'skeleton'}
    Alors un squelette est visible pour la surface {'crashes'}
    Quand le serveur émet la liste des crashs jusqu'au temps {'components'}
    Alors aucune ligne de la liste des crashs n'est affichée
    Et aucun squelette n'est visible pour la surface {'crashes'}
    Et la surface {'crashes'} n'affiche pas l'état neutre
    Quand le serveur émet la liste des crashs jusqu'au temps {'data'}
    Alors la liste des crashs affiche {5} lignes
    Et la surface {'crashes'} affiche {'Plantage à la validation du panier (3-D Secure 2)'}
    Et la surface {'crashes'} affiche {'Plantage à l\'ouverture d\'une notification push'}
    Et aucune erreur n'est signalée
    Et aucun message A2UI n'est refusé

  @F-02 @NFR-03
  Scénario: F-02 Le texte de la liste est lisible et les libellés longs tiennent sur deux lignes au plus
    Soit le tableau de la release 3.4 est affiché
    Quand le serveur émet la liste des crashs jusqu'au temps {'data'}
    Alors la liste des crashs affiche {5} lignes
    Et le texte de la liste des crashs fait au moins {24} px
    Et chaque libellé de la liste des crashs tient sur {2} lignes au plus puis une ellipse
    Et aucune erreur n'est signalée

  @F-02 @RG-10
  Scénario: F-02 Un champ items de mauvais type donne l'état neutre
    Soit le tableau de la release 3.4 est affiché
    Quand le serveur émet la liste des crashs dont le champ {'items'} est une chaîne
    Alors la surface {'crashes'} affiche l'état neutre {'Données indisponibles'}
    Et aucune ligne de la liste des crashs n'est affichée
    Et les surfaces de l'acte 1 gardent leur State
    Et aucune erreur n'est signalée

  @F-02 @RG-10
  Scénario: F-02 Une ligne sans libellé donne l'état neutre
    Soit le tableau de la release 3.4 est affiché
    Quand le serveur émet la liste des crashs dont une ligne n'a pas de libellé
    Alors la surface {'crashes'} affiche l'état neutre {'Données indisponibles'}
    Et aucune ligne de la liste des crashs n'est affichée
    Et les surfaces de l'acte 1 gardent leur State
    Et aucune erreur n'est signalée
