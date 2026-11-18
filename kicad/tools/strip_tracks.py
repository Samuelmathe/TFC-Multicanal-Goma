import pcbnew

from pathlib import Path
# Chemins relatifs au depot : fonctionne sous Linux comme sous Windows
MULTICAL = Path(__file__).resolve().parents[1] / "multical"
PCB = str(MULTICAL / "multical.kicad_pcb")

b = pcbnew.LoadBoard(PCB)
tracks = list(b.GetTracks())
print("removing", len(tracks), "tracks/vias")
for t in tracks:
    b.Remove(t)
b.Save(PCB)
print("SAVED")
