import 'dart:io';
import 'dart:typed_data';

/// Lecture minimale de la table `cmap` d'un fichier TrueType : l'ensemble des
/// points de code qui ont un glyphe (autre que `.notdef`). Formats 4 (BMP) et
/// 12 (plans complets), les seuls que portent les polices de la scène.
Set<int> mappedCodePoints(String path) {
  final Uint8List bytes = File(path).readAsBytesSync();
  final ByteData data = ByteData.sublistView(bytes);
  final int tableCount = data.getUint16(4);
  int? cmapOffset;
  for (int i = 0; i < tableCount; i++) {
    final int record = 12 + 16 * i;
    final String tag = String.fromCharCodes(bytes.sublist(record, record + 4));
    if (tag == 'cmap') cmapOffset = data.getUint32(record + 8);
  }
  if (cmapOffset == null) throw StateError('table cmap absente de $path');
  final int subtables = data.getUint16(cmapOffset + 2);
  final Set<int> result = <int>{};
  for (int i = 0; i < subtables; i++) {
    final int offset = cmapOffset + data.getUint32(cmapOffset + 4 + 8 * i + 4);
    final int format = data.getUint16(offset);
    if (format == 4) {
      final int segX2 = data.getUint16(offset + 6);
      final int endBase = offset + 14;
      final int startBase = endBase + segX2 + 2;
      final int deltaBase = startBase + segX2;
      final int rangeBase = deltaBase + segX2;
      for (int s = 0; s < segX2 ~/ 2; s++) {
        final int end = data.getUint16(endBase + 2 * s);
        final int start = data.getUint16(startBase + 2 * s);
        final int delta = data.getInt16(deltaBase + 2 * s);
        final int rangeOffset = data.getUint16(rangeBase + 2 * s);
        for (int c = start; c <= end && c != 0xFFFF; c++) {
          int glyph;
          if (rangeOffset == 0) {
            glyph = (c + delta) & 0xFFFF;
          } else {
            final int at = rangeBase + 2 * s + rangeOffset + 2 * (c - start);
            glyph = data.getUint16(at);
            if (glyph != 0) glyph = (glyph + delta) & 0xFFFF;
          }
          if (glyph != 0) result.add(c);
        }
      }
    } else if (format == 12) {
      final int groups = data.getUint32(offset + 12);
      for (int g = 0; g < groups; g++) {
        final int base = offset + 16 + 12 * g;
        final int start = data.getUint32(base);
        final int end = data.getUint32(base + 4);
        final int firstGlyph = data.getUint32(base + 8);
        for (int c = start; c <= end; c++) {
          if (firstGlyph + (c - start) != 0) result.add(c);
        }
      }
    }
  }
  return result;
}
