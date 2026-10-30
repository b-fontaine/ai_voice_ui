import 'package:meta/meta.dart' show immutable;

/// État de la régie : l'acte courant de la démo (FR-11, pdr-0054).
@immutable
final class StageState {
  const StageState({required this.act})
    : assert(
        act >= 1 && act <= actCount,
        "l'acte doit être compris entre 1 et 3",
      );

  /// Nombre d'actes de la démo.
  static const int actCount = 3;

  /// Noms des actes, dans l'ordre (l'acte 1 est « Créer »).
  static const List<String> actNames = <String>[
    'Créer',
    'Transformer',
    'Interagir',
  ];

  /// Acte courant, de 1 à [actCount].
  final int act;

  /// Nom de l'acte courant.
  String get actName => actNames[act - 1];

  @override
  bool operator ==(Object other) => other is StageState && other.act == act;

  @override
  int get hashCode => act.hashCode;

  @override
  String toString() => 'StageState(act: $act)';
}
