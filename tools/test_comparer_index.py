#!/usr/bin/env python3
"""Verifications de tools/comparer_index.py.

Chacune a ete vue echouer avant d'etre vue passer : la verification est lancee
contre une copie volontairement cassee de l'outil, et elle doit se plaindre.

    python3 tools/test_comparer_index.py
"""
import io, json, os, subprocess, sys, tempfile, unittest

ICI = os.path.dirname(os.path.abspath(__file__))
OUTIL = os.environ.get('COMPARER', os.path.join(ICI, 'comparer_index.py'))


def ecrire(dossier, nom, fiches):
    os.makedirs(dossier, exist_ok=True)
    with open(os.path.join(dossier, nom + '.json'), 'w', encoding='utf-8') as f:
        json.dump({'indexVersion': 2, 'sourceId': nom, 'scripts': fiches}, f)


def fiche(i, statut='ok', impact='lecture', badge='PS7'):
    return {'Id': i, 'Status': statut, 'Impact': impact, 'Badge': badge}


def comparer(ancien, nouveau):
    r = subprocess.run([sys.executable, OUTIL, ancien, nouveau, '--annoter'],
                       capture_output=True, text=True)
    if r.returncode != 0:
        raise AssertionError(f"code {r.returncode} : {r.stderr}")
    return r.stdout


class Comparaison(unittest.TestCase):

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.av = os.path.join(self.tmp, 'avant')
        self.ap = os.path.join(self.tmp, 'apres')

    def test_premiere_construction(self):
        """Sans etat precedent, l'outil le dit au lieu de tout compter ajoute."""
        os.makedirs(self.av)
        ecrire(self.ap, 'alpha', [fiche('a:1'), fiche('a:2')])
        s = comparer(self.av, self.ap)
        self.assertIn('premiere construction', s)
        self.assertIn('2 fiche(s)', s)

    def test_transition_de_statut_comptee(self):
        """Le decompte par transition est ce qui repond a « lesquelles »."""
        ecrire(self.av, 'alpha', [fiche('a:1', 'broken', badge='Obsolete'),
                                  fiche('a:2', 'broken', badge='Obsolete')])
        ecrire(self.ap, 'alpha', [fiche('a:1'), fiche('a:2', 'broken', badge='Obsolete')])
        s = comparer(self.av, self.ap)
        self.assertIn('broken -> ok', s)
        self.assertIn('1  broken -> ok', s)
        self.assertIn('a:1', s)

    def test_fiche_deplacee_entre_fichiers_est_changee(self):
        """Comparer a plat : un fichier d'index renomme ne cree pas deux ecarts.

        C'est le defaut trouve a la repetition du 27 septembre 2026 : la version
        precedente comparait fichier par fichier et comptait la meme fiche
        ajoutee **et** retiree, en perdant le changement de statut.
        """
        ecrire(self.av, 'ancien-nom', [fiche('a:1', 'broken', badge='Obsolete')])
        ecrire(self.ap, 'nouveau-nom', [fiche('a:1')])
        s = comparer(self.av, self.ap)
        self.assertIn('1  broken -> ok', s)
        self.assertIn('0 ajoutee(s), 0 retiree(s)', s)

    def test_construction_identique(self):
        ecrire(self.av, 'alpha', [fiche('a:1'), fiche('a:2')])
        ecrire(self.ap, 'alpha', [fiche('a:1'), fiche('a:2')])
        s = comparer(self.av, self.ap)
        self.assertIn('0 ajoutee(s), 0 retiree(s), 0 changement(s)', s)

    def test_fiche_retiree(self):
        ecrire(self.av, 'alpha', [fiche('a:1'), fiche('a:2')])
        ecrire(self.ap, 'alpha', [fiche('a:1')])
        s = comparer(self.av, self.ap)
        self.assertIn('1 retiree(s)', s)
        self.assertIn('Retirees', s)

    def test_fichier_sans_fiches_ignore(self):
        """`manifest.json` et `catalog.json` ne portent pas de liste de fiches.

        Le manifeste en porte bien un champ `scripts`, mais c'est un **compte**
        par source, pas une liste : un outil qui l'itererait s'arreterait net.
        """
        ecrire(self.av, 'alpha', [fiche('a:1')])
        ecrire(self.ap, 'alpha', [fiche('a:1')])
        with open(os.path.join(self.ap, 'manifest.json'), 'w', encoding='utf-8') as f:
            json.dump({'indexVersion': 2, 'catalogVersion': '2.2.2',
                       'sources': [{'id': 'alpha', 'scripts': 1, 'sizeKb': 12}]}, f)
        with open(os.path.join(self.ap, 'catalog.json'), 'w', encoding='utf-8') as f:
            json.dump({'catalogVersion': '2.2.2'}, f)
        s = comparer(self.av, self.ap)
        self.assertIn('Fiches : 1 -> 1', s)

    def test_index_illisible_signale_sans_arreter(self):
        ecrire(self.av, 'alpha', [fiche('a:1')])
        ecrire(self.ap, 'alpha', [fiche('a:1')])
        with open(os.path.join(self.ap, 'casse.json'), 'w', encoding='utf-8') as f:
            f.write('{ pas du json')
        s = comparer(self.av, self.ap)
        self.assertIn('casse.json illisible', s)
        self.assertIn('Fiches : 1 -> 1', s)


if __name__ == '__main__':
    unittest.main(verbosity=2)
