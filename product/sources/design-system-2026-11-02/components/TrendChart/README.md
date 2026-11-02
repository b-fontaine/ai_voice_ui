# TrendChart
Série quotidienne de la version courante contre la précédente et le seuil.

- Version courante : `signal`, trait plein 3px + halo. Précédente : `baseline`, pointillé. Seuil : `nogo`, tirets.
- Les deux versions diffèrent en **luminance et en motif**, jamais par une teinte proche (deux bleus = illisible).
- Zone `breach` rouge translucide là où la série franchit le seuil, annotée (« seuil franchi dès J3 »).
- Axe Y gradué avec unité. Animation `gc-wipe` (révélation gauche→droite 1,6 s), tête de série pulsée.
- Cohérence : la moyenne 7 j de la série doit égaler le KPI (ici 0,57 % de crash ↔ 99,43 % sans crash).
