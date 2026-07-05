# IOTA T@H Monitor — Guide agent

@AGENTS.md

> Lis ce fichier, `AGENTS.md`, `MEMORY.md` et `llms.txt` **avant** toute tâche de code.

## Ce que c'est
App **menu bar macOS** (Swift/AppKit) qui lit le log CLI de l'app officielle IOTA
"Train at Home" et affiche la vraie position de queue / state / work — que l'UI
officielle n'affiche pas (son handler `register.queue_state` renvoie 503). Lecture
seule, aucune connexion réseau, aucune dépendance runtime.

## Stack
Swift 6 · AppKit (`NSStatusItem`) · ServiceManagement (`SMAppService`, login item) ·
macOS 13+ · SwiftPM (tests du core uniquement) · pas de dépendance tierce.

## Commandes
| But | Commande |
|-----|----------|
| Tests (core) | `swift test` |
| Build app | `./build.sh` → `IOTA Monitor.app` |
| Lancer | `open "IOTA Monitor.app"` |
| Test parser sur log réel | voir `README.md` § Maintainability |

## Layout
- `Sources/IOTAMonitorCore/` — logique pure **testée** (`LogReader`, `StateParser`), aucune dépendance AppKit. Cible SwiftPM.
- `App/` — app AppKit (`main.swift`, `Preferences.swift`). **Hors SwiftPM**, buildée par `build.sh` via `swiftc` (compile core + app en un seul module).
- `Tests/IOTAMonitorCoreTests/` — tests du parser (`@testable import IOTAMonitorCore`).

## Mémoire & documentation (obligatoire)
- **Avant de coder** : lire `MEMORY.md` (état courant) + `llms.txt` (index doc).
- **Après chaque edit** : mettre à jour `MEMORY.md` (état, prochaines étapes, gotchas).
- **À chaque changement d'archi/pattern/format de log** : mettre à jour `docs/` + `llms.txt`.
- `MEMORY.md` = mémoire de travail courte. `docs/` = doc détaillée stable. Ne pas dupliquer.

## Qualité de code
- **DRY / SRP** : 1 fichier = 1 responsabilité. Le core reste **sans AppKit** (testable).
- **Taille** : warning à 400 LOC, découpage à 500.
- **Naming explicite** ; booléens `is/has/can/should`.
- **Early returns**, max 3 niveaux d'indentation.
- **Pas de dead code**, pas de `TODO` sans suite.
- **Parsing défensif** : `StateParser` ne doit **jamais** throw ni crasher sur une ligne inconnue — fallback sur la dernière ligne brute.

## Conventions du projet
- **Tests** : le core (`LogReader`/`StateParser`) est couvert par `swift test` — toute modif du parsing doit garder les tests verts et ajouter un cas pour le nouveau format. L'app AppKit n'a pas de tests auto (vérif manuelle : `./build.sh` + `open`).
- **Format de log = contrat** : tout dépend des strings écrites par le miner. Voir `docs/architecture.md` et `README.md` § Maintainability pour où toucher.
- **Commits** : Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`…).
- **Langue** : doc/commentaires en **FR** possible, identifiants + commentaires de code existants en **EN** (garder la cohérence du fichier édité).
- **Pas de réseau** : ne jamais ajouter de connexion au ws `127.0.0.1:8010` (token tournant + conflit avec l'hôte Electron). Lecture de log uniquement.

## Parallélisation des subagents (par défaut)
Pour tout travail décomposable, lancer plusieurs subagents en parallèle (une réponse, plusieurs appels) :
- Exploration : plusieurs `Explore` ciblés.
- Édition multi-fichiers : un agent par fichier indépendant.
- Revue : agents par dimension en parallèle.
- Optimiser le `model` par agent : `haiku` recherche/doc/mécanique, `sonnet` code/review, `opus` archi/debug difficile.

## Agents projet
- `log-format-watcher` (haiku) — vérifie que les matchers de `StateParser` collent au log réel courant. **Point de fragilité #1.**
- `swift-reviewer` (sonnet) — review Swift/AppKit (retain cycles, main-thread UI, idiomes `NSStatusItem`/`SMAppService`).
- `doc-maintainer` (haiku) — sync `docs/` + `llms.txt` + `MEMORY.md` après changement d'archi/pattern.

## MCP
Aucun `.mcp.json` : app native sans surface web (le MCP `chrome-devtools` ne s'applique pas). `context7` (global) reste utile pour la doc AppKit/SwiftPM.

## Pointeurs
`AGENTS.md` — règles agent · `llms.txt` — index doc · `docs/` — doc détaillée · `MEMORY.md` — mémoire de travail · `README.md` — usage + maintenabilité.
