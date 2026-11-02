import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Spike jetable (017 T10) : échelle de graisses 400/500/600/700 en trois
/// variantes (wght + fontWeight, fontWeight seul, wght seul) pour les deux
/// familles. Écrit une capture PNG dans $SPIKE_PNG, imprime l'encre mesurée de
/// chaque ligne (moteur réel), puis quitte.
void main() => runApp(const _Spike());

const String _sample = '99,43 % NO-GO ✓▲▶↺◆ éàç';
final GlobalKey _page = GlobalKey();
final Map<String, GlobalKey> _lines = <String, GlobalKey>{};

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

  Widget _line(
    String family,
    String tag,
    int w,
    FontWeight? fw,
    bool variation,
  ) {
    final GlobalKey key = _lines['$family|$tag|$w'] = GlobalKey();
    return Row(
      children: <Widget>[
        SizedBox(
          width: 130,
          child: Text(
            '$w $tag',
            style: const TextStyle(color: Colors.amber, fontSize: 16),
          ),
        ),
        RepaintBoundary(
          key: key,
          child: Container(
            color: Colors.black,
            height: 36,
            width: 420,
            alignment: Alignment.centerLeft,
            child: Text(
              _sample,
              maxLines: 1,
              style: TextStyle(
                fontFamily: family,
                fontFamilyFallback: const <String>['DejaVu Sans'],
                fontSize: 24,
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
    final List<Widget> rows = <Widget>[
      Text(family, style: const TextStyle(color: Colors.amber, fontSize: 24)),
      for (final int w in <int>[400, 500, 600, 700])
        _line(family, 'var+fw', w, FontWeight(w), true),
      const SizedBox(height: 8),
      for (final int w in <int>[400, 500, 600, 700])
        _line(family, 'fw', w, FontWeight(w), false),
      const SizedBox(height: 8),
      for (final int w in <int>[400, 700]) _line(family, 'var', w, null, true),
    ];
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
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
    );
  }
}
