// Génère lib/src/generated/scene_tokens.g.dart depuis tokens/*.tokens.json.
//
// Outil de développement uniquement : l'application n'exécute jamais Node.
// Le fichier généré est committé ; son en-tête porte le sha256 des tokens,
// recalculé par test/tokens_hash_test.dart (même algorithme : fichiers
// triés par nom, contenu brut concaténé).
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import StyleDictionary from 'style-dictionary';

const packageDir = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const tokensDir = join(packageDir, 'tokens');
const outputDir = join(packageDir, 'lib', 'src', 'generated');
const outputName = 'scene_tokens.g.dart';

const tokenFiles = readdirSync(tokensDir)
  .filter((name) => name.endsWith('.tokens.json'))
  .sort();
if (tokenFiles.length === 0) {
  throw new Error(`Aucun fichier *.tokens.json dans ${tokensDir}`);
}

const hash = createHash('sha256');
for (const name of tokenFiles) hash.update(readFileSync(join(tokensDir, name)));
const tokensSha256 = hash.digest('hex');

const upperFirst = (word) => word.charAt(0).toUpperCase() + word.slice(1);

/** `scene.color.okBackground` devient `colorOkBackground`. */
function dartName(path) {
  const [root, first, ...rest] = path;
  if (root !== 'scene') throw new Error(`Token hors scène : ${path.join('.')}`);
  return first + rest.map(upperFirst).join('');
}

/** Retourne [type Dart, expression Dart] d'un token résolu. */
function dartValue(token) {
  const value = token.$value;
  const where = token.path.join('.');
  switch (token.$type) {
    case 'color': {
      if (value.colorSpace !== 'srgb' || !/^#[0-9A-Fa-f]{6}$/.test(value.hex)) {
        throw new Error(`Couleur sRGB hexadécimale attendue : ${where}`);
      }
      return ['Color', `Color(0xFF${value.hex.slice(1).toUpperCase()})`];
    }
    case 'dimension': {
      if (value.unit !== 'px') throw new Error(`Unité px attendue : ${where}`);
      return ['double', Number(value.value).toFixed(1)];
    }
    case 'duration': {
      if (value.unit !== 'ms') throw new Error(`Unité ms attendue : ${where}`);
      return ['Duration', `Duration(milliseconds: ${Number(value.value)})`];
    }
    case 'fontWeight': {
      if (!Number.isInteger(value) || value < 100 || value > 900 || value % 100) {
        throw new Error(`Graisse 100 à 900 attendue : ${where}`);
      }
      return ['FontWeight', `FontWeight.w${value}`];
    }
    case 'number':
      return ['double', Number(value).toFixed(1)];
    default:
      throw new Error(`Type de token non géré (${token.$type}) : ${where}`);
  }
}

StyleDictionary.registerFormat({
  name: 'dart/scene-tokens',
  format: ({ dictionary }) => {
    const lines = dictionary.allTokens
      .filter((token) => token.path[0] === 'scene')
      .map((token) => {
        const [type, expression] = dartValue(token);
        return `  static const ${type} ${dartName(token.path)} = ${expression};`;
      });
    return [
      '// GENERATED CODE - DO NOT MODIFY BY HAND',
      '// Source : tokens/*.tokens.json ; régénérer par tool/build_tokens.sh.',
      `// tokens-sha256: ${tokensSha256}`,
      '',
      "import 'dart:ui' show Color, FontWeight;",
      '',
      '/// Valeurs de la scène issues des tokens de conception (DTCG).',
      'abstract final class SceneTokens {',
      ...lines,
      '}',
      '',
    ].join('\n');
  },
});

const styleDictionary = new StyleDictionary({
  source: tokenFiles.map((name) => join(tokensDir, name)),
  usesDtcg: true,
  log: { warnings: 'error', verbosity: 'default' },
  platforms: {
    dart: {
      // Noms uniques par chemin complet (sinon « background » entre en collision).
      transforms: ['name/camel'],
      buildPath: `${outputDir}/`,
      files: [{ destination: outputName, format: 'dart/scene-tokens' }],
    },
  },
});

await styleDictionary.buildAllPlatforms();
execFileSync('dart', ['format', join(outputDir, outputName)], {
  stdio: 'inherit',
});
