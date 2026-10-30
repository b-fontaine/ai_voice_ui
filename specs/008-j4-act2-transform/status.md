# 008 — État

- **Étape** : Gherkin
- **Tentatives** : 0/3
- **Tâche en cours** : —
- **Fichiers touchés** (tâche en cours) : —
- **Branche** : feat/008-j4-act2-transform
- **Backlog** : EP-03, EP-04, EP-09
- **Mis à jour** : 2026-10-30

## Journal
| Date | Étape | Fait | Preuve (journal gate.sh, capture) |
|---|---|---|---|
| 2026-10-30 | Définir | `spec.md`, `plan.md`, `tasks.md` rédigés ; **pdr-0064** (D1 à D5, détails tranchés sous pdr-0062) créée et indexée (`product_lint` 0 erreur). Périmètre : FR-07 complet ; FR-17 en premier temps seulement (correction de plateforme ; « l'IA se tait » et annulation en vol : J7). Q-73 résolue par construction (registre partagé, pdr-0058). | commit de cette étape |
| 2026-10-30 | Revue du plan | architect-reviewer (Opus, mode PLAN) : **À AMENDER** (2 bloquants, 5 importants, 1 mineur). Amendements A1 à A8 intégrés dans `plan.md` (bloc « Amendements », prioritaire) et `tasks.md` (T10 scindée en T10a/b/c ; T14 renforcée ; T04 et T16 étendues). Détails tranchés ajoutés sous pdr-0062 : **vue iOS** définie dans `dataset.md` (GO iOS, 3 extraits iOS inventés par l'assistant, pdr-0040) ; **D6** remise à vide au démarrage de l'app en mode vivant ; **D7** `comparison` incomplet = ligne omise, couleur neutre. Fait corrigé : l'origine de la demande des agents est la transcription d'entrée, pas un texte de délégation. Passage à Gherkin (T01, T02 d'abord, puis T03 et T04). | commit de cette étape |

## Revue d'architecte

### Revue du plan (mode PLAN, 2026-10-30) — verdict : À AMENDER
- A1 [bloquant] canevas partagé : `orchestrate.Canvas` (registre + verrou + `running`), `ResetCanvas` en une passe, ordre `Canvas.mu` → `p.mu` → `Registry.mu` ; tests (a) à (f) sous `-race`.
- A2 [bloquant] vue iOS absente (extraits, valeurs) : `dataset.md` + extraits par vue + fixtures `correction-ios-*`.
- A3 [important] app relancée, backend actif : reset au démarrage en mode vivant. A4 [important] tests existants à remplacer par des assertions de même force. A5 [important] phrases de refus et grammaire. A6 [important] origine de la demande (deux délégations). A7 [important] couverture Flutter (B1 app, S-02 dans le canevas, B2 remplacement). A8 [mineur] versions dans `dataset.json`, `FormatPts`, README du contrat.
- Réponses : D1 acceptée par les validateurs Go et Dart sans `updateComponents` ; le planificateur retient bien trois agents pour l'acte 2 et un seul pour « les avis Android » ; aucun conflit avec une décision.
<!-- Verdict et R1…Rn ; cocher celles appliquées. -->

## Questions pour le porteur
Aucune bloquante. À signaler (pdr-0062) : pdr-0064 D1 à D5, en particulier D4 (S-07 reste rouge jusqu'à J7).
