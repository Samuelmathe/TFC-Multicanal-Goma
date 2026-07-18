import uuid

FILE = "/home/samuel/Documents/TFC-Multicanal-Goma/kicad/multical/multical.kicad_pcb"

with open(FILE, encoding="utf-8") as f:
    content = f.read()

def make_segment(x1, y1, x2, y2, width, layer, net):
    return (
        '\t(segment\n'
        f'\t\t(start {x1:.4f} {y1:.4f})\n'
        f'\t\t(end {x2:.4f} {y2:.4f})\n'
        f'\t\t(width {width})\n'
        f'\t\t(layer "{layer}")\n'
        f'\t\t(net "{net}")\n'
        f'\t\t(uuid "{uuid.uuid4()}")\n'
        '\t)\n'
    )

segments = []

# --- CANAL1_OUT : U6 (pin3 127.525,124.635 / pin4 127.525,125.905) -> J11 (209,124) ---
# detour vertical/horizontal pour eviter D1 (155,124) et K5 (178-192,124-136)
segments.append(make_segment(127.525, 124.635, 127.525, 125.905, 2.5, "F.Cu", "/CANAL1_OUT"))  # relie pin3-pin4
segments.append(make_segment(127.525, 125.905, 127.525, 140, 2.5, "F.Cu", "/CANAL1_OUT"))
segments.append(make_segment(127.525, 140, 205, 140, 2.5, "F.Cu", "/CANAL1_OUT"))
segments.append(make_segment(205, 140, 205, 124, 2.5, "F.Cu", "/CANAL1_OUT"))
segments.append(make_segment(205, 124, 209, 124, 2.5, "F.Cu", "/CANAL1_OUT"))

# --- CANAL3_OUT : bout de piste existant (122.9657,174.4434) -> U8 pin3/pin4 ---
segments.append(make_segment(122.9657, 174.4434, 127.525, 174.135, 2.5, "B.Cu", "/CANAL3_OUT"))
segments.append(make_segment(127.525, 174.135, 127.525, 175.405, 2.5, "B.Cu", "/CANAL3_OUT"))

# --- NEUTRE_BUS : U12 pin2 (20,47.54) -> bout de piste existant pres du HLK (165,40) ---
# chemin par le haut de la carte pour eviter ESP32/U13/U14
segments.append(make_segment(20, 47.54, 20, 20, 1.0, "F.Cu", "/NEUTRE_BUS"))
segments.append(make_segment(20, 20, 155, 20, 1.0, "F.Cu", "/NEUTRE_BUS"))
segments.append(make_segment(155, 20, 155, 40, 1.0, "F.Cu", "/NEUTRE_BUS"))
segments.append(make_segment(155, 40, 165, 40, 1.0, "F.Cu", "/NEUTRE_BUS"))

marker = "\t(embedded_fonts no)\n)"
assert content.count(marker) == 1
block = "\n" + "".join(segments)
content = content.replace(marker, block + marker)

with open(FILE, "w", encoding="utf-8") as f:
    f.write(content)

print(f"OK: {len(segments)} segments ajoutes")
