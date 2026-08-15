import pcbnew

PCB = "/home/samuel/Documents/TFC-Multicanal-Goma/kicad/multical/multical.kicad_pcb"

b = pcbnew.LoadBoard(PCB)
tracks = list(b.GetTracks())
print("removing", len(tracks), "tracks/vias")
for t in tracks:
    b.Remove(t)
b.Save(PCB)
print("SAVED")
