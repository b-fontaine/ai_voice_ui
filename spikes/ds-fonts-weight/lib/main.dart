import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Spike jetable (017, R2 du lot M) : mesure de l'encre dans le vrai moteur
/// pour les quatre variantes de pose de la graisse, par famille et par graisse.
///  a = wght seul (fontWeight w400) ; b = wght + FontWeight(n) (sceneWeight) ;
///  c = FontWeight(n) seul ; d = FontWeight standard (w400..w700) seul.
/// Imprime des lignes `INK famille variante n valeur`, écrit une capture PNG
/// dans $SPIKE_PNG, puis quitte.
void main() => runApp(const _Spike());

const String _sample = '99,43 % NO-GO ANDROID';
const List<int> _weights = <int>[400, 500, 600, 700];
const List<String> _variants = <String>['a', 'b', 'c', 'd'];
final GlobalKey _page = GlobalKey();
final Map<String, GlobalKey> _lines = <String, GlobalKey>{};

FontWeight _standard(int n) => FontWeight.values[n ~/ 100 - 1];

class _Spike extends StatefulWidget {
  const _Spike();
  @override
  State<_Spike> createState() => _SpikeState();
}

class _SpikeState extends State<_Spike> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(seconds: 2));
      for (final MapEntry<String, GlobalKey> line in _lines.entries) {
        final RenderRepaintBoundary b =
            line.value.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final ui.Image image = await b.toImage();
        final ByteData raw = (await image.toByteData())!;
        double ink = 0;
        for (int i = 0; i < raw.lengthInBytes; i += 4) {
          ink += raw.getUint8(i) / 255;
        }
        stdout.writeln('INK ${line.key} ${ink.round()}');
      }
      final RenderRepaintBoundary b =
          _page.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await b.toImage();
      final ByteData data = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!;
      File(Platform.environment['SPIKE_PNG']!)
          .writeAsBytesSync(data.buffer.asUint8List());
      exit(0);
    });
  }

  Widget _line(String family, String variant, int w) {
    final String id = family.replaceAll(' ', '');
    final GlobalKey key = _lines['$id $variant $w'] = GlobalKey();
    final FontWeight? fw = switch (variant) {
      'a' => FontWeight.w400,
      'b' || 'c' => FontWeight(w),
      _ => _standard(w),
    };
    final bool variation = variant == 'a' || variant == 'b';
    return Row(
      children: <Widget>[
        SizedBox(
          width: 70,
          child: Text(
            '$variant $w',
            style: const TextStyle(color: Colors.amber, fontSize: 16),
          ),
        ),
        RepaintBoundary(
          key: key,
          child: Container(
            color: Colors.black,
            height: 56,
            width: 560,
            alignment: Alignment.centerLeft,
            child: Text(
              _sample,
              maxLines: 1,
              style: TextStyle(
                fontFamily: family,
                fontFamilyFallback: const <String>['DejaVu Sans'],
                fontSize: 40,
                color: Colors.white,
                fontWeight: fw,
                fontVariations: variation
                    ? <FontVariation>[FontVariation('wght', w.toDouble())]
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _column(String family) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(family, style: const TextStyle(color: Colors.amber, fontSize: 24)),
        for (final String v in _variants) ...<Widget>[
          for (final int w in _weights) _line(family, v, w),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: const Color(0xFF0B0F14),
        child: RepaintBoundary(
          key: _page,
          child: Container(
            color: const Color(0xFF0B0F14),
            padding: const EdgeInsets.all(16),
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.topLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _column('Space Grotesk'),
                  const SizedBox(width: 16),
                  _column('JetBrains Mono'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
