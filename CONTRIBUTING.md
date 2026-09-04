# Contribuer

Le catalogue est consommé directement par des postes en production. Une erreur ici se propage à toutes les installations qui pointent sur cette URL. D'où une règle simple : **rien n'atteint `main` sans passer par une proposition et la validation automatique.**

## Le cycle

```bash
git switch -c annotation/audit-file-deletion
# éditer catalog.json, incrémenter catalogVersion, compléter CHANGELOG.md
python3 tools/validate_catalog.py catalog.json --check-format
git commit -am "feat(overrides): annoter Audit File Deletion"
git push -u origin annotation/audit-file-deletion
gh pr create --fill
```

## Nommage des branches

`<type>/<sujet-court>` : `source/pnp-samples`, `regle/module-az`, `annotation/mfa-status`, `docs/versionnage`.

## Messages de commit

Format [Conventional Commits](https://www.conventionalcommits.org/fr/) - `type(portée): description à l'infinitif`.

| Type | Emploi |
|---|---|
| `feat` | source, règle, service ou lot d'annotations ajouté |
| `fix` | expression régulière corrigée, verdict erroné rectifié |
| `docs` | documentation seule |
| `ci` | workflow, validateur, outillage |
| `chore` | ménage sans effet sur le contenu publié |

Portées usuelles : `sources`, `rules`, `services`, `overrides`, `schema`.

L'intérêt n'est pas cosmétique : `git log --oneline --grep '^fix'` répond en une commande à « qu'est-ce qui a été corrigé depuis trois mois ». C'est aussi ce qui rend le CHANGELOG rapide à écrire.

## Les trois choses à ne pas oublier

**Incrémenter `catalogVersion`.** Sans ça, aucune installation ne verra la mise à jour - le fichier changera en ligne et personne ne le saura. La CI refuse un contenu modifié à version constante. Le niveau à choisir est décrit dans [docs/VERSIONING.md](docs/VERSIONING.md).

**Compléter `CHANGELOG.md`** sous « Non publié ». Un journal rédigé au moment du changement est juste ; reconstitué six mois plus tard, il est faux.

**Tester les expressions régulières sur des scripts réels.** Une règle trop large classe des dizaines de scripts corrects en « obsolète » et les fait disparaître de l'interface, puisqu'ils sont masqués par défaut. Vérifiez le nombre de scripts touchés avant de proposer :

```bash
grep -rlE "votre|motif" /chemin/vers/le/depot --include='*.ps1' | wc -l
```

## Écrire une règle de compatibilité

Une règle porte trois messages, dans cet ordre d'importance :

1. `severity` - ce que l'application en fait. `broken` masque le script par défaut et demande confirmation avant lancement ; `warn` affiche un bandeau ; `ok` ne change rien.
2. `reason` - ce que l'utilisateur lit. Il doit comprendre **pourquoi** et **quoi faire à la place**. « Module retiré » ne suffit pas ; « les modules MSOnline et AzureAD ont été retirés par Microsoft, l'équivalent moderne passe par Microsoft Graph PowerShell » lui donne la sortie.
3. `pattern` - comment on détecte. Ancré sur ce qui casse réellement, pas sur un nom de fichier ou un commentaire.

Attention aux échappements JSON : `\b` s'écrit `\\b`, `\s` s'écrit `\\s`, `\.` s'écrit `\\.`.

## Annoter un script

Les `overrides` sont l'endroit où se capitalise l'expérience : « validé en production », « ne marche pas sur les tenants GCC », « préférer tel autre ». C'est ce que le dépôt source ne dira jamais.

Une bonne note est datée dans son texte et dit dans quelles conditions elle a été observée. « Ne marche pas » sans contexte vieillit mal et devient impossible à réfuter.

## Ne jamais recopier de code tiers

Une annotation décrit un script, elle ne le reproduit pas. Ne collez jamais d'extrait de code, de README ou de texte provenant d'un dépôt référencé dans les champs `notes`, `reason` ou `name` : ce dépôt ne redistribue rien, et c'est ce qui rend sa licence MIT tenable. Voir [NOTICE.md](NOTICE.md).

## Publier une version

Après fusion sur `main` :

```bash
git switch main && git pull
git tag -a v1.2.0 -m "Catalogue 1.2.0"
git push origin v1.2.0
```

L'étiquette rend la version restaurable. Sans elle, revenir six mois en arrière suppose de fouiller les commits un par un.
