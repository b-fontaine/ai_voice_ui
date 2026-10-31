---
id: p-fn-screen
title: Écran unique, orbe vocal et raccourcis
area: functional
status: validated
updated: 2026-10-31
sources: [specs/012-llm-composer-crashlist/status.md, specs/011-voice-interaction/spec.md, specs/011-voice-interaction/status.md, specs/010-j6-act4-replay/spec.md, specs/010-j6-act4-replay/status.md, specs/009-j5-act3-interact/status.md, specs/007-j3-act1-frontend/spec.md, specs/007-j3-act1-frontend/status.md, product/sources/product-description.pdf#p7, product/sources/product-description.pdf#p8, product/sources/product-description.pdf#p9, product/sources/product-description.pdf#p10, product/sources/design-example.pdf]
links: [p-fn-feature-llm-composer-012, pdr-0074-012-llm-composer-gateway-crashlist-details, pdr-0069-voice-interruption-hybrid-stop-011, pdr-0071-act2-focus-memory-act-indicator-click-feedback, pdr-0073-011-voice-interaction-details-assistant-decided, p-ar-voice-interruption, pdr-0066-010-act4-replay-details-assistant-decided, pdr-0072-design-ergonomics-013, p-ar-replay, pdr-0065-009-act3-interact-details-assistant-decided, p-fn-dataset-acts, p-ar-frontend-screen, pdr-0054-stage-screen-orb-acts-checklist, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, pdr-0063-007-stage-ui-details-assistant-decided, pdr-0053-client-side-a2ui-validation-from-007, p-fn-requirements, p-fn-business-rules, p-fn-catalog, p-fn-mockups, p-ar-frontend, pdr-0008-single-screen-show-the-making, pdr-0002-desktop-platform, ux-voice-multimodal, ux-desktop-shortcuts, ux-desktop-focus, rt-barge-in, rt-transcription, pdr-0032-obs-video-fallback-a2ui-replay-act, pdr-0033-optional-shortcuts-mouse-first]
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
| **Barre supérieure** (+ régie) | orbe, transcription, bouton Démarrer ; **indicateur d'acte** « Acte n/3 · Créer / Transformer / Interagir » (D1) et bouton **« Remettre à vide »** (D4) empilés dans la barre, sans zone « régie » séparée ; l'indicateur vaut 1 par défaut et **avance tout seul depuis 011** ([pdr-0071](../decisions/pdr-0071-act2-focus-memory-act-indicator-click-feedback.md)) : acte 2 quand la Barre d'actions apparaît, acte 3 au clic accepté, jamais en arrière, sans effet en rejeu ; un clic manuel passe à l'acte suivant pour corriger (souris d'abord) ; retour à 1 à la remise à vide ; le bouton est inactif tant qu'un agent travaille ou attend |
| **Rail des agents** | piloté par le message `plan` (D5, RG-29) : l'orchestrateur, puis les agents du plan, sans nom codé en dur ; états en toutes lettres (« en attente », « en cours », « terminé », « échec », « hors périmètre ») ; un agent non retenu est **« en veille »** ; plan vide : **« aucun agent retenu »** (RG-08) ; rail vide tant qu'aucun `plan` n'est arrivé (RG-01) |
| **Canevas** | surfaces au rang du contrat (indicateur clé, courbe, avis, checklist), grille **2×2 jusqu'à 4 surfaces, 3×2 dès la cinquième** (6 surfaces au plus ; la liste des crashs, 012, est la cinquième cellule, [p-fn-catalog](catalog.md)) ; **bandeau de 72 px sous la grille** pour la Barre d'actions (009, pdr-0065 D7), réservé dès la première surface ; **contour pointillé** autour de la surface du message en cours (D2) |
| **Flux du protocole** | **replié en bas à droite** ; déplié (clic), il recouvre le canevas à droite **sans le redimensionner** ; message en cours mis en évidence, messages refusés marqués « refusé » ; JSON affiché brut |
| **Étagère** | « CATALOGUE · n / 6 utilisés » ; « 4 / 6 » en fin d'acte 1, **« 5 / 6 »** quand la Barre d'actions apparaît (fin de l'acte 2, 009) **ou** quand la liste des crashs est demandée (012, « 6 / 6 » avec les deux) ; Liste des crashs « inutilisée » tant qu'elle n'a pas été demandée (FR-06) |
| **Rejeu** | **zone active depuis 010** (voir ci-dessous) ; emplacement « REJEU » aux commandes inactives en 007 (D3) |

D6 : composants au seul thème de scène (RG-09), statuts par codes fermés `ok|risk|blocking`, courbe dessinée sans nouvelle dépendance.

**Budget des zones à 1920×1080** (modifié par 009, [pdr-0065](../decisions/pdr-0065-009-act3-interact-details-assistant-decided.md) D8) : barre supérieure **128 px** (160 en 007), rail ≤ 200 px, canevas **572 px** (520 en 007 : grille 2×250 + bandeau de la Barre d'actions de 72 px ; cellules ≈ 940×250, ≈ 620×250 en grille 3×2 depuis 012), rangée du bas ≤ 140 px (étagère **900 px**, Rejeu **480 px** depuis 010, panneau replié 460 px), marges et intervalles **40 px** au total à la verticale (60 en 007 ; marge verticale 18 → 8 px) ; texte ≥ 24 px partout (NFR-05), aucun défilement ni mise à l'échelle. ⚠️ **Limite assumée** : l'écran suppose 1920×1080 (la fenêtre Linux s'ouvre à cette taille) ; en dessous, les zones débordent ; projection 16:9 en 1080p de la machine de démo ([pdr-0028](../decisions/pdr-0028-linux-demo-machine.md)).

**À valider par le porteur** (détail d'interface tranché par la boucle sous pdr-0062, contestable) : le bandeau étant réservé dès la première surface, **une bande vide de 72 px reste en bas du canevas pendant les actes 1 et 2**. C'est le prix d'une grille qui ne bouge pas quand la barre arrive (S-02 : « les surfaces existantes restent à leur place »). Une grille 3×2 évitait la bande mais déplaçait les quatre surfaces ; seul le porteur peut assouplir S-02. Les couleurs de bordure des deux boutons sont aussi un choix de la boucle (contrastes mesurés).

## Zone Rejeu et acte 4 (010, 2026-10-30)

FR-09 livrée ; la fiche ne détaille pas les commandes : détails tranchés par la boucle sous pdr-0062 ([pdr-0066](../decisions/pdr-0066-010-act4-replay-details-assistant-decided.md) D1 à D8, contestables). Mécanisme : [p-ar-replay](../architecture/replay.md) ; implémentation : [p-ar-frontend-screen](../architecture/frontend-screen.md) § Acte 4.

| Élément | Comportement |
|---|---|
| Disposition | zone de **480 px** à 1920×1080, **deux rangées de 48 px** (étagère ramenée de 1040 à 900 px) : rangée 1 « REJEU », Lecture/Pause (un bouton), Recommencer, curseur, « Direct » ; rangée 2 : vitesses 0,25×, 0,5×, 1×, 1,5×, 2× (1× par défaut, la vitesse choisie est gardée par Recommencer) |
| Entrée | « Lecture » : sans appel backend ; inactif sans surface créée au journal, pendant qu'un agent travaille ou qu'une action est en cours |
| Indicateur d'acte | « Acte 4 · Rejeu » (texte seul, non cliquable) pendant le rejeu |
| En rejeu | le canevas se vide puis se reconstruit comme en direct ; le panneau du protocole suit le message rejoué et reste déplié pendant un positionnement (FR-05) ; « Démarrer » et les boutons du canevas sont inactifs ; la session voix n'est pas touchée ; les messages A2UI vivants sont écartés |
| Curseur | couvre la durée comprimée (silence plafonné à 3 s entre deux messages) ; un seul positionnement au relâchement |
| Sortie | « Direct » (toujours actif) ou « Remettre à vide » : remise à vide complète, journal vidé |

⚠️ **À voir avec le porteur en répétition** (détails d'interface tranchés par la boucle, rien n'est décidé par le porteur) : le titre du panneau reste « FLUX A2UI · live » pendant le rejeu (cosmétique) ; le rail des agents est vide pendant le rejeu (seul le flux A2UI est rejoué, pdr-0032) ; plafond d'écart de 3 s ; place de la zone Rejeu dans la rangée du bas. Hors périmètre de 010 : panneau déplié qui déborde de 39 px, boutons d'acte et de remise à vide à 44 px (013, [pdr-0072](../decisions/pdr-0072-design-ergonomics-013.md)).

## États de l'orbe vocal (fiche § 6, p. 9)

| État | Signification | Rendu visuel |
|---|---|---|
| Repos | Session ouverte, personne ne parle | Pulsation lente |
| Écoute | Le speaker parle | L'orbe suit le volume de la voix |
| Réflexion | Les agents travaillent | Rotation, agents allumés dans le rail |
| Parole | L'IA parle | L'orbe suit la voix de l'IA |
| Interrompue | Le speaker vient de couper l'IA | Arrêt net, bref flash, retour à « Écoute » ; **livré par 011** sur « Stop » (orbe à niveau 0, son distant coupé, réplique tronquée) |
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
    Interrompue --> Ecoute : silence de 3 s ou 15 s au plus (011)
    Parole --> Repos : fin de réplique
    Repos --> MicroCoupe : touche M (FR-12)
    MicroCoupe --> Repos : touche M
```

⚠️ **À voir avec le porteur en répétition** (détail tranché par la boucle sous pdr-0062, la fiche ne chiffre pas la durée) : « Interrompue » est tenue jusqu'à 3 s de silence (`GENESIS_INTERRUPT_RESUME_SILENCE_MS`) ou 15 s au plus, pas seulement un flash ; la transition « immédiat » du schéma est une déduction de l'assistant. Couper la parole **sans** dire « Stop » ne passe pas par « Interrompue » (S-05 en partie, Q-77).

L'état Secours et la transition « touche B » (FR-10) sont retirés par [pdr-0032](../decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md) : le secours est une vidéo gérée par le porteur.

⚠️ Les maquettes affichent la pastille « EN ÉCOUTE » pendant la planification et la construction, là où la fiche prévoit « Réflexion » (écart E12 · Q-30 tranché : la fiche s'applique, [pdr-0054](../decisions/pdr-0054-stage-screen-orb-acts-checklist.md)). Repères : [ux-voice-multimodal], [rt-barge-in].

## Modes d'interaction (fiche § 6, p. 9)

| Mode | Usage | Qui |
|---|---|---|
| **Voix** (principal) | Demander, modifier, corriger, couper la parole à l'IA | Speaker |
| **Clic sur un composant généré** | La réponse de l'agent arrive à la voix et dans l'interface ; livré par 009 pour la Barre d'actions ; **retour au clic fort depuis 011** : indicateur « en cours » pendant l'envoi, pastille de décision (« Bloquée » / « Validée ») visible en entier, bouton « <libellé> · fait ✓ » désactivé sans nouvelle requête, réactivé si une demande vocale réécrit la checklist (Q-76) | Speaker |
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
| ← / → | Reculer ou avancer dans le rejeu | FR-09 ; **non fourni** (010) : pas de pas-à-pas : lecture, pause et vitesse suffisent (Q-52 → [pdr-0059](../decisions/pdr-0059-acts-2-3-and-replay-simplifications.md)) |

Points d'attention (assistant) :
- Sur desktop, Espace active aussi le bouton qui a le focus (par exemple « Bloquer la release ») ; un raccourci Flutter ne se déclenche que dans le sous-arbre focalisé ([ux-desktop-shortcuts], [ux-desktop-focus]).
- NFR-12 est assoupli (pdr-0033) : une action critique sans raccourci fiable reste faisable à la souris.

## Barre supérieure : transcription

La transcription affiche les deux voix en direct ; la réplique de l'IA coupée est tronquée à l'endroit de l'interruption (FR-19). Sources de transcription par fournisseur : [rt-transcription].
