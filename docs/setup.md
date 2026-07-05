# Setup

## Prérequis
- macOS 13 (Ventura) ou plus
- Xcode command-line tools avec `swiftc` + `swift` (build & tests). Aucune
  dépendance runtime.

## Cloner & builder
```bash
git clone git@github.com:CorentinGC/iota-tah-monitor.git
cd iota-tah-monitor
swift test        # lance les tests du core
./build.sh        # produit "IOTA Monitor.app"
open "IOTA Monitor.app"
```

Pour garder l'app : glisser `IOTA Monitor.app` dans `/Applications`.

## Variables d'environnement
Aucune. Le seul chemin externe est le répertoire de log, codé dans
`LogReader.logDir` :
`~/Library/Logs/IOTA Train at Home/`.

## Lancement au démarrage
Menu de l'app → *Lancer au démarrage*, ou fenêtre *Préférences…*. Utilise
`SMAppService` ; macOS peut demander l'approbation dans *Réglages Système →
Général → Ouverture*.

## Commandes
| But | Commande |
|-----|----------|
| Tests | `swift test` |
| Build | `./build.sh` |
| Lancer | `open "IOTA Monitor.app"` |
| Tuer l'instance | `pkill -f "IOTA Monitor"` |
