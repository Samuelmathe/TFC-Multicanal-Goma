import pcbnew

PCB = "/home/samuel/Documents/TFC-Multicanal-Goma/kicad/multical/multical.kicad_pcb"
DSN = "/home/samuel/Documents/TFC-Multicanal-Goma/kicad/multical/multical_v3.dsn"

b = pcbnew.LoadBoard(PCB)
ok = pcbnew.ExportSpecctraDSN(b, DSN)
print("Export DSN:", "OK" if ok else "ECHEC")
