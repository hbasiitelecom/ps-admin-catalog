#!/usr/bin/env python3
"""Compare deux constructions d'index et dit ce qui a change.

Pourquoi cet outil existe. La branche « index » etait reecrite a chaque
construction, en orphelin pousse en force : l'historique n'enflait pas, et il
etait impossible de comparer deux etats. Le 27 septembre 2026, apres un
correctif, le nombre de fiches marquees Obsolete est passe de 53 a 50 la ou
l'arithmetique en attendait 49, et la question « lesquelles ont change » etait
sans reponse : l'etat precedent n'existait plus.

Usage :
    python3 tools/comparer_index.py <ancien_dossier> <nouveau_dossier> [--annoter]

    --annoter  emet aussi des ::notice:: pour l'integration continue. Les
               annotations sont le seul canal de la CI lisible par l'API ; les
               resumes de job ne le sont pas.

Rend 0 meme quand il y a des changements : c'est un rapport, pas une barriere.
"""
import argparse, glob, json, os, sys

CHAMPS_SUIVIS = ('Status', 'Impact', 'Badge')


def charger(dossier):
    """Rend {id_fiche: fiche}, toutes sources confondues.

    Les identifiants sont deja prefixes par la source (`<source>:<chemin>`), donc
    uniques a l'echelle du corpus. Comparer a plat plutot que fichier par fichier
    fait apparaitre comme *changee* une fiche dont le fichier d'index a change de
    nom, la ou une comparaison par fichier la comptait ajoutee **et** retiree -
    defaut vu a la repetition du 27 septembre 2026.

    Un dossier absent rend un dict vide. `manifest.json` et `catalog.json` ne
    portent pas de fiches et sont ignores.
    """
    out, sources = {}, set()
    for f in sorted(glob.glob(os.path.join(dossier, '*.json'))):
        nom = os.path.splitext(os.path.basename(f))[0]
        if nom in ('catalog', 'manifest'):
            continue
        try:
            d = json.load(open(f, encoding='utf-8-sig'))
        except Exception as e:
            print(f"  [!] {nom}.json illisible : {e}")
            continue
        fiches = d.get('scripts')
        if not isinstance(fiches, list):
            continue
        sources.add(nom)
        for fi in fiches:
            i = fi.get('Id')
            if not i:
                continue
            if i in out:
                print(f"  [!] identifiant en double : {i}")
            out[i] = fi
    return out, sources


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('ancien')
    ap.add_argument('nouveau')
    ap.add_argument('--annoter', action='store_true')
    a = ap.parse_args()

    av, src_av = charger(a.ancien)
    ap_, src_ap = charger(a.nouveau)
    if not ap_:
        print("Aucun index neuf a comparer.")
        return 0
    if not av:
        msg = (f"premiere construction comparable : {len(ap_)} fiche(s), "
               f"{len(src_ap)} source(s)")
        print(msg)
        if a.annoter:
            print(f"::notice title=Index::{msg}")
        return 0

    ajoutees = sorted(set(ap_) - set(av))
    retirees = sorted(set(av) - set(ap_))
    changees = []
    for i in sorted(set(av) & set(ap_)):
        for c in CHAMPS_SUIVIS:
            a_, n_ = av[i].get(c), ap_[i].get(c)
            if a_ != n_:
                changees.append((i, c, a_, n_))

    total_av, total_ap = len(av), len(ap_)
    perdues = sorted(src_av - src_ap)
    if perdues:
        print("Sources disparues de l'index : " + ', '.join(perdues))
    print(f"Fiches : {total_av} -> {total_ap}")
    print(f"  {len(ajoutees)} ajoutee(s), {len(retirees)} retiree(s), "
          f"{len(changees)} changement(s) de statut, d'impact ou de badge")

    for titre, liste in (('Ajoutees', ajoutees), ('Retirees', retirees)):
        if liste:
            print(f"\n{titre} :")
            for i in liste[:40]:
                print(f"  {i}")
            if len(liste) > 40:
                print(f"  ... et {len(liste) - 40} autre(s)")

    if changees:
        print("\nChangements :")
        for i, c, x, y in changees[:60]:
            print(f"  {c:<7} {x} -> {y}   {i}")
        if len(changees) > 60:
            print(f"  ... et {len(changees) - 60} autre(s)")

    # Le decompte par transition de statut : c'est lui qui repond en une ligne a
    # « combien de fiches ont cesse d'etre marquees Obsolete ».
    trans = {}
    for i, c, x, y in changees:
        if c == 'Status':
            trans[f"{x} -> {y}"] = trans.get(f"{x} -> {y}", 0) + 1
    if trans:
        print("\nStatuts, par transition :")
        for k in sorted(trans):
            print(f"  {trans[k]:>4}  {k}")

    if a.annoter:
        resume = (f"{total_av} -> {total_ap} fiches · {len(ajoutees)} ajoutee(s) · "
                  f"{len(retirees)} retiree(s) · {len(changees)} changement(s)")
        if trans:
            resume += " · statuts : " + ", ".join(f"{v} {k}" for k, v in sorted(trans.items()))
        print(f"::notice title=Index::{resume}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
