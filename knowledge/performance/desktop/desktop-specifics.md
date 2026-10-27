---
id: perf-desktop-specifics
title: Desktop (Windows/macOS/Linux) — spécificités perf
tags: [desktop, windows, macos, linux, impeller, audio]
status: verified
updated: 2026-10-26
sources:
  - https://docs.flutter.dev/perf/impeller
  - https://flutter.dev/blog/whats-new-in-flutter-3-47
  - https://docs.flutter.dev/perf/app-size
  - https://pub.dev/packages/record
links: [perf-impeller-status, perf-audio-packages, perf-profile-mode-devtools, rt-provider-abstraction]
---
# Desktop : Impeller par défaut depuis 3.47, opt-out temporaire

Depuis Flutter 3.47 (2026-08-12), Impeller est le moteur par défaut sur desktop : Metal sur macOS, Vulkan sur Windows et Linux. Le texte passe par un rendu SDF, plus net, et le Wide Gamut est actif par défaut sur macOS.

**Opt-out temporaire (sera supprimé) :**
- macOS : clé `FLTEnableImpeller` à `<false/>` dans `Info.plist`.
- Windows (`main.cpp`) : `project.set_impeller_switch(flutter::ImpellerSwitch::Disabled);`.
- Linux (`my_application.cc`) : `fl_dart_project_set_enable_impeller(project, FALSE);`.

**Spécificités à surveiller (opinion, sauf mention contraire) :**
- **Linux/Windows sur Vulkan** : les VM, le RDP et les vieux GPU Intel ont des pilotes Vulkan fragiles. Tester sur le parc réel des utilisateurs Septeo, souvent sous Windows en entreprise.
- **Profiling** : `flutter run -d windows --profile` et DevTools fonctionnent comme sur mobile.
- **Taille** : `flutter build windows|macos|linux --analyze-size` fonctionne (doc app-size).
- **Audio** : les isolates sont disponibles sur desktop (contrairement au web). `record` et `flutter_soloud` supportent les trois OS (pub.dev ; `record` exige `parecord`, `pactl` et `ffmpeg` sous Linux). Vérifier les permissions micro macOS (entitlements et `NSMicrophoneUsageDescription`).
- **Fenêtres** : le multi-window desktop n'est pas couvert ici. Ne pas présumer de son état.

## ⚠️ Pièges
- **Intel Mac en fin de support** (blog 3.47) : tests Intel automatisés désactivés, warnings CLI qui deviendront des erreurs. Build ARM64 seul : `flutter config --enable-macos-arm64-only`.
- **Minimums OS relevés en 3.47** : iOS 13 → 15, macOS 10.15 → 12. Vérifier le parc des utilisateurs.
