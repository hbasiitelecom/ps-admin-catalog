#!/usr/bin/env python3
"""
Validateur du catalogue AdminDroid Script Launcher.

Sans aucune dependance : uniquement la bibliotheque standard de Python.
C'est deliberé — ce script s'execute dans la CI, et n'installer aucun paquet
tiers supprime toute surface d'attaque par la chaine d'approvisionnement.

Il verifie ce qu'un JSON Schema ne peut pas verifier seul :
  - unicite et stabilite des identifiants
  - existence de la source referencee par chaque annotation
  - compilation effective de chaque expression reguliere
  - absence de constructions regex a risque d'explosion combinatoire
  - incrementation de catalogVersion par rapport a la reference

Usage :
    python3 tools/validate_catalog.py catalog.json
    python3 tools/validate_catalog.py catalog.json --baseline ancien.json
    python3 tools/validate_catalog.py catalog.json --check-format
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

SEVERITIES = ("ok", "warn", "broken")
ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,39}$")
GH_NAME_RE = re.compile(r"^[A-Za-z0-9._-]{1,100}$")
BRANCH_RE = re.compile(r"^[A-Za-z0-9._/-]{1,100}$")
ICON_RE = re.compile(r"^[0-9A-Fa-f]{4,5}$")
SEMVER_RE = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")
# Quantificateur imbrique : (a+)+ , (a*)* , (a|b)+* ... classique des regex explosives
NESTED_QUANT_RE = re.compile(r"\([^()]*[+*]\)[+*]")

problems: list[str] = []
notes: list[str] = []


def fail(msg: str) -> None:
    problems.append(msg)


def note(msg: str) -> None:
    notes.append(msg)


def need(obj: dict, key: str, where: str, kind=str, required=True):
    if key not in obj or obj[key] is None:
        if required:
            fail(f"{where} : champ obligatoire « {key} » absent.")
        return None
    val = obj[key]
    if kind is str and not isinstance(val, str):
        fail(f"{where} : « {key} » doit etre une chaine.")
        return None
    if kind is bool and not isinstance(val, bool):
        fail(f"{where} : « {key} » doit etre un booleen.")
        return None
    if kind is int and not isinstance(val, int):
        fail(f"{where} : « {key} » doit etre un entier.")
        return None
    return val


def check_pattern(pattern: str, where: str) -> None:
    try:
        re.compile(pattern)
    except re.error as exc:
        fail(f"{where} : expression reguliere invalide ({exc}).")
        return
    if NESTED_QUANT_RE.search(pattern):
        fail(
            f"{where} : quantificateur imbrique detecte. Ce motif peut faire exploser "
            f"le temps d'analyse sur certains scripts. Reecrivez-le."
        )
    if len(pattern) > 1000:
        fail(f"{where} : motif trop long ({len(pattern)} caracteres, maximum 1000).")


def check_unique(items, key, kind, seen_note=True):
    seen = {}
    for i, it in enumerate(items):
        val = it.get(key)
        if val is None:
            continue
        if val in seen:
            fail(f"{kind} : identifiant « {val} » utilise deux fois (positions {seen[val]} et {i}).")
        seen[val] = i
    return seen


def validate(cat: dict) -> set:
    where = "racine"

    sv = need(cat, "schemaVersion", where, int)
    if sv is not None and sv != 1:
        fail(f"racine : schemaVersion vaut {sv}, seul 1 est reconnu par cette version du validateur.")

    cv = need(cat, "catalogVersion", where)
    if cv and not SEMVER_RE.match(cv):
        fail(f"racine : catalogVersion « {cv} » n'est pas au format SemVer MAJEUR.MINEUR.CORRECTIF.")

    need(cat, "name", where)

    known = {"$schema", "schemaVersion", "catalogVersion", "name", "description", "okLabel",
             "sources", "services", "rules", "overrides"}
    for extra in sorted(set(cat) - known):
        fail(f"racine : champ inconnu « {extra} ». L'application l'ignorerait silencieusement.")

    # ---------------------------------------------------------------- sources
    sources = cat.get("sources") or []
    if not isinstance(sources, list) or not sources:
        fail("racine : « sources » doit etre une liste non vide.")
        sources = []
    source_ids = set()
    for i, s in enumerate(sources):
        w = f"sources[{i}]"
        if not isinstance(s, dict):
            fail(f"{w} : doit etre un objet.")
            continue
        sid = need(s, "id", w)
        if sid:
            if not ID_RE.match(sid):
                fail(f"{w} : id « {sid} » invalide (minuscules, chiffres et tirets, 40 caracteres max).")
            source_ids.add(sid)
        need(s, "name", w)
        for field, rx, label in (("owner", GH_NAME_RE, "compte"), ("repo", GH_NAME_RE, "depot")):
            val = need(s, field, w)
            if val and not rx.match(val):
                fail(f"{w} : {label} « {val} » contient des caracteres interdits. "
                     f"L'application construit l'URL GitHub a partir de ce champ.")
        br = s.get("branch")
        if br is not None and (not isinstance(br, str) or not BRANCH_RE.match(br)):
            fail(f"{w} : branche « {br} » invalide.")
        en = s.get("enabled")
        if en is not None and not isinstance(en, bool):
            fail(f"{w} : « enabled » doit etre un booleen.")
        lay = s.get("layout")
        if lay is not None and lay not in ("folders", "flat", "tree"):
            fail(f"{w} : layout « {lay} » inconnu. Valeurs admises : folders, flat, tree.")
        tr = s.get("trust")
        if tr is not None and tr not in ("official", "verified", "community", "unknown"):
            fail(f"{w} : trust « {tr} » inconnu.")
        for fld in ("include", "exclude"):
            if s.get(fld) is not None and not isinstance(s[fld], list):
                fail(f"{w} : « {fld} » doit etre une liste de motifs.")
        known_src = {"id","name","owner","repo","branch","metadataStyle","enabled",
                     "layout","include","exclude","trust","license","note"}
        for extra in sorted(set(s) - known_src):
            fail(f"{w} : champ inconnu « {extra} ».")
    check_unique(sources, "id", "sources")

    # --------------------------------------------------------------- services
    services = cat.get("services") or []
    for i, sv_ in enumerate(services):
        w = f"services[{i}]"
        if not isinstance(sv_, dict):
            fail(f"{w} : doit etre un objet.")
            continue
        sid = need(sv_, "id", w)
        if sid and not ID_RE.match(sid):
            fail(f"{w} : id « {sid} » invalide.")
        need(sv_, "label", w)
        pat = need(sv_, "pattern", w)
        if pat:
            check_pattern(pat, w)
        ico = sv_.get("icon")
        if ico is not None and (not isinstance(ico, str) or not ICON_RE.match(ico)):
            fail(f"{w} : icone « {ico} » doit etre un point de code hexadecimal (ex. E715).")
    check_unique(services, "id", "services")

    # ------------------------------------------------------------------ rules
    rules = cat.get("rules") or []
    for i, r in enumerate(rules):
        w = f"rules[{i}]"
        if not isinstance(r, dict):
            fail(f"{w} : doit etre un objet.")
            continue
        rid = need(r, "id", w)
        if rid and not ID_RE.match(rid):
            fail(f"{w} : id « {rid} » invalide.")
        sev = need(r, "severity", w)
        if sev and sev not in SEVERITIES:
            fail(f"{w} : severite « {sev} » inconnue. Valeurs admises : {', '.join(SEVERITIES)}.")
        need(r, "label", w)
        reason = need(r, "reason", w)
        if reason is not None and len(reason) < 10:
            fail(f"{w} : « reason » est affiche a l'utilisateur, il doit expliquer le probleme.")
        pat = need(r, "pattern", w)
        if pat:
            check_pattern(pat, w)
    check_unique(rules, "id", "rules")
    if not any((r.get("severity") == "broken") for r in rules if isinstance(r, dict)):
        note("aucune regle de severite « broken » : plus rien ne sera masque par defaut.")

    # -------------------------------------------------------------- overrides
    overrides = cat.get("overrides") or []
    seen_ovr = {}
    for i, o in enumerate(overrides):
        w = f"overrides[{i}]"
        if not isinstance(o, dict):
            fail(f"{w} : doit etre un objet.")
            continue
        osid = need(o, "sourceId", w)
        path = need(o, "path", w)
        if osid and source_ids and osid not in source_ids:
            fail(f"{w} : sourceId « {osid} » ne correspond a aucune source declaree.")
        if path:
            if "\\" in path:
                fail(f"{w} : le chemin « {path} » contient un antislash. "
                     f"Utilisez des barres obliques : l'application normalise ainsi.")
            if not path.endswith(".ps1"):
                fail(f"{w} : le chemin « {path} » doit designer un fichier .ps1.")
            key = (osid, path)
            if key in seen_ovr:
                fail(f"{w} : doublon avec overrides[{seen_ovr[key]}] pour le meme script.")
            seen_ovr[key] = i
        st = o.get("status")
        if st is not None and st not in SEVERITIES:
            fail(f"{w} : status « {st} » inconnu.")
        hid = o.get("hidden")
        if hid is not None and not isinstance(hid, bool):
            fail(f"{w} : « hidden » doit etre un booleen.")

    return source_ids


def semver_tuple(v: str):
    return tuple(int(x) for x in v.split("."))


def compare_baseline(cat: dict, baseline_path: Path) -> None:
    try:
        old = json.loads(baseline_path.read_text(encoding="utf-8"))
    except Exception as exc:
        note(f"reference illisible ({exc}) — comparaison de version ignoree.")
        return

    old_v, new_v = old.get("catalogVersion"), cat.get("catalogVersion")
    if not (isinstance(old_v, str) and SEMVER_RE.match(old_v)):
        note("la reference n'a pas de catalogVersion SemVer — comparaison ignoree.")
        return
    if not (isinstance(new_v, str) and SEMVER_RE.match(new_v)):
        return

    same_content = all(cat.get(k) == old.get(k) for k in ("sources", "services", "rules", "overrides", "name"))
    if same_content:
        if new_v != old_v:
            note(f"catalogVersion passe de {old_v} a {new_v} sans changement de contenu.")
        return

    if semver_tuple(new_v) <= semver_tuple(old_v):
        fail(f"le contenu a change mais catalogVersion n'a pas ete incremente "
             f"({old_v} -> {new_v}). L'application ne proposerait aucune mise a jour.")
        return

    # Detection des changements incompatibles : une source disparue ou renommee
    old_ids = {s.get("id") for s in (old.get("sources") or []) if isinstance(s, dict)}
    new_ids = {s.get("id") for s in (cat.get("sources") or []) if isinstance(s, dict)}
    removed = old_ids - new_ids
    if removed:
        major_bumped = semver_tuple(new_v)[0] > semver_tuple(old_v)[0]
        msg = (f"source(s) retiree(s) ou renommee(s) : {', '.join(sorted(str(r) for r in removed))}. "
               f"Les favoris et l'historique qui s'y referent deviennent orphelins.")
        if major_bumped:
            note(msg + " Version MAJEURE incrementee, c'est coherent.")
        else:
            fail(msg + f" Cela impose une version MAJEURE (actuellement {old_v} -> {new_v}).")


def check_format(path: Path, cat: dict) -> None:
    raw = path.read_bytes()
    if raw.startswith(b"\xef\xbb\xbf"):
        fail("le fichier commence par une marque d'ordre des octets (BOM). Enregistrez-le en UTF-8 sans BOM.")
    text = raw.decode("utf-8")
    if "\r\n" in text:
        fail("le fichier contient des fins de ligne CRLF. Utilisez LF (voir .gitattributes).")
    expected = json.dumps(cat, indent=2, ensure_ascii=False) + "\n"
    if text != expected:
        fail("mise en forme non canonique. Reformatez avec :\n"
             "    python3 -c \"import json,io;p='catalog.json';"
             "d=json.load(open(p,encoding='utf-8'));"
             "open(p,'w',encoding='utf-8').write(json.dumps(d,indent=2,ensure_ascii=False)+chr(10))\"")


def main() -> int:
    ap = argparse.ArgumentParser(description="Valide un catalogue AdminDroid Script Launcher.")
    ap.add_argument("catalog", type=Path, help="chemin du catalog.json")
    ap.add_argument("--baseline", type=Path, help="version de reference, pour exiger l'incrementation")
    ap.add_argument("--check-format", action="store_true", help="exige une mise en forme canonique")
    args = ap.parse_args()

    if not args.catalog.is_file():
        print(f"[ECHEC] fichier introuvable : {args.catalog}", file=sys.stderr)
        return 2

    try:
        cat = json.loads(args.catalog.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"[ECHEC] JSON invalide, ligne {exc.lineno} colonne {exc.colno} : {exc.msg}", file=sys.stderr)
        return 2
    if not isinstance(cat, dict):
        print("[ECHEC] la racine du catalogue doit etre un objet.", file=sys.stderr)
        return 2

    validate(cat)
    if args.check_format:
        check_format(args.catalog, cat)
    if args.baseline:
        compare_baseline(cat, args.baseline)

    for n in notes:
        print(f"[note]   {n}")
    for p in problems:
        print(f"[ECHEC]  {p}", file=sys.stderr)

    if problems:
        print(f"\n{len(problems)} probleme(s). Catalogue refuse.", file=sys.stderr)
        return 1

    print(f"Catalogue valide — version {cat.get('catalogVersion')}, "
          f"{len(cat.get('sources') or [])} source(s), "
          f"{len(cat.get('services') or [])} service(s), "
          f"{len(cat.get('rules') or [])} regle(s), "
          f"{len(cat.get('overrides') or [])} annotation(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
