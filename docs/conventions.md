# Conventions

## Code
- **Core sans AppKit** : `Sources/IOTAMonitorCore/` n'importe que Foundation. Toute
  logique parseable/testable y vit. AppKit/ServiceManagement restent dans `App/`.
- **`StateParser` défensif** : ne throw jamais, ne crash pas sur ligne inconnue —
  fallback sur `lastRawLine`. Un format non reconnu doit dégrader, pas planter.
- **Naming** explicite ; booléens `is/has/can/should` ; early returns ; ≤ 3 niveaux
  d'indentation ; pas de dead code.
- **Commentaires de code en anglais** (cohérence avec l'existant). Docs `docs/` en FR.

## Tests
- Le core est couvert par `swift test` (`Tests/IOTAMonitorCoreTests/`).
- Toute modif du parsing : garder les tests verts **et** ajouter un cas pour le
  nouveau motif de log. Utiliser des fixtures = vraies lignes de log.
- L'app AppKit n'a pas de tests auto → vérif manuelle (`./build.sh` + `open`).

## Format de log (contrat)
Les matchers de `StateParser` dépendent des strings du miner. Où toucher quand le
format change :
| Donnée | Point de code |
|--------|---------------|
| Position | `firstInt(after: "'position':")` |
| Phase | `derivePhase(...)` |
| Work | `workDescription(in:)` (best-effort) |
| Backend | comptage `503 … queue_state` / `404 … orchestrator request` |

## Git
- **Conventional Commits** : `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`.
- Pas de commit/push sans validation explicite.
- `IOTA Monitor.app`, `.build/`, `.mcp/` sont gitignorés.

## Décisions
Toute décision technique notable → un ADR dans `docs/decisions/` (voir le template).
