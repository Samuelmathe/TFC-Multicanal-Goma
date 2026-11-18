"""Nettoyage apres routage : supprime les bouts de piste en l'air (track_dangling)
et rentre dans la carte les references de borniers qui touchent le bord.

Usage : python.exe cleanup_after_route.py <drc.json>
"""
import json, sys
from pathlib import Path
import pcbnew

MULTICAL = Path(__file__).resolve().parents[1] / "multical"
PCB = str(MULTICAL / "multical.kicad_pcb")

import re

drc = json.load(open(sys.argv[1], encoding="utf-8"))
board = pcbnew.LoadBoard(PCB)
dangling = []
for v in drc["violations"]:
    if v["type"] == "track_dangling":
        dangling += [it["uuid"] for it in v["items"]]
    elif v["type"] == "silk_edge_clearance":
        for it in v["items"]:
            if it["description"].startswith("Reference field of "):
                ref = it["description"].split()[-1]
                f = board.FindFootprintByReference(ref)
                txt = f.Reference()
                p = txt.GetPosition()
                txt.SetPosition(pcbnew.VECTOR2I(p.x - pcbnew.FromMM(2.5), p.y))
                print("reference deplacee :", ref)
board.Save(PCB)

# Suppression des pistes en l'air par uuid, sur le texte du fichier
# (BOARD.GetItem / GetTracks ne sont pas utilisables avec le SWIG de KiCad 10.0.8)
txt = Path(PCB).read_text(encoding="utf-8")
for uid in dangling:
    m = re.search(r'\n\t\(segment\b(?:(?!\n\t\().)*?\(uuid "' + re.escape(uid) + r'"\)\s*\)', txt, re.S)
    if m:
        txt = txt[:m.start()] + txt[m.end():]
        print("piste en l'air supprimee :", uid)
    else:
        print("introuvable :", uid)
Path(PCB).write_text(txt, encoding="utf-8", newline="\n")
