"""Replace les reperes de serigraphie "PH" / "N" a cote des broches 1 et 2 des
borniers J10-J18 (remplace add_ph_n_labels.py, dont les positions etaient figees).
Supprime d'abord les anciens textes "PH" / "N" de la carte.
"""
import re
from pathlib import Path
import pcbnew

MULTICAL = Path(__file__).resolve().parents[1] / "multical"
PCB = MULTICAL / "multical.kicad_pcb"

# 1) suppression des anciens textes (sur le fichier texte, l'API SWIG ne permet
#    pas d'iterer les dessins de facon fiable sous KiCad 10.0.8 / Windows)
txt = PCB.read_text(encoding="utf-8")
txt, n = re.subn(r'\n\t\(gr_text "(?:PH|N)"\n(?:\t\t.*\n)*?\t\)', "", txt)
PCB.write_text(txt, encoding="utf-8", newline="\n")
print("anciens reperes supprimes :", n)

# 2) nouveaux reperes, 7 mm a gauche de chaque pastille
board = pcbnew.LoadBoard(str(PCB))
for ref in ["J10"] + [f"J{i}" for i in range(11, 19)]:
    f = board.FindFootprintByReference(ref)
    for pad in f.Pads():
        label = {"1": "PH", "2": "N"}.get(pad.GetNumber())
        if not label:
            continue
        p = pad.GetPosition()
        t = pcbnew.PCB_TEXT(board)
        t.SetText(label)
        t.SetLayer(pcbnew.F_SilkS)
        t.SetTextSize(pcbnew.VECTOR2I(pcbnew.FromMM(1), pcbnew.FromMM(1)))
        t.SetTextThickness(pcbnew.FromMM(0.15))
        t.SetPosition(pcbnew.VECTOR2I(p.x - pcbnew.FromMM(7.0), p.y))
        board.Add(t)
board.Save(str(PCB))
print("nouveaux reperes places")
