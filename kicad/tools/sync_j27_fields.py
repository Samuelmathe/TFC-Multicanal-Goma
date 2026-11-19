"""Recopie dans l'empreinte J27 du PCB les champs du symbole (Description, Sim.*)
pour que la verification de parite schema/PCB ne signale pas d'ecart."""
import re
from pathlib import Path

M = Path(__file__).resolve().parents[1] / "multical"
sch = (M / "multical.kicad_sch").read_text(encoding="utf-8")
pcb_path = M / "multical.kicad_pcb"
pcb = pcb_path.read_text(encoding="utf-8")

i = sch.index('(property "Reference" "J27"')
st = sch.rindex("\n\t(symbol", 0, i)
end = sch.index("\n\t)\n", i)
fields = dict(re.findall(r'\(property "((?:Description|Sim\.[^"]+))" "([^"]*)"', sch[st:end]))

i = pcb.index('(property "Reference" "J27"')
st = pcb.rindex("\n\t(footprint", 0, i)
blk_end = pcb.index("\n\t)\n", i)
blk = pcb[st:blk_end]
m = re.search(r'\t\t\(property "Datasheet" "[^"]*".*?\n\t\t\)\n', blk, re.S)
tmpl = m.group(0)
for name, val in fields.items():
    if f'(property "{name}"' in blk:
        blk = re.sub(r'(\(property "' + re.escape(name) + r'" )"[^"]*"', lambda mm: mm.group(1) + f'"{val}"', blk, count=1)
    else:
        new = re.sub(r'\(property "Datasheet" "[^"]*"', f'(property "{name}" "{val}"', tmpl, count=1)
        new = re.sub(r'\(uuid "[^"]+"\)', "", new)
        if "(hide yes)" not in new:
            new = new.replace("\t\t\t(layer", "\t\t\t(hide yes)\n\t\t\t(layer", 1)
        blk = blk.replace(tmpl, tmpl + new, 1)
pcb = pcb[:st] + blk + pcb[blk_end:]
pcb_path.write_text(pcb, encoding="utf-8", newline="\n")
print("champs J27 :", ", ".join(fields))
