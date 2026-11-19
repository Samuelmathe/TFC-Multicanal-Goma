"""Ajoute au schema les ponts diviseurs 10 k / 12 k entre les sorties des
capteurs (alimentes en 5 V) et les entrees ADC de l'ESP32.

Pour chaque capteur : l'etiquette posee sur sa broche de sortie (GPIOxx) est
renommee ACSn_VOUT (ou ZMPT_VOUT) ; deux resistances sont ajoutees dans le bas
de la feuille, reliees par etiquettes :
    ACSn_VOUT --[10k]-- GPIOxx --[12k]-- GND
Rapport 12/22 : 0,5-4,5 V -> 0,27-2,45 V (plage utile de l'ADC a 12 dB).
"""
import re, uuid
from pathlib import Path

SCH = Path(__file__).resolve().parents[1] / "multical" / "multical.kicad_sch"
ROOT_UUID = "58486ab8-8a77-40bd-879b-8044d35a44e6"
FOOTPRINT = "Resistor_SMD:R_0805_2012Metric"

# (capteur, etiquette actuelle sur la broche de sortie (x, y), nouveau nom)
SENSORS = [
    ("U6", "GPIO36", (58.42, 50.8), "ACS1_VOUT"),
    ("U7", "GPIO26", (57.15, 76.2), "ACS2_VOUT"),
    ("U8", "GPIO27", (59.69, 96.52), "ACS3_VOUT"),
    ("U9", "GPIO39", (62.23, 116.84), "ACS4_VOUT"),
    ("U2", "GPIO32", (101.6, 49.53), "ACS5_VOUT"),
    ("U3", "GPIO33", (101.6, 72.39), "ACS6_VOUT"),
    ("U4", "GPIO34", (101.6, 95.25), "ACS7_VOUT"),
    ("U5", "GPIO35", (101.6, 118.11), "ACS8_VOUT"),
    ("U12", "GPIO25", (185.42, 149.86), "ZMPT_VOUT"),
]

s = SCH.read_text(encoding="utf-8")
assert "ACS1_VOUT" not in s, "deja applique"
u = lambda: str(uuid.uuid4())


def fmt(v):
    return f"{v:.2f}".rstrip("0").rstrip(".")


# 1) renommage des etiquettes cote capteur
for ref, old, (x, y), new in SENSORS:
    pat = re.compile(r'\(label "' + old + r'"\s+\(at ' + re.escape(fmt(x)) + r" " + re.escape(fmt(y)) + r" ")
    m = pat.search(s)
    assert m, (ref, old, x, y)
    s = s[:m.start()] + f'(label "{new}"\n\t\t(at {fmt(x)} {fmt(y)} ' + s[m.end():]


def label(name, x, y, angle=0):
    return (f'\t(label "{name}"\n\t\t(at {fmt(x)} {fmt(y)} {angle})\n\t\t(effects\n\t\t\t(font\n\t\t\t\t(size 1.27 1.27)\n'
            f'\t\t\t)\n\t\t\t(justify left)\n\t\t)\n\t\t(uuid "{u()}")\n\t)\n')


def prop(name, value, x, y, hide=False, angle=0, justify=True):
    return (f'\t\t(property "{name}" "{value}"\n\t\t\t(at {fmt(x)} {fmt(y)} {angle})\n'
            + ("\t\t\t(hide yes)\n" if hide else "")
            + '\t\t\t(show_name no)\n\t\t\t(do_not_autoplace no)\n\t\t\t(effects\n\t\t\t\t(font\n\t\t\t\t\t(size 1.27 1.27)\n\t\t\t\t)\n'
            + ("\t\t\t\t(justify left)\n" if justify else "") + "\t\t\t)\n\t\t)\n")


def resistor(ref, value, x, y):
    return ("\t(symbol\n\t\t(lib_id \"Device:R\")\n" f"\t\t(at {fmt(x)} {fmt(y)} 0)\n"
            "\t\t(unit 1)\n\t\t(body_style 1)\n\t\t(exclude_from_sim no)\n\t\t(in_bom yes)\n\t\t(on_board yes)\n"
            "\t\t(in_pos_files yes)\n\t\t(dnp no)\n\t\t(fields_autoplaced yes)\n" f"\t\t(uuid \"{u()}\")\n"
            + prop("Reference", ref, x + 2.54, y - 1.27)
            + prop("Value", value, x + 2.54, y + 1.27)
            + prop("Footprint", FOOTPRINT, x - 1.778, y, hide=True, angle=90, justify=False)
            + prop("Datasheet", "", x, y, hide=True, justify=False)
            + prop("Description", "Resistor", x, y, hide=True, justify=False)
            + f'\t\t(pin "2"\n\t\t\t(uuid "{u()}")\n\t\t)\n\t\t(pin "1"\n\t\t\t(uuid "{u()}")\n\t\t)\n'
            f'\t\t(instances\n\t\t\t(project "multical"\n\t\t\t\t(path "/{ROOT_UUID}"\n\t\t\t\t\t(reference "{ref}")\n'
            "\t\t\t\t\t(unit 1)\n\t\t\t\t)\n\t\t\t)\n\t\t)\n\t)\n")


# 2) resistances + etiquettes dans le bas de la feuille (y 172-196 mm)
blocks = []
X0, DX = 25.4, 19.05
Y_TOP, Y_BOT = 177.8, 189.23            # centres des deux resistances
n = 6
for k, (ref, gpio, _, vout) in enumerate(SENSORS):
    x = X0 + k * DX
    rt, rb = f"R{n}", f"R{n + 1}"
    n += 2
    blocks.append(resistor(rt, "10k", x, Y_TOP))
    blocks.append(resistor(rb, "12k", x, Y_BOT))
    blocks.append(label(vout, x, Y_TOP - 3.81))
    blocks.append(label(gpio, x, Y_TOP + 3.81))
    blocks.append(label(gpio, x, Y_BOT - 3.81))
    blocks.append(label("GND", x, Y_BOT + 3.81))
note = (f'\t(text "Ponts diviseurs 10k / 12k : sorties des capteurs (alimentes en 5 V, 0,5-4,5 V)\\n'
        f'ramenees a 0,27-2,45 V pour les entrees ADC de l\'ESP32 (attenuation 12 dB)"\n'
        f"\t\t(exclude_from_sim no)\n\t\t(at {fmt(X0 - 2.54)} 168.91 0)\n\t\t(effects\n\t\t\t(font\n\t\t\t\t(size 1.27 1.27)\n"
        f"\t\t\t)\n\t\t\t(justify left)\n\t\t)\n\t\t(uuid \"{u()}\")\n\t)\n")
marker = "\t(sheet_instances"
assert s.count(marker) == 1
s = s.replace(marker, "".join(blocks) + note + marker)
SCH.write_text(s, encoding="utf-8", newline="\n")
print(f"{len(SENSORS)} ponts diviseurs ajoutes (R6 a R{n - 1})")
