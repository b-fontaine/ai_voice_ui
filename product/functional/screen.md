---
id: p-fn-screen
title: Écran unique, orbe vocal et raccourcis
area: functional
status: validated
updated: 2026-10-30
sources: [specs/009-j5-act3-interact/status.md, specs/007-j3-act1-frontend/spec.md, specs/007-j3-act1-frontend/status.md, product/sources/product-description.pdf#p7, product/sources/product-description.pdf#p8, product/sources/product-description.pdf#p9, product/sources/product-description.pdf#p10, product/sources/design-example.pdf]
links: [pdr-0065-009-act3-interact-details-assistant-decided, p-fn-dataset-acts, p-ar-frontend-screen, pdr-0054-stage-screen-orb-acts-checklist, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, pdr-0063-007-stage-ui-details-assistant-decided, pdr-0053-client-side-a2ui-validation-from-007, p-fn-requirements, p-fn-business-rules, p-fn-catalog, p-fn-mockups, p-ar-frontend, pdr-0008-single-screen-show-the-making, pdr-0002-desktop-platform, ux-voice-multimodal, ux-desktop-shortcuts, ux-desktop-focus, rt-barge-in, rt-transcription, pdr-0032-obs-video-fallback-a2ui-replay-act, pdr-0033-optional-shortcuts-mouse-first]
tags: [ecran, zones, orbe, raccourcis, interaction]
---
# Écran unique « Genesis Canvas »

**En bref.** Un seul écran, projeté en 16:9 (1920×1080), montre en même temps le **résultat** (le canevas) et sa **fabrication** (agents, protocole, catalogue). Six zones, sept états de l'orbe vocal, trois modes d'interaction (fiche § 6, p. 7-10). Décision : [pdr-0008](../decisions/pdr-0008-single-screen-show-the-making.md).

Un pointillé relie le message en cours dans le flux du protocole au composant qu'il construit dans le canevas (fiche § 6, légende de la maquette fonctionnelle).

## Les 6 zones (fiche § 6)

| Zone | Ce qu'elle montre | Comportement | FR |
|---|---|---|---|
| **Barre supérieure** | Orbe vocal, transcription de la conversation, forme d'onde | Les répliques du speaker et de l'IA s'affichent en direct ; une réplique coupée est tronquée | FR-02, FR-19 |
| **Canevas génératif** | Les surfaces générées (6 au maximum) | Vide au départ ; chaque surface passe par squelette, composants, données ; une modification transforme sur place | FR-01, FR-04, FR-07 |
| **Rail des agents** | L'orchestrateur et les 3 agents spécialisés | Un agent s'allume quand il est sollicité, avec sa tâche ; une liaison animée montre la délégation | FR-03 |
| **Flux du protocole** | Les messages d'interface envoyés par les agents | Replié par défaut, déplié à la demande ; le message en cours est mis en évidence et relié à son composant | FR-05 |
| **Étagère du catalogue** | Les 6 composants disponibles ([pdr-0014](../decisions/pdr-0014-six-component-catalog.md)) | Le composant choisi par l'agent s'allume au moment où il est utilisé | FR-06 |
| **Rejeu** | Un curseur sur l'historique de la session | Rejoue la construction au ralenti ou en accéléré ; sert aussi de mode secours | FR-09, FR-10 — mode secours retiré ([pdr-0032](../decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md)) : la zone sert l'acte 4 (flux A2UI seul) |

Libellés vus dans les maquettes : « AGENTS A2A » (rail), « FLUX A2UI · live » (flux), « CATALOGUE · n / 6 utilisés » (étagère), « CANEVAS · release-3-4 ». La zone Rejeu n'apparaît sur aucune maquette (écart E13 · Q-31, [p-fn-mockups](mockups.md)).

## Les six zones telles que livrées (007, 2026-10-30)

Fiche muette sur les détails d'interface : tranchés par la boucle sous [pdr-0062](../decisions/pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details.md), contestables par le porteur ([pdr-0063](../decisions/pdr-0063-007-stage-ui-details-assistant-decided.md)). Implémentation : [p-ar-frontend-screen](../architecture/frontend-screen.md).

| Zone | Telle que livrée |
|---|---|
| **Barre supérieure** (+ régie) | orbe, transcription, bouton Démarrer ; **indicateur d'acte** « Acte n/3 · Créer / Transformer / Interagir » (D1) et bouton **« Remettre à vide »** (D4) empilés dans la barre, sans zone « régie » séparée ; l'indicateur vaut 1 par défaut, un clic passe à l'acte suivant (souris d'abord), retour à 1 à la remise à vide ; le bouton est inactif tant qu'un agent travaille ou attend |
| **Rail des agents** | piloté par le message `plan` (D5, RG-29) : l'orchestrateur, puis les agents du plan, sans nom codé en dur ; états en toutes lettres (« en attente », « en cours », « terminé », « échec », « hors périmètre ») ; un agent non retenu est **« en veille »** ; plan vide : **« aucun agent retenu »** (RG-08) ; rail vide tant qu'aucun `plan` n'est arrivé (RG-01) |
| **Canevas** | surfaces au rang du contrat (indicateur clé, courbe, avis, checklist), grille 2×2 (6 surfaces au plus) ; **bandeau de 72 px sous la grille** pour la Barre d'actions (009, pdr-0065 D7), réservé dès la première surface ; **contour pointillé** autour de la surface du message en cours (D2) |
| **Flux du protocole** | **replié en bas à droite** ; déplié (clic), il recouvre le canevas à droite **sans le redimensionner** ; message en cours mis en évidence, messages refusés marqués « refusé » ; JSON affiché brut |
| **Étagère** | « CATALOGUE · n / 6 utilisés » ; « 4 / 6 » en fin d'acte 1, **« 5 / 6 »** quand la Barre d'actions apparaît (fin de l'acte 2, 009), Liste des crashs « inutilisée » (FR-06) |
| **Rejeu** | **emplacement** « REJEU », commandes inactives jusqu'à J6 (D3) |

D6 : composants au seul thème de scène (RG-09), statuts par codes fermés `ok|risk|blocking`, courbe dessinée sans nouvelle dépendance.

**Budget des zones à 1920×1080** (modifié par 009, [pdr-0065](../decisions/pdr-0065-009-act3-interact-details-assistant-decided.md) D8) : barre supérieure **128 px** (160 en 007), rail ≤ 200 px, canevas **572 px** (520 en 007 : grille 2×250 + bandeau de la Barre d'actions de 72 px ; cellules ≈ 940×250), rangée du bas ≤ 140 px (étagère, Rejeu, panneau replié), marges et intervalles **40 px** au total à la verticale (60 en 007 ; marge verticale 18 → 8 px) ; texte ≥ 24 px partout (NFR-05), aucun défilement ni mise à l'échelle. ⚠️ **Limite assumée** : l'écran suppose 1920×1080 (la fenêtre Linux s'ouvre à cette taille) ; en dessous, les zones débordent ; projection 16:9 en 1080p de la machine de démo ([pdr-0028](../decisions/pdr-0028-linux-demo-machine.md)).

**À valider par le porteur** (détail d'interface tranché par la boucle sous pdr-0062, contestable) : le bandeau étant réservé dès la première surface, **une bande vide de 72 px reste en bas du canevas pendant les actes 1 et 2**. C'est le prix d'une grille qui ne bouge pas quand la barre arrive (S-02 : « les surfaces existantes restent à leur place »). Une grille 3×2 évitait la bande mais déplaçait les quatre surfaces ; seul le porteur peut assouplir S-02. Les couleurs de bordure des deux boutons sont aussi un choix de la boucle (contrastes mesurés).

## États de l'orbe vocal (fiche § 6, p. 9)

| État | Signification | Rendu visuel |
|---|---|---|
| Repos | Session ouverte, personne ne parle | Pulsation lente |
| Écoute | Le speaker parle | L'orbe suit le volume de la voix |
| Réflexion | Les agents travaillent | Rotation, agents allumés dans le rail |
| Parole | L'IA parle | L'orbe suit la voix de l'IA |
| Interrompue | Le speaker vient de couper l'IA | Arrêt net, bref flash, retour à « Écoute » |
| Micro coupé | Le speaker a coupé son micro | Orbe grisé barré |
| Secours | Rejeu d'une session enregistrée | Indicateur discret dans un coin — **retiré (pdr-0032)** |

Transitions déduites de la fiche (synthèse de l'assistant, à relire) :

```mermaid
stateDiagram-v2
    [*] --> Repos
    Repos --> Ecoute : le speaker parle
    Ecoute --> Reflexion : fin de phrase, agents sollicités
    Reflexion --> Parole : l'IA commente (RG-04)
    Parole --> Interrompue : le speaker parle (FR-13) ou raccourci silence (FR-20)
    Interrompue --> Ecoute : immédiat
    Parole --> Repos : fin de réplique
    Repos --> MicroCoupe : touche M (FR-12)
    MicroCoupe --> Repos : touche M
```

L'état Secours et la transition « touche B » (FR-10) sont retirés par [pdr-0032](../decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md) : le secours est une vidéo gérée par le porteur.

⚠️ Les maquettes affichent la pastille « EN ÉCOUTE » pendant la planification et la construction, là où la fiche prévoit « Réflexion » (écart E12 · Q-30 tranché : la fiche s'applique, [pdr-0054](../decisions/pdr-0054-stage-screen-orb-acts-checklist.md)). Repères : [ux-voice-multimodal], [rt-barge-in].

## Modes d'interaction (fiche § 6, p. 9)

| Mode | Usage | Qui |
|---|---|---|
| **Voix** (principal) | Demander, modifier, corriger, couper la parole à l'IA | Speaker |
| **Clic sur un composant généré** | La réponse de l'agent arrive à la voix et dans l'interface ; livré par 009 pour la Barre d'actions (boutons inactifs pendant l'action) | Speaker |
| **Clavier** | Régie de scène (raccourcis ci-dessous) | Réservé au speaker |

## Raccourcis clavier proposés (fiche § 6, p. 10)

Tranché (E5 · Q-05, [pdr-0033](../decisions/pdr-0033-optional-shortcuts-mouse-first.md)) : les raccourcis sont **facultatifs**. Toute action critique a un contrôle cliquable ; un raccourci ne s'ajoute que s'il ne pose pas de problème (focus, conflit).

| Touche | Action | Exigence |
|---|---|---|
| Espace | Faire taire l'IA | FR-20 |
| M | Couper ou rétablir le micro | FR-12 |
| P | Déplier ou replier le flux du protocole | FR-05 (zone flux) |
| R | Remettre le canevas à vide | FR-11 ; **non fourni** : bouton « Remettre à vide » (007, [pdr-0033](../decisions/pdr-0033-optional-shortcuts-mouse-first.md)) |
| ~~B~~ | ~~Basculer en mode secours~~ | ~~FR-10~~ retirée (pdr-0032) |
| ← / → | Reculer ou avancer dans le rejeu | FR-09 ; pas de pas-à-pas : lecture, pause et vitesse suffisent (Q-52 → [pdr-0059](../decisions/pdr-0059-acts-2-3-and-replay-simplifications.md)) |

Points d'attention (assistant) :
- Sur desktop, Espace active aussi le bouton qui a le focus (par exemple « Bloquer la release ») ; un raccourci Flutter ne se déclenche que dans le sous-arbre focalisé ([ux-desktop-shortcuts], [ux-desktop-focus]).
- NFR-12 est assoupli (pdr-0033) : une action critique sans raccourci fiable reste faisable à la souris.

## Barre supérieure : transcription

La transcription affiche les deux voix en direct ; la réplique de l'IA coupée est tronquée à l'endroit de l'interruption (FR-19). Sources de transcription par fournisseur : [rt-transcription].
