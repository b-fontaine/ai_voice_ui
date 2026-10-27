---
id: arch-dto-mappers
title: DTO et mappers — séparer modèles API et entités
tags: [clean-architecture, dto, mapper, json, freezed]
status: verified
updated: 2026-10-26
sources: [https://docs.flutter.dev/app-architecture/recommendations, https://docs.flutter.dev/app-architecture/case-study]
links: [arch-clean-flutter-layers, arch-freezed, rt-provider-abstraction]
---
# Modèles API ≠ modèles de domaine

La doc officielle classe en **Conditional** la règle « créer des modèles API séparés des modèles de domaine ». Elle est verbeuse, mais protège les ViewModels et les use-cases dans les grosses apps. Compass range les modèles API dans `data/model/` et le domaine dans `domain/models/`.

**Pratique proposée (opinion) :**
- Les DTO (`@freezed` + `json_serializable`) vivent dans `data/` : ils reflètent le JSON brut.
- Les entités vivent dans `domain/` et n'ont **pas de `fromJson`**.
- Le mapping passe par des extensions dans `data/mappers/`.

```dart
extension ToolCallDtoX on ToolCallDto {
  ToolCall toEntity() => ToolCall(id: callId, name: name,
      args: jsonDecode(arguments) as Map<String, Object?>);
}
```

**Cas multi-agents :** les événements OpenAI Realtime et Gemini Live ont des formats différents. Exemples :
- `response.output_item.done` (OpenAI) face à `LiveServerToolCall` (Gemini) ;
- les anciens et les nouveaux noms d'événements OpenAI.

On définit un DTO par fournisseur, puis on les mappe vers une entité commune `ToolCall` / `AgentEvent`. Le reste de l'app ignore ainsi le fournisseur (cf. `proj-avw-voice-runners`).

⚠️ Pièges
- Les messages A2UI / GenUI sont déjà des modèles du package `genui` : ne pas les dupliquer en DTO maison sans raison.
- Le mapping doit tolérer les champs inconnus. Les API temps réel évoluent souvent : noter la date de version dans le DTO.
