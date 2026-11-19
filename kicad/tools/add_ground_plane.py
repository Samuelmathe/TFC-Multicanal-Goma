"""Ajoute un plan de masse GND sur la couche B.Cu (toute la carte, 0,5 mm en
retrait du bord). Le remplissage est fait ensuite par kicad-cli
(pcb drc --refill-zones --save-board). La regle "Plan de masse eloigne du
230 V" de multical.kicad_dru le tient a 3 mm de tous les reseaux HT."""
from pathlib import Path
import pcbnew

PCB = Path(__file__).resolve().parents[1] / "multical" / "multical.kicad_pcb"
mm = pcbnew.FromMM
board = pcbnew.LoadBoard(str(PCB))
assert "plan_gnd_bcu" not in PCB.read_text(encoding="utf-8"), "deja applique"

bb = board.GetBoardEdgesBoundingBox()
x0, y0 = pcbnew.ToMM(bb.GetLeft()) + 0.5, pcbnew.ToMM(bb.GetTop()) + 0.5
x1, y1 = pcbnew.ToMM(bb.GetRight()) - 0.5, pcbnew.ToMM(bb.GetBottom()) - 0.5

z = pcbnew.ZONE(board)
z.SetLayer(pcbnew.B_Cu)
z.SetNet(board.FindNet("/GND"))
z.SetZoneName("plan_gnd_bcu")
z.SetLocalClearance(mm(0.3))
z.SetMinThickness(mm(0.25))
z.SetPadConnection(pcbnew.ZONE_CONNECTION_THERMAL)
z.SetThermalReliefGap(mm(0.5))
z.SetThermalReliefSpokeWidth(mm(0.5))
z.SetIslandRemovalMode(pcbnew.ISLAND_REMOVAL_MODE_ALWAYS)
z.SetAssignedPriority(0)
outline = z.Outline()
outline.NewOutline()
for x, y in ((x0, y0), (x1, y0), (x1, y1), (x0, y1)):
    outline.Append(mm(x), mm(y))
board.Add(z)
board.Save(str(PCB))
print(f"zone GND B.Cu : {x1 - x0:.1f} x {y1 - y0:.1f} mm (a remplir par kicad-cli)")
