# AGENTS.md — IOTA T@H Monitor

Règles pour les agents IA. Inclus par `CLAUDE.md` (`@AGENTS.md`).

## Avant de coder
- Lire `MEMORY.md` + `llms.txt`. Mettre à jour `MEMORY.md` après chaque edit.
- La doc officielle fait foi sur tes données d'entraînement. Pour AppKit /
  ServiceManagement / SwiftPM, vérifier l'API via la doc Apple ou le MCP
  `context7` plutôt que de deviner (`SMAppService` est macOS 13+, API récente).

## Le format de log est le contrat
- Le projet ne fait que **lire et parser** le log de l'app officielle. Tout le
  comportement dépend des strings que le miner écrit dans
  `~/Library/Logs/IOTA Train at Home/<date>-cli.log`.
- Avant de modifier `StateParser`, regarder un log réel courant pour confirmer le
  format. Après modif : `swift test` doit rester vert + ajouter un cas de test
  pour tout nouveau motif.
- Le parsing du **work effectif** est *best-effort* : aucune ligne de training
  réelle observée à ce jour. Quand une vraie apparaît (front de queue atteint),
  capturer la ligne exacte et enrichir `workDescription`.

## Invariants non négociables
- **Lecture seule** : jamais d'écriture dans les logs, jamais de modif de l'app
  officielle, jamais de connexion au ws `127.0.0.1:8010`.
- **`StateParser` ne throw jamais** et ne crash pas sur ligne inconnue.
- **Core sans AppKit** : `Sources/IOTAMonitorCore/` reste importable/testable sans
  UI. L'UI vit dans `App/`.

## Outillage
- Pas de dépendance tierce, et c'est un objectif : préférer la stdlib/Foundation.
  N'ajouter une dépendance qu'avec raison documentée (ADR dans `docs/decisions/`).
- Build app = `./build.sh` (swiftc → `.app`). Tests = `swift test`.

## Workflow
- Paralléliser le travail indépendant (cf. `CLAUDE.md`).
- Jamais de commit/push sans validation explicite. Respecter Conventional Commits.
- Respecter lint implicite : pas de warning `swiftc`, code idiomatique.
