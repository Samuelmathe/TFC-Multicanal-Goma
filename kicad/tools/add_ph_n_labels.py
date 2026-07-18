import uuid

FILE = "/home/samuel/Documents/TFC-Multicanal-Goma/kicad/multical/multical.kicad_pcb"

with open(FILE, encoding="utf-8") as f:
    content = f.read()

def gr_text(text, x, y):
    return (
        f'\t(gr_text "{text}"\n'
        f'\t\t(at {x:.2f} {y:.2f} 0)\n'
        '\t\t(layer "F.SilkS")\n'
        f'\t\t(uuid "{uuid.uuid4()}")\n'
        '\t\t(effects\n'
        '\t\t\t(font\n'
        '\t\t\t\t(size 1 1)\n'
        '\t\t\t\t(thickness 0.15)\n'
        '\t\t\t)\n'
        '\t\t)\n'
        '\t)\n'
    )

# Bornier: (ref, x instance, y instance) ; pin1 (PH) = (x,y) ; pin2 (N) = (x,y+5)
borniers = {
    "J10": (209.5, 23),
    "J11": (209, 124),
    "J12": (209, 147.5),
    "J13": (209.5, 173.5),
    "J14": (209, 197.5),
    "J15": (209, 222.5),
    "J16": (210, 244),
    "J17": (210, 271),
    "J18": (210, 294),
}

items = []
for ref, (x, y) in borniers.items():
    items.append(gr_text("PH", x - 6, y))
    items.append(gr_text("N", x - 5, y + 5))

marker = "\t(embedded_fonts no)\n)"
assert content.count(marker) == 1
block = "\n" + "".join(items)
content = content.replace(marker, block + marker)

with open(FILE, "w", encoding="utf-8") as f:
    f.write(content)

print(f"OK: {len(items)} labels PH/N ajoutes ({len(borniers)} borniers)")
