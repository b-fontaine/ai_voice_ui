import 'package:flutter/widgets.dart';

/// Orbe vocal (FR-01). Version statique : sans Bloc ni audio pour l'instant.
class VoiceOrb extends StatelessWidget {
  const VoiceOrb({super.key = const Key('voice-orb')});

  static const double diameter = 64;

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0xFF7C4DFF)),
    child: SizedBox.square(dimension: diameter),
  );
}
