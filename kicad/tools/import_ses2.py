import pcbnew

PCB = "/home/samuel/Documents/TFC-Multicanal-Goma/kicad/multical/multical.kicad_pcb"
SES = "/home/samuel/Documents/TFC-Multicanal-Goma/kicad/multical/multical_v2.ses"

b = pcbnew.LoadBoard(PCB)
ok = pcbnew.ImportSpecctraSES(b, SES)
print("Import SES:", "OK" if ok else "ECHEC")
b.Save(PCB)
print("SAVED")
