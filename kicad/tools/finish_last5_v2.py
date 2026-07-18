import uuid

FILE = "/home/samuel/Documents/TFC-Multicanal-Goma/kicad/multical/multical.kicad_pcb"

with open(FILE, encoding="utf-8") as f:
    content = f.read()

def seg(x1, y1, x2, y2, width, layer, net):
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

def via(x, y, size, drill, net):
    return (
        '\t(via\n'
        f'\t\t(at {x:.4f} {y:.4f})\n'
        f'\t\t(size {size})\n'
        f'\t\t(drill {drill})\n'
        '\t\t(layers "F.Cu" "B.Cu")\n'
        f'\t\t(net "{net}")\n'
        f'\t\t(uuid "{uuid.uuid4()}")\n'
        '\t)\n'
    )

items = []

# --- CANAL1_OUT : U6 (SMD, pitch 1.27mm -> taper fin) -> via -> B.Cu large -> J11 ---
# x=133 choisi pour eviter la diagonale GPIO36 (B.Cu, se termine a x=130.97)
items.append(seg(127.525, 124.635, 127.525, 125.905, 0.3, "F.Cu", "/CANAL1_OUT"))  # pin3-pin4
items.append(seg(127.525, 125.905, 133.0, 128.0, 0.3, "F.Cu", "/CANAL1_OUT"))       # taper vers via
items.append(via(133.0, 128.0, 0.6, 0.3, "/CANAL1_OUT"))
items.append(seg(133.0, 128.0, 133.0, 110.0, 2.5, "B.Cu", "/CANAL1_OUT"))
items.append(seg(133.0, 110.0, 205.0, 110.0, 2.5, "B.Cu", "/CANAL1_OUT"))
items.append(seg(205.0, 110.0, 205.0, 124.0, 2.5, "B.Cu", "/CANAL1_OUT"))
items.append(seg(205.0, 124.0, 209.0, 124.0, 2.5, "B.Cu", "/CANAL1_OUT"))

# --- CANAL3_OUT : bout de piste existant (B.Cu) -> via -> F.Cu -> U8 pin3/pin4 (SMD F.Cu uniquement) ---
items.append(via(122.9657, 174.4434, 0.6, 0.3, "/CANAL3_OUT"))
items.append(seg(122.9657, 174.4434, 126.0, 174.135, 0.3, "F.Cu", "/CANAL3_OUT"))
items.append(seg(126.0, 174.135, 127.525, 174.135, 0.3, "F.Cu", "/CANAL3_OUT"))
items.append(seg(127.525, 174.135, 127.525, 175.405, 0.3, "F.Cu", "/CANAL3_OUT"))

# --- NEUTRE_BUS : U12 pin2 -> fin (evite pin1 a 2.54mm) -> bus existant pres du HLK ---
items.append(seg(20.0, 47.54, 24.0, 47.54, 0.3, "F.Cu", "/NEUTRE_BUS"))   # sort horizontalement, loin de pin1 (au-dessus)
items.append(seg(24.0, 47.54, 24.0, 20.0, 0.3, "F.Cu", "/NEUTRE_BUS"))
items.append(seg(24.0, 20.0, 155.0, 20.0, 0.3, "F.Cu", "/NEUTRE_BUS"))
items.append(seg(155.0, 20.0, 155.0, 40.0, 0.3, "F.Cu", "/NEUTRE_BUS"))
items.append(seg(155.0, 40.0, 165.0, 40.0, 0.3, "F.Cu", "/NEUTRE_BUS"))

marker = "\t(embedded_fonts no)\n)"
assert content.count(marker) == 1
block = "\n" + "".join(items)
content = content.replace(marker, block + marker)

with open(FILE, "w", encoding="utf-8") as f:
    f.write(content)

print(f"OK: {len(items)} elements ajoutes")
