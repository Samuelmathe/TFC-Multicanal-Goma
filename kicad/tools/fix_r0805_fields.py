"""Corrige les champs des resistances 0805 ajoutees (R6-R23) pour que le PCB
corresponde au schema : nom de bibliotheque complet et champ Description."""
import re
from pathlib import Path

PCB = Path(__file__).resolve().parents[1] / "multical" / "multical.kicad_pcb"
s = PCB.read_text(encoding="utf-8")
n = 0


def fix(m):
    global n
    n += 1
    b = m.group(0).replace('(footprint "R_0805_2012Metric"', '(footprint "Resistor_SMD:R_0805_2012Metric"', 1)
    return b.replace('(property "Description" ""', '(property "Description" "Resistor"', 1)


s = re.sub(r'\n\t\(footprint "R_0805_2012Metric".*?(?=\n\t\((?:footprint|gr_|segment|via|zone|embedded))', fix, s, flags=re.S)
PCB.write_text(s, encoding="utf-8", newline="\n")
print("resistances corrigees :", n)
