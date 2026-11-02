# Spike jetable : échelle de graisses (017, T10)

Prouve avec le vrai moteur (Impeller OpenGLES, Linux sous Xvfb) que les polices
variables Space Grotesk et JetBrains Mono rendent les graisses 400 à 700. Les
trois fichiers de police sont des copies de
`packages/shared/design_system/assets/fonts/` (le paquet du design system est en
`resolution: workspace`, un projet hors workspace ne peut pas en dépendre). Hors
workspace et hors porte.

```
flutter build linux --debug
GDK_BACKEND=x11 SPIKE_PNG=$PWD/weights.png xvfb-run -a -s "-screen 0 1920x1080x24" \
  build/linux/x64/debug/bundle/ds_fonts_weight_spike
```

Imprime l'encre mesurée de chaque ligne (lignes `INK`) et écrit `weights.png`.
