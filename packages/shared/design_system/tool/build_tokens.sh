#!/usr/bin/env bash
# Régénère lib/src/generated/scene_tokens.g.dart (développement uniquement).
# Node n'est jamais requis à l'exécution de l'application ni par la porte :
# le fichier généré est committé et son hash est contrôlé par un test Dart.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
# Les paquets npm embarquent des pubspec.yaml d'exemple que la porte (verify.sh)
# prendrait pour des paquets Flutter du dépôt : node_modules ne reste jamais sur
# le disque après la génération.
trap 'rm -rf node_modules' EXIT
npm ci --ignore-scripts --no-audit --no-fund
node build_tokens.mjs
