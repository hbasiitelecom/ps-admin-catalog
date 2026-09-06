<!--
  Merci de proposer un changement au catalogue.

  Ce modele n'est pas une formalite : les trois cases correspondent aux trois
  facons dont une modification de catalogue casse quelque chose en aval. Une
  application deja installee lit ce fichier ; ce qui part d'ici arrive chez
  quelqu'un.
-->

## Ce qui change

<!-- Une ou deux phrases. Quelle source, quelle regle, quelle annotation. -->

## Pourquoi

<!--
  Pour une annotation, dites ce que l'usage a appris - c'est la seule chose
  qu'aucune analyse automatique ne trouvera. Pour une source, dites ce qu'elle
  apporte que les autres n'ont pas.
-->

## Avant de demander la fusion

- [ ] **Le validateur passe.**
      `python3 tools/validate_catalog.py catalog.json --check-format`
      Il verifie ce qu'un schema seul ne voit pas : unicite des identifiants,
      existence de la source referencee par chaque annotation, compilation
      effective de chaque expression reguliere, absence de motifs a explosion
      combinatoire.

- [ ] **`catalogVersion` est incremente**, selon [docs/VERSIONING.md](../docs/VERSIONING.md).
      Rappel de la regle propre a ce catalogue : **retirer ou renommer l'`id`
      d'une source impose une version MAJEURE**, parce que les favoris et
      l'historique des utilisateurs designent les scripts par
      `<id de source>:<chemin>` et deviendraient orphelins.

- [ ] **Le [CHANGELOG](../CHANGELOG.md) dit ce qui change**, en une ligne lisible
      par quelqu'un qui n'a pas suivi.

## Si cette PR ajoute ou retire une source

- [ ] La **licence** du depot est relevee et reportee dans
      [NOTICE.md](../NOTICE.md). Un depot sans licence declaree n'est pas
      redistribuable : le catalogue se contente d'y pointer, et la mention doit
      etre exacte.
- [ ] La source contient de **vrais scripts lancables**, et non des fonctions
      internes de module ou des tests. C'est ce qui avait ramene le corpus de
      3 292 a 833 fiches.
