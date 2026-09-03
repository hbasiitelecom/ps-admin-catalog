# Journal des versions

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).
Le versionnage suit [SemVer](https://semver.org/lang/fr/), avec les règles propres
à ce catalogue décrites dans [docs/VERSIONING.md](docs/VERSIONING.md).

## [Non publié]

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

[Non publié]: https://github.com/hbasiitelecom/ps-admin-catalog/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/hbasiitelecom/ps-admin-catalog/releases/tag/v1.0.0
