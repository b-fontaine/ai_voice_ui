// Tests du générateur par fixtures (Node : `tool/test_tokens.sh`). Ils couvrent
// ce que la scène n'utilise pas encore (cubicBezier, fontFamily, interlettrage)
// et les refus (ombre inset). Hors porte : Node n'y est jamais requis.
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { dartFontVariations, dartValue } from './build_tokens.mjs';

const srgb = (hex, components, alpha) => ({
  colorSpace: 'srgb',
  components,
  ...(alpha === undefined ? {} : { alpha }),
  hex,
});
const px = (value) => ({ value, unit: 'px' });
const token = ($type, $value) => ({ $type, $value, path: ['scene', 'test'] });

test('couleur avec alpha : octet = round(alpha x 255)', () => {
  const [type, expression] = dartValue(
    token('color', srgb('#3EF2A5', [0.243137, 0.94902, 0.647059], 0.109804)),
  );
  assert.equal(type, 'Color');
  assert.equal(expression, 'Color(0x1C3EF2A5)');
});

test('couleur opaque : alpha FF', () => {
  const [, expression] = dartValue(token('color', srgb('#04060C', [0, 0, 0])));
  assert.equal(expression, 'Color(0xFF04060C)');
});

test('alpha hors de 0 à 1 refusé', () => {
  assert.throws(
    () => dartValue(token('color', srgb('#000000', [0, 0, 0], 1.5))),
    /alpha/,
  );
});

test('nombres sans arrondi : 1,333... et 1,142857... conservés', () => {
  assert.equal(dartValue(token('number', 20 / 15))[1], String(20 / 15));
  assert.equal(dartValue(token('number', 8 / 7))[1], String(8 / 7));
  assert.equal(dartValue(token('number', 1.3))[1], '1.3');
  assert.equal(dartValue(token('number', 24))[1], '24.0');
  assert.equal(dartValue(token('dimension', px(1.5)))[1], '1.5');
});

test('ombre : flou CSS B converti en blurRadius, spread et offset recopiés', () => {
  const [type, expression] = dartValue(
    token('shadow', [
      {
        color: srgb('#000000', [0, 0, 0], 0.4),
        offsetX: px(0),
        offsetY: px(24),
        blur: px(48),
        spread: px(2),
      },
      {
        color: srgb('#3DE8FF', [0.239216, 0.909804, 1], 0.333333),
        offsetX: px(0),
        offsetY: px(0),
        blur: px(0),
        spread: px(1),
      },
    ]),
  );
  assert.equal(type, 'List<BoxShadow>');
  const radius = (48 / 2 - 0.5) / 0.57735;
  assert.ok(expression.includes(`blurRadius: ${radius}`), expression);
  assert.ok(expression.includes('offset: Offset(0.0, 24.0)'), expression);
  assert.ok(expression.includes('spreadRadius: 2.0'), expression);
  assert.ok(expression.includes('color: Color(0x66000000)'), expression);
  assert.ok(expression.includes('blurRadius: 0.0'), expression);
  assert.ok(expression.includes('spreadRadius: 1.0'), expression);
});

test('ombre : blurRadius recopié sans conversion, avec blur refusé', () => {
  const layer = {
    color: srgb('#A58BFF', [0.647059, 0.545098, 1], 0.6),
    offsetX: px(0),
    offsetY: px(0),
    blurRadius: px(10),
  };
  const [, expression] = dartValue(token('shadow', [layer]));
  assert.ok(expression.includes('blurRadius: 10.0'), expression);
  assert.throws(
    () => dartValue(token('shadow', [{ ...layer, blur: px(10) }])),
    /exclusifs/,
  );
});

test('ombre inset refusée avec une erreur claire', () => {
  assert.throws(
    () =>
      dartValue(
        token('shadow', {
          color: srgb('#FFFFFF', [1, 1, 1], 0.03),
          offsetX: px(0),
          offsetY: px(1),
          blur: px(0),
          inset: true,
        }),
      ),
    /inset/,
  );
});

test('cubicBezier devient Cubic', () => {
  const [type, expression] = dartValue(token('cubicBezier', [0.2, 0.8, 0.2, 1]));
  assert.equal(type, 'Cubic');
  assert.equal(expression, 'Cubic(0.2, 0.8, 0.2, 1.0)');
});

test('cubicBezier : abscisses hors de 0 à 1 refusées', () => {
  assert.throws(() => dartValue(token('cubicBezier', [1.2, 0, 0.2, 1])), /cubicBezier/);
});

test('fontFamily : nom seul et liste de repli', () => {
  assert.deepEqual(dartValue(token('fontFamily', 'Space Grotesk')), [
    'String',
    "'Space Grotesk'",
  ]);
  assert.deepEqual(dartValue(token('fontFamily', ['A', "B'c", '$d'])), [
    'List<String>',
    "['A', 'B\\'c', '\\$d']",
  ]);
});

test('interlettrage en em : px calculé à la taille donnée', () => {
  const [type, expression] = dartValue(
    token('letterSpacing', { value: -0.04, unit: 'em', fontSize: px(76) }),
  );
  assert.equal(type, 'double');
  assert.equal(expression, '-3.04');
});

test('interlettrage en px recopié', () => {
  const [, expression] = dartValue(token('letterSpacing', { value: 1.5, unit: 'px' }));
  assert.equal(expression, '1.5');
});

test('interlettrage en em sans taille refusé', () => {
  assert.throws(
    () => dartValue(token('letterSpacing', { value: 0.1, unit: 'em' })),
    /fontSize/,
  );
});

test('interlettrage en em dont fontSize diffère du token frère refusé', () => {
  const at = (name, $type, $value) => ({ $type, $value, path: ['scene', 'text', 'value', name] });
  const spacing = at('letterSpacing', 'letterSpacing', {
    value: -0.04,
    unit: 'em',
    fontSize: px(76),
  });
  assert.throws(() => dartValue(spacing, [at('fontSize', 'dimension', px(72))]), /fontSize/);
  assert.equal(dartValue(spacing, [at('fontSize', 'dimension', px(76))])[1], '-3.04');
});

test('graisse : variation wght jumelle de la valeur FontWeight', () => {
  assert.deepEqual(dartFontVariations(token('fontWeight', 600)), [
    'List<FontVariation>',
    "[FontVariation('wght', 600.0)]",
  ]);
});

test('seule une graisse a une variation wght', () => {
  assert.equal(dartFontVariations(token('number', 1.3)), null);
});
