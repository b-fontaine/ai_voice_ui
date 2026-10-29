import 'dart:convert';
import 'dart:io';

import 'app_channel_envelope.dart';

/// Journal JSONL local des enveloppes reçues, base du rejeu (contrat
/// `app-channel-contract` § Journal).
///
/// Une ligne = l'enveloppe sans `v` (clés `type`, `session`, `t_ms`, `data`,
/// puis `agent` et `task` si présents) plus `unix_ms`, lu sur l'horloge de
/// l'app et jamais déduit de `t_ms`. Pour rejouer une ligne, retirer `unix_ms`
/// et ajouter `"v": 1` avant [AppChannelEnvelope.parse].
///
/// Le journal ne casse jamais la session : une erreur d'E/S est transmise une
/// fois à `onError`, puis le journal se désactive.
class EnvelopeLog {
  /// [path] nul ou vide : journal inactif, toutes les opérations sont des
  /// no-ops. [nowUnixMs] est l'horloge injectée de l'app.
  EnvelopeLog({required String? path, required this._nowUnixMs, this._onError})
    : _path = (path == null || path.isEmpty) ? null : path;

  final String? _path;
  final int Function() _nowUnixMs;
  final void Function(Object error)? _onError;

  RandomAccessFile? _file;
  Future<void>? _opening;
  bool _disabled = false;

  /// Vrai tant que le journal est configuré, non fermé et sans erreur d'E/S.
  bool get isActive => _path != null && !_disabled;

  /// Crée les dossiers parents et ouvre le fichier en ajout. Idempotent.
  Future<void> open() {
    if (!isActive) return Future<void>.value();
    return _opening ??= _doOpen();
  }

  Future<void> _doOpen() async {
    try {
      final file = File(_path!);
      await file.parent.create(recursive: true);
      final raf = await file.open(mode: FileMode.append);
      if (_disabled) {
        await raf.close();
        return;
      }
      _file = raf;
    } on Object catch (error) {
      _fail(error);
    }
  }

  /// Ajoute une ligne. Ignoré si le journal est inactif, pas encore ouvert
  /// (avant la fin de [open]) ou fermé.
  void append(AppChannelEnvelope envelope) {
    final file = _file;
    if (!isActive || file == null) return;
    try {
      final line = jsonEncode(<String, Object?>{
        'type': envelope.type,
        'session': envelope.session,
        't_ms': envelope.tMs,
        'data': envelope.data,
        'agent': ?envelope.agent,
        'task': ?envelope.task,
        'unix_ms': _nowUnixMs(),
      });
      file.writeStringSync('$line\n');
    } on Object catch (error) {
      _fail(error);
    }
  }

  /// Vide les tampons et ferme le fichier. Idempotent ; [append] est ensuite
  /// ignoré.
  Future<void> close() async {
    if (_path == null) return;
    final opening = _opening;
    if (opening != null) await opening;
    final file = _file;
    _file = null;
    _disabled = true;
    if (file == null) return;
    try {
      await file.flush();
      await file.close();
    } on Object catch (error) {
      _onError?.call(error);
    }
  }

  void _fail(Object error) {
    if (_disabled) return;
    _disabled = true;
    final file = _file;
    _file = null;
    if (file != null) {
      file.close().ignore();
    }
    _onError?.call(error);
  }
}
