"""PCB : ajoute les 9 ponts diviseurs (R6-R23, 0805) et les points d'accueil des
barres de cuivre, puis supprime toutes les pistes pour un re-routage complet.

Points d'accueil (pastilles traversantes Ø 4 mm, percage 2,5 mm, "carte seule") :
  - a cote de la broche 1 de chaque bornier IN et OUT, reliee par une piste de 1,8 mm ;
  - a cote des broches IP+ (1-2) et IP- (3-4) de chaque ACS712, reliee par une
    piste de 1,8 mm qui recouvre les deux broches.
Les broches COM et NO des relais (percage 2,5 mm) servent directement.
Les pistes d'accueil sont verrouillees : Freerouting les conserve.
"""
import re
from pathlib import Path
import pcbnew

MULTICAL = Path(__file__).resolve().parents[1] / "multical"
PCB = MULTICAL / "multical.kicad_pcb"
SCH = MULTICAL / "multical.kicad_sch"
FP_LIB = Path(r"C:\Users\User\Tools\KiCad\share\kicad\footprints\Resistor_SMD.pretty")
mm = pcbnew.FromMM

# ---- 0) suppression de toutes les pistes / vias (texte) ------------------------------
txt = PCB.read_text(encoding="utf-8")
assert "/ACS1_VOUT" not in txt, "deja applique"
out, i = [], 0
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
    out.append(txt[i:m.start()]); i = p + 1
out.append(txt[i:])
PCB.write_text("".join(out), encoding="utf-8", newline="\n")

# uuid des symboles R6-R23 dans le schema (lien PCB <-> schema)
sch = SCH.read_text(encoding="utf-8")
sym_uuid = {}
for m in re.finditer(r'\(lib_id "Device:R"\)\s+\(at [^)]*\)(?:(?!\(lib_id).)*?\(uuid "([^"]+)"\)\s+\(property "Reference" "(R\d+)"', sch, re.S):
    sym_uuid[m.group(2)] = m.group(1)

board = pcbnew.LoadBoard(str(PCB))


def net(name):
    n = board.FindNet(name)
    if n is None:
        n = pcbnew.NETINFO_ITEM(board, name)
        board.Add(n)
    return n


def pad_of(ref, num):
    f = board.FindFootprintByReference(ref)
    for p in f.Pads():
        if p.GetNumber() == num:
            return p
    raise KeyError((ref, num))


def track(x0, y0, x1, y1, netname, w=1.8):
    t = pcbnew.PCB_TRACK(board)
    t.SetStart(pcbnew.VECTOR2I(mm(x0), mm(y0)))
    t.SetEnd(pcbnew.VECTOR2I(mm(x1), mm(y1)))
    t.SetWidth(mm(w)); t.SetLayer(pcbnew.F_Cu); t.SetNet(net(netname)); t.SetLocked(True)
    board.Add(t)


def resistor(ref, value, x, y, n1, n2):
    f = pcbnew.FootprintLoad(str(FP_LIB), "R_0805_2012Metric")
    f.SetParent(board)
    f.SetReference(ref); f.SetValue(value)
    f.SetPosition(pcbnew.VECTOR2I(mm(x), mm(y)))
    f.SetPath(pcbnew.KIID_PATH("/" + sym_uuid[ref]))
    f.SetSheetname("/"); f.SetSheetfile("multical.kicad_sch")
    board.Add(f)
    for p in f.Pads():
        p.SetNet(net(n1 if p.GetNumber() == "1" else n2))


n_bar = [0]
def landing(x, y, netname):
    n_bar[0] += 1
    f = pcbnew.FOOTPRINT(board)
    # nom de bibliotheque obligatoire : sinon le .ses de Freerouting contient
    # "(component )" vide et KiCad refuse de le reimporter
    f.SetFPID(pcbnew.LIB_ID("multical_local", "Point_barre_cuivre"))
    f.SetReference(f"BAR{n_bar[0]}"); f.SetValue("Point barre cuivre")
    f.Reference().SetVisible(False); f.Value().SetVisible(False)
    f.SetBoardOnly(True); f.SetExcludedFromBOM(True); f.SetExcludedFromPosFiles(True)
    p = pcbnew.PAD(f)
    p.SetNumber("1")
    p.SetAttribute(pcbnew.PAD_ATTRIB_PTH)
    p.SetShape(pcbnew.PADSTACK.ALL_LAYERS, pcbnew.PAD_SHAPE_CIRCLE)
    p.SetSize(pcbnew.PADSTACK.ALL_LAYERS, pcbnew.VECTOR2I(mm(4), mm(4)))
    p.SetDrillSize(pcbnew.VECTOR2I(mm(2.5), mm(2.5)))
    p.SetLayerSet(pcbnew.PAD.PTHMask())
    f.Add(p)
    f.SetPosition(pcbnew.VECTOR2I(mm(x), mm(y)))
    board.Add(f)
    p.SetNet(net(netname))


P = lambda pad: (pcbnew.ToMM(pad.GetPosition().x), pcbnew.ToMM(pad.GetPosition().y))

# ---- 1) ponts diviseurs ------------------------------------------------------------
canaux = [  # canal, ACS, GPIO, bornier OUT, bornier IN
    (1, "U6", "/GPIO36", "J11", "J23"), (2, "U7", "/GPIO26", "J12", "J24"),
    (3, "U8", "/GPIO27", "J13", "J25"), (4, "U9", "/GPIO39", "J14", "J26"),
    (5, "U2", "/GPIO32", "J15", "J19"), (6, "U3", "/GPIO33", "J16", "J20"),
    (7, "U4", "/GPIO34", "J17", "J21"), (8, "U5", "/GPIO35", "J18", "J22"),
]
r = 6
for n, acs, gpio, jout, jin in canaux:
    vout = f"/ACS{n}_VOUT"
    pad_of(acs, "7").SetNet(net(vout))
    xs, ys = P(pad_of(acs, "1"))
    resistor(f"R{r}", "10k", 47.0, ys + 5.8, vout, gpio)
    resistor(f"R{r + 1}", "12k", 47.0, ys + 8.8, gpio, "/GND")
    r += 2
pad_of("U12", "6").SetNet(net("/ZMPT_VOUT"))
resistor("R22", "10k", 112.0, 72.0, "/ZMPT_VOUT", "/GPIO25")
resistor("R23", "12k", 112.0, 75.0, "/GPIO25", "/GND")

# ---- 2) points d'accueil des barres ------------------------------------------------
for n, acs, gpio, jout, jin in canaux:
    ht, outn = f"/CANAL{n}_HT", f"/CANAL{n}_OUT"
    (x1, y1), (_, y2), (_, y3), (_, y4) = (P(pad_of(acs, k)) for k in "1234")
    yp, ym = (y1 + y2) / 2, (y3 + y4) / 2           # milieu IP+ / IP-
    landing(53.5, yp - 4.5, ht)
    track(53.5, yp - 4.5, 55.6, yp, ht); track(55.6, yp, x1, yp, ht)
    landing(53.5, ym + 4.5, outn)
    track(53.5, ym + 4.5, 55.6, ym, outn); track(55.6, ym, x1, ym, outn)
    for j in (jin, jout):
        pad1 = pad_of(j, "1")
        xj, yj = P(pad1)
        nn = pad1.GetNetname()
        landing(xj - 12, yj, nn)
        track(xj - 12, yj, xj, yj, nn)

board.Save(str(PCB))
print(f"ponts diviseurs : R6-R23 ; points d'accueil : {n_bar[0]}")
