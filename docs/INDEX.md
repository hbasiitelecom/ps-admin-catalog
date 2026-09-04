# Les index précalculés

L'application n'analyse plus les dépôts sur le poste. Elle lit des **index déjà construits**, publiés sur la branche [`index`](https://github.com/hbasiitelecom/ps-admin-catalog/tree/index), et ne télécharge un script que lorsqu'on le lance.

Le modèle est celui des fichiers à la demande de OneDrive : le catalogue donne la liste et la fiche complète de chaque script, le fichier lui-même reste en ligne jusqu'au moment où on en a besoin.

## Pourquoi

Activer les quinze sources revenait à cloner **environ 500 Mo** - Microsoft365DSC pèse 252 Mo à lui seul, Maester 119 Mo - puis à analyser près de cinq mille fichiers par arbre syntaxique. Quatre-vingt-dix secondes, sur le fil d'exécution de l'interface : la fenêtre se figeait.

Les mêmes quinze sources tiennent en **environ 5 Mo d'index**. Un script demandé se télécharge en un appel, autour de 400 ms pour 34 Ko.

## Ce que contient un index

Un fichier par source, à la racine de la branche `index` : `<sourceId>.json`.

| Champ | Rôle |
|---|---|
| `indexVersion` | version du format. Un index d'une version que l'application ne connaît pas est ignoré, elle retombe sur l'analyse locale. |
| `sourceId`, `sourceName`, `owner`, `repo`, `branch` | identité de la source, reprise du catalogue |
| `commit` | le commit **exact** analysé |
| `catalogVersion` | la version du catalogue au moment de la construction |
| `builtUtc` | horodatage de construction |
| `rawBase` | base de téléchargement, **épinglée sur le commit** |
| `scriptCount` | nombre de scripts |
| `scripts[]` | une fiche par script |

`rawBase` est épinglée sur le commit, jamais sur la branche : le fichier téléchargé est celui qui a été analysé, et pas une version poussée entre-temps. L'URL d'un script est `rawBase + RelPath`, celle de son README `rawBase + Folder + "/README.md"` quand `HasReadme` vaut vrai.

Chaque fiche porte ce que l'application affichait déjà - nom, description, service, statut de compatibilité, impact réel, commandes appelées, modules, permissions Graph, bloc `param()` avec `ValidateSet` et paramètres sensibles - plus deux champs propres au mode à la demande :

- `Bytes` : la taille, affichée avant téléchargement
- `Sha` : le **condensé d'objet git** du fichier, `sha1("blob <taille>\0" + contenu)`

`Sha` est ce qui rend le téléchargement vérifiable. L'application recalcule le condensé du fichier reçu et le compare : s'il diffère, le fichier n'est pas celui qui a été analysé, et il n'est pas exécuté.

## `manifest.json`

Le sommaire : pour chaque source, son commit, son nombre de scripts, sa taille et sa date de construction. L'application le lit en premier - quelques kilo-octets - pour savoir ce qui a bougé, et ne retélécharge que les index dont le commit a changé.

## Comment les index sont construits

`tools/Build-SourceIndex.ps1`, sur `main`, clone chaque source en profondeur 1, applique les règles d'éligibilité de la source (`layout`, `include`, `exclude`), analyse chaque script par arbre syntaxique, relève les condensés par `git ls-tree -r`, écrit le JSON, puis supprime le clone.

L'action `.github/workflows/build-index.yml` l'exécute :

- à chaque modification de `catalog.json` ou du générateur ;
- toutes les semaines, le lundi à 4 h UTC, pour suivre les commits des sources ;
- à la demande, avec le choix des sources à reconstruire et l'option d'inclure les sources désactivées.

Elle valide le catalogue avant de générer, et ne publie que si quelque chose a changé.

## Pourquoi une branche à part

`main` est protégée : rien n'y entre sans que le catalogue ait été validé, et le jeton de l'action n'est pas administrateur. Deux voies ont été essayées avant celle-ci.

Un `git push` direct sur `main` est refusé par la protection - c'est le but de la protection, et la lever pour l'action reviendrait à la vider de son sens.

Une demande de fusion avec fusion automatique ne marche pas non plus : **GitHub ne déclenche pas les vérifications requises sur une demande ouverte par l'action elle-même**, par prévention des boucles. La vérification reste en attente, la fusion automatique ne se conclut jamais, et la demande s'accumule chaque semaine.

Les index sont un produit dérivé, pas le catalogue. Ils vivent donc sur la branche `index`, que l'action détient seule et réécrit à chaque construction. `main` reste protégée sans exception, l'action n'y touche jamais, et l'historique de la branche `index` ne s'accumule pas.

## Ce qui reste possible sans réseau

Les index téléchargés et les scripts déjà lancés sont conservés dans le cache local. Un script déjà téléchargé se relance hors ligne ; un script jamais ouvert ne peut pas l'être - c'est le compromis assumé du modèle.

## Si `indexBaseUrl` est absente

Le champ racine `indexBaseUrl` est **facultatif**. Sans lui, l'application revient à son comportement antérieur : clonage puis analyse locale. Les deux modes coexistent, aucun n'est retiré.
