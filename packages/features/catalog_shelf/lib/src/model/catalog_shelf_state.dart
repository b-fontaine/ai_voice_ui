import 'package:entity_catalog/entity_catalog.dart';
import 'package:meta/meta.dart' show immutable;

/// Un composant de l'étagère.
@immutable
final class ShelfComponent {
  const ShelfComponent(this.name, {required this.used});

  final String name;
  final bool used;

  @override
  bool operator ==(Object other) =>
      other is ShelfComponent && other.name == name && other.used == used;

  @override
  int get hashCode => Object.hash(name, used);
}

/// État de l'étagère : les composants du contrat, dans l'ordre du contrat.
@immutable
final class CatalogShelfState {
  const CatalogShelfState(this.components);

  /// Tous les composants éteints (dérivé du contrat).
  factory CatalogShelfState.empty() => CatalogShelfState.fromUsed(const {});

  /// État où seuls les composants de [used] sont allumés.
  factory CatalogShelfState.fromUsed(Set<String> used) =>
      CatalogShelfState(<ShelfComponent>[
        for (final String name in GenesisContract.catalogComponents)
          ShelfComponent(name, used: used.contains(name)),
      ]);

  final List<ShelfComponent> components;

  int get usedCount => components.where((c) => c.used).length;
  int get total => components.length;

  @override
  bool operator ==(Object other) =>
      other is CatalogShelfState && _same(other.components, components);

  @override
  int get hashCode => Object.hashAll(components);
}

bool _same(List<ShelfComponent> a, List<ShelfComponent> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
