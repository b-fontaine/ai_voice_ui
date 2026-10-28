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
| `adr-` | décisions (ADR) |
| `ds-` | design system / Widgetbook |
| `ux-` | UX desktop et UI générative |

- **Décisions (ADR) :** une note `knowledge/decisions/adr-NNNN-<slug>.md` par décision technologique ou d'architecture. Le numéro est séquentiel et n'est jamais réutilisé. Une note contient :
  - les métadonnées : date, statut (proposée, acceptée, remplacée par adr-XXXX, abandonnée), décideur et part de l'assistant ;
  - le contexte et les **hypothèses**, en signalant celles qui ne sont pas confirmées ;
  - les options, la décision, les raisons et les options écartées ;
  - les cas où il faudra réexaminer la décision ;
  - les chemins des archives.
- **Une décision n'est jamais effacée :** on la marque remplacée et on crée un nouvel ADR.
- **Les sorties brutes** des panels, recherches et juges vont dans `decisions/_archive/AAAA-MM-JJ-<slug>.md`, sans limite de taille et ignorées par le lint.

- **Info datée :** toute information susceptible d'évoluer (version, modèle, preview) indique sa date dans `updated` et le mentionne dans le corps.
