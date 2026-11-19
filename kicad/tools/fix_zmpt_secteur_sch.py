"""Schema : l'entree secteur du ZMPT101B passe par un bornier dedie J27 (pas 5 mm).

U12 (module ZMPT101B) garde ses broches L/N reliees a PHASE_BUS / NEUTRE_BUS
(c'est electriquement vrai : par cable, via J27), mais son empreinte devient un
connecteur 1x04 basse tension (GND, GND, VCC, OUT) : plus aucune pastille 230 V
au pas de 2,54 mm sur la carte.
"""
import re, uuid
from pathlib import Path

SCH = Path(__file__).resolve().parents[1] / "multical" / "multical.kicad_sch"
s = SCH.read_text(encoding="utf-8")
assert '"J27"' not in s, "deja applique"
u = lambda: str(uuid.uuid4())


def block_of(ref):
    i = s.index(f'(property "Reference" "{ref}"')
    st = s.rindex("\n\t(symbol", 0, i) + 1
    d = 0
    for p in range(st, len(s)):
        if s[p] == "(":
            d += 1
        elif s[p] == ")":
            d -= 1
            if d == 0:
                return st, p + 1


# 1) empreinte de U12
a, b = block_of("U12")
blk = s[a:b]
blk2 = re.sub(r'\(property "Footprint" "[^"]*"', '(property "Footprint" "multical_local:ZMPT101B_Header_1x04"', blk, count=1)
assert blk2 != blk
s = s[:a] + blk2 + s[b:]

# 2) J27 : copie de J10 deplacee
a, b = block_of("J10")
j = s[a:b]
m = re.search(r"\(lib_id \"[^\"]+\"\)\s+\(at ([\d.]+) ([\d.]+) ", j)
x0, y0 = float(m.group(1)), float(m.group(2))
X, Y = 152.4, 149.86
dx, dy = X - x0, Y - y0
j = re.sub(r"\(at ([\-\d.]+) ([\-\d.]+)", lambda mm: f"(at {float(mm.group(1)) + dx:.2f} {float(mm.group(2)) + dy:.2f}", j)
j = re.sub(r'\(uuid "[^"]+"\)', lambda mm: f'(uuid "{u()}")', j)
j = j.replace('"J10"', '"J27"')
j = re.sub(r'\(property "Value" "[^"]*"', '(property "Value" "ZMPT_secteur"', j, count=1)

def label(name, x, y):
    return (f'\t(label "{name}"\n\t\t(at {x:.2f} {y:.2f} 0)\n\t\t(effects\n\t\t\t(font\n\t\t\t\t(size 1.27 1.27)\n'
            f'\t\t\t)\n\t\t\t(justify left)\n\t\t)\n\t\t(uuid "{u()}")\n\t)\n')

note = (f'\t(text "J27 : entree secteur du module ZMPT101B (pas 5 mm).\\nCabler J27 vers le bornier a vis L/N du module ;\\n'
        f'le connecteur U12 ne porte plus que GND / VCC / OUT."\n\t\t(exclude_from_sim no)\n\t\t(at 137.16 160.02 0)\n'
        f"\t\t(effects\n\t\t\t(font\n\t\t\t\t(size 1.27 1.27)\n\t\t\t)\n\t\t\t(justify left)\n\t\t)\n\t\t(uuid \"{u()}\")\n\t)\n")
add = "\t" + j.lstrip("\t") + "\n" + label("PHASE_BUS", X - 5.08, Y) + label("NEUTRE_BUS", X - 5.08, Y + 2.54) + note
marker = "\t(sheet_instances"
s = s.replace(marker, add + marker)
SCH.write_text(s, encoding="utf-8", newline="\n")
print("U12 -> ZMPT101B_Header_1x04 ; J27 ajoute")
