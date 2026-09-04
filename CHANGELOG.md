# Journal des versions

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).
Le versionnage suit [SemVer](https://semver.org/lang/fr/), avec les règles propres
à ce catalogue décrites dans [docs/VERSIONING.md](docs/VERSIONING.md).

## [Non publié]

## [1.2.0] — 2026-09-04

### Ajouté

- **Quatorze sources candidates déclarées**, toutes **désactivées par défaut** : elles apparaissent dans la fenêtre de réglages de l'application et s'activent d'un interrupteur, sans rien changer tant qu'on n'y touche pas.
- Nouveaux champs de source : `layout` (`folders`, `flat`, `tree`), `include`, `exclude`, `trust`, `license` et `note`.
- `note` porte ce qu'il faut savoir avant d'activer — notamment que huit de ces dépôts sont des **modules** dont les `.ps1` sont des fonctions internes ou des tests Pester, et non des scripts lançables.

### Notes

Licences relevées à l'ajout : Office365ITPros et Maester en MIT, ScubaGear en CC0 (domaine public), Monkey365 en Apache-2.0, Mike-Crowley en GPL-3.0. M365Corner, Devolutions et DCToolbox n'en déclarent aucune.

Microsoft365DSC a pour branche par défaut `Dev`, et non `main`.

## [1.1.0] — 2026-09-04

### Ajouté

- Champ racine `okLabel` : libellé du badge des scripts sans problème détecté, désormais piloté par le catalogue au lieu d'être codé dans l'application.

### Modifié

- Le badge passe de « PS7 OK » à « **PS7** ». *OK* laissait entendre « prêt à exécuter », alors que la compatibilité, la disponibilité des modules et l'impact sont trois dimensions distinctes.

## [1.0.0] — 2026-09-03

Première version publiée du catalogue.

### Ajouté

- Source **AdminDroid Community** (`admindroid-community/powershell-scripts`, branche `master`) : 183 scripts d'administration Microsoft 365.
- Six catégories de services, déduites des cmdlets de connexion : Exchange Online, Microsoft Graph/Entra, SharePoint/OneDrive, Microsoft Teams, Sécurité & Conformité, Azure AD.
- Règle `retired-modules` (sévérité `broken`) : détecte les modules `MSOnline` et `AzureAD`, retirés par Microsoft, ainsi que `Get-WmiObject`, absent de PowerShell 7. **10 scripts** concernés sur la source AdminDroid ; ils sont masqués par défaut.
- Règle `spo-legacy-module` (sévérité `warn`) : détecte `Connect-SPOService`, qui impose `Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell` sous PowerShell 7. **5 scripts** concernés.
- Schéma JSON exécutable (`schema/catalog.schema.json`, draft 2020-12) pour la validation dans l'éditeur.
- Validateur sans dépendance (`tools/validate_catalog.py`) et intégration continue de validation à chaque proposition.

### Notes

Répartition obtenue sur la source AdminDroid : **168** scripts sans problème détecté, **5** à vérifier, **10** obsolètes.

[Non publié]: https://github.com/hbasiitelecom/ps-admin-catalog/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/hbasiitelecom/ps-admin-catalog/releases/tag/v1.2.0
[1.1.0]: https://github.com/hbasiitelecom/ps-admin-catalog/releases/tag/v1.1.0
[1.0.0]: https://github.com/hbasiitelecom/ps-admin-catalog/releases/tag/v1.0.0
