# StatusBadge
Pastille d'état d'un critère ou d'une release : Validé, À risque, Bloquant, En attente.

- Classes : `gc-badge` + `gc-badge--go | --warn | --nogo | --idle`, `gc-badge--lg` pour le verdict.
- Le mot est obligatoire : la couleur ne porte jamais seule l'information (daltonisme, projecteur délavé).
- Seul `--nogo` pulse (`gc-beacon`). Une seule chose doit attirer l'œil.
- **À risque** = seuil respecté mais marge < 0,1 pt. Si ce n'est pas votre règle, ne l'affichez pas : un 99,57 % ≥ 99,50 % marqué « à risque » sans explication sera contesté dans la salle.
