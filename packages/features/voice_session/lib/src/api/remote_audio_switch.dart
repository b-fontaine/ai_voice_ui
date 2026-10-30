/// Interrupteur de la piste audio distante (voix de l'IA).
///
/// La piste n'existe qu'après l'événement `onTrack` de la connexion : l'état
/// demandé avant son arrivée est mémorisé et appliqué dès qu'elle est
/// [attach]ée. Une instance par connexion : un nouveau démarrage repart de
/// « son actif ».
class RemoteAudioSwitch {
  bool _enabled = true;
  void Function(bool enabled)? _apply;

  /// Dernier état demandé (`true` tant que rien n'a été coupé).
  bool get enabled => _enabled;

  /// Demande de couper (`false`) ou rétablir (`true`) la lecture.
  void setEnabled(bool value) {
    _enabled = value;
    _apply?.call(value);
  }

  /// Branche la piste distante arrivée par `onTrack`. N'agit que si le son
  /// a été coupé : une piste neuve est déjà active.
  void attach(void Function(bool enabled) apply) {
    _apply = apply;
    if (!_enabled) apply(false);
  }
}
