import re

SRC = "/home/samuel/Documents/TFC-Multicanal-Goma/kicad/multical/multical.kicad_pcb"

with open(SRC, encoding="utf-8") as f:
    content = f.read()

positions = {}

# --- Zone BT partagee (gauche) ---
positions["U1"]  = (50, 60, None)
positions["U13"] = (85, 30, None)
positions["U14"] = (85, 60, None)
positions["U12"] = (20, 45, None)
positions["U11"] = (95, 90, None)
positions["C1"]  = (35, 85, None)
positions["C10"] = (98, 82, None)
positions["C11"] = (98, 98, None)
positions["R1"]  = (20, 100, None)
positions["R2"]  = (35, 100, None)
positions["R3"]  = (50, 100, None)
positions["R4"]  = (65, 100, None)
positions["R5"]  = (80, 100, None)

# --- HLK-PM01 rapproche du bornier secteur J10 ---
positions["U10"] = (165, 23, None)

# --- Clusters par canal, regroupes pres de leur bornier (Jx fixe, non touche) ---
canaux = {
    1: (124,   "U6", "C6", "K5", "D1"),
    2: (147.5, "U7", "C7", "K6", "D2"),
    3: (173.5, "U8", "C8", "K7", "D3"),
    4: (197.5, "U9", "C9", "K8", "D4"),
    5: (222.5, "U2", "C2", "K1", "D5"),
    6: (244,   "U3", "C3", "K2", "D6"),
    7: (271,   "U4", "C4", "K3", "D7"),
    8: (294,   "U5", "C5", "K4", "D8"),
}
for canal, (y, u, c, k, d) in canaux.items():
    positions[c] = (115, y, None)
    positions[u] = (130, y, None)
    positions[d] = (155, y, None)
    positions[k] = (180, y, None)

out = []
cursor = 0
placed = set()
start_re = re.compile(r'\t\(footprint "')

while True:
    m = start_re.search(content, cursor)
    if not m:
        out.append(content[cursor:])
        break
    open_idx = m.start() + 1
    out.append(content[cursor:open_idx])

    depth = 0
    end_idx = None
    for p in range(open_idx, len(content)):
        ch = content[p]
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                end_idx = p + 1
                break
    block = content[open_idx:end_idx]

    ref_match = re.search(r'\(property "Reference" "([^"]+)"', block)
    assert ref_match, f"bloc sans Reference pres de {open_idx}"
    ref = ref_match.group(1)

    if ref in positions:
        x, y, rot = positions[ref]
        at_pattern = re.compile(r'\(at [\-\d.]+ [\-\d.]+(?: [\-\d.]+)?\)')
        at_match = at_pattern.search(block)
        assert at_match, f"pas de (at ...) pour {ref}"
        new_at = f"(at {x:.2f} {y:.2f})" if rot is None else f"(at {x:.2f} {y:.2f} {rot})"
        block = block[:at_match.start()] + new_at + block[at_match.end():]
        placed.add(ref)

    out.append(block)
    cursor = end_idx

content = "".join(out)

missing = set(positions.keys()) - placed
print(f"replaces: {len(placed)} / {len(positions)}")
if missing:
    print("MANQUANTS:", missing)

with open(SRC, "w", encoding="utf-8") as f:
    f.write(content)
