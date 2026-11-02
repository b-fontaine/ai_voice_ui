import 'package:shared_design_system/shared_design_system.dart'
    show registerSceneFontLicenses;

/// Enregistre les licences embarquées par l'app (OFL des polices Space Grotesk
/// et JetBrains Mono) dans la page de licences. Idempotent.
void registerAppLicenses() => registerSceneFontLicenses();
