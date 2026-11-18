import pcbnew

from pathlib import Path
# Chemins relatifs au depot : fonctionne sous Linux comme sous Windows
MULTICAL = Path(__file__).resolve().parents[1] / "multical"
PCB = str(MULTICAL / "multical.kicad_pcb")
DSN = str(MULTICAL / "multical_v3.dsn")

b = pcbnew.LoadBoard(PCB)
ok = pcbnew.ExportSpecctraDSN(b, DSN)
print("Export DSN:", "OK" if ok else "ECHEC")
