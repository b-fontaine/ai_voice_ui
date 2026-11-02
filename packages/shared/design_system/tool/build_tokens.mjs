// Génère lib/src/generated/scene_tokens.g.dart depuis tokens/*.tokens.json.
//
// Outil de développement uniquement : l'application n'exécute jamais Node.
// Le fichier généré est committé ; son en-tête porte le sha256 des tokens,
// recalculé par test/tokens_hash_test.dart (même algorithme : fichiers
// *.tokens.json triés par nom, puis ce script, contenu brut concaténé). Le
// script entre dans le hash : modifier le générateur sans régénérer fait
// échouer le test.
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
hash.update(readFileSync(fileURLToPath(import.meta.url)));
const tokensSha256 = hash.digest('hex');

const upperFirst = (word) => word.charAt(0).toUpperCase() + word.slice(1);

/** `scene.color.okBackground` devient `colorOkBackground`. */
function dartName(path) {
  const [root, first, ...rest] = path;
  if (root !== 'scene') throw new Error(`Token hors scène : ${path.join('.')}`);
  return first + rest.map(upperFirst).join('');
}

/** Nombre Dart `double` : tous les chiffres sont conservés (aucun arrondi). */
function dartDouble(number, where) {
  if (typeof number !== 'number' || !Number.isFinite(number)) {
    throw new Error(`Nombre fini attendu : ${where}`);
  }
  const text = String(number);
  return /[.eE]/.test(text) ? text : `${text}.0`;
}

function pxValue(dimension, where) {
  if (dimension?.unit !== 'px') throw new Error(`Unité px attendue : ${where}`);
  return Number(dimension.value);
}

/** Couleur DTCG 2025.10 : hex sRGB à six chiffres et `alpha` facultatif. */
function dartColor(value, where) {
  if (value?.colorSpace !== 'srgb' || !/^#[0-9A-Fa-f]{6}$/.test(value.hex)) {
    throw new Error(`Couleur sRGB hexadécimale attendue : ${where}`);
  }
  const alpha = value.alpha ?? 1;
  if (typeof alpha !== 'number' || !(alpha >= 0 && alpha <= 1)) {
    throw new Error(`alpha entre 0 et 1 attendu : ${where}`);
  }
  // Octet d'opacité = round(alpha x 255) ; tokens_parity_test vérifie la même
  // règle contre l'octet de la source.
  const alphaByte = Math.round(alpha * 255)
    .toString(16)
    .toUpperCase()
    .padStart(2, '0');
  return `Color(0x${alphaByte}${value.hex.slice(1).toUpperCase()})`;
}

/**
 * Rayon de flou de `BoxShadow` pour un flou CSS `cssBlur` (px).
 *
 * Le flou CSS B donne un écart type gaussien sigma = B / 2. Flutter calcule
 * sigma = 0,57735 x r + 0,5 pour `blurRadius = r` (`Shadow.convertRadiusToSigma`),
 * donc r = (B / 2 - 0,5) / 0,57735. Sous B = 1 le résultat serait nul ou
 * négatif : pas de flou (r = 0). Les décalages et les étalements (spread) sont
 * recopiés tels quels.
 */
function blurRadiusFromCss(cssBlur) {
  const radius = (cssBlur / 2 - 0.5) / 0.57735;
  return radius > 0 ? radius : 0;
}

function dartShadow(value, where) {
  const layers = Array.isArray(value) ? value : [value];
  const items = layers.map((layer) => {
    if (layer?.inset === true) {
      throw new Error(
        `Ombre « inset » non exprimable par BoxShadow : ${where}. ` +
          'Exprimer le filet par un token couleur peint par le widget.',
      );
    }
    const blur = pxValue(layer.blur ?? { value: 0, unit: 'px' }, where);
    if (blur < 0) throw new Error(`Flou négatif : ${where}`);
    const spread = pxValue(layer.spread ?? { value: 0, unit: 'px' }, where);
    const offsetX = dartDouble(pxValue(layer.offsetX, where), where);
    const offsetY = dartDouble(pxValue(layer.offsetY, where), where);
    return (
      'BoxShadow(' +
      `color: ${dartColor(layer.color, where)}, ` +
      `offset: Offset(${offsetX}, ${offsetY}), ` +
      `blurRadius: ${dartDouble(blurRadiusFromCss(blur), where)}, ` +
      `spreadRadius: ${dartDouble(spread, where)})`
    );
  });
  return `<BoxShadow>[${items.join(', ')}]`;
}

function dartString(text) {
  return `'${String(text).replace(/[\\'$]/g, (c) => `\\${c}`)}'`;
}

const dartUses = {
  Color: ['dart:ui', 'Color'],
  FontWeight: ['dart:ui', 'FontWeight'],
  Offset: ['dart:ui', 'Offset'],
  BoxShadow: ['package:flutter/painting.dart', 'BoxShadow'],
  Cubic: ['package:flutter/animation.dart', 'Cubic'],
};

/** Retourne [type Dart, expression Dart] d'un token résolu. */
export function dartValue(token) {
  const value = token.$value;
  const where = token.path.join('.');
  switch (token.$type) {
    case 'color':
      return ['Color', dartColor(value, where)];
    case 'dimension':
      return ['double', dartDouble(pxValue(value, where), where)];
    case 'duration': {
      if (value.unit !== 'ms' || !Number.isInteger(Number(value.value))) {
        throw new Error(`Millisecondes entières attendues : ${where}`);
      }
      return ['Duration', `Duration(milliseconds: ${Number(value.value)})`];
    }
    case 'fontWeight': {
      if (!Number.isInteger(value) || value < 100 || value > 900 || value % 100) {
        throw new Error(`Graisse 100 à 900 attendue : ${where}`);
      }
      return ['FontWeight', `FontWeight.w${value}`];
    }
    case 'number':
      return ['double', dartDouble(Number(value), where)];
    case 'shadow':
      return ['List<BoxShadow>', dartShadow(value, where)];
    case 'cubicBezier': {
      if (!Array.isArray(value) || value.length !== 4 || !value.every(Number.isFinite)) {
        throw new Error(`cubicBezier : quatre nombres attendus : ${where}`);
      }
      if (value[0] < 0 || value[0] > 1 || value[2] < 0 || value[2] > 1) {
        throw new Error(`cubicBezier : abscisses entre 0 et 1 attendues : ${where}`);
      }
      return ['Cubic', `Cubic(${value.map((n) => dartDouble(n, where)).join(', ')})`];
    }
    case 'fontFamily': {
      if (typeof value === 'string') return ['String', dartString(value)];
      if (Array.isArray(value) && value.length > 0 && value.every((n) => typeof n === 'string')) {
        return ['List<String>', `[${value.map(dartString).join(', ')}]`];
      }
      throw new Error(`fontFamily : nom ou liste de noms attendu : ${where}`);
    }
    case 'letterSpacing': {
      // Interlettrage CSS en em, converti en px à la taille de police donnée
      // (Flutter attend des pixels logiques) ; en px, recopié.
      if (value?.unit === 'px') {
        return ['double', dartDouble(Number(value.value), where)];
      }
      if (value?.unit !== 'em') throw new Error(`Unité em ou px attendue : ${where}`);
      if (value.fontSize === undefined) {
        throw new Error(`Interlettrage en em : fontSize (px) requis : ${where}`);
      }
      const computed = Number(value.value) * pxValue(value.fontSize, where);
      // Retire le bruit de calcul flottant (-0,04 x 76 = -3,0400000000000005).
      return ['double', dartDouble(Number(computed.toPrecision(12)), where)];
    }
    default:
      throw new Error(`Type de token non géré (${token.$type}) : ${where}`);
  }
}

/** Directives `import` nécessaires aux types réellement émis. */
function dartImports(expressions) {
  const byLibrary = new Map();
  for (const [name, [library, symbol]] of Object.entries(dartUses)) {
    if (!expressions.some((text) => new RegExp(`\\b${name}\\b`).test(text))) continue;
    byLibrary.set(library, [...(byLibrary.get(library) ?? []), symbol]);
  }
  return [...byLibrary.keys()].sort().map((library) => {
    const symbols = byLibrary.get(library).sort().join(', ');
    return `import '${library}' show ${symbols};`;
  });
}

StyleDictionary.registerFormat({
  name: 'dart/scene-tokens',
  format: ({ dictionary }) => {
    const emitted = dictionary.allTokens
      .filter((token) => token.path[0] === 'scene')
      .map((token) => {
        const [type, expression] = dartValue(token);
        return { type, expression, name: dartName(token.path) };
      });
    const lines = emitted.map(
      ({ type, expression, name }) => `  static const ${type} ${name} = ${expression};`,
    );
    return [
      '// GENERATED CODE - DO NOT MODIFY BY HAND',
      '// Source : tokens/*.tokens.json ; régénérer par tool/build_tokens.sh.',
      `// tokens-sha256: ${tokensSha256}`,
      '',
      ...dartImports(emitted.flatMap(({ type, expression }) => [type, expression])),
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

// Importé par build_tokens.test.mjs : ne génère que lancé directement.
if (resolve(process.argv[1] ?? '') === fileURLToPath(import.meta.url)) {
  await styleDictionary.buildAllPlatforms();
  execFileSync('dart', ['format', join(outputDir, outputName)], {
    stdio: 'inherit',
  });
}
