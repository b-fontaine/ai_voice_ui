import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage, A2uiValidationError;

/// Message A2UI v0.9 refusé par [A2uiDecoder].
///
/// Le message d'erreur ne reproduit jamais le corps brut reçu.
class A2uiDecodeException implements Exception {
  const A2uiDecodeException(this.message);

  final String message;

  @override
  String toString() => 'A2uiDecodeException : $message';
}

/// Convertit un JSON brut en [A2uiMessage] (A2UI v0.9).
///
/// Partagé par le rejeu et le flux vivant.
abstract final class A2uiDecoder {
  /// Décode [raw], qui doit être un objet JSON (`Map` à clés texte).
  ///
  /// Lève [A2uiDecodeException] si l'entrée n'est pas un objet, si la version
  /// est refusée ou si le corps est mal formé.
  static A2uiMessage decode(Object? raw) {
    if (raw is! Map<String, Object?>) {
      throw const A2uiDecodeException('objet JSON attendu');
    }
    try {
      return A2uiMessage.fromJson(raw);
    } on A2uiValidationError catch (e) {
      throw A2uiDecodeException(e.message);
    } on TypeError catch (e) {
      throw A2uiDecodeException('corps de message A2UI mal formé : $e');
    }
  }
}
