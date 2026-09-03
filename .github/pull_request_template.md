## Ce que change cette proposition

<!-- En une ou deux phrases. -->

## Type de changement

- [ ] Nouvelle source (dépôt GitHub indexé)
- [ ] Nouvelle règle de compatibilité ou modification d'une règle
- [ ] Annotation d'un script (`overrides`)
- [ ] Nouveau service / catégorie
- [ ] Documentation ou outillage uniquement

## Version

- [ ] `catalogVersion` a été incrémenté selon [docs/VERSIONING.md](../docs/VERSIONING.md)
- [ ] `CHANGELOG.md` a été complété sous « Non publié »

**Rappel :** retirer ou renommer l'`id` d'une source impose une version **MAJEURE** — les favoris et l'historique qui s'y réfèrent deviennent orphelins.

## Vérifications

- [ ] `python3 tools/validate_catalog.py catalog.json --check-format` passe en local
- [ ] Les expressions régulières ajoutées ont été testées sur des scripts réels
- [ ] Aucun secret, jeton, adresse interne ou nom de client dans le contenu
