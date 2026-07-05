# 0001 — Lire le log, ne pas tapper le ws

- **Statut** : accepté
- **Date** : 2026-07-05

## Contexte
L'app officielle expose un serveur ws local (`ws://127.0.0.1:8010/ws?token=…`) qui
porte l'état temps réel (position de queue, training.state…). On pourrait s'y
brancher pour un affichage plus riche. Alternativement, tout l'état passe aussi
dans le log CLI `~/Library/Logs/IOTA Train at Home/<date>-cli.log`.

## Décision
Source **unique = le log CLI**, en lecture seule. Pas de connexion au ws.

## Raisons
- Le **token du ws change à chaque restart** de l'app (observé : 4 tokens
  différents sur 3 jours) → impossible à câbler de façon stable.
- L'**hôte Electron occupe déjà la connexion** ; un second client risque
  d'interférer avec le mining.
- Le log contient déjà tout le nécessaire (position, state, speedtest, erreurs
  backend). Lire un fichier est robuste et sans effet de bord.

## Conséquences
- Rafraîchissement par polling (5 s) plutôt que push temps réel — acceptable.
- Le comportement dépend du **format des lignes de log** (contrat implicite) → couvert
  par les tests de `StateParser` et surveillé par l'agent `log-format-watcher`.
- Si un jour un affichage sub-seconde devient nécessaire, réévaluer le ws (avec
  lecture du token depuis le log courant, et en read-only côté protocole).
