import 'package:flutter/widgets.dart';

/// La surface en dessous était-elle **déjà en place** au montage (surface
/// restaurée) ? Posé par le canevas autour de chaque surface.
///
/// Sert aux animations ponctuelles du catalogue (compteur, jauge, cascade) :
/// une surface restaurée affiche son état final sans les rejouer
/// (pdr-0088 F13). Notion du canevas, pas du design system : `DsRise` ne
/// connaît que son paramètre `settled`.
class SurfaceRestored extends InheritedWidget {
  const SurfaceRestored({
    super.key,
    required this.restored,
    required super.child,
  });

  /// Vrai : le contenu est déjà en place, aucune animation ponctuelle.
  final bool restored;

  /// Le contenu sous le [SurfaceRestored] le plus proche était-il déjà en
  /// place au montage ? Faux sans canevas. Lecture sans abonnement : la valeur
  /// ne change pas pendant la vie du contenu.
  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SurfaceRestored>()?.restored ??
      false;

  @override
  bool updateShouldNotify(SurfaceRestored oldWidget) =>
      restored != oldWidget.restored;
}
