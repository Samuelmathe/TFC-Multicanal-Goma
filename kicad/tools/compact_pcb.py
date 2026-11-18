"""Compactage du PCB multical (carte 260 x 440 mm -> ~138 x 340 mm).

Principe (garde la topologie qui avait ete routee avec succes) :
  - zone basse tension (ESP32, ULN2003, AMS1117, R, C) inchangee en haut a gauche ;
  - HLK-PM01 + bornier secteur J10 + ZMPT101B (U12) regroupes en haut a droite,
    pres de J10, pour que le 230 V ne traverse plus toute la zone BT ;
  - les 8 canaux en lignes (C, ACS712, diode, relais tourne de 90 deg) avec un
    pas de 30 mm au lieu de 40-45 mm ;
  - les 17 borniers restent tous sur le bord DROIT (compatible avec le boitier) ;
  - toutes les pistes sont supprimees : la carte est ensuite re-routee avec
    Freerouting (voir route_pcb.ps1 / GUIDE_KICAD.md).

Usage (Python de KiCad) :
  "C:\\Program Files\\KiCad\\10.0\\bin\\python.exe" compact_pcb.py [entree] [sortie]
"""
import sys
from pathlib import Path
import pcbnew

MULTICAL = Path(__file__).resolve().parents[1] / "multical"
SRC = sys.argv[1] if len(sys.argv) > 1 else str(MULTICAL / "multical.kicad_pcb")
DST = sys.argv[2] if len(sys.argv) > 2 else SRC

# ---- Geometrie de la nouvelle carte ------------------------------------------
X0, Y0 = 14.0, 18.5            # coin haut-gauche (inchange)
E = 152.0                      # bord droit
ROW_Y0 = 128.0                 # centre de la premiere ligne de canal
PITCH = 30.0                   # pas vertical entre canaux
MARGIN_BOTTOM = 14.0

mm = pcbnew.FromMM
board = pcbnew.LoadBoard(SRC)


def fp(ref):
    f = board.FindFootprintByReference(ref)
    assert f is not None, ref
    return f


def place(ref, x, y, rot=None):
    """Place le CENTRE du boitier (courtyard / bbox) en (x, y)."""
    f = fp(ref)
    if rot is not None:
        f.SetOrientationDegrees(rot)
    bb = f.GetBoundingBox(False)          # sans les textes
    c = bb.GetCenter()
    pos = f.GetPosition()
    f.SetPosition(pcbnew.VECTOR2I(pos.x + mm(x) - c.x, pos.y + mm(y) - c.y))


def place_edge(ref, y, gap=0.6):
    """Bornier : bord droit du boitier (serigraphie comprise) a `gap` mm du bord."""
    f = fp(ref)
    bb = f.GetBoundingBox(False)
    pos = f.GetPosition()
    dx = mm(E - gap) - bb.GetRight()
    dy = mm(y) - bb.GetCenter().y
    f.SetPosition(pcbnew.VECTOR2I(pos.x + dx, pos.y + dy))


def place_origin(ref, x, y, rot=None):
    f = fp(ref)
    if rot is not None:
        f.SetOrientationDegrees(rot)
    f.SetPosition(pcbnew.VECTOR2I(mm(x), mm(y)))


# ---- Zone haute : secteur + alimentation, pres du bord droit -------------------
place_edge("J10", 30.0)                 # entree secteur, rotation d'origine
# Le HLK (~15 mm de haut) doit rester a gauche de la rampe inclinee du boitier
# (au-dessus des borniers), donc a gauche du bord droit des relais (x ~122).
place("U10", 103.0, 32.0, 180)              # HLK-PM01, broches AC cote J10
place_origin("U13", 85.2, 50.1)             # ULN2003 (relais 1-4), origine = broche 1
place_origin("U14", 100.2, 50.1)            # ULN2003 (relais 5-8)  (bbox faussee par un element graphique)
place("U12", 117.0, 60.0)                   # ZMPT101B, pres du HLK et de J10

# ---- Canaux : (C, ACS712, diode, relais, bornier OUT, bornier IN) ---------------
canaux = [
    # canal, C,    U,    D,    K,    J_OUT, J_IN
    (1, "C6", "U6", "D1", "K5", "J11", "J23"),
    (2, "C7", "U7", "D2", "K6", "J12", "J24"),
    (3, "C8", "U8", "D3", "K7", "J13", "J25"),
    (4, "C9", "U9", "D4", "K8", "J14", "J26"),
    (5, "C2", "U2", "D5", "K1", "J15", "J19"),
    (6, "C3", "U3", "D6", "K2", "J16", "J20"),
    (7, "C4", "U4", "D7", "K3", "J17", "J21"),
    (8, "C5", "U5", "D8", "K4", "J18", "J22"),
]
for n, c, u, d, k, jout, jin in canaux:
    y = ROW_Y0 + (n - 1) * PITCH
    place(c, 46.0, y - 6.0)
    place(u, 60.0, y)
    place(d, 76.0, y + 7.0)
    place(k, 106.0, y, 90)
    place_edge(jin, y - 7.0)
    place_edge(jout, y + 7.0)

last_row_bottom = ROW_Y0 + 7 * PITCH + 16.0
Y1 = last_row_bottom + MARGIN_BOTTOM

# ---- Trous de fixation (3,2 mm) ----------------------------------------------
place_origin("MH1", X0 + 6, Y0 + 6)
place_origin("MH2", X0 + 6, Y1 - 6)
place_origin("MH3", E - 24, Y1 - 6)
place_origin("MH4", E - 24, 112.0)

# ---- Contour de carte ----------------------------------------------------------
for d in list(board.GetDrawings()):
    if d.GetLayer() == pcbnew.Edge_Cuts:
        board.Remove(d)
rect = pcbnew.PCB_SHAPE(board)
rect.SetShape(pcbnew.SHAPE_T_RECT)
rect.SetLayer(pcbnew.Edge_Cuts)
rect.SetWidth(mm(0.05))
rect.SetStart(pcbnew.VECTOR2I(mm(X0), mm(Y0)))
rect.SetEnd(pcbnew.VECTOR2I(mm(E), mm(Y1)))
board.Add(rect)

board.Save(DST)

# ---- Suppression de toutes les pistes et vias (re-routage complet) --------------
# (fait sur le texte : board.GetTracks() n'est plus iterable avec le SWIG de
# KiCad 10.0.8 sous Windows)
import re
txt = Path(DST).read_text(encoding="utf-8")
out, i, n_removed = [], 0, 0
for m in re.finditer(r"\n\t\((?:segment|via|arc)\b", txt):
    if m.start() < i:
        continue
    depth, j = 0, m.start() + 2
    for p in range(j, len(txt)):
        if txt[p] == "(":
            depth += 1
        elif txt[p] == ")":
            depth -= 1
            if depth == 0:
                break
    out.append(txt[i:m.start()])
    i = p + 1
    n_removed += 1
out.append(txt[i:])
Path(DST).write_text("".join(out), encoding="utf-8", newline="\n")
print(f"Pistes/vias supprimees : {n_removed}")
print(f"Carte : {E - X0:.1f} x {Y1 - Y0:.1f} mm  (avant : 260 x 440 mm)")
print(f"Sauve : {DST}")
