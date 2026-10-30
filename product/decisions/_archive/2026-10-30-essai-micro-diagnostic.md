# Diagnostic de l'essai au micro du 2026-10-30 (sorties brutes)
Journaux : sessions live_u0/u1/u2 de l'orchestrateur (volume genesis-demo_journal). Chaque diagnostic a été contre-vérifié par un sceptique.

## act2-compare — décision-manquante (confiance haute, effort M, vérifié : True)

### symptom

Acte 2 : le porteur demande à se concentrer sur Android et à comparer avec la 3.3, mais ne voit pas la comparaison 3.3 sur le canevas. Il voit la vue Android seule, puis un refus (« Cette comparaison n'est pas disponible telle quelle »).

### evidence

Journaux : /tmp/claude-1000/-home-bfontaine-github-ai-voice-ui/50bad832-a017-4573-94ff-cace94e2436b/scratchpad/essai-micro-2026-10-30/

A. Session Eejy4 (16:42:08 à 16:44:59), le déroulé complet des actes 1, 2 et 3. La demande a été dite en DEUX tours séparés par le porteur, et GPT-Live n'a pas coupé une phrase unique :
- 16:42:51 (t=43370), transcription de l'utilisateur, fragments start_ms 41800 à 42800 : « Concentre-toi sur Android ». Rien d'autre n'est entendu avant t=115200. La délégation item_EejynvAde174qmz6Ete3R (offset_ms 43600) part à 16:42:53.
- 16:42:53 (t=45123), a2ui : la vue Android arrive SANS champ comparison. /kpi vaut {"label":"Sessions sans crash · Android","value":"99,43 %",…}, /trend ne contient que la série "Android 3.4", /checklist vaut "99,43 %" sans « (3.3 : …) ».
- 16:43:06 à 16:43:17 (t=58281, 67773, 69388) : plans act-1, act-2 et act-3, puis decisionStatus « Bloquée ». Le porteur a donc bloqué la release avant de demander la comparaison.
- 16:44:05 (t=116752), transcription de l'utilisateur : « Compare avec la 3.3 ». Délégation item_EejzyoaHnHnDtW3ArunUF avec selected [Qualité, Voix du client, Livraison].
- 16:44:06 (t=118119) : agent.activity state "rejected", detail "hors périmètre", pour les TROIS agents. Aucun message a2ui ne suit.
- t=120610, l'IA : « Cette comparaison n'est pas disponible telle quelle. Voulez-vous voir Android ou iOS, avec la comparaison à la version précédente uniquement pour Android ? »
- 16:44:20 (t=132237), l'utilisateur : « Juste Android ». Délégation item_Eek0DQ9rucpjWOntTZMT1 ; a2ui à t=133066 : vue Android de nouveau SANS comparison. En plus, /checklist est réécrite avec decisionStatus « En attente de décision » (c'est Q-76).
- 16:44:54 (t=165958), l'utilisateur : « Fais voir ». Le plan ne retient aucun agent (selected [] à t=166769) et l'IA répond « Je ne peux pas afficher cela ».

B. Session Eejwtp (16:40:55 à 16:41:32), un essai précédent où la phrase a été dite d'un seul tenant :
- Fragments de 16:41:20 à 16:41:21 (start_ms 23000 à 24800) : « Concentre-toi sur Android et compare avec la 3.3 ». La délégation item_EejxKJhmUk3Ckgj6VF1a9 a un offset_ms de 25200, qui englobe tout.
- 16:41:22 (t=26714), a2ui : la comparaison est bien produite. /kpi contient comparison {"label":"3.3","value":"99,71 %","delta":"−0,28 pt"}. /reviews contient comparison {"label":"3.3","value":"14 % négatifs","delta":"+16 pts"}. /trend contient les séries "Android 3.4" et "Android 3.3". /checklist contient "99,43 % (3.3 : 99,71 %)".
- La voix commence « …3.3 : 99,71 % », puis la session est fermée à 16:41:32 (close_requested). La session suivante, ouverte à 16:42:12, réécrit /kpi, /trend et /reviews en vue globale.

Code :
- backend/agents/internal/kit/scope.go:83 : comparing = compareWord.MatchString(text).
- scope.go:135-137 : `if comparing { if in.Platform == "" { return Intent{}, &ScopeError{Reason: ReasonCompareWithoutPlatform} }`. Sur « Compare avec la 3.3 », « 3.3 » est admise parce qu'il y a comparaison (l.86-87), aucune plateforme n'est trouvée (l.121-134), et la demande est donc refusée avec compare_without_platform.
- backend/orchestrator/internal/app/orchestrate/window.go:67-90 : RequestWindow.Take ne renvoie que les deltas d'entrée postérieurs à la délégation précédente. La demande transmise est donc « Compare avec la 3.3 » seule.
- backend/orchestrator/internal/app/orchestrate/pipeline.go:378-380 : AgentRequest{Text: d.Request, ContextID: SessionID, …}. L'intention de l'agent ne tient compte ni d'une plateforme précédente ni de l'état du canevas (agents sans état, cf. Q-74 dans product/roadmap/open-questions.md:105).
- pipeline.go:33 : DetailOutOfScope = "hors périmètre". Le motif précis n'est pas journalisé dans le JSONL. Il se déduit avec certitude de scope.go, car c'est la seule branche possible pour ce texte.
- Côté Flutter, la comparaison est bien rendue quand elle est reçue : packages/features/canvas/lib/src/catalog/key_indicator.dart:121-125 et review_sentiment.dart:148, via readComparisonText dans bound_item.dart:146-155.

### root_cause

Le cas Q-74 s'est produit, mais par le speaker et non par GPT-Live. Dans le déroulé complet (session Eejy4), le porteur a dit « Concentre-toi sur Android », a écouté la réponse, a bloqué la release, puis a dit 73 s plus tard « Compare avec la 3.3 ». Chaque tour donne une délégation distincte. Comme l'orchestrateur ne transmet que la transcription depuis la délégation précédente (window.go:70-90), la seconde demande arrive sans plateforme aux agents, qui sont sans état. ParseIntent la refuse alors avec compare_without_platform (scope.go:135-137) : les trois agents sont « rejected » et aucun a2ui n'est émis.

La relance a aggravé la situation. La voix a posé une question de clarification ambiguë, et la réponse « Juste Android » ne contient plus le mot « compar ». La vue Android est donc renvoyée sans comparaison, et la décision « Bloquée » est effacée (Q-76).

Le chemin nominal fonctionne : quand la phrase est dite d'un seul tenant (session Eejwtp, 16:41:21), les quatre surfaces reçoivent la comparaison 3.3, et le rendu Flutter la sait afficher. Cette vue n'a cependant duré que jusqu'à la fermeture de la session (16:41:32) et à la session suivante (16:42:12), qui a tout réécrit.

Il n'y a donc pas de bug de calcul ni de rendu. Le défaut tient au produit : il n'existe aucune mémoire du contexte (plateforme en cours) d'un tour à l'autre, et la demande de comparaison n'est acceptée que si plateforme et comparaison sont dans la même phrase.

### fix

Plusieurs options, à trancher par le porteur.

(1) Recommandée, effort M : mémoriser le focus courant. L'orchestrateur garde par canevas (registre partagé, pipeline.go:139) la dernière Intent réussie, au minimum la plateforme. Il la transmet aux agents dans AgentRequest, par exemple dans un champ de métadonnées « focus », sur le modèle d'ActiveSurfaces (pipeline.go:379 et kit/executor.go:75). Dans kit/scope.go, une demande « compar… » sans plateforme hérite alors de la plateforme du focus au lieu d'être refusée avec ReasonCompareWithoutPlatform (l.136). De même, « Juste Android » garde la comparaison si le focus la contenait (sinon c'est à décider). Tests : rejouer les deux délégations du journal Eejy4 (« Concentre-toi sur Android », puis « Compare avec la 3.3 ») et attendre comparison dans /kpi, /reviews, /trend et /checklist. Le refus reste attendu sans aucun focus.

(2) Effort S, plus fragile : quand la demande contient un mot de comparaison sans plateforme, l'orchestrateur y préfixe la demande de la délégation précédente dans RequestWindow (window.go). Le risque est un refus two_platforms après « plutôt iOS ».

(3) Effort S, pour la démo seulement : consigne vocale (pdr-0037) et répétition. Dire la phrase d'un seul tenant, et faire reformuler la question de clarification de la voix pour qu'elle propose explicitement « Android comparé à la 3.3 ».

Dans tous les cas, deux points en complément. Journaliser le motif du refus (scopeReason) dans le detail de l'agent.activity, ou au moins dans le journal de l'orchestrateur. Traiter Q-76 : la vue reconstruite efface « Bloquée ».

### owner_decision

Q-74 est observée en réel (session Eejy4, 16:44:05) : faut-il qu'une demande de comparaison sans plateforme hérite de la plateforme affichée ? Trois options :
- A. Mémoire de focus par canevas, transmise aux agents. Robuste, effort M.
- B. Concaténation de la demande précédente par l'orchestrateur. Effort S, risque two_platforms.
- C. Garder le comportement actuel et exiger la phrase en un seul tenant (répétition et consigne vocale).

Recommandation de l'assistant : A, avec C en filet pour le talk. La question Q-74 passe ainsi de « hypothèse » à « constatée ». À décider aussi : faut-il conserver la comparaison quand le speaker précise ensuite seulement la plateforme (« Juste Android ») ?

### contre-vérification

J'ai vérifié les preuves dans les journaux et dans le code. Elles sont exactes et la cause tient.

Ce que j'ai confirmé :
- **Session Eejy4.** « Concentre-toi sur Android » (start_ms 41800), puis la délégation à offset 43600. La vue a2ui à t=45123 ne contient qu'« Android 3.4 », sans comparison. « Compare avec la 3.3 » (start_ms 115200) suit, avec la délégation à offset 116600. À t=118119, les trois agents sont « rejected / hors périmètre » et aucun a2ui ne suit. « Juste Android » renvoie ensuite la vue sans comparison, avec decisionStatus « En attente de décision » (t=133066). Enfin, « Fais voir » donne selected [].
- **Session Eejwtp.** À t=26714, la comparaison est présente sur /kpi (−0,28 pt), /reviews (+16 pts) et /trend (« Android 3.3 » et « Android 3.4 »). La session se ferme par close_requested à t=37215.
- **Code.** scope.go:44 : compareWord matche « compar ». Aux lignes 135-137, une comparaison sans plateforme donne ReasonCompareWithoutPlatform, seule branche possible pour ce texte. window.go Take ne garde que les fragments postérieurs au consommé. pipeline.go:378-380 envoie Text: d.Request, et DetailOutOfScope est en task.go:163.

Corrections et précisions mineures :
1. **Le blocage de la release.** Les plans act-1, act-2 et act-3 (t=58281, 67773, 69388) correspondent à TROIS écritures successives de /checklist/decisionStatus = « Bloquée » (t=58283, 67774 et 69389). Ce sont vraisemblablement trois clics. Il faut l'écrire ainsi plutôt que « puis decisionStatus Bloquée ». Ces clics ont eu lieu pendant que la voix parlait encore : le tour IA commencé à t=45626 finit par « C'est fait. La release 3.4 est bloquée. » Ce point recoupe un autre symptôme du porteur (clic pris en compte seulement après le discours). Il faut le croiser avec ce diagnostic, sans l'imputer à act2-compare.
2. **La comparaison réussie de la session Eejwtp a été visible environ 10 s**, de t=26714 à t=37215, puis la session s'est fermée. Le porteur a donc pu ne pas la voir, ou la voir à peine. Ce point mérite d'apparaître dans le symptôme : la comparaison n'a été absente que dans le déroulé complet.
3. **La question de clarification de la voix** (« Voulez-vous voir Android ou iOS, avec la comparaison… uniquement pour Android ? ») vient de GPT-Live, qui reformule le refus. Ce n'est pas un texte d'agent. L'option C, qui touche la consigne vocale de pdr-0037, doit le cibler explicitement. Elle doit faire proposer « Android comparé à la 3.3 » pour que la réponse contienne la plateforme et le mot « compar ».
4. **L'option A (mémoire de focus) doit fixer la portée de la mémoire.** La mémoire est-elle par canevas ou par session ? Survit-elle à une reconnexion ? La session suivante réécrit la vue globale. Il faut aussi fixer l'interaction avec Q-76 : la même mémoire par canevas pourrait conserver la décision Bloquée/Validée et la réappliquer, ce qui traiterait les deux questions d'un coup. Il faut enfin préciser le test de non-régression : « plutôt iOS » après un focus Android avec comparaison ne doit pas produire two_platforms. Il doit soit remplacer la plateforme, soit être refusé de façon cohérente avec ds.Comparison (compare_unavailable pour iOS).
5. **Q-74 n'était pas qu'une hypothèse sur GPT-Live.** Le diagnostic a raison de dire que la coupure vient du speaker. Il faut préciser que la réponse proposée dans Q-74 (« fenêtre de transcription plus longue ») n'aurait pas suffi ici : 73 s séparent les deux tours, et la délégation précédente a déjà consommé la fenêtre. C'est un argument de plus pour A plutôt que pour la fenêtre ou pour B.

Aucune cause plus probable n'a été trouvée : pas de bug de rendu Flutter ni de calcul. Le seul chemin du refus est compare_without_platform.

## crashlist — non-implémenté (confiance haute, effort L, vérifié : True)

### symptom

Le composant CrashList (Liste des crashs) n'apparaît jamais, même quand le porteur le demande explicitement à la voix (« Affiche la crash list », puis « Pourquoi tu n'affiches pas la crash list »). L'IA renvoie à chaque fois le même indicateur « Sessions sans crash » et la même courbe, sans rien refuser ni expliquer.

### evidence

JOURNAUX (live_u1_Eek1Dp3oMX0N2vQ101D7Vsh3v4uOzShd.jsonl, vers 16:45 heure de l'essai) :
- unix_ms 1793378726845 : le porteur dit « Affiche la crash list ».
- 1793378729052 (t_ms 5079) : delegation item_Eek1IP3A9sx0U5gMCJyLo.
- 1793378729053 : plan selected=["Qualité"], idle=["Voix du client","Livraison"].
- 1793378729054 et 729055 : deux a2ui seulement, updateDataModel /kpi (KeyIndicator) et /trend (TrendChart). Aucun createSurface, aucun composant CrashList.
- 1793378729563 : l'IA répond « 99,57 % de sessions sans crash sur 7 jours… Android franchit le seuil de crash à J5. »
- 1793378751513 : le porteur demande « Pourquoi tu n'affiches pas la crash list ».
- 1793378753914 : nouvelle délégation, même plan [Qualité], mêmes updateDataModel /kpi et /trend (753916 et 753917), même résumé mot pour mot (754360). Il n'y a ni état rejected ni refus RG-08.
- Les 5 sessions ne contiennent aucun message a2ui avec CrashList.
- Toutes les tâches d'agent passent de working à completed en 0 à 3 ms (par ex. 1793378729054 → 729055). C'est incompatible avec un appel à un LLM : la composition est déterministe.

CODE :
- Pas de LLM dans les agents : `grep openai|LLM` sur backend/agents ne renvoie rien. kit.Composer (backend/agents/internal/kit/composer.go:47-49) n'a qu'une implémentation déterministe par agent.
- backend/agents/internal/quality/composer.go:36-57 : ParseIntent n'extrait que Platform et CompareTo (kit/scope.go:56-61). Le composeur émet toujours exactement deux surfaces, kpi/KeyIndicator (l.54) et trend/TrendChart (l.55). Aucune branche ne produit CrashList, et aucun autre agent non plus : `grep CrashList backend` ne trouve rien dans le Go.
- Planificateur déterministe : orchestrator/internal/app/orchestrate/planner.go:40-91 (TagPlanner, correspondance de mots exacts avec les tags). Il est câblé en dur dans bootstrap/app.go:205 (`Planner: orchestrate.TagPlanner{}`). Le mot « crash » correspond au tag de Qualité (quality/profile.json:8) ; « list » ne correspond à aucun tag. Le choix de Qualité est donc correct, mais Qualité ne sait pas faire de liste.
- Les données manquent : les clés de backend/agents/internal/dataset/dataset.json n'ont aucun « top crashs » (signature, plateforme, volume). Seuls existent rows.crashes, des comptes par jour (dataset.go:33). pdr-0014 le signale déjà : « ⚠️ Hypothèse non confirmée : les données de la Liste des crashs … restent à écrire dans le jeu figé ».
- Le contrat ne le permet pas non plus : contracts/a2ui/genesis/v1/catalog.json:18 ne cite CrashList que dans catalogComponents (étagère), sans schéma. La liste blanche A2UI_COMPONENTS (bootstrap/config.go:298) n'en compte que 5. product/functional/catalog.md:41,43,53 et app-channel-contract.md:125 : « CrashList n'a pas de schéma … n'est jamais utilisé ». packages/features/canvas/lib/src/catalog/genesis_catalog.dart:11 : « CrashList n'a pas de schéma et reste hors catalogue ». Même si un agent l'émettait, le validateur le rejetterait.
- pdr-0060 (acceptée le 2026-10-30) n'est pas mise en œuvre : product/architecture/backend.md:37 (`out.LlmText` : « fournisseur non choisi »), :81 (« Composition déterministe (provisoire ; repli de pdr-0060 …) »), :149 (« petit modèle OpenAI à choisir par mesure en J3 »). Aucune mesure ni aucun adaptateur LLM n'existe dans le code.
- Les consignes vocales (backend/orchestrator/config/voice-instructions.fr.md:5) disent de déléguer tout sujet sur les crashs, sans annoncer que la liste n'existe pas. Le modèle vocal a donc relu le résumé de Qualité comme s'il répondait à la demande.

### root_cause

CrashList n'existe que comme tuile de l'étagère (catalogComponents). Il n'est pas implémenté de bout en bout : pas de données dans le jeu figé, pas de schéma dans le catalogue, absent de la liste blanche A2UI_COMPONENTS, pas de widget rendu, et aucun agent ni composeur ne sait l'émettre. Le « choix par l'IA » promis par pdr-0014 suppose le compositeur LLM de pdr-0060, qui n'a pas été construit : les trois agents composent de façon déterministe, et le planificateur est un TagPlanner à mots-clés. « Affiche la crash list » réveille donc Qualité par le mot « crash ». Qualité renvoie toujours ses deux mêmes surfaces (KPI et courbe), sans refuser et sans signaler que la liste n'est pas disponible. Ce silence est un défaut d'honnêteté secondaire : RG-08 (refus hors catalogue) n'est pas déclenché, parce que la demande est « dans le sujet » d'un agent.

### fix

Trois niveaux, au choix du porteur.

(A) Rendre CrashList réel. C'est une fonctionnalité de taille M à L, avec TDD et BDD :
1. Ajouter au jeu figé backend/agents/internal/dataset/dataset.json une liste « top crashs » (signature, plateforme, occurrences, part, version), avec son accesseur Go.
2. Écrire le schéma CrashList dans contracts/a2ui/genesis/v1/catalog.json, l'ajouter à `components` et à A2UI_COMPONENTS, et créer une fixture `examples/crashlist-*.jsonl` avec ses tests négatifs.
3. Côté Flutter : widget CrashList (états squelette, neutre et rempli) dans packages/features/canvas, ajouté à genesis_catalog.dart, et mise à jour de genesis_contract.dart.
4. Dans quality/composer.go : étendre kit.Intent avec un champ fermé `View` (par ex. crashlist), reconnu dans kit/scope.go (« liste des crashs », « crash list », « top crashs »), avec une branche qui émet la surface `crashes`/CrashList. Ajouter les tags « liste », « list », « top » à quality/profile.json.
5. Ajouter un scénario .feature « Affiche la liste des crashs ».

(B) Mettre en œuvre pdr-0060, c'est-à-dire un adaptateur LLM derrière kit.Composer, guidé par les fixtures. Cela ne suffit pas sans (A) : sans données ni schéma, le LLM ne peut pas produire une CrashList valide.

(C) Correctif minimal et immédiat, que (A) soit fait ou non : un agent ne doit pas répondre « à côté ». Quand l'intention demande une vue que l'agent ne sait pas produire (liste des crashs), Qualité renvoie une ScopeError avec un motif fermé (par ex. `view_unavailable`) dans kit/scope.go. L'IA dit alors honnêtement que la liste n'est pas disponible, au lieu de relire le KPI.

Il faut aussi corriger la documentation : préciser dans pdr-0014 et catalog.md que CrashList n'est pas démontrable aujourd'hui, et dans backend.md l'état réel de pdr-0060 (mesure J3 non faite, repli déterministe en vigueur de fait).

### owner_decision

Question : CrashList doit-il être démontrable pour le talk, et par quel moyen ?
Options :
(1) Implémenter CrashList de façon déterministe : données, schéma, widget, intention « liste des crashs » dans Qualité. Effort M à L. Cela démontre qu'on choisit un composant du catalogue selon la demande, mais par mots-clés et non par un LLM.
(2) Mettre d'abord en œuvre pdr-0060 (compositeur LLM, après la mesure J3), puis CrashList. Effort L. C'est fidèle à pdr-0014 et pdr-0023, avec un risque de latence (NFR-02/03) et un coût dans le budget de 20 €.
(3) Laisser CrashList hors scénario, comme le dit déjà catalog.md, mais livrer le correctif (C) pour que l'IA dise « la liste des crashs n'est pas disponible » au lieu de répondre à côté. Effort S. Il faut alors noter que la promesse « l'IA la choisit selon la demande » de pdr-0014 n'est pas tenue, et le dire au public.
Il faut aussi trancher le sort de pdr-0060 : la mesure J3 n'a jamais eu lieu et la composition reste déterministe. Faut-il déclarer formellement le repli, assumé devant le public, ou planifier la mesure ?
Recommandation : (3) tout de suite, pour l'honnêteté vocale, puis (1) si le calendrier J7 le permet. Pour pdr-0060, déclarer explicitement le repli par un nouvel ADR ou PDR, sauf si le porteur tient à un LLM réel sur scène.

### contre-vérification

J'ai vérifié les preuves et elles tiennent. Dans live_u1_Eek1Dp…jsonl, aux horodatages 726845 à 754960, on trouve la transcription « Affiche la crash list », puis la délégation et le plan [Qualité]. Viennent ensuite deux updateDataModel seulement (/kpi et /trend). Les tâches passent de working à completed en 1 ms. La seconde demande produit la même chose, et le résumé cité entre guillemets est identique. Aucun des 5 journaux ne contient le mot CrashList. Dans quality/composer.go:36-57, le composant émet toujours KeyIndicator et TrendChart. kit.Intent ne porte que Platform et CompareTo. TagPlanner est câblé en dur dans bootstrap/app.go:205. Le mot « crash » figure dans les tags de quality/profile.json:8, mais « list » n'y est pas. Aucun code Go ne contient LLM ni openai, et dans le Go, CrashList n'apparaît que dans un test de fixtures. La cause est juste : CrashList n'est pas mis en œuvre de bout en bout et la composition est déterministe.

Corrections à apporter :

1. Les données NE manquent PAS côté produit. product/functional/dataset.md:91-101 (« Liste des crashs ») donne déjà le top 5 de la 3.4 : libellé, plateforme, volume, sessions touchées. Par exemple : n° 1 « Plantage à la validation du panier (3-D Secure 2) », Android, 371/352. Ces données manquent seulement dans backend/agents/internal/dataset/dataset.json. L'avertissement de pdr-0014:28 (« Hypothèse non confirmée … restent à écrire ») et sa ligne 65 sont donc périmés. Il faut les corriger, et pas seulement citer pdr-0014 comme preuve. Le point (A).1 doit dire « recopier le tableau de dataset.md § Liste des crashs dans dataset.json », et non inventer des champs (signature, part, version).

2. bootstrap/config.go:298 se contente de lire la variable d'environnement. La valeur à 5 composants vient de docker-compose.yaml:40, avec la valeur par défaut `KeyIndicator,TrendChart,ReviewSentiment,ReleaseChecklist,ActionBar`. Le contrôle est fait par backend/check-compose.sh, qui la compare à `components` de catalog.json. Il faut citer cette source et ajouter compose et check-compose au correctif (A).2.

3. La gravité du silence est sous-estimée. Il ne s'agit pas d'un défaut « secondaire » : il rompt un contrat explicite. voice-instructions.fr.md:6 interdit au modèle vocal de refuser lui-même une demande d'affichage, « c'est lui [l'orchestrateur] qui dira si elle est possible ». La chaîne compte donc sur l'orchestrateur et les agents pour refuser. Or ParseIntent n'a aucun motif fermé pour une vue non prise en charge. Le modèle vocal ne pouvait rien faire d'autre que relire le résumé. Le correctif (C) doit donc passer de « hygiène » à « défaut à corriger en priorité ». Il doit aussi couvrir les autres agents : toute demande de vue nommée qu'aucun composeur ne sait produire doit aboutir à un refus de type RG-08, ou à une ScopeError avec un motif fermé.

4. La documentation produit se contredit. catalog.md:26 et pdr-0014:46/54 disent « l'IA la choisit selon la demande », alors que catalog.md:41/53 dit « jamais utilisé ». Il faut le mentionner dans la correction documentaire, en plus de backend.md pour pdr-0060.

5. Précision mineure : la seconde réponse vocale commence par « Je vérifie ça. Voici ce que je constate : … ». Seule la citation du résumé est identique mot pour mot, pas toute la réplique.

Le reste du diagnostic (catégorie « non-implémenté », confiance haute, options (1), (2) et (3), recommandation (3) puis (1), effort) est juste. Il est suffisant une fois ces corrections faites.

## stop — non-implémenté (confiance haute, effort M, vérifié : True)

### symptom

Pendant l'essai réel, le porteur a dit « Stop » alors que l'IA lisait les chiffres de l'acte 1. L'IA a fini sa phrase sans se taire ni accuser réception. Aucune génération n'a été annulée et l'écran n'a rien montré. FR-16 (Must : « Stop » ou « annule » arrête la voix et la génération en cours) n'est pas tenue.

### evidence

JOURNAL (session live_u2_Eejv9p3oN8Gl1ddn1dKEpIAJEY8oOdTJ.jsonl, la seule des 5 où « stop » apparaît ; aucune occurrence de « annule », « arrête » ou « tais-toi » dans les transcripts utilisateur) :
- t=30651-31298 ms (unix 1793378378132-1793378378779) : transcript user « Ouais, ça avance pour ce coup ». Il tombe pendant que l'IA lit « … seuil ≥ 99,50 %, » et l'IA continue (« à risque, marge 0,07 pt) ; Android franchit… »).
- t=38077 : user « Pareil » (start_ms 36600).
- t=39465 ms (unix_ms 1793378386947) : transcript user « . Stop » (start_ms 38000, end_ms 38200).
- t=39515 à 46082 : l'IA continue sans coupure (« is négatifs sur 1 164 avis en 7 jours (seuil ≤ 25 %, à risque) ; note moyenne 4,0. ») jusqu'au bout de sa réplique.
- orb.level (RMS de la voix IA, copie sideband) : 0,126 à t=38641, puis entre 0,03 et 0,12 sans interruption jusqu'à t=46228 (0,062) et t=46483 (0,028). Il tombe à 0 à t=46641. La voix a donc duré environ 7 s après « Stop » et s'est arrêtée à la fin naturelle de la phrase. Aucun « D'accord, je m'arrête » n'apparaît dans le transcript.
- Aucun événement d'interruption, d'annulation ni de changement d'état entre t=39465 et la fermeture. L'événement suivant est session.state closed reason=close_requested à t=54695 (unix 1793378402177), c'est-à-dire la fermeture demandée par l'app. Les délégations étaient déjà « completed » à t=22507-22508 (agent.activity) : il n'y avait plus de génération en vol à annuler.

CODE (aucune détection de « Stop » n'existe) :
- backend/orchestrator/internal/adapter/openailive/sideband.go:299-330 (translate) : seuls input_transcript.delta, output_transcript.delta, output_audio.delta, usage.updated, delegation.created et closed sont décodés. Il n'existe aucun événement d'interruption, ce qui est cohérent avec knowledge/realtime-voice/patterns/barge-in.md:13 [rt-barge-in] : « GPT-Live (full-duplex) : le modèle gère lui-même l'écoute pendant qu'il parle et l'interruption. Aucun événement d'interruption n'existe dans l'API. »
- backend/orchestrator/internal/app/voice/service.go:493-501 : le transcript d'entrée sert à deux choses seulement. Il est publié tel quel (translate, service.go:549-551) et il alimente la fenêtre de demande des délégations (fw.transcript → orchestrate/window.go:40 RequestWindow.Add, qui se contente de l'accumuler). Aucune recherche de mot-clé, aucun appel à Manager/SessionDelegations.Close, aucun deleteSurface, aucune commande au sideband pour faire taire la voix.
- backend/orchestrator/config/voice-instructions.fr.md:1-9 : les 9 lignes d'instructions vocales ne disent rien de « Stop » ni de « annule ». Le modèle n'a aucune consigne pour se taire sur ce mot.
- La seule annulation existante est celle de la fin de session : orchestrate/manager.go:502-510 Close → cancel(ErrSessionClosed), avec CancelTask A2A dans agents/internal/kit/executor.go:126-137. Elle n'est pas reliée à la voix.
- Côté Flutter (apps/genesis_canvas/lib) : rien pour couper la parole ou passer en muet. Le seul « interrompu » est l'état d'un agent dans le rail (agents_rail.dart:55).

DOCUMENTATION PRODUIT (c'est prévu pour plus tard) :
- product/functional/requirements.md:50 FR-16 Must ; FR-17 (l.51) précise que l'arrêt de la voix et l'annulation en vol (FR-14, FR-16) sont prévus à J7.
- product/roadmap/roadmap.md:63 : J7 Durcissement (8-9/11) = « Barge-in, "stop", faire-taire » avec FR-12 à FR-16. La l.23 ajoute « l'annulation en vol à J7 ».
- product/roadmap/open-questions.md:77 : Q-42 « Qui détecte "Stop" ? » est toujours ouverte (options : mot-clé côté orchestrateur ou décision du modèle), échéance avant J7.
- product/functional/features/barge-in.feature:19-25 : le scénario S-06 est écrit, mais aucun test ne le couvre (aucune occurrence de S-06 dans backend/ ni dans les tests de l'app).

### root_cause

Rien n'est implémenté, et c'est volontaire à ce stade : FR-16 est planifiée à J7 et Q-42 (qui détecte « Stop ») n'est pas tranchée. Le dépôt ne contient aucune détection de mot-clé : l'orchestrateur ne lit le transcript d'entrée que pour construire les demandes de délégation. Les instructions vocales ne contiennent aucune règle d'arrêt. Comme GPT-Live n'émet aucun événement d'interruption [rt-barge-in], le seul mécanisme actif aujourd'hui est le barge-in natif du modèle full-duplex, et c'est lui qui décide s'il cède la parole. Pendant l'essai, il ne l'a pas fait : « Pareil. Stop », court et précédé d'un « Ouais, ça avance » également ignoré, a probablement été pris pour une relance d'acquiescement. L'IA lisait aussi le commentaire de l'orchestrateur, qu'on lui demande de reprendre fidèlement (voice-instructions.fr.md:8). Cette dernière explication reste une hypothèse : les journaux ne montrent pas comment le modèle a décidé. Elle contraste avec la mesure du 2026-10-29 [rt-barge-in], où un « Stop » franc coupait la voix en 0,6 à 1,0 s, mais sur un seul essai, avec le navigateur et son AEC, alors qu'ici on passe par flutter_webrtc sous Linux. Enfin, aucune génération n'était en vol (délégations terminées à t=22,5 s) : l'autre moitié de FR-16, l'annulation et le retrait des surfaces inachevées, n'a pas été mise à l'épreuve.

### fix

À faire à J7, une fois Q-42 tranchée. Proposition en trois volets complémentaires :
1) Détection déterministe dans l'orchestrateur : dans backend/orchestrator/internal/app/voice/service.go, à la réception d'EventInputTranscriptDelta (l.494), passer le texte normalisé (minuscules, ponctuation retirée, sur une fenêtre glissante de quelques deltas) à un détecteur de mots d'arrêt (« stop », « annule », « arrête », « tais-toi »), avec une liste injectée par configuration. En cas de détection : (a) annuler les délégations en vol de la session (nouvelle méthode Manager.CancelInFlight, qui réutilise cancel/CancelTask comme manager.go:502-510 sans fermer la session) ; (b) envoyer un deleteSurface pour les surfaces inachevées et garder les surfaces complètes (RG-14) ; (c) publier sur l'app-channel un événement « interrupted » (voir le contrat app-channel) pour que l'orbe passe à l'écoute (FR-19) ; (d) faire taire la voix. Pour (d), il n'existe pas de cancel de réponse dans GPT-Live : il faut soit couper ou atténuer la piste audio distante côté app à réception de l'événement, soit, mieux, appendInstructions « tais-toi » combiné à la coupure côté client. C'est à vérifier dans la doc gpt-live avant de coder.
2) Ajouter dans backend/orchestrator/config/voice-instructions.fr.md une règle du type « Si l'utilisateur dit "stop", "annule" ou "arrête", tais-toi immédiatement et réponds seulement "D'accord." ». Coût presque nul, mais non déterministe.
3) Bouton « faire taire » à la souris (FR-20, pdr-0033) en secours, qui passe par le même chemin que le volet 1.
Tests : S-06 en BDD (Go avec faux fournisseur qui émet le delta « Stop » pendant une délégation en vol ; Flutter pour l'orbe et le retrait des surfaces), puis un essai réel où « Stop » tombe pendant la construction des surfaces.

### owner_decision

Q-42 : qui détecte « Stop » ? Options : (A) mot-clé repéré dans le transcript par l'orchestrateur. C'est déterministe et testable en BDD, et ça déclenche à coup sûr CancelTask et deleteSurface. Limites : la transcription arrive après coup (~1 à 1,5 s, cf. t=39465 pour un end_ms de 38200), et le mot « stop » cité dans une autre phrase peut déclencher à tort. (B) Décision du modèle via les instructions : c'est naturel, mais l'essai montre que le modèle peut ignorer « Stop », et rien n'annule la génération côté agents. (C) Hybride : le modèle est consigné pour se taire, l'orchestrateur détecte le mot-clé et pilote annulation, retrait des surfaces et coupure audio côté app. Il y a en plus le bouton souris (FR-20). Recommandation : (C), parce que FR-16 est un Must de démo et ne peut pas dépendre du seul jugement du modèle, qui vient d'échouer en conditions réelles. À trancher avant J7 (dim. 8/11). Il faut aussi confirmer qu'on accepte de couper ou d'atténuer la lecture côté app, puisque GPT-Live n'offre pas de commande pour annuler une réponse.

### contre-vérification

J'ai vérifié les preuves, et le diagnostic tient pour l'essentiel. Le code cité est exact : sideband.go:294-330 translate ne décode aucun événement d'interruption. Dans service.go:493-501, le transcript d'entrée ne sert qu'à fw.transcript. voice-instructions.fr.md fait 9 lignes et ne contient aucune règle d'arrêt. FR-16 (l.50), FR-17 (l.51), Q-42 (l.77, ouverte) et rt-barge-in:13 disent bien ce qui est cité. Dans les journaux, « Stop » n'apparaît que dans live_u2 (t=39465, start 38000-38200). La voix continue sans coupure jusqu'à « 4,0. » (end 44800) et aucun événement ne suit avant closed/close_requested à t=54695. Les délégations passent working→completed à t=22506-22508. Côté Flutter, le micro n'est pas coupé pendant que l'IA parle (getUserMedia avec echoCancellation, noiseSuppression et autoGainControl à true, flutter_web_rtc_platform.dart:18-22). Le modèle a donc bien reçu « Stop » et l'a transcrit. La cause retenue tient : rien n'est implémenté (FR-16 est prévue à J7, Q-42 est ouverte), et le barge-in natif de GPT-Live n'a pas cédé la parole.

Corrections à apporter :
1) Il est inexact d'écrire que « l'IA continue » pendant « Ouais, ça avance pour ce coup ». Le transcript de l'IA s'arrête à « 50 %, » (end_ms 29200) et ne reprend qu'avec « à » (start_ms 30800). Ce trou de 1,6 s recouvre exactement la parole utilisateur (29200-30000). Le modèle a donc écouté, a classé l'intervention comme un acquiescement, puis a repris. Le trou de 0,8 s autour de « Pareil » (36000→36800) est moins net, car il peut s'agir d'une fin de phrase. Après « Stop », il n'y a aucun trou : « d'av » finit à 38000 et « is » commence à 38000. Ces faits renforcent la cause (le modèle a entendu et a choisi de ne pas céder) et ils doivent remplacer la formulation actuelle. Ils montrent aussi que le barge-in natif fonctionne en partie sous flutter_webrtc Linux, puisque la voix de l'utilisateur est bien prise en compte.
2) L'argument de latence de l'option (A), « transcription ~1 à 1,5 s après coup, cf. t=39465 pour end_ms 38200 », n'est pas prouvé. Le transcript de sortie de l'IA présente le même écart constant de ~1235-1250 ms entre t_ms et end_ms. C'est donc un décalage d'horloge entre t_ms et l'horloge média, pas une latence d'ASR. Il faut retirer ce chiffre, ou le reformuler comme « latence réelle de la transcription non mesurée ».
3) Les transcripts de l'utilisateur dans cette session sont fragmentaires et douteux (« Ouais, ça avance pour ce coup », « Pareil », « . Stop », « Hop » à start 44600). Le porteur parle de « stop » au pluriel (« Lui dire stop ou essayer de lui couper la parole »). « Hop », juste avant la fin de la réplique, est peut-être une deuxième tentative mal transcrite. Il faut le signaler. Écrire « une seule occurrence de Stop » sous-estime peut-être les tentatives. Il faut aussi noter que noiseSuppression ou l'AEC de libwebrtc sous Linux peuvent dégrader la parole simultanée (double-talk), ce qui reste non prouvé. Pour le correctif, un détecteur de mot-clé strict raterait les « Stop » mal transcrits : il faut une liste tolérante, et le bouton souris (FR-20) devient un secours indispensable, pas seulement un complément.
4) Le volet 1(c) du correctif renvoie au contrat app-channel pour un événement « interrupted ». Cet événement n'existe pas dans product/architecture/app-channel-contract.md (aucune occurrence). Il faut l'ajouter au contrat, ce qui le fait évoluer et demande sans doute un PDR. Pour 1(d), la knowledge base dit que les instructions sont fixées au démarrage et que session.update se limite aux réglages delegation.responses (rt-gpt-live-session-config, rt-gpt-live-lifecycle). La consigne « tais-toi » envoyée en cours de session n'est donc possible que via un session.*.append, et son effet sur une réplique déjà en cours n'est pas démontré. Le seul levier sûr pour couper la voix vite est l'action côté app : couper ou atténuer la piste distante. Il faut le dire comme tel.
5) Le reste est juste : il n'y avait aucune génération en vol, donc la moitié annulation et retrait des surfaces (RG-14) n'a pas été mise à l'épreuve. Le niveau de confiance « haute » tient pour « non implémenté ». Pour la raison pour laquelle le modèle n'a pas cédé, il ne vaut que « moyenne ».

## barge-in — non-implémenté (confiance moyenne, effort M, vérifié : True)

### symptom

1) Quand le porteur parle pendant que l'IA parle (« Stop », « Pareil », « Hop »), l'IA ne se tait pas : elle lit son commentaire jusqu'au bout. L'orbe ne passe jamais par « Interrompue » et la réplique n'est pas tronquée (FR-13, FR-19, RG-11, RG-17). 2) Une pause au milieu d'une phrase est prise pour une fin de tour : la délégation part avant la fin de la phrase (FR-14, RG-12). 3) Les bruits ambiants ne déclenchent rien, ce qui confirme FR-18 et le bon fonctionnement de l'AEC.

### evidence

JOURNAUX (scratchpad/essai-micro-2026-10-30). Dans les transcripts, t_ms est l'heure du relais et start_ms/end_ms l'heure média. L'orb.level est le RMS de la SORTIE de l'IA : le seul événement qui le nourrit est EventOutputAudio (backend/orchestrator/internal/app/voice/service.go:555, adapter/openailive/sideband.go:305).

A. Absence de barge-in, session live_u2_Eejv9… (2026-10-30 ~16:39) :
- 22744→46082 : l'IA lit le commentaire final « D'accord… Voici ce que je constate : « 99,57 %… note moyenne 4,0. ».
- Pendant cette lecture, quatre énoncés de l'utilisateur sont transcrits par le serveur : « Ouais, ça avance pour ce coup » (t 30651, média 29200-30000), « Pareil » (t 38077, 36600-36800), « . Stop » (t 39465, 38000-38200) et « Hop » (t 46034, 44600-44800).
- Aussitôt après « Stop », la sortie reprend au mot près : delta ai « is » à t 39515 (38000-38200), puis « négatifs sur 1 164 avis en 7 jours (seuil ≤ 25 %, à risque) ; note moyenne 4,0. » jusqu'à t 46082 (end 44800).
- Le niveau de sortie reste en parole après « Stop » : 39461:0,075, 39638:0,094, 39842:0,076, 40932:0,121, 43228:0,117, 45148:0,115. Il ne tombe à 0 qu'à t 46641. L'IA a donc continué environ 6,6 s après le « Stop », jusqu'à la fin du texte.
- Aucun événement de délégation ni d'interruption après t 22505. Le serveur a pourtant entendu et transcrit chaque énoncé : le problème n'est ni l'AEC ni le micro.
- Les autres sessions ne contiennent aucun chevauchement. Dans live_u0_Eejy4…, l'IA parle sans interruption de t 45626 à 74801 et aucun transcript utilisateur parasite n'apparaît : l'AEC de flutter_webrtc sous Linux tient (FR-18 conforme).

B. Fin de tour prématurée :
- live_u2, t 22503 : le dernier mot « livraison » a start_ms=21000. La délégation arrive à t 22505 avec offset_ms=21000, c'est-à-dire au DÉBUT du dernier mot. Le message plan de t 22505 donne selected ["Qualité","Voix du client"], idle ["Livraison"], alors que l'utilisateur a dit « Qualité, voix du client et livraison ». La cause est dans backend/orchestrator/internal/app/orchestrate/window.go:77, `if f.start < offsetMs` : le fragment dont start == offset est exclu de la demande et reste en tampon pour une délégation suivante.
- Écart fin du dernier mot → offset_ms, sur les 11 délégations : −200, +200, +200, +200, +200, +400, +400, +800, +800, +1000, +1200 ms (granularité de 200 ms). Le modèle clôt donc le tour 0 à 800 ms après le dernier mot, et parfois avant sa fin. Une pause naturelle de plus de ~0,5 s suffit à fermer le tour.
- Sur la même demande : live_u0_Eejw… t 24464-26187, « Concentre-toi sur Android et compare avec la 3.3 », dite d'un trait, donne une seule délégation avec la comparaison. live_u0_Eejy4… t 43370-44126, « Concentre-toi sur Android », donne une délégation à offset 43600, soit 800 ms après le dernier mot. Puis à t 116752, « Compare avec la 3.3 » isolé donne trois agent.activity « rejected / hors périmètre » (t 118119). C'est le scénario de Q-74 (demande coupée en deux) : il explique aussi l'absence de comparaison vue par le porteur. Je ne peux pas prouver depuis les journaux que le porteur a marqué une pause à cet endroit précis.

CODE ET CONNAISSANCES :
- GPT-Live : aucun événement d'interruption, aucun réglage de tour de parole ([rt-barge-in], [rt-gpt-live-lifecycle], [rt-openai-realtime-vs-live] : « Tour de parole : géré par le modèle, non configurable »). SP-02 avait mesuré un arrêt en 0,6 à 1,0 s, mais pendant la parole propre du modèle, jamais pendant la lecture d'un `session.commentary.append`.
- `session.instructions.append` « peut interrompre la parole en cours » ([rt-gpt-live-lifecycle]). `session.input_audio.mute` ne coupe pas la sortie.
- L'app : packages/features/voice_session/lib/src/api/flutter_web_rtc_platform.dart:9-12 indique que « l'audio distant est joué nativement par la pile WebRTC ». Aucun contrôle de la piste distante, donc aucun arrêt local possible aujourd'hui.
- voice_session_status.dart n'a que Idle, Connecting, Active, Stopping… : il n'existe pas d'état Interrompue. Une recherche de « interrupt|Interrompu » dans apps/packages/backend ne trouve que agent_activity (fin de session), rien sur la voix.
- Le backend ne détecte pas « stop » : aucune occurrence dans backend/*.go, et Q-42 est ouverte.
- backend/orchestrator/config/voice-instructions.fr.md:8 dit « reprends fidèlement ses chiffres ». Aucune consigne ne demande de s'arrêter quand l'utilisateur parle.
- Le commentaire final est long : result_template « Voici ce que je constate : « %s » » (internal/bootstrap/config/phrases.fr.json:11) et résumé jusqu'à 600 runes (orchestrate/commentary.go:15). Il donne 15 à 30 s de monologue.
- Roadmap : barge-in, « stop » et FR-13 à FR-19 sont planifiés en J7 (product/roadmap/roadmap.md:37, 63). Q-40, Q-42, Q-67 et Q-74 sont ouvertes (product/roadmap/open-questions.md:75, 77, 98, 105).
- L'avertissement CMake libpulse concerne la capture loopback de getDisplayMedia, pas getUserMedia ni l'AEC. Il est sans rapport avec ces symptômes (lecture du message, non vérifié dans le code du plugin).

### root_cause

Trois causes se cumulent.

(1) Fonctionnalité non implémentée, planifiée en J7. Rien dans la chaîne ne gère l'interruption :
- pas de détection de chevauchement ni de « stop » côté orchestrateur (Q-42) ;
- pas de signal d'interruption vers l'app (Q-40) ;
- pas d'état « Interrompue » ni de troncature du transcript (FR-19) ;
- pas d'arrêt local de la lecture WebRTC (Q-67).
Tout repose sur le comportement natif de gpt-live-1.

(2) Limite ou comportement du fournisseur, aggravé par nos réglages. Pendant la lecture d'un commentaire injecté (`commentary.append`), gpt-live-1 a ignoré quatre prises de parole pourtant transcrites. Il a fini le texte au lieu de céder comme en SP-02. Hypothèse de confiance moyenne : un commentaire « à dire » long, ajouté à la consigne « reprends fidèlement ses chiffres », pousse le modèle à finir sa lecture. Le fournisseur n'expose ni événement d'interruption ni réglage `interrupt_response`/VAD.

(3) Fin de tour : le fournisseur clôt le tour 0 à 800 ms après le dernier mot, parfois avant la fin de ce mot. Ce n'est pas réglable : c'est une limite du fournisseur. S'y ajoute un BUG de code, window.go:77 (`f.start < offsetMs`), qui retire de la demande le mot commencé à l'instant même de l'offset (« livraison » perdu). Enfin, la reconstruction « par délégation » avec des agents sans état fait qu'une phrase coupée en deux donne une seconde moitié refusée (Q-74).

### fix

Par ordre de rapport effet/coût :

A. BUG de la fenêtre de demande, effort S. Dans backend/orchestrator/internal/app/orchestrate/window.go:77, inclure les fragments dont start <= offsetMs + marge (par exemple 400 ms, valeur à mettre en configuration). Dans manager.go:378, attendre brièvement (environ 300 ms) les deltas tardifs avant Take. Ajouter un test rouge reproduisant le cas réel : deltas « … client et » 20600, « livraison » 21000, offset 21000, et Livraison doit être sélectionnée.

B. Consignes vocales, effort S (pdr-0037, réglage prévu en J7). Ajouter dans backend/orchestrator/config/voice-instructions.fr.md :
- « Si l'utilisateur parle pendant que tu parles, même au milieu d'un commentaire, tais-toi aussitôt, écoute, et ne reprends pas la lecture sauf s'il le demande » ;
- « N'agis que quand la phrase de l'utilisateur est complète ; après une hésitation ou une phrase inachevée, attends la suite ».
Raccourcir le commentaire final (moins de 600 runes, une phrase par surface) pour réduire la fenêtre où une interruption est ignorée. À valider par un essai au micro : effet non garanti, puisque le tour de parole n'est pas configurable.

C. Interruption pilotée par l'orchestrateur, effort M (cœur de J7, FR-13 et FR-19) :
- Dans le service voix, on sait que l'IA parle (EventOutputAudio dont le RMS dépasse un seuil, ou deltas de sortie récents). On sait que l'utilisateur parle (EventInputTranscriptDelta dont le start_ms chevauche la sortie).
- Sur un chevauchement d'au moins 1 mot non trivial, ou sur un mot-clé (stop, attends, non, arrête : Q-42), envoyer `session.instructions.append` « L'utilisateur t'interrompt : arrête de parler et écoute ».
- Publier sur le canal app un nouveau message, par exemple `voice.interrupted {at_ms}`, à ajouter au contrat app-channel-contract.md. Il porte l'orbe à « Interrompue » puis « Écoute », et le TranscriptBloc tronque la réplique au dernier delta dont end_ms <= at_ms.
- Pour « stop », annuler aussi les tâches A2A en vol (FR-16).

D. Arrêt local de la lecture, effort M (Q-67). Dans flutter_web_rtc_platform.dart, exposer la piste audio distante (onTrack). Sur `voice.interrupted`, la couper (track.enabled = false), puis la réactiver à la première sortie du tour suivant. Cela masque le délai du serveur. Le comportement sur flutter_webrtc Linux reste à vérifier : non testé ([rt-barge-in], règle 5).

E. Phrase coupée en deux (Q-74, FR-14), effort M. Si un nouvel énoncé arrive moins de N s après une délégation dont le résultat n'est pas encore dit, ou si la seconde moitié est refusée faute de plateforme, la fusionner avec la demande précédente (contexte de l'acte : plateforme courante). Sinon, annuler et relancer la délégation (annulation en vol, J7).

### owner_decision

Questions :
1. Avancer maintenant (avant J6) le traitement du barge-in, prévu en J7, au vu de l'essai ?
2. Q-42 : qui détecte « stop », le mot-clé côté orchestrateur ou le modèle ?
3. Q-67 : accepter un arrêt côté client de la piste distante (coupure nette, mais l'IA peut finir sa phrase côté serveur et le transcript diverger du son) ?
4. Q-74 : fusionner les demandes rapprochées, ou laisser le refus ?

Options et recommandation :
- Corriger tout de suite le bug A de window.go (sans décision, effort S).
- Faire un essai court au micro avec les consignes B (coût de quelques centimes) pour voir si gpt-live-1 cède pendant un commentaire.
- Puis lancer C et D ensemble comme fonctionnalité dédiée.
- Pour Q-42 : un mot-clé côté orchestrateur plus le chevauchement, plus fiable et testable en BDD que la décision du modèle.
- Pour Q-74 : fusionner avec le contexte de l'acte, car l'agent sans état refuse « Compare avec la 3.3 », ce qui explique la comparaison absente.

### contre-vérification

J'ai vérifié les journaux et le code. Le cœur du diagnostic sur le barge-in tient : rien n'est implémenté (prévu en J7), et gpt-live-1 a lu son commentaire jusqu'au bout alors que le serveur avait transcrit « Pareil », « . Stop » et « Hop ». Les points suivants sont faux ou non prouvés et doivent être corrigés.

1. Q-74 et la comparaison absente : l'attribution est FAUSSE. Dans live_u0_Eejy4, « Concentre-toi sur Android » est dit à 41800-42800 ms (délégation offset 43600). « Compare avec la 3.3 » est dit à 115200-116200 ms, donc 72 s plus tard, après le commentaire, les actes act-1, act-2 et act-3 (t 58281, 67773, 69388) et l'annonce « La release 3.4 est bloquée ». Ce n'est pas une phrase coupée en deux par une pause : c'est une relance séparée, sans contexte. La demande reconstruite pour la délégation item_Eejzyoa… est seulement « Compare avec la 3.3 », et les trois agents sans état la rejettent (« hors périmètre », t 118119). La cause relève du contexte conversationnel : une demande de suivi n'hérite ni de la plateforme ni de la release courante. Ce n'est ni la fin de tour ni FR-14. Il faut retirer cet exemple de la preuve du symptôme 2, et la correction E doit viser la reprise du contexte de session ou d'acte pour une relance, pas la fusion d'énoncés rapprochés de moins de N s.

2. Symptôme 2 (une pause prise pour une fin de tour) : il n'est PAS prouvé par les journaux.
- Aucune des 11 délégations ne montre une phrase scindée en deux délégations rapprochées.
- Le seul cas réel de perte, « livraison » (start 21000, offset 21000), vient du bug de window.go:77 (`f.start < offsetMs`). Le mot était déjà dans le tampon : il est arrivé à t 22503, et la délégation à t 22505. Ce bug est confirmé.
- L'écart de −200 à +1200 ms est exact : je l'ai recalculé sur les 11 délégations. Mais il ne montre pas qu'une pause d'environ 0,5 s ferme le tour. Il faut retirer cette affirmation ou la marquer comme hypothèse.
- Il faut aussi préciser que offset_ms vient de `session.delegation.created`, émis par le modèle (sideband.go:317). C'est l'instant où le modèle DÉCIDE de déléguer, pas la fin d'un tour mesurée par une VAD.
- Un indice plus pertinent, à citer comme non prouvé : dans live_u0_Eejy4, « Fais voir » (164400-165000) donne la délégation offset 165200 avec selected [] et tous les agents en idle. Cela ressemble à une demande tronquée, mais aucune suite n'a été transcrite.

3. Nuance sur l'absence de barge-in. Trois des quatre énoncés tombent dans des silences de la sortie de l'IA :
- « Ouais… » (29200-30000) pendant le trou de sortie 29200-30800 ;
- « Pareil » (36600-36800) pendant le trou 36000-36800, avec l'orb.level à environ 0,001 entre t 37870 et 38463 ;
- « Hop » vers 44600, après un creux à t 44683-44909.
Les journaux ne permettent donc pas de distinguer deux cas : le modèle cède brièvement puis reprend (fausse interruption suivie d'une reprise), ou l'utilisateur parle dans les pauses naturelles. Seul « . Stop » (38000-38200) chevauche franchement la sortie (« is », 38000-38200), et la lecture continue jusqu'à end 44800. La conclusion « il ne s'arrête pas sur Stop » tient. En revanche, « aucun événement d'interruption » ne veut pas dire « le modèle n'a jamais cédé ».

4. Correction A : elle est juste, mais il faut aussi traiter le delta qui arrive APRÈS le Take avec start == offset. Aujourd'hui, ce delta reste dans le tampon et part avec la délégation suivante, puisqu'il n'est pas « tardif ». La marge et la brève attente proposées couvrent ce cas, à condition que le test rouge inclue aussi la variante où le delta arrive après la délégation.

5. Le reste est conforme à ce que j'ai vu : manager.go:378 Take, absence d'état Interrompue, gabarit « Voici ce que je constate : « … » ». Les recommandations C, D et les questions au porteur restent valables. Il faut remplacer la question 4 (Q-74, fusion) par : « Une relance comme ‹ Compare avec la 3.3 › doit-elle hériter de la plateforme et de la release de l'acte courant ? »

## click-latency — décision-manquante (confiance moyenne, effort M, vérifié : True)

### symptom

Clic sur « Bloquer la release » pendant que l'IA lit le résultat d'une délégation : le porteur dit n'avoir vu d'effet qu'une fois la voix terminée. Dans les journaux, il a cliqué trois fois (act-1, act-2, act-3) en 11 s, et la voix n'a confirmé qu'une fois, 16 s après le premier clic.

### evidence

Session live_u0_Eejy4p3oN2x0ythjZucUExikqmvEgxt1.jsonl (t_ms = temps de session ; unix_ms donné entre parenthèses) :
- t=45120 (1793378573398) : délégation vocale item_EejynvAde… (« Concentre-toi sur Android »). Livraison republie `/checklist` avec decisionStatus « En attente de décision » à t=45124.
- La voix lit ensuite un long résumé. Le premier transcript IA tombe à t=45626 (start_ms 44000). « Voici ce que je constate : « 99,43 %… » » s'étend de start_ms 46200 à 73400, puis la parole continue jusqu'à t=74801.
- t=58281 (1793378586559) : `plan` {delegation:"act-1", selected:["Livraison"]}. t=58282 : agent.activity Livraison working. **t=58283 (1793378586561) : a2ui `updateDataModel` path `/checklist/decisionStatus` value « Bloquée »**. t=58283 : Livraison completed. Il s'écoule 2 ms entre l'acceptation et le message d'interface, et à cet instant la voix est au milieu de « 30 % d'avis négatifs » (t=58235–58608).
- t=67773 (1793378596051) : act-2, nouvelle écriture « Bloquée » à t=67774. t=69388 (1793378597666) : act-3, « Bloquée » à t=69389. Le porteur a donc recliqué 9,5 s puis 11,1 s après le premier clic. Le bouton est bien redevenu actif, mais rien n'a signalé que la décision était prise.
- t=76233–78297 (start_ms 74600–76800) : la voix dit « C'est fait. La release 3.4 est bloquée. », une seule fois pour trois actions et seulement après la fin du résumé en cours (start_ms 73400). C'est 16,3 s après act-1. Plus aucune parole IA jusqu'à t=116752.
- t=133066 : une nouvelle demande vocale réécrit `/checklist` avec « En attente de décision ». La décision est perdue (limite connue Q-76).
Code :
- backend/orchestrator/internal/app/orchestrate/action.go:42-73 : `Manager.Act` met l'action en file sans attendre la voix. Le seul blocage est `busy` (l.60-67, délégation en file ou en cours).
- manager.go:463-486 (`run`/`busy`) : `pending` retombe à la fin de `Runner.Run`.
- pipeline.go:168-238 : une délégation vocale se termine après `say` (AppendCommentary).
- sideband.go:198-244 : `say` attend l'acquittement, borné par VOICE_APPEND_ACK_TIMEOUT (2 s, bootstrap/config.go:35). D'après la note de la base, cet acquittement arrive en 0,7 s (gpt-live-delegation-latency.md:17). La session ne pouvait donc plus être `busy` à t=58 s.
- action_run.go:37-81 : les messages a2ui de l'agent sont relayés pendant `runTasks`, avant `waitGeneric`/`announce`. L'annonce vocale vient ensuite : action_run.go:113-118 → reply.go:147-156 `AppendGeneralCommentary`, commentaire à delegation_id nul.
- VOICE_ANNOUNCE_TIMEOUT (config.go:37,341) sert uniquement à journaliser si la voix a parlé, sans rien attendre (reply.go:186-212). Il ne sérialise rien.
- Côté client : packages/features/canvas/lib/src/model/canvas_action_bloc.dart:52-105 retente sur 409, jusqu'à 6 essais à 1 s d'intervalle. Aucun 409 n'apparaît ici : act-1 est accepté dès qu'il arrive.
- release_checklist.dart:113-120 : le statut s'affiche en `Text` `textSecondary` dans un `Flexible` coincé entre le titre (`Expanded`) et la puce de recommandation. Il n'y a ni animation ni mise en avant, et le texte peut être tronqué par l'ellipse.
- action_bar.dart:84-88 : pendant l'envoi, le seul retour est la bordure qui passe de 2 à 1 px, pendant quelques millisecondes.
Limite : je n'ai pas les journaux de l'application (réception WSS, rendu) ni le stderr de l'orchestrateur (409 éventuels, « annonce vocale observée »). Je ne peux donc pas prouver que l'app a affiché « Bloquée » à t=58,3 s. C'est seulement très probable : genui 0.10.4 applique ce sous-chemin sans reconstruire la surface (knowledge/genui/core/data-model-binding.md), et le validateur client l'autorise (genesis_contract.dart:107-109).

### root_cause

Le backend ne fait pas attendre l'action derrière la voix. Il n'y a ni file bloquée, ni attente d'acquittement, ni effet de VOICE_ANNOUNCE_TIMEOUT : le statut « Bloquée » part vers l'app 2 ms après l'acceptation du clic, alors que la voix parle encore. Le retard ressenti a deux causes :
1. **Côté fournisseur, la confirmation vocale attend son tour.** Un `session.commentary.append` à delegation_id nul, envoyé pendant une réponse en cours, n'est dit qu'à la fin de cette réponse : ici 16,3 s plus tard, après un résumé de 28 s. L'orchestrateur ne coupe pas la parole en cours au clic (pdr-0065 D5 : la voix confirme après `completed`, sans préemption). Cela tranche Q-75 en partie : la voix parle bien hors délégation, avec un délai, et les trois annonces n'ont produit qu'une phrase.
2. **Côté interface, le retour visuel est presque invisible.** Seul un petit texte secondaire passe de « En attente de décision » à « Bloquée », sans mise en avant. Le bouton reste actif et pareil après la décision. Le porteur n'a pas vu le changement (deux clics de plus) et a pris la confirmation vocale pour le seul « effet ».
Facteur aggravant : aucune idempotence. Chaque clic relance Livraison et une annonce, dont deux sur trois se sont perdues.

### fix

A. Interface (à faire de toute façon, effort S à M) :
- packages/features/canvas/lib/src/catalog/release_checklist.dart:113-120 : afficher decisionStatus comme une puce ou un badge bien visible (DsStatusChip ou équivalent du design system), avec une brève mise en avant au changement (AnimatedSwitcher et surlignage), et sans troncature.
- action_bar.dart : montrer un état « en cours » (indicateur) pendant ActionSending/ActionRunning. Une fois la décision prise, marquer le bouton correspondant comme fait, par exemple « Release bloquée ✓ » désactivé, à partir de decisionStatus ou d'un champ de `/actions`.
- Ajouter un scénario BDD : « le statut change pendant que l'IA parle ».
B. Voix, au choix du porteur :
- (1) Garder l'ordre actuel : la confirmation vient après la phrase en cours. Rien à coder, mais documenter ce délai.
- (2) Au clic, interrompre la réponse en cours puis annoncer. Cela demande de vérifier ce que le sideband GPT-Live permet pour annuler une réponse, absent de knowledge/realtime-voice/openai/. Il faudrait alors appeler cette annulation dans Pipeline.runAction avant `announce`, en mode barge-in et derrière un drapeau de configuration.
C. Idempotence, effort S : dans Livraison ou dans l'orchestrateur, ignorer, ou ne pas réannoncer, une action dont l'effet est déjà en place.
D. Mettre à jour Q-75 (la voix hors délégation est observée, mais différée et dite une seule fois pour trois annonces) et la ligne FR-08 de requirements.md. Ajouter côté app une trace horodatée de réception et de rendu a2ui, pour pouvoir conclure lors du prochain essai.

### owner_decision

Faut-il qu'un clic sur une décision coupe la phrase que l'IA est en train de dire, pour confirmer tout de suite (« C'est fait, la release est bloquée ») ? Options :
(1) Non : la confirmation vocale vient après la phrase en cours, et l'interface montre le changement immédiatement et clairement.
(2) Oui : le clic interrompt la voix, comme un barge-in, puis la confirmation est dite. Cela demande un spike sur l'annulation de réponse dans GPT-Live.
(3) Oui, mais seulement si la phrase en cours dure encore plus de N secondes.
Recommandation : (1) d'abord, avec un retour visuel fort (correctif A), parce que c'est sûr et peu coûteux. Puis tester (2) en répétition si le délai vocal gêne le récit de l'acte 3.

### contre-vérification

J'ai vérifié les preuves citées : elles tiennent. J'ai relu live_u0_Eejy4p3oN2x0ythjZucUExikqmvEgxt1.jsonl avec jq et tous les horodatages concordent.
- act-1 : plan à t=58281, écriture `/checklist/decisionStatus` = « Bloquée » à 58283.
- act-2 : plan à 67773, écriture à 67774. act-3 : plan à 69388, écriture à 69389.
- Une seule phrase « C'est fait. La release 3.4 est bloquée. » (start_ms 74600 à 76800), juste après le « » » de fin du résumé (start_ms 73200 à 73400). Elle reprend mot pour mot `action_result_template` « C'est fait. %s » (phrases.fr.json:12). C'est donc bien une annonce de l'orchestrateur, pas une paraphrase du modèle.
- t=133066 : `/checklist` est réécrit avec « En attente de décision » (Q-76).

Le code confirme aussi ce que dit le diagnostic. `Act` (action.go:42-73) ne bloque que sur `busy` ou `running`. `runAction` relaie l'interface pendant `runTasks`, puis appelle `announce`, qui envoie `AppendGeneralCommentary` (reply.go:147). `watch` se contente d'observer. Côté client, `CanvasActionScope` remet les boutons en état actif dès que l'activité repasse au repos, ce qui explique que le porteur ait pu recliquer. Enfin, le statut s'affiche dans un `Text` secondaire en `Flexible` (release_checklist.dart:113-120), et la bordure du bouton passe seulement de 2 à 1 px.

La cause est bien établie : l'interface ne reste pas bloquée derrière la voix. Le diagnostic doit toutefois être corrigé ou nuancé sur les points suivants.

1. **Fichier mal cité.** Le diagnostic cite « reply.go:147-156 ». Le bon chemin est backend/orchestrator/internal/app/voice/reply.go, pas le paquet orchestrate.

2. **« Deux annonces sur trois perdues » n'est pas prouvé.** Sans le stderr de l'orchestrateur, on ne sait ni quelle stratégie a parlé (null, puis repli sur la dernière délégation, puis instructions), ni si les trois envois ont été acquittés ou refusés, ni lequel des trois actes a produit la phrase entendue. Le modèle peut aussi avoir fusionné trois commentaires identiques. Il faut le présenter comme une hypothèse.
   - Seul fait observé : trois actions ont produit une seule phrase.
   - Pour Q-75 : la voix a dit le texte hors délégation, avec un retard. On ne sait pas si c'était la stratégie 1. Q-75 ne peut donc pas être déclarée « tranchée en partie » sur la stratégie, seulement sur le fait que la voix a parlé.

3. **Facteur oublié : la longueur du résumé lu à voix haute.** Le retard de 16 s vient surtout du commentaire de la délégation vocale précédente, lu presque mot pour mot entre guillemets pendant environ 27 s (start_ms 46200 à 73400). Raccourcir ce résumé réduirait directement l'attente avant la confirmation, sans toucher à la préemption, et c'est sans risque. Il faut l'ajouter au correctif B comme option (0) : budget de résumé ou gabarit `result_template` plus court.

4. **Lien avec « Acte 1/3 ».** Juste avant ce point, le porteur signale que l'indicateur reste sur « Acte 1/3 » après le blocage. L'indicateur est piloté à la main (stage_bar.dart:11 : « un clic passe à l'acte suivant »). Aucun élément visible ne change donc au clic, à part le petit texte du statut. Cela renforce la cause 2 (retour visuel quasi invisible) et doit être cité comme symptôme lié, à traiter avec le diagnostic qui porte sur l'acte.

5. **Correctif A, précision sur la troncature.** `Expanded` (le titre) et `Flexible` (le statut) se partagent l'espace à parts égales. « Bloquée » est court et ne sera sans doute pas tronqué. Le vrai problème est le manque de mise en avant, pas l'ellipse.

6. **Idempotence (correctif C).** La justification « dont deux sur trois se sont perdues » est à retirer (voir point 2). Le correctif reste utile : il évite de relancer l'agent et de risquer plusieurs annonces. Il faut aussi désactiver ou marquer le bouton une fois la décision prise (déjà prévu en A).

7. **Confiance « moyenne » : c'est juste.** On n'a ni journaux de l'application ni stderr, donc rien ne prouve que « Bloquée » s'est affiché à t=58,3 s. Pour lever ce doute, il faut instrumenter la réception et le rendu a2ui côté app au prochain essai.

8. **Option B(2), barge-in au clic.** Elle reste un spike non documenté dans knowledge/realtime-voice/. Elle ne doit pas être présentée comme réalisable avant de vérifier l'annulation de réponse dans GPT-Live, ni avant le correctif du barge-in vocal, qui ne marche pas non plus d'après ce même essai.

## act-indicator — décision-manquante (confiance haute, effort S, vérifié : True)

### symptom

Pendant l'essai du 2026-10-30, l'indicateur de la barre supérieure est resté à « Acte 1/3 · Créer », y compris après la transformation de l'acte 2 et le clic « Bloquer la release » de l'acte 3.

### evidence

CODE : aucune avance automatique n'existe. C'est conforme à la décision en vigueur.
- packages/features/stage_controls/lib/src/model/stage_bloc.dart:17-24 : le StageBloc ne traite que deux événements. StageActAdvanced fait avancer l'acte de façon cyclique (ligne 20). StageResetRequested ramène à l'acte 1 (ligne 22). L'état initial est l'acte 1 (ligne 14).
- Il n'y a que deux émetteurs dans tout apps/ et packages/ (vérifié par grep) :
  - apps/genesis_canvas/lib/widgets/stage_bar/stage_bar.dart:38-40 : le clic sur `act-indicator` envoie StageActAdvanced ;
  - apps/genesis_canvas/lib/pages/genesis_canvas/genesis_canvas_page.dart:301 : `_resetStage()` envoie StageResetRequested.
- Aucun message `plan`, `a2ui` ou d'action ne touche au StageBloc. stage_bloc.dart:9-10 ajoute que le Bloc ne mute aucun autre Bloc : c'est la page qui coordonne.
- product/decisions/pdr-0063-007-stage-ui-details-assistant-decided.md:34 (D1) : l'indicateur « vaut 1 par défaut, se règle d'un clic (régie) […] L'avance automatique des actes n'est pas décidée ici ».
- Même fichier, ligne 46 (option écartée) : « Avancer l'acte automatiquement à partir des surfaces : relève de la mise en scène (porteur) ».

JOURNAL live_u0_Eejy4p3oN2x0ythjZucUExikqmvEgxt1.jsonl (session de 16:42:08 à 16:44:59), qui couvre les trois actes :
- Acte 1. 16:42:10, paroles « Prépare un release 3.4 ». 16:42:12, `plan` avec Qualité, Voix du client et Livraison retenus, puis createSurface reviews, checklist, kpi et trend.
- Acte 2. 16:42:51, « Concentre-toi sur Android ». 16:42:53, updateDataModel sur kpi, reviews, trend et checklist, plus createSurface `actions` (barre d'actions en fin d'acte 2, pdr-0061).
- Acte 3. Trois `plan` arrivent avec delegation=`act-1` à 16:43:06, `act-2` à 16:43:16 et `act-3` à 16:43:17 (selected=[Livraison]). Chacun est suivi d'un updateDataModel `/checklist/decisionStatus`=« Bloquée ». Cela fait trois actions acceptées en 11 s.
- Après l'acte 3 arrivent encore des demandes vocales : 16:44:05 « Compare avec la 3.3 » (updateDataModel à 16:44:21), puis 16:44:54 « Fais voir » (plan vide).

JOURNAL live_u0_Eejwtp3oMQLUCh9F7pRKedhD9xK2Q0PR.jsonl : à 16:41:00, une nouvelle demande de création sur un canevas déjà rempli ne produit que des updateDataModel pour reviews, kpi et trend, soit la même forme qu'une transformation d'acte 2. Seule checklist est recréée. Puis createSurface `actions` arrive à 16:41:22.

SIGNAUX DISPONIBLES :
- product/architecture/app-channel-contract.md:39 : un `plan` d'action porte delegation=`act-<n>` avec selected = Livraison seul. Le `plan` est rejoué aux abonnés tardifs.
- packages/features/canvas/lib/src/model/canvas_action_bloc.dart:101 : `emit(ActionRunning(name))` après le 202 de POST /canvas/actions. C'est un signal local, sous le contrôle de l'app.
- Le message `plan` ne contient aucun type de demande (créer, transformer ou interagir). Le seul champ qui distingue une action est l'id `act-<n>`. backend/orchestrator/internal/app/orchestrate/action.go:69.

### root_cause

Ce n'est pas un défaut. L'app n'a aucun chemin d'avance automatique, parce que pdr-0063 D1 a choisi un réglage manuel par la régie et a renvoyé l'avance automatique au porteur, comme question de mise en scène. Pendant l'essai, personne n'a cliqué sur l'indicateur, donc StageState est resté à act=1 (stage_bloc.dart:14). Le protocole ne fournit pas non plus d'information explicite sur l'acte : `plan` ne donne ni type de demande ni numéro d'acte. L'acte ne se déduit qu'indirectement, par la forme des messages A2UI (createSurface ou updateDataModel), par la surface `actions` ou par l'id `act-<n>`.

### fix

Pour une avance automatique fiable, il faut une règle monotone qui n'avance jamais en arrière toute seule. Le clic manuel reste prioritaire et la remise à vide ramène à 1.

1) Ajouter un événement `StageActReached(int act)` au StageBloc. Il émettrait max(état, act), avec un transformer séquentiel inchangé. StageActAdvanced resterait le moyen manuel de correction cyclique.

2) La page coordonne, comme `_resetStage()` le fait déjà (genesis_canvas_page.dart:295-303). Le StageBloc ne lit aucun autre Bloc.

3) Signaux, du plus fiable au moins fiable :
   - Acte 3 : le passage du CanvasActionBloc à ActionRunning (canvas_action_bloc.dart:101), c'est-à-dire un clic accepté (202). Ce signal est local, déterministe et ne peut pas venir d'un rejeu. Il vaut mieux l'utiliser que le `plan` `act-<n>`, qui est rejoué aux abonnés tardifs (app-channel-contract.md:39).
   - Acte 2 : l'apparition de la surface `actions` dans le CanvasBloc. Par pdr-0061, la barre d'actions arrive à la fin de l'acte 2, ce que confirment les journaux à 16:41:22 et 16:42:53. À ne pas utiliser : « un updateDataModel sur une surface existante ». Le journal de 16:41:00 montre qu'une nouvelle demande de création sur un canevas plein produit exactement cette forme, ce qui ferait un faux acte 2.
   - Acte 1 : c'est déjà la valeur par défaut, rien à faire.

4) Tests BDD (.feature) et un test unitaire du Bloc, pour vérifier : la monotonie, la remise à vide puis le retour à 1, la correction manuelle après une avance automatique, un clic d'action sans surface `actions`, et le rejeu sans effet.

Risques :
(a) Le signal de l'acte 2 dépend d'un choix de l'agent Livraison. Si l'agent ne crée pas `actions` (l'agent a refusé, ou la transformation est partielle), l'indicateur reste à 1. Avec un clic ensuite, il saute directement de 1 à 3.
(b) Si le speaker improvise, par exemple en recréant après une transformation ou en demandant une comparaison après l'acte 3 (16:44:05), l'indicateur n'est jamais faux grâce à la monotonie, mais il peut être en retard.
(c) Après une remise à vide, un abonnement tardif peut rejouer des messages retenus. Cela ne pose pas de problème si l'acte 3 est déclenché par le signal local et l'acte 2 par l'état du CanvasBloc déjà remis à vide. À vérifier dans le test de remise à vide.
(d) Avec pdr-0052 (une session voix par acte), on pourrait être tenté d'utiliser l'ouverture de session comme signal. Les journaux montrent que non : 5 sessions ont eu lieu sans lien avec les actes (16:38:49, 16:39:07, 16:40:55, 16:42:08, 16:45:23).
(e) Les doubles clics (act-1, act-2, act-3 en 11 s) sont sans effet grâce à max().

Option la plus robuste, plus coûteuse : ajouter au message `plan` un champ explicite (`kind`: create|transform|action) calculé par l'orchestrateur. Cela demande de changer le contrat app-channel et le backend Go. Le planner à tags (TagPlanner) ne distingue pas aujourd'hui créer et transformer : il faudrait le lui apprendre.

### owner_decision

Question : faut-il que l'indicateur d'acte avance tout seul ? pdr-0063 D1 l'a laissé non décidé et a classé l'avance automatique comme un choix de mise en scène qui revient au porteur.

Options :
(A) Garder le réglage manuel et prévoir le clic dans le script de répétition. Coût nul. Risque : l'oubli sur scène, comme pendant l'essai.
(B) Avance automatique monotone côté app : acte 2 quand la surface `actions` apparaît, acte 3 au premier clic d'action accepté. Le clic manuel sert de correction et la remise à vide ramène à 1. Effort S, sans changement du backend ni du contrat.
(C) Comme B, mais avec un champ `kind` explicite dans `plan`, émis par l'orchestrateur. C'est plus juste, mais il faut toucher au contrat, au backend Go et au planner. Effort M.
(D) Supprimer l'indicateur.

Recommandation : (B). Les deux signaux sont déjà présents dans l'app, ils sont déterministes et ont été observés pendant l'essai (16:42:53 et 16:43:06). La monotonie protège des faux reculs, et la correction manuelle reste possible. La décision doit faire l'objet d'un nouveau PDR qui complète pdr-0063 D1.

### contre-vérification

J'ai vérifié les preuves citées, qui sont exactes. Dans stage_bloc.dart, l'état initial vaut act=1 (ligne 14). Le gestionnaire unique et séquentiel occupe les lignes 17-24 : l'avance est cyclique à la ligne 20, le retour à 1 à la ligne 22. Le grep confirme qu'il n'y a que deux émetteurs : stage_bar.dart:40 (onPressed de `act-indicator`) et genesis_canvas_page.dart:301 (`_resetStage`). pdr-0063 D1 (l.34) et l'option écartée (l.46) sont cités fidèlement, comme app-channel-contract.md:39 (rejeu du `plan` aux abonnés tardifs, `act-<n>`) et canvas_action_bloc.dart:101 (`emit(ActionRunning(name))`). Les journaux confirment la chronologie. Pour live_u0_Eejy4p3o…, les surfaces reviews, checklist, kpi et trend sont créées à 16:42:12, `actions` à 16:42:53, puis les plans act-1, act-2 et act-3 arrivent à 16:43:06, 16:43:16 et 16:43:17, suivis de « Compare avec la 3.3 » à 16:44:05 et de « Fais voir » à 16:44:54. Pour live_u0_Eejwtp3o…, seule checklist est recréée à 16:41:00 et `actions` apparaît à 16:41:22. La cause est la bonne : l'indicateur est une commande manuelle de régie et personne n'a cliqué dessus. Aucune cause plus probable n'apparaît.

Quatre corrections mineures à apporter :
1) FR-11 porte sur la remise à vide, pas sur l'indicateur. Elle ne vaut que pour le « retour à 1 ». Les références de l'indicateur sont pdr-0054 (Q-22) et pdr-0063 D1. Il faut aussi citer product/functional/screen.md:36 et product/architecture/frontend-screen.md:19, qui décrivent ce comportement manuel et cyclique : ce comportement est donc documenté et attendu, pas un écart.
2) Il manque une cause ergonomique. Le porteur demande « C'est normal ? », ce qui montre qu'il ignorait que l'indicateur se clique. C'est un TextButton stylé comme un libellé, sans affordance visible. Le diagnostic doit le dire, et l'option (A) n'est crédible que si l'affordance est rendue visible (et la consigne ajoutée au script de répétition).
3) Les trois plans act-1, act-2 et act-3 en 11 s sont probablement des clics répétés faute de retour visible. Le porteur signale en effet que « Bloquer la release » n'a eu d'effet qu'après le discours de l'IA. Il faut lier ce point au diagnostic de ce symptôme plutôt que de parler seulement de « doubles clics sans effet ». Cela ne change pas la recommandation (B), puisque max() les absorbe.
4) Le nouveau PDR doit être enregistré comme « proposé » jusqu'à ce que le porteur tranche. pdr-0063 classe l'avance automatique comme un choix de mise en scène qui revient au porteur.

La correction (B) est juste et suffisante. Ses deux signaux sont bien choisis : ActionRunning est local et non rejoué, et la surface `actions` ne se confond pas avec la forme updateDataModel trompeuse vue à 16:41:00. La monotonie et la correction manuelle sont cohérentes avec le code existant.
