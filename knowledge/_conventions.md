# Conventions de la base de connaissances (zettelkasten)

- **Une note = une idée atomique.** Moins de 60 lignes, en français. Code et identifiants restent dans leur langue d'origine.
- **Emplacement :** `knowledge/<domaine>/<sous-thème>/<slug>.md`. Le slug est en kebab-case, en anglais.
- **Frontmatter YAML obligatoire :**
  ```yaml
  ---
  id: <préfixe-domaine>-<slug>   # unique, stable, sert aux liens
  title: <titre court>
  tags: [..]
  status: verified | sourced | opinion   # verified = vérifié sur doc officielle ; sourced = source secondaire ; opinion = recommandation interne
  updated: 2026-10-26
  sources: [<url>, ...]
  links: [<id>, ...]   # autres notes liées (zettelkasten)
  ---
  ```
- **Corps de la note :** l'affirmation en 1 ou 2 phrases, puis les détails ou un exemple de code court, puis « ⚠️ Pièges » si pertinent.
- **Un `index.yaml` par domaine** (et par sous-dossier si plus de 8 notes) :
  ```yaml
  domain: <nom>
  description: <une ligne>
  notes:
    - {id: ..., path: <relatif>, summary: "<une ligne>", tags: [..]}
  ```
- **`knowledge/index.yaml` (racine)** liste les domaines, leurs index et les mots-clés pour le routage.
- **Préfixes d'id :**

  | Préfixe | Domaine |
  |---|---|
  | `proj-` | projets Septeo |
  | `rt-` | voix temps réel |
  | `genui-` | GenUI / A2UI |
  | `arch-` | architecture Flutter |
  | `di-` | DI |
  | `bloc-` | BLoC |
  | `test-` | tests |
  | `perf-` | performance |
  | `proto-` | protocoles agents |
  | `ma-` | orchestration multi-agents |

- **Info datée :** toute information susceptible d'évoluer (version, modèle, preview) indique sa date dans `updated` et le mentionne dans le corps.
