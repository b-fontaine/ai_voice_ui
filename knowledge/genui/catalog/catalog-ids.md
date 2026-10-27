---
id: genui-catalog-ids
title: Catalogues — catalogId, catalogue basique, catalogues multiples
tags: [genui, a2ui, catalog]
status: verified
updated: 2026-10-26
sources: [https://github.com/google/A2UI/blob/main/specification/v0_9_1/docs/a2ui_protocol.md, https://a2ui.org/concepts/catalogs/, https://github.com/flutter/genui/blob/main/packages/genui/CHANGELOG.md]
links: [genui-custom-catalog-item, genui-a2ui-messages, genui-a2ui-security, genui-a2ui-v1-rc]
---
# Le `catalogId` est un contrat nommé entre agent et renderer

En A2UI, chaque surface est créée avec un `catalogId` : une chaîne au format URI par convention, qui n'a pas besoin d'être résolvable. Agent et client doivent s'accorder sur des ids partagés. La spec recommande (« should ») qu'une définition de catalogue porte `$id` et `catalogId` avec la même URI.

- **Catalogue basique v0.9 :** `https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json` (`basicCatalogId` dans genui ≥ 0.10.3, avec `catalogIdAliases` pour les anciennes URLs).
- Composants de base : Text, Image, Icon, Video, AudioPlayer, Row, Column, List, Card, Tabs, Divider, Modal, Button, CheckBox, TextField, DateTimeInput, ChoicePicker, Slider.
- Fonctions de base : required, regex, length, numeric, email, formatString, formatNumber, formatCurrency, formatDate, pluralize, openUrl, and, or, not.

```dart
final appCatalog = Catalog([appointmentCard, invoiceTable],
    catalogId: 'https://septeo.example/a2ui/catalogs/rdv/v1');   // id fictif
SurfaceController(catalogs: [BasicCatalogItems.asCatalog(), appCatalog]);
```

- `SurfaceController(catalogs: [...])` accepte plusieurs catalogues. En v0.9, **une surface n'utilise qu'un catalogue**, celui de son `createSurface`.
- Le client annonce ses catalogues via `a2uiClientCapabilities.supportedCatalogIds` (`controller.clientCapabilities`).
- Versionner l'id (`…/v1`, `…/v2`) à chaque changement de schéma incompatible (opinion).

⚠️ Pièges
- Un catalogue « maison » qui étend le basique (`copyWith(newItems:)`) garde l'id basique, sauf si on passe `catalogId`. Un agent distant ne connaîtra alors pas les items ajoutés.
- Le mélange de catalogues dans une même surface n'arrive qu'en A2UI v1.0 (RC).
