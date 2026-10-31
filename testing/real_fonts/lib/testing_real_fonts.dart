/// Polices réelles de la scène et mesure du texte tronqué, pour les tests de
/// lisibilité (NFR-05) des slices et de l'app.
library;

export 'src/paragraphs_truncated.dart' show paragraphsTruncated;
export 'src/real_fonts.dart'
    show
        realFontFamily,
        realFontFallback,
        realFontFiles,
        fontsDirectory,
        loadRealFonts;
