import pcbnew

from pathlib import Path
# Chemins relatifs au depot : fonctionne sous Linux comme sous Windows
MULTICAL = Path(__file__).resolve().parents[1] / "multical"
PCB = str(MULTICAL / "multical.kicad_pcb")
SES = str(MULTICAL / "multical.ses")

b = pcbnew.LoadBoard(PCB)
ok = pcbnew.ImportSpecctraSES(b, SES)
print("Import SES:", "OK" if ok else "ECHEC")
b.Save(PCB)
print("SAVED")
