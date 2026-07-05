# MEMORY — IOTA T@H Monitor

> Mémoire de travail. À LIRE avant de coder, à METTRE À JOUR après chaque edit.
> Concis (< 150 lignes). Doc détaillée → `llms.txt` / `docs/`.

## État courant
- v1 fonctionnelle : menu bar affiche position/state/work/speedtest/backend,
  toggle *launch at login* (`SMAppService`) + fenêtre Préférences.
- Publié sur GitHub `CorentinGC/iota-tah-monitor` (branche `main`).
- Core restructuré en cible SwiftPM testable ; `swift test` = 6 tests verts.
- Config agentique en place (CLAUDE.md, AGENTS.md, docs/, llms.txt, agents).

## Prochaines étapes
- [ ] Affiner `StateParser.workDescription` une fois le front de queue atteint
      (capturer une vraie ligne de training — jamais observée à ce jour).
- [ ] Optionnel : icône `.icns` + statut coloré selon phase.

## Décisions récentes
- 2026-07-05 — Lecture du log CLI uniquement, pas de ws (token tournant + conflit
  hôte Electron). Voir `docs/decisions/0001`.
- 2026-07-05 — Core sans AppKit dans `Sources/IOTAMonitorCore/` (SwiftPM/tests),
  app AppKit dans `App/` (build via `build.sh`/swiftc, hors SwiftPM).

## Pièges / gotchas
- **Format de log = contrat** : un changement de wording côté Macrocosmos casse le
  parsing en silence. Lancer l'agent `log-format-watcher` en cas de doute.
- L'app officielle relancée = nouveau `queue_id` = fin de queue. Ne pas restart.
- `main.swift` n'importe PAS `IOTAMonitorCore` : au build app, swiftc compile
  core + App ensemble en un seul module.
- `swift test` ne build PAS l'app (AppKit) — seulement le core.

## Pointeurs
- Archi : `docs/architecture.md` · Setup : `docs/setup.md` · Index : `llms.txt`
