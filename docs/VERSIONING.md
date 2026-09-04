# Versionnage

Deux champs versionnent des choses différentes. Les confondre est la principale source d'erreur.

## `schemaVersion` - le contrat avec l'application

Un entier. Il décrit la **structure** du fichier, pas son contenu.

L'application refuse un catalogue dont le `schemaVersion` dépasse celui qu'elle connaît, et le dit clairement plutôt que de planter sur un champ inattendu. C'est ce qui permet de faire évoluer le format sans casser les postes qui n'ont pas encore été mis à jour.

Il ne bouge que lorsqu'un changement rendrait le fichier illisible pour une application existante : un champ obligatoire ajouté, un champ renommé, une sémantique modifiée. Ajouter un champ **facultatif** ne le fait pas bouger.

Valeur actuelle : **1**.

## `catalogVersion` - la version du contenu

Format [SemVer](https://semver.org/lang/fr/) : `MAJEUR.MINEUR.CORRECTIF`.

L'application compare simplement cette chaîne à celle de sa copie locale : toute différence déclenche la pastille « mise à jour disponible ». Le découpage sémantique ne sert donc pas à la machine - il sert aux humains, pour savoir en un coup d'œil si une mise à jour est anodine ou si elle demande de l'attention.

### MAJEUR - quelque chose casse chez l'utilisateur

- **Une source est retirée, ou son `id` change.** C'est le cas le plus important. Les favoris et l'historique désignent les scripts par `<id de source>:<chemin>` ; changer l'identifiant rend ces références orphelines, sans que l'utilisateur comprenne pourquoi ses favoris ont disparu. *Le validateur refuse ce changement s'il n'est pas accompagné d'un incrément MAJEUR.*
- Un `id` de service ou de règle disparaît alors qu'une couche locale s'y référait.
- Le sens d'un champ change à contenu identique.

### MINEUR - quelque chose s'ajoute

- Une source ajoutée.
- Une règle de compatibilité ajoutée, ou une règle existante élargie à de nouveaux cas.
- Un service ajouté.
- Un lot d'annotations sur des scripts jusque-là non documentés.

### CORRECTIF - quelque chose se corrige, sans rien déplacer

- Reformulation d'un `reason` ou d'un `label`.
- Correction d'une expression régulière qui produisait un faux positif ou un faux négatif.
- Note ajoutée ou précisée sur un script déjà annoté.
- Correction d'une faute, d'un intitulé, d'une icône.

## En pratique

1. Modifier `catalog.json`.
2. Incrémenter `catalogVersion` selon la règle ci-dessus.
3. Compléter `CHANGELOG.md` sous « Non publié ».
4. Ouvrir une *pull request*. La CI compare avec `main` et refuse un contenu modifié sans incrément.
5. Après fusion, poser l'étiquette et publier :

```bash
git tag -a v1.2.0 -m "Catalogue 1.2.0"
git push origin v1.2.0
gh release create v1.2.0 --title "Catalogue 1.2.0" --notes-file <(sed -n '/## \[1.2.0\]/,/## \[/p' CHANGELOG.md | head -n -1)
```

L'étiquette Git est ce qui rend une version restaurable. Sans elle, revenir à l'état d'il y a trois mois suppose de fouiller l'historique des commits.

## Pourquoi SemVer et pas CalVer

Le versionnage calendaire (`2026.09.03`) conviendrait à un contenu qui n'est qu'un instantané daté, où toutes les mises à jour se valent. Ce n'est pas le cas ici : **certains changements cassent quelque chose chez l'utilisateur et d'autres non**, et cette distinction mérite d'être lisible dans le numéro lui-même.

Un administrateur qui voit passer `1.4.2 → 1.4.3` sait qu'il peut appliquer sans réfléchir. `1.4.3 → 2.0.0` lui dit d'aller lire le journal avant. Une date ne dit rien de tout ça.

Le revers assumé : il faut décider du niveau à chaque changement. Le validateur automatise le cas le plus coûteux - la source retirée ou renommée - et laisse le reste au jugement.
