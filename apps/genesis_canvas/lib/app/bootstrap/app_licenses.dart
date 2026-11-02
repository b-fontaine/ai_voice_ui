import 'package:shared_design_system/shared_design_system.dart'
    show registerSceneFontLicenses;

/// Enregistre les licences embarquées par l'app (OFL de Space Grotesk et de
/// JetBrains Mono, Bitstream Vera de DejaVu Sans) dans la page de licences.
/// Idempotent.
void registerAppLicenses() => registerSceneFontLicenses();
