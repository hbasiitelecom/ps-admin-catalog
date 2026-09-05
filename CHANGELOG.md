# Journal des versions

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).
Le versionnage suit [SemVer](https://semver.org/lang/fr/), avec les règles propres
à ce catalogue décrites dans [docs/VERSIONING.md](docs/VERSIONING.md).

## [Non publié]

## [2.1.1] - 2026-09-05

### Corrigé

- **Les mots-clés des tâches contenaient des verbes génériques** - `supprimer`, `attribuer`, `retirer`, `réinitialiser` - et des noms qui n'appartiennent à aucun domaine en particulier : `utilisateur`, `compte`. *« licence utilisateur »* désignait alors la tâche « Supprimer des comptes », et *« supprimer »* seul aurait désigné n'importe quelle tâche destructive. Les mots-clés sont maintenant des **termes du domaine** : ce qui distingue une tâche des autres, pas ce qui la décrit.
- La règle de reconnaissance s'assouplit en conséquence : une seule correspondance **exacte** suffit désormais, car *« message d'absence »* n'a qu'un mot distinctif. Une correspondance exacte pèse double, de sorte qu'entre deux tâches partageant un mot, celle dont le terme propre est touché l'emporte.

## [2.1.0] - 2026-09-05

### Ajouté

- **Tableau `tasks`** : une tâche est une intention d'administrateur, ses mots-clés en français, et la **signature de cmdlets** qui rapproche les candidats. C'est le pivot : `Remove-PnPFileVersion` ne veut dire qu'une chose, quelle que soit la façon dont l'auteur a nommé son fichier. Le nom, lui, ment - *File Version History Report* et *Automate Version History Cleanup* se ressemblent et ne font pas la même chose. Champ facultatif, `schemaVersion` inchangé.
- **Neuf tâches**, toutes tirées du corpus et non inventées : elles ont été trouvées en groupant les scripts par cmdlet d'action partagée entre au moins deux sources. Supprimer des comptes, réagir à un compte compromis, déployer une signature Outlook, réinitialiser la MFA, convertir une liste de distribution, synchroniser l'appartenance d'un groupe, gérer les licences, nettoyer les versions SharePoint, configurer un message d'absence.
- **Le générateur date chaque fichier.** Le clone passe de `--depth 1` à `--filter=blob:none` : l'historique complet des commits est nécessaire pour dater les fichiers, les blobs anciens ne le sont pas et restent sur le serveur. Un seul parcours de l'historique date tout le dépôt, là où un `git log` par fichier coûterait des dizaines de millisecondes chacun. C'est le critère de fraîcheur, et c'est bien la date du **fichier** - un projet actif peut abriter un script inchangé depuis quatre ans qui appelle une API dépréciée.
- Chaque fiche porte aussi `HasHeader`, pour le critère de lisibilité.
- Le validateur refuse une tâche sans signature, une cmdlet mal formée, un impact hors des trois valeurs, un identifiant en double, un `best` désignant une source inconnue, une alternative sans référence, un champ inconnu. Neuf cas éprouvés.

### Modifié

- **`indexVersion` passe à 2.** Les index portent deux champs de plus. Une application qui n'attend que la version 1 doit être mise à jour ; l'application 1.11.0 accepte les deux, un index plus ancien perdant simplement les critères qui en dépendent.

### Notes

Aucune tâche ne porte de `best`. Le champ existe et passe devant le classement automatique, mais il désigne un jugement humain - *« validé en production chez un client de 400 boîtes »* - et ce jugement n'est pas le mien à écrire. Tant qu'il est vide, l'application affiche le meilleur candidat calculé, avec la phrase qui dit pourquoi, et sans jamais faire passer ce calcul pour une validation.

## [2.0.0] - 2026-09-05

Version MAJEURE : cinq sources sont retirées. Les favoris et l'historique qui s'y référaient deviennent orphelins - ils sont ignorés, pas supprimés.

### Retiré

Ces dépôts sont des **modules**, pas des collections de scripts. Leurs `.ps1` sont des fonctions internes, appelées par le module, qui ne se lancent pas seules. Les déclarer comme sources apportait 2 292 fiches dont aucune n'était lançable, et noyait les 829 qui le sont.

| Source | Fiches | Ce qu'elles étaient |
|---|---:|---|
| Microsoft365DSC | 1 197 | 1 183 exemples de configuration DSC, plus le générateur et les utilitaires du dépôt |
| Maester | 721 | `powershell/public` et `internal` : les fonctions du module, qui s'utilise par `Invoke-Maester` |
| Monkey365 | 388 sur 391 | `core/` et `collectors/` : le cœur du module et ses collecteurs |
| 365Inspect | 108 sur 112 | `Inspectors/` : une fonction par contrôle, appelée par le script principal |
| ScubaGear | 27 | outillage de compilation, tests Pester et fichiers de dépendances ; ScubaGear s'utilise par `Invoke-SCuBA` |
| EntraExporter | 15 | `src/` : les fonctions du module |
| DCToolbox | 0 | aucun fichier éligible depuis le premier index |

### Modifié

- **Monkey365** et **365Inspect** restent, réduits à leurs points d'entrée réels : `Invoke-Monkey365.ps1` et `monkey365.ps1` pour l'un, `365Inspect.ps1` et `Create-365InspectApp.ps1` pour l'autre. Ce sont de vrais scripts, qui se lancent et prennent des paramètres.
- La description du catalogue le dit maintenant explicitement : **seuls des scripts lançables sont référencés**.

### Notes

Le corpus passe de 3 292 fiches à environ 830. Ce n'est pas une perte : c'est le nombre réel de scripts qu'un administrateur peut lancer. Les 2 462 autres polluaient la recherche, les comptes du rail et la palette de commandes.

La note de la 1.2.0 signalait déjà que huit de ces dépôts étaient des modules. C'était une hypothèse au moment de les déclarer ; les index l'ont vérifiée.

## [1.4.0] - 2026-09-04

### Ajouté

- **Les constats portent leur numéro de ligne.** *« Supprime des objets du tenant : Remove-MgUser (l. 122) »* au lieu de *« supprime des objets du tenant »*. Un constat sans endroit où le vérifier oblige à relire tout le script ; avec la ligne, il se contrôle en dix secondes. La ligne est celle du premier appel, relevée dans l'arbre syntaxique.
- Le téléchargement depuis une URL externe nomme désormais la cmdlet et sa ligne, comme les autres constats.

### Retiré

- Le constat **« installe un module depuis PSGallery »**. Il est vrai de **178 des 183 scripts d'AdminDroid** : c'est le contrôle de prérequis que la source place en tête de chaque script. Un constat vrai partout n'apprend rien, et il noyait les deux qui comptent. Même piège que `-Force`, présent sur 174 scripts sans jamais y être une confirmation utilisateur.

### Notes

Sur AdminDroid, 114 scripts sur 183 portent au moins un constat : 104 acceptent un identifiant en clair, 12 suppriment des objets du tenant, 1 télécharge depuis une URL externe.

## [1.3.2] - 2026-09-04

### Modifié

- **L'application qui consomme ce catalogue s'appelle désormais PS Admin Launcher**, et non plus AdminDroid Script Launcher : elle sert quinze sources, pas une. Le nom du produit disparaît de la `description` du catalogue, du titre du schéma, de l'en-tête du validateur et d'un commentaire du générateur d'index.
- La source `admindroid` ne bouge pas : son identifiant, son nom, son propriétaire et l'attribution de `NOTICE.md` restent tels quels. C'est une source référencée, pas une marque de produit - et la clause de non-affiliation est plus nécessaire qu'avant, pas moins.
- Les modèles de tickets renvoyaient vers le seul dépôt AdminDroid pour les questions portant sur un script ; ils renvoient maintenant vers le catalogue, qui liste les quinze dépôts d'origine.
- Les tirets cadratins cèdent la place à des tirets simples dans tous les fichiers du dépôt.

## [1.3.1] - 2026-09-04

### Modifié

- **Les index sont publiés sur la branche [`index`](https://github.com/hbasiitelecom/ps-admin-catalog/tree/index)**, plus sur `main`. `main` est protégée et le jeton de l'action n'est pas administrateur : un push direct y est refusé, et une demande de fusion ne se conclut jamais puisque **GitHub ne déclenche pas les vérifications requises sur une demande ouverte par l'action elle-même**. Les index sont un produit dérivé, pas le catalogue : ils sortent de la branche du produit. `main` reste protégée sans aucune dérogation.
- `indexBaseUrl` pointe désormais sur cette branche.

### Corrigé

- Le splat d'un tableau lie les arguments **par position** : `-Catalog` était pris pour une valeur et `index` atterrissait sur `-TimeoutSeconds`. Table de hachage désormais.
- Chaque commande de publication qui échoue émet une **annotation d'erreur** : les journaux d'exécution ne sont pas toujours consultables, les annotations le sont.

## [1.3.0] - 2026-09-04

Le catalogue ne décrit plus seulement où trouver les scripts : il publie l'analyse elle-même.

### Ajouté

- **Index précalculés** sous `index/`, un fichier par source plus un `index/manifest.json`. L'application n'analyse plus les dépôts sur le poste : elle lit l'index et ne télécharge un script qu'au moment de le lancer. Quinze sources actives représentaient environ 500 Mo de clones et quatre-vingt-dix secondes d'analyse ; les index pèsent environ 5 Mo. Format décrit dans [docs/INDEX.md](docs/INDEX.md).
- Champ racine **`indexBaseUrl`**, facultatif : la base où l'application lit les index. Absent, elle revient au clonage et à l'analyse locale - les deux modes coexistent, aucun n'est retiré.
- Chaque fiche de script porte sa **taille** et son **condensé d'objet git**. L'application recalcule le condensé du fichier téléchargé et refuse de l'exécuter s'il diffère de celui qui a été analysé.
- `rawBase` est **épinglée sur le commit analysé**, jamais sur la branche : le fichier téléchargé est celui qui a été décrit, pas une version poussée entre-temps.
- **`tools/Build-SourceIndex.ps1`** et l'action **`.github/workflows/build-index.yml`** : construction à chaque modification du catalogue ou du générateur, chaque lundi à 4 h UTC, et à la demande, source par source.

### Notes

Les quinze sources représentent 3 292 scripts pour environ 3 Mo d'index.

## [1.2.0] - 2026-09-04

### Ajouté

- **Quatorze sources candidates déclarées**, toutes **désactivées par défaut** : elles apparaissent dans la fenêtre de réglages de l'application et s'activent d'un interrupteur, sans rien changer tant qu'on n'y touche pas.
- Nouveaux champs de source : `layout` (`folders`, `flat`, `tree`), `include`, `exclude`, `trust`, `license` et `note`.
- `note` porte ce qu'il faut savoir avant d'activer - notamment que huit de ces dépôts sont des **modules** dont les `.ps1` sont des fonctions internes ou des tests Pester, et non des scripts lançables.

### Notes

Licences relevées à l'ajout : Office365ITPros et Maester en MIT, ScubaGear en CC0 (domaine public), Monkey365 en Apache-2.0, Mike-Crowley en GPL-3.0. M365Corner, Devolutions et DCToolbox n'en déclarent aucune.

Microsoft365DSC a pour branche par défaut `Dev`, et non `main`.

## [1.1.0] - 2026-09-04

### Ajouté

- Champ racine `okLabel` : libellé du badge des scripts sans problème détecté, désormais piloté par le catalogue au lieu d'être codé dans l'application.

### Modifié

- Le badge passe de « PS7 OK » à « **PS7** ». *OK* laissait entendre « prêt à exécuter », alors que la compatibilité, la disponibilité des modules et l'impact sont trois dimensions distinctes.

## [1.0.0] - 2026-09-03

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
