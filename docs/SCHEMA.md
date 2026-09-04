# Référence du format

Description exhaustive des champs de `catalog.json`. Pour la mise en route, voir le [README](../README.md) ; pour les règles de version, [VERSIONING.md](VERSIONING.md).

L'application le télécharge, le met en cache localement, et signale discrètement quand une nouvelle version est publiée. **Rien n'est jamais écrasé sans action de ta part**, et le catalogue ne contient aucune donnée personnelle : favoris, historique et préférences restent sur chaque machine.

## Schéma

### Racine

| Champ | Obligatoire | Rôle |
|---|---|---|
| `schemaVersion` | oui | `1`. Une application plus ancienne refuse un schéma plus récent. |
| `catalogVersion` | oui | SemVer `MAJEUR.MINEUR.CORRECTIF`. Toute différence avec la version locale déclenche la notification. Voir [VERSIONING.md](VERSIONING.md). |
| `name` | oui | Nom affiché dans la barre d'état et la fenêtre de réglages. |
| `indexBaseUrl` | non | Base des index précalculés, terminée par `/`. L'application y lit `manifest.json` puis `<sourceId>.json` au lieu de cloner et d'analyser. Absente : analyse locale. Voir [INDEX.md](INDEX.md). |
| `sources` | oui | Dépôts GitHub à indexer. |
| `services` | non | Catégories du rail de navigation. |
| `rules` | non | Règles de compatibilité PowerShell 7. |
| `overrides` | non | Annotations par script. |

### `sources`

```json
{
  "id": "admindroid",
  "name": "AdminDroid Community",
  "owner": "admindroid-community",
  "repo": "powershell-scripts",
  "branch": "master",
  "enabled": true
}
```

`id` sert de clé pour les favoris et l'historique : **ne le change jamais** sur une source existante, sinon les favoris qui la référencent deviennent orphelins. `owner`, `repo` et `branch` reconstruisent l'URL de clonage. Chaque source est indexée dans son propre dossier local.

### `services`

```json
{ "id": "exo", "label": "Exchange Online", "icon": "E715", "pattern": "Connect-ExchangeOnline" }
```

Un script appartient au service dès que son code correspond à `pattern` (expression régulière .NET). Un script peut appartenir à plusieurs services, ou à aucun - il tombe alors dans « Autre / local ». `icon` est un point de code hexadécimal de la police Segoe Fluent Icons.

### `rules`

```json
{
  "id": "retired-modules",
  "severity": "broken",
  "label": "Obsolète",
  "pattern": "Connect-MsolService|Connect-AzureAD\\b",
  "reason": "Modules retirés par Microsoft, non supportés par PowerShell 7."
}
```

`severity` vaut `ok`, `warn` ou `broken`. Toutes les règles sont évaluées et **la sévérité la plus élevée gagne**. `label` est le texte du badge, `reason` le message affiché dans le bandeau d'avertissement et dans la confirmation avant lancement. Les scripts `broken` sont masqués par défaut.

Attention aux échappements JSON : `\b` s'écrit `\\b`, `\s` s'écrit `\\s`, `\.` s'écrit `\\.`.

### `overrides`

```json
{
  "sourceId": "admindroid",
  "path": "Audit File Deletion/AuditFileDeletion.ps1",
  "name": "Audit des suppressions de fichiers",
  "notes": "Validé en production. Penser à filtrer sur -SharePointOnline.",
  "status": "ok",
  "label": "Validé",
  "hidden": false
}
```

`path` est relatif à la racine du dépôt, **avec des barres obliques** (`/`), pas des antislashs. Tous les champs sauf `sourceId` et `path` sont facultatifs :

- `name` remplace le nom affiché
- `notes` ajoute un encadré en tête de la documentation
- `status` / `label` / `reason` forcent le verdict de compatibilité, court-circuitant les règles
- `hidden: true` retire le script de l'application

C'est le bon endroit pour capitaliser : « celui-ci ne marche pas chez nous », « préférer tel autre », « validé le 12/03 ».

## Couche locale

Chaque machine peut avoir un `catalog.local.json` dans
`%LOCALAPPDATA%\PSAdminLauncher\catalog\`, de même structure. Il est fusionné **par-dessus** le catalogue partagé - les entrées locales gagnent, par `id` pour les sources, services et règles, par `sourceId` + `path` pour les surcharges.

Ce fichier n'est **jamais** touché par une mise à jour du catalogue. C'est là que vont les essais, les sources personnelles et les annotations qui n'ont pas vocation à être partagées.

## Ce qui reste local

| Fichier | Contenu | Synchronisé ? |
|---|---|---|
| `catalog\catalog.json` | copie du catalogue partagé | remplacé sur demande |
| `catalog\catalog.local.json` | ta couche personnelle | jamais touché |
| `profile\profile.json` | favoris, historique, thème, URL du catalogue | jamais touché - export/import manuel |
| `repos\<id>\` | clones des dépôts | cache, retéléchargeable |
| `backup\` | catalogues précédents | conservés à chaque mise à jour |

## Ce que le validateur vérifie en plus du schéma

`tools/validate_catalog.py` couvre les invariants qu'un JSON Schema ne peut pas exprimer :

- unicité des `id` au sein de `sources`, `services` et `rules`
- unicité du couple `sourceId` + `path` dans `overrides`
- existence de la source référencée par chaque annotation
- **compilation effective** de chaque expression régulière - un motif invalide ferait échouer l'analyse côté application
- absence de quantificateurs imbriqués du type `(a+)+`, qui peuvent faire exploser le temps d'analyse sur un fichier bien choisi
- caractères autorisés dans `owner`, `repo` et `branch` - l'application construit l'URL GitHub à partir de ces champs
- mise en forme canonique du fichier (indentation de 2, UTF-8 sans BOM, fins de ligne LF), pour que les différences restent lisibles
- incrémentation de `catalogVersion` quand le contenu change, et incrément MAJEUR quand une source disparaît
