# Sécurité

## Ce que ce dépôt ne contient jamais

Aucun secret, jeton, mot de passe, chaîne de connexion, adresse interne, nom de tenant ni nom de client. Le catalogue est un fichier **public** : tout ce qui y entre est définitivement public, y compris après suppression, puisque l'historique Git le conserve.

Le protection contre l'envoi de secrets (*push protection*) de GitHub est active sur les dépôts publics et bloque un envoi contenant un motif de secret connu. C'est un filet, pas une garantie : la revue relève de l'auteur de la proposition.

## Le catalogue est une frontière de confiance

C'est le point le plus important de ce document.

Le catalogue décide **quels dépôts sont clonés sur le poste de l'utilisateur** et **quelles expressions régulières sont exécutées** sur le contenu de ces dépôts. Quiconque contrôle le catalogue que vous consommez influence donc ce qui est téléchargé chez vous.

Trois garde-fous :

**L'hôte est figé dans l'application.** Les URL sont reconstruites sous la forme `https://github.com/<owner>/<repo>`. Un catalogue ne peut pas rediriger le téléchargement vers un autre domaine. Le validateur restreint en plus `owner`, `repo` et `branch` à un jeu de caractères sûr.

**Les expressions régulières sont vérifiées.** Chaque motif est compilé par la CI, et les quantificateurs imbriqués du type `(a+)+` sont refusés : sur un fichier bien choisi, ils peuvent faire consommer un temps déraisonnable à l'analyse.

**L'application n'exécute jamais un script toute seule.** Elle ouvre une console PowerShell et attend une action explicite. Un catalogue ne peut ni lancer ni planifier quoi que ce soit.

Ce qu'un catalogue hostile pourrait néanmoins faire : faire apparaître un dépôt d'apparence légitime dans l'interface, ou faire passer un script dangereux pour validé via une annotation. **Ne consommez que l'URL d'un catalogue que vous contrôlez ou dont vous connaissez le mainteneur.**

## Chaîne d'intégration continue

- Le workflow est déclaré en `permissions: contents: read`. Il ne peut rien écrire.
- `persist-credentials: false` : le jeton d'intégration n'est pas laissé dans la configuration Git du *runner*.
- Les actions tierces sont **épinglées sur un SHA de commit complet**, jamais sur une étiquette : une étiquette peut être redirigée vers un autre commit après coup. Dependabot les fait remonter quand une version paraît.
- Le validateur n'installe aucun paquet. Il n'utilise que la bibliothèque standard de Python, ce qui supprime toute surface d'attaque par la chaîne d'approvisionnement.

## Réglages recommandés du dépôt

À activer une fois, dans *Settings* :

- **Branche `main` protégée** : proposition obligatoire, validation `Valider le catalogue` requise, envoi en force interdit.
- **Secret scanning** et **push protection** : gratuits et actifs par défaut sur les dépôts publics.
- **Dependabot alerts** : activées.
- Restreindre le jeton par défaut des workflows à la lecture seule (*Actions → General → Workflow permissions*).

## Signaler un problème

Pour une vulnérabilité, n'ouvrez pas de ticket public : utilisez l'onglet **Security → Report a vulnerability** du dépôt, ou contactez directement le mainteneur.

Pour une erreur de contenu — un script marqué à tort comme valide, une source douteuse —, un ticket public convient et vaut mieux qu'un silence.
