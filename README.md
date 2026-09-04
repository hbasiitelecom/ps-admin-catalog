# ps-admin-catalog

Base de données partagée du lanceur de scripts PowerShell 7 pour Microsoft 365 - une interface graphique qui parcourt, documente et exécute des scripts d'administration provenant de dépôts publics.

Ce dépôt ne contient **aucun script**. Il contient la couche de connaissance qui les rend exploitables : quels dépôts indexer, comment classer les scripts par service, lesquels ne tournent plus sous PowerShell 7, et ce qu'on a appris de chacun à l'usage.

**Le fichier publié est [`catalog.json`](catalog.json).** L'application le télécharge, le met en cache, et signale discrètement quand une nouvelle version paraît. Rien n'est jamais écrasé sans action de l'utilisateur.

## Brancher l'application

Copiez l'URL brute de `catalog.json` :

```
https://raw.githubusercontent.com/<compte>/<dépôt>/main/catalog.json
```

Dans l'application : bouton **⚙** → collez l'URL → **Vérifier maintenant** → **Appliquer la mise à jour**. À refaire une fois sur chaque machine.

## Ce que contient le catalogue

| Section | Rôle |
|---|---|
| `sources` | Dépôts GitHub indexés par l'application |
| `services` | Catégories du rail de navigation, déduites des cmdlets de connexion |
| `rules` | Verdicts de compatibilité PowerShell 7, avec leur explication |
| `overrides` | Annotations par script : note d'usage, verdict forcé, renommage, masquage |
| `indexBaseUrl` | Où l'application lit les index précalculés, plutôt que de cloner les dépôts |

Les **index précalculés** vivent sur la branche [`index`](https://github.com/hbasiitelecom/ps-admin-catalog/tree/index) : une fiche complète par script, construite une fois par l'action GitHub, que l'application lit au lieu d'analyser les dépôts sur le poste. Le script lui-même reste en ligne jusqu'au moment où on le lance. Format et raisons dans **[docs/INDEX.md](docs/INDEX.md)**.

La référence complète du format est dans **[docs/SCHEMA.md](docs/SCHEMA.md)**. Le schéma exécutable est dans [`schema/catalog.schema.json`](schema/catalog.schema.json) - les éditeurs qui lisent le champ `$schema` offrent l'autocomplétion et la validation à la frappe.

## Organisation du dépôt

```
catalog.json              le fichier publié - c'est le produit
schema/                   JSON Schema (draft 2020-12)
tools/validate_catalog.py validateur sans dépendance, utilisé par la CI
tools/Build-SourceIndex.ps1 générateur des index, exécuté par la CI
docs/SCHEMA.md            référence du format
docs/INDEX.md             format des index et modèle « à la demande »
docs/VERSIONING.md        ce qui déclenche un MAJEUR, un MINEUR, un CORRECTIF
CHANGELOG.md              historique lisible des versions
CONTRIBUTING.md           comment proposer un changement
SECURITY.md               modèle de menace et signalement

branche « index »         index précalculés, un par source, plus manifest.json -
                          produit dérivé, réécrit par l'action, hors de main
```

`catalog.json` reste **à la racine** volontairement : son URL brute est le contrat avec toutes les installations déjà déployées. La déplacer casserait chaque poste configuré.

## Contribuer

Toute modification passe par une *pull request* et doit franchir la validation automatique. Voir [CONTRIBUTING.md](CONTRIBUTING.md).

En local, avant de proposer :

```bash
python3 tools/validate_catalog.py catalog.json --check-format
```

Le validateur vérifie ce qu'un schéma seul ne peut pas voir : unicité des identifiants, existence de la source référencée par chaque annotation, compilation effective de chaque expression régulière, absence de motifs à explosion combinatoire, et incrémentation cohérente de `catalogVersion`.

## Versions

`catalogVersion` suit le [versionnage sémantique](https://semver.org/lang/fr/). Le point important, propre à ce catalogue :

> **Retirer ou renommer l'`id` d'une source impose une version MAJEURE.** Les favoris et l'historique des utilisateurs se réfèrent aux scripts par `<id de source>:<chemin>` - changer l'identifiant les rend orphelins.

Les règles complètes sont dans [docs/VERSIONING.md](docs/VERSIONING.md), et l'historique dans [CHANGELOG.md](CHANGELOG.md).

`schemaVersion` est un champ distinct : c'est le contrat structurel avec l'application, qui refuse proprement un catalogue trop récent pour elle plutôt que de planter.

## Licence et provenance

Le contenu de ce dépôt - schéma, validateur, documentation, catalogue - est sous [licence MIT](LICENSE).

**Aucun code tiers n'est redistribué ici.** Les scripts référencés restent soumis aux conditions de leurs dépôts d'origine, que ce catalogue ne modifie ni n'étend. Le dépôt `admindroid-community/powershell-scripts` ne déclare aucune licence : tous droits réservés à ses auteurs, avec les seuls droits que les conditions de GitHub attachent à un dépôt public.

Projet indépendant, sans affiliation avec AdminDroid ni avec aucun des éditeurs référencés. Détails dans [NOTICE.md](NOTICE.md).
