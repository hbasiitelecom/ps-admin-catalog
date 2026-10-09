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

Chaque fiche porte ce que l'application affichait déjà - nom, description, service, statut de compatibilité, impact réel, commandes appelées, modules, permissions Graph, bloc `param()` avec `ValidateSet` et paramètres sensibles - plus les **types .NET qualifiés** employés (`Types`, relevés par l'arbre syntaxique : un script EWS n'appelle aucune cmdlet, tout passe par `[Microsoft.Exchange.WebServices.Data.ExchangeService]`), et deux champs propres au mode à la demande :

- `Bytes` : la taille, affichée avant téléchargement
- `Sha` : le **condensé d'objet git** du fichier, `sha1("blob <taille>\0" + contenu)`

`Sha` est ce qui rend le téléchargement vérifiable. L'application recalcule le condensé du fichier reçu et le compare : s'il diffère, le fichier n'est pas celui qui a été analysé, et il n'est pas exécuté.

- `Companions[]` : les **fichiers de données que le script lit à côté de lui**, chacun avec `Name`, `RelPath`, `Bytes` et `Sha`

`Companions` existe depuis le catalogue 3.1.0 et répond à un défaut réel : le téléchargement à la demande ne ramenait que le `.ps1`. Le rapport de licences d'AdminDroid lit `.\LicenseFriendlyName.txt`, 12 Ko, qui n'arrivait jamais - le script se connectait au locataire puis échouait sur `Cannot find path`. Le clone de dépôt d'avant la 1.4.0 ramenait tout le dossier ; le téléchargement d'un fichier ne ramène qu'un fichier.

Le constructeur relève les noms dans le code, commentaires neutralisés, sous trois formes : `.\nom.ext`, `$PSScriptRoot\nom.ext` et `Join-Path $PSScriptRoot 'nom.ext'`. **Un nom relevé n'est déclaré que s'il correspond à un blob réel de l'arbre au commit indexé** : un nom inventé, un chemin avec séparateur, un retour en arrière et un fichier que le script *écrit* au lieu de le lire disparaissent d'eux-mêmes. Les fichiers déclarés se téléchargent et se vérifient exactement comme le script : `rawBase + RelPath`, condensé confronté.

Le champ est **additif** : `indexVersion` reste à 2, et une application qui ne le connaît pas l'ignore sans rien casser.

## `manifest.json`

Le sommaire : pour chaque source, son commit, son nombre de scripts, sa taille et sa date de construction. L'application le lit en premier - quelques kilo-octets - pour savoir ce qui a bougé, et ne retélécharge que les index dont le commit a changé.

## Comment les index sont construits

`tools/Build-SourceIndex.ps1`, sur `main`, clone chaque source en profondeur 1, applique les règles d'éligibilité de la source (`layout`, `include`, `exclude`), analyse chaque script par arbre syntaxique, relève les condensés par `git ls-tree -r`, écrit le JSON, puis supprime le clone.

L'action `.github/workflows/build-index.yml` l'exécute :

- à chaque modification de `catalog.json` ou du générateur ;
- toutes les semaines, le lundi à 4 h UTC, pour suivre les commits des sources ;
- à la demande, avec le choix des sources à reconstruire et l'option d'inclure les sources désactivées.

Elle valide le catalogue avant de générer, compare la construction à la précédente, et ne publie que si quelque chose a changé.

## Pourquoi une branche à part

`main` est protégée : rien n'y entre sans que le catalogue ait été validé, et le jeton de l'action n'est pas administrateur. Deux voies ont été essayées avant celle-ci.

Un `git push` direct sur `main` est refusé par la protection - c'est le but de la protection, et la lever pour l'action reviendrait à la vider de son sens.

Une demande de fusion avec fusion automatique ne marche pas non plus : **GitHub ne déclenche pas les vérifications requises sur une demande ouverte par l'action elle-même**, par prévention des boucles. La vérification reste en attente, la fusion automatique ne se conclut jamais, et la demande s'accumule chaque semaine.

Les index sont un produit dérivé, pas le catalogue. Ils vivent donc sur la branche `index`, que l'action détient seule. `main` reste protégée sans exception, et l'action n'y touche jamais.

## Comparer deux constructions

La branche `index` était **réécrite** à chaque construction, en orphelin poussé en force, pour que son historique ne s'accumule pas. Le prix a été payé le 27 septembre 2026 : après un correctif sur les commentaires, le nombre de fiches marquées obsolètes est passé de 53 à 50 là où l'arithmétique en attendait 49. « Lesquelles ont changé » était sans réponse, l'état précédent n'existant plus.

Depuis, chaque construction s'empile sur la précédente et la poussée n'est plus en force. Le coût est mesuré : dix fichiers JSON, environ 1,2 Mo par construction, une construction par semaine, des écarts minces que git stocke en delta. Quelques mégaoctets par an pour un historique du corpus semaine après semaine.

L'action compare avant de publier, et le résultat arrive en annotation sur l'exécution : combien de fiches en plus, en moins, et le décompte des changements de statut par transition (`3 broken -> ok`).

La même comparaison se fait à la main, entre deux révisions quelconques de la branche :

```bash
git fetch origin index
mkdir -p /tmp/idx-avant /tmp/idx-apres
git archive refs/remotes/origin/index~1 | tar -x -C /tmp/idx-avant
git archive refs/remotes/origin/index   | tar -x -C /tmp/idx-apres
python3 tools/comparer_index.py /tmp/idx-avant /tmp/idx-apres
```

Remplacer `~1` par `~4` compare à un mois, et `refs/remotes/origin/index~N` par n'importe quel identifiant de révision.

L'historique commence à la première construction publiée après ce changement : `~1` n'a de sens qu'à partir de la deuxième.

`tools/comparer_index.py` compare `Status`, `Impact` et `Badge`, fiche par fiche, identifiants confondus toutes sources : une fiche dont le fichier d'index change de nom apparaît comme **changée**, pas comme retirée puis ajoutée.

## Ce qui reste possible sans réseau

Les index téléchargés et les scripts déjà lancés sont conservés dans le cache local. Un script déjà téléchargé se relance hors ligne ; un script jamais ouvert ne peut pas l'être - c'est le compromis assumé du modèle.

## Si `indexBaseUrl` est absente

Le champ racine `indexBaseUrl` est **facultatif**. Sans lui, l'application revient à son comportement antérieur : clonage puis analyse locale. Les deux modes coexistent, aucun n'est retiré.
