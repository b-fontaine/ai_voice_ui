# language: fr
Fonctionnalité: Acte 2 - transformer sans recréer
  Pour montrer qu'une phrase transforme l'écran sans le refabriquer, le
  speaker demande Android et la comparaison avec la 3.3 : le serveur ne
  renvoie que des mises à jour de données (updateDataModel, aucun
  createSurface), les quatre surfaces gardent leur place et leur état, et la
  comparaison s'ajoute dans les composants existants (pdr-0064, D1, D2, D7).
  S-02 de product/functional/features/voice-screen-generation.feature ; B1, B2
  et B4 viennent de la spec 008 (A7). « Android seul » se cherche dans le
  canevas seul : le panneau du protocole et le rail peuvent citer iOS.

  Contexte:
    Étant donné les polices réelles de la scène sont chargées
    Et un faux backend local
    Et l'app lancée sur ce backend en relevant ses erreurs

  After:
    Alors l'app est fermée et le faux backend arrêté

  @S-02 @FR-07
  Scénario: S-02 Acte 2 - transformer sans recréer
    Étant donné le tableau de la release 3.4 est affiché
    Quand je dis {'Concentre-toi sur Android et compare avec la 3.3'}
    Alors les surfaces existantes restent à leur place
    Et les données affichées concernent uniquement Android
    Et une comparaison avec la 3.3 apparaît

  Scénario: B1 Une seconde session transforme le tableau de la première
    Étant donné le tableau de la release 3.4 est affiché
    Et je clique sur Arrêter
    Et je clique sur Démarrer
    Et la session active est la seconde du relais
    Quand je dis {'Concentre-toi sur Android et compare avec la 3.3'}
    Alors aucun message A2UI n'est refusé
    Et les surfaces existantes restent à leur place
    Et aucun squelette n'est réapparu
    Et les données affichées concernent uniquement Android
    Et une comparaison avec la 3.3 apparaît

  Scénario: B2 La correction vers iOS retire la comparaison sans recréer
    Étant donné le tableau de la release 3.4 est affiché
    Et je dis {'Concentre-toi sur Android et compare avec la 3.3'}
    Et une comparaison avec la 3.3 apparaît
    Quand je dis {'Non, plutôt iOS'}
    Alors la ligne de comparaison de la surface {'kpi'} a disparu
    Et la ligne de comparaison de la surface {'reviews'} a disparu
    Et la courbe ne contient que la série {'iOS 3.4'}
    Et la surface {'kpi'} affiche {'99,80 %'}
    Et la surface {'checklist'} affiche {'GO iOS'}
    Et les surfaces existantes restent à leur place
    Et aucun squelette n'est réapparu
    Et aucun message A2UI n'est refusé

  Scénario: B4 La ligne de comparaison de l'indicateur clé est neutre
    Étant donné le tableau de la release 3.4 est affiché
    Quand je dis {'Concentre-toi sur Android et compare avec la 3.3'}
    Alors la ligne de comparaison de la surface {'kpi'} affiche {'3.3 : 99,71 % · −0,28 pt'}
    Et la ligne de comparaison de la surface {'reviews'} affiche {'3.3 : 14 % négatifs · +16 pts'}
    Et la ligne de comparaison de la surface {'kpi'} n'a pas de couleur de statut

  Scénario: B4 Une comparaison sans écart omet seulement sa ligne
    Étant donné le tableau de la release 3.4 est affiché
    Et je dis {'Concentre-toi sur Android et compare avec la 3.3'}
    Et la ligne de comparaison de la surface {'kpi'} affiche {'3.3 : 99,71 % · −0,28 pt'}
    Quand le serveur émet l'acte 2 de la surface {'kpi'} sans le champ {'delta'} de la comparaison
    Alors la surface {'kpi'} affiche {'99,43 %'}
    Et la ligne de comparaison de la surface {'kpi'} a disparu
    Et la surface {'kpi'} n'affiche pas l'état neutre
    Et aucune erreur n'est signalée

  Scénario: B4 Une comparaison sans valeur omet seulement sa ligne
    Étant donné le tableau de la release 3.4 est affiché
    Et je dis {'Concentre-toi sur Android et compare avec la 3.3'}
    Et la ligne de comparaison de la surface {'reviews'} affiche {'3.3 : 14 % négatifs · +16 pts'}
    Quand le serveur émet l'acte 2 de la surface {'reviews'} sans le champ {'value'} de la comparaison
    Alors la surface {'reviews'} affiche {'30 %'}
    Et la ligne de comparaison de la surface {'reviews'} a disparu
    Et la surface {'reviews'} n'affiche pas l'état neutre
    Et aucune erreur n'est signalée
