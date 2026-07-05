# Architecture

## Vue d'ensemble

Un seul processus Swift/AppKit, **lecture seule**, sans réseau. Un timer (5 s) lit
la fin du log CLI de l'app officielle, le parse, et repeint la barre de menu.

```
~/Library/Logs/IOTA Train at Home/<YYYY-MM-DD>-cli.log
        │  (tail, 64 KB)
        ▼
   LogReader ──► StateParser ──► MinerState ──► MenuBarApp (NSStatusItem)
```

## Modules

| Fichier | Rôle | Dépendances |
|---------|------|-------------|
| `Sources/IOTAMonitorCore/LogReader.swift` | Résout le log du jour, lit le tail (64 KB), gère fichier absent/vide + rotation de date à minuit. | Foundation |
| `Sources/IOTAMonitorCore/StateParser.swift` | Regex du tail → `MinerState`. Défensif, ne throw jamais. | Foundation |
| `App/main.swift` | `NSStatusItem`, boucle timer, rendu titre + menu. | AppKit, ServiceManagement |
| `App/Preferences.swift` | Toggle *launch at login* (`SMAppService`) + fenêtre Préférences. | AppKit, ServiceManagement |

## Frontière core / app

Le **core** (`Sources/IOTAMonitorCore/`) ne dépend que de Foundation → testable via
SwiftPM (`swift test`, `@testable import`). L'**app** (`App/`) porte tout AppKit.
`build.sh` compile les deux répertoires ensemble en un seul module via `swiftc`
(donc `main.swift` n'importe pas `IOTAMonitorCore` — même module au build app).
SwiftPM ne connaît que le core + les tests.

## Flux de données

1. `LogReader.readTail()` → `.ok(text, mtime)` / `.empty` / `.missing`.
2. `StateParser.parse(text:now:)` → `MinerState { position, trendPerMin, phase,
   workLine, speedtestOk, queueStateErrors, notFoundErrors, uptime, lastLogTime,
   lastRawLine }`.
3. `MenuBarApp` mappe `phase` → titre (`⛏ <pos> ▼/▲`, `off`, `…`, `▶︎`, `?`) et
   construit le menu déroulant.

## Décisions structurantes
- **Log-only, pas de ws** : le token du ws `127.0.0.1:8010` tourne à chaque
  restart et l'hôte Electron occupe la connexion. Voir `decisions/0001`.
- **Machine à états** dérivée du log : `off → starting → resetting → speedtest →
  queued → working`. `off` aussi si dernière ligne > 120 s (log figé).

## Point de fragilité
Le **format des lignes de log** est le contrat implicite. Un changement de wording
côté Macrocosmos casse le parsing silencieusement — d'où l'agent
`log-format-watcher` et la couverture de tests sur `StateParser`.
