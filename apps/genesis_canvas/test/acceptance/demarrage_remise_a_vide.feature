# language: fr
Fonctionnalité: Démarrage de l'app - remise à vide du canevas du backend
  Avec la mutation par données seules (pdr-0064, D1), une mutation qui vise
  une surface que l'app ne connaît pas est refusée (unknown_surface). L'app,
  vide au démarrage, demande donc une fois POST /canvas/reset avant la première
  session voix, en mode vivant seulement (D6, A3 du plan 008).

  After:
    Alors l'app est fermée et le faux backend arrêté

  Scénario: A3 En mode vivant, l'app vide le canevas du backend avant la première session
    Étant donné un faux backend local
    Et l'app lancée sur ce backend
    Alors le faux backend a reçu une requête de remise à vide au démarrage
    Et aucune session voix n'a été créée
    Quand je clique sur Démarrer
    Alors le relais a reçu l'offre du transport
    Et la remise à vide précède la première session
    Et le faux backend a reçu exactement une requête de remise à vide

  Scénario: A3 En mode rejeu, l'app ne demande aucune remise à vide
    Étant donné un faux backend local
    Et l'app lancée en rejeu {'act1-replay'} sur ce backend
    Quand le rejeu est joué
    Alors le faux backend n'a reçu aucune requête de remise à vide
