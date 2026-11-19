"""PCB : U12 -> connecteur 1x04 basse tension, ajout du bornier J27 (secteur du
module ZMPT101B, pas 5 mm) ; suppression des pistes non verrouillees avant
re-routage (les pistes des points d'accueil des barres sont conservees)."""
import re
from pathlib import Path
import pcbnew

MULTICAL = Path(__file__).resolve().parents[1] / "multical"
PCB = MULTICAL / "multical.kicad_pcb"
SCH = MULTICAL / "multical.kicad_sch"
LIB = str(MULTICAL / "multical_local.pretty")

# 0) pistes non verrouillees + vias supprimees (texte)
txt = PCB.read_text(encoding="utf-8")
out, i, kept = [], 0, 0
for m in re.finditer(r"\n\t\((?:segment|via|arc)\b", txt):
    if m.start() < i:
        continue
    d = 0
    for p in range(m.start() + 2, len(txt)):
        if txt[p] == "(":
            d += 1
        elif txt[p] == ")":
            d -= 1
            if d == 0:
                break
    blk = txt[m.start():p + 1]
    if "(locked yes)" in blk:
        kept += 1
        continue
    out.append(txt[i:m.start()]); i = p + 1
out.append(txt[i:])
PCB.write_text("".join(out), encoding="utf-8", newline="\n")
print("pistes verrouillees conservees :", kept)

sch = SCH.read_text(encoding="utf-8")
m = re.search(r'\(uuid "([^"]+)"\)\s+\(property "Reference" "J27"', sch)
j27_uuid = m.group(1)

board = pcbnew.LoadBoard(str(PCB))

# 1) U12 : nouvelle empreinte, meme position, memes reseaux sur les broches 3-6
old = board.FindFootprintByReference("U12")
nets = {p.GetNumber(): p.GetNetname() for p in old.Pads()}
new = pcbnew.FootprintLoad(LIB, "ZMPT101B_Header_1x04")
new.SetParent(board)
new.SetFPID(pcbnew.LIB_ID("multical_local", "ZMPT101B_Header_1x04"))
new.SetReference("U12"); new.SetValue(old.GetValue())
new.SetPosition(old.GetPosition()); new.SetOrientation(old.GetOrientation())
new.SetPath(old.GetPath()); new.SetSheetname("/"); new.SetSheetfile("multical.kicad_sch")
board.Add(new)
for p in new.Pads():
    p.SetNet(board.FindNet(nets[p.GetNumber()]))
board.Remove(old)

# 2) J27 : bornier secteur du module, a droite de U12
j = pcbnew.FootprintLoad(LIB, "TerminalBlock_MaiXu_MX126-5.0-02P_1x02_P5.00mm")
j.SetParent(board)
j.SetFPID(pcbnew.LIB_ID("multical_local", "TerminalBlock_MaiXu_MX126-5.0-02P_1x02_P5.00mm"))
j.SetReference("J27"); j.SetValue("ZMPT_secteur")
j.SetOrientationDegrees(-90)
j.SetPosition(pcbnew.VECTOR2I(pcbnew.FromMM(128.5), pcbnew.FromMM(55.0)))
j.SetPath(pcbnew.KIID_PATH("/" + j27_uuid)); j.SetSheetname("/"); j.SetSheetfile("multical.kicad_sch")
board.Add(j)
for p in j.Pads():
    p.SetNet(board.FindNet("/PHASE_BUS" if p.GetNumber() == "1" else "/NEUTRE_BUS"))

board.Save(str(PCB))
print("U12 remplace, J27 ajoute")
