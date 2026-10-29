# 000 — Outillage de boucle dans l'app

> **En bref.** Le squelette de l'app Genesis Canvas existe, compile sous Linux et sait, en mode debug, **rejouer un flux A2UI v0.9 enregistré puis écrire une capture PNG de sa fenêtre et se fermer**. C'est ce qui permet à la boucle de voir l'app tourner sans micro, sans réseau et sans coût (`tools/loop/app-smoke.sh`).

- **Jalon** : J2 (socle du walking skeleton)
- **Exigences visées** : FR-01 (canevas vide au démarrage), FR-04 (surface en trois temps, version minimale), NFR-10 (versions figées), base de FR-09 (rejeu A2UI)
- **Décisions applicables** : pdr-0018 (A2UI v0.9, genui 0.10.4), pdr-0028 (Linux), pdr-0010 (versions figées), pdr-0015 (mise en page tenue par l'app), pdr-0032 (rejeu = flux A2UI seul), adr-0001 (Clean + FSD, Bloc, get_it/injectable, TDD/BDD)
- **Hors périmètre** : voix, backend, agents, catalogue métier (composants du catalogue de base genui seulement), thème de scène définitif

## Scénarios (Gherkin)
Scénarios propres à l'outillage, à ajouter dans `apps/genesis_canvas/test/acceptance/loop_harness.feature` :
- **H-01** Étant donné l'app lancée sans scénario, alors le canevas est vide et l'orbe est visible (FR-01 ; reprend le début de S-01).
- **H-02** Étant donné l'app lancée avec le scénario `act1-replay`, quand le rejeu se termine, alors une surface affiche le texte « Sessions sans crash » et la valeur liée au modèle de données.
- **H-03** Étant donné `GENESIS_SNAPSHOT=<chemin>`, quand le rejeu se termine, alors un PNG non vide est écrit à ce chemin et l'app se ferme avec le code 0.

## Critères d'acceptation
- [ ] H-01 à H-03 automatisés et verts (`gate.sh --full`)
- [ ] `tools/loop/app-smoke.sh` produit une capture lisible sous Xvfb (ou `UNAVAILABLE` si Xvfb manque)
- [ ] Workspace pub racine, versions exactes (`genui: 0.10.4` ; `genui_a2a: 0.10.1` est ajouté avec la fonctionnalité A2A, qui l'utilise — amendé le 2026-10-29 après la revue), `pubspec.lock` committé
- [ ] Aucun `getIt` hors racine de composition ; Bloc pour l'état du canevas (pas de Cubit)
- [ ] Revue d'architecte : CONFORME

## Questions ouvertes
- Aucune bloquante. Le format du fichier de rejeu (JSONL de messages A2UI horodatés) préfigure le journal de session de pdr-0032 ; à harmoniser dans la fonctionnalité « rejeu » (J6).
