# Mentions et provenance

## Ce que contient ce dépôt

Ce dépôt ne contient **aucun code tiers**. Il ne redistribue aucun script, aucun README, aucune image provenant des dépôts référencés.

`catalog.json` et les index publiés sur la branche `index` contiennent uniquement :

- des **références factuelles** : noms de comptes, de dépôts, de branches, chemins de fichiers, dates de commit, condensés d'objet git ;
- des **métadonnées extraites par analyse** : noms de paramètres, modules requis, cmdlets appelées. Ce sont des faits sur le code, pas le code ;
- du **contenu original** : intitulés de services, expressions régulières de détection, explications de compatibilité, annotations d'usage.

Ces éléments sont couverts par la [licence MIT](LICENSE) de ce dépôt.

## Licence des dépôts référencés

Les scripts référencés **ne sont pas couverts par la licence de ce dépôt**. Chacun reste soumis aux conditions de son dépôt d'origine, que ce catalogue ne modifie ni n'étend d'aucune manière.

État relevé le 5 septembre 2026 :

| Dépôt | Licence déclarée |
|---|---|
| [`12Knocksinna/Office365itpros`](https://github.com/12Knocksinna/Office365itpros) | MIT |
| [`microsoft/mggraph-intune-samples`](https://github.com/microsoft/mggraph-intune-samples) | MIT |
| [`MSEndpointMgr/Intune`](https://github.com/MSEndpointMgr/Intune) | MIT |
| [`Apoc70/Exchange4ITPros`](https://github.com/Apoc70/Exchange4ITPros) | MIT |
| [`soteria-security/365Inspect`](https://github.com/soteria-security/365Inspect) | MIT |
| [`silverhack/monkey365`](https://github.com/silverhack/monkey365) | Apache-2.0 |
| [`Mike-Crowley/Public-Scripts`](https://github.com/Mike-Crowley/Public-Scripts) | GPL-3.0 |
| [`admindroid-community/powershell-scripts`](https://github.com/admindroid-community/powershell-scripts) | **aucune** |
| [`m365corner/M365Corner-Scripts`](https://github.com/m365corner/M365Corner-Scripts) | **aucune** |
| [`Devolutions/ScriptLibrary`](https://github.com/Devolutions/ScriptLibrary) | **aucune** |

## Dépôts sans licence déclarée

Trois des dépôts référencés sont **publics mais ne déclarent aucune licence**. En l'absence de licence explicite, le droit d'auteur s'applique par défaut : tous droits réservés à leurs auteurs. Les seuls droits accordés sont ceux que les conditions d'utilisation de GitHub attachent à un dépôt public - le consulter et le dupliquer sur la plateforme.

Ce que cela implique concrètement :

- **Télécharger et exécuter** ces scripts pour administrer son propre tenant correspond à l'usage pour lequel leurs auteurs les publient et les documentent.
- **Les redistribuer, les republier ou les intégrer à un produit** n'est pas autorisé sans leur accord. Ce catalogue s'en abstient : il ne fait que pointer vers le dépôt d'origine, et le script n'est téléchargé qu'au moment où l'utilisateur le lance, depuis ce dépôt.
- **L'attribution est préservée.** Les en-têtes des scripts, leurs README et les liens vers les articles d'origine sont affichés tels quels par l'application, sans retrait des mentions de leurs auteurs.

Une licence permissive n'est pas non plus un blanc-seing : `Mike-Crowley/Public-Scripts` est sous **GPL-3.0**, dont les obligations s'appliquent à toute redistribution ou œuvre dérivée. Là encore, ce catalogue ne redistribue rien.

Si vous distribuez l'application au-delà d'un usage interne, sollicitez l'accord des auteurs des dépôts référencés.

## Absence d'affiliation

Ce projet est indépendant. Il n'est ni développé, ni approuvé, ni soutenu par aucun des éditeurs des dépôts référencés. Les noms de produits et de sociétés cités le sont à titre d'identification des sources, et appartiennent à leurs détenteurs respectifs.

## Signaler un problème de provenance

Si vous êtes l'auteur d'un dépôt référencé et souhaitez qu'il soit retiré du catalogue, ouvrez un ticket : la source sera supprimée dans la version suivante, et l'entrée retirée du fichier publié.
