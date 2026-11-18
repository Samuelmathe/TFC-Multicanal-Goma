"""Termine les liaisons des broches IP+ (1-2) et IP- (3-4) des ACS712 apres Freerouting.

Freerouting ne connait pas la regle speciale de multical.kicad_dru (0,3 mm entre
CANALn_HT et CANALn_OUT, qui sont au meme potentiel a travers le shunt) : il
applique 1 mm et s'arrete a quelques mm des broches. Ce script lit le rapport
DRC JSON (kicad-cli pcb drc --format json) et ajoute, pour chaque connexion
manquante sur un net CANAL*, un segment droit (vertical, le long de la rangee
de broches) entre les deux points signales.

Usage : python.exe finish_acs712.py <drc.json>
"""
import json, sys
from pathlib import Path
import pcbnew

MULTICAL = Path(__file__).resolve().parents[1] / "multical"
PCB = str(MULTICAL / "multical.kicad_pcb")
WIDTH_MM = 1.0                      # largeur de la netclasse HT

drc = json.load(open(sys.argv[1], encoding="utf-8"))
board = pcbnew.LoadBoard(PCB)
added = 0
for u in drc["unconnected_items"]:
    a, b = u["items"]
    desc = a["description"]
    net = desc[desc.index("[") + 1:desc.index("]")]
    if "CANAL" not in net:
        print("ignore (pas un net CANAL) :", desc)
        continue
    (xa, ya), (xb, yb) = (a["pos"]["x"], a["pos"]["y"]), (b["pos"]["x"], b["pos"]["y"])
    if abs(xa - xb) > 0.01:
        print("ignore (pas vertical) :", desc, "<->", b["description"])
        continue
    # Broche "interieure" (2 pour IP+, 3 pour IP-) : la plus proche de l'autre net.
    # Le dernier pas (1,27 mm) jusqu'a elle est trace en 0,6 mm (= hauteur de la
    # pastille) pour garder 0,67 mm avec la broche voisine ; le reste en 1 mm.
    inner = "Pad 2 " if net.endswith("_HT") else "Pad 3 "
    if b["description"].startswith(inner):
        (xa, ya), (xb, yb) = (xa, ya), (xb, yb)
    elif a["description"].startswith(inner):
        (xa, ya), (xb, yb) = (xb, yb), (xa, ya)
    else:
        print("ignore (pas de broche interieure) :", desc, "<->", b["description"])
        continue
    # (xa, ya) = point exterieur, (xb, yb) = broche interieure
    step = 1.27 if yb > ya else -1.27
    y_mid = yb - step
    segs = [((ya, yb), 0.6)] if abs(yb - ya) <= 1.271 else [((ya, y_mid), WIDTH_MM), ((y_mid, yb), 0.6)]
    for (y0, y1), w in segs:
        t = pcbnew.PCB_TRACK(board)
        t.SetStart(pcbnew.VECTOR2I(pcbnew.FromMM(xa), pcbnew.FromMM(y0)))
        t.SetEnd(pcbnew.VECTOR2I(pcbnew.FromMM(xa), pcbnew.FromMM(y1)))
        t.SetWidth(pcbnew.FromMM(w))
        t.SetLayer(pcbnew.F_Cu)
        t.SetNet(board.FindNet(net))
        board.Add(t)
        added += 1
board.Save(PCB)
print(f"{added} segments ajoutes")
