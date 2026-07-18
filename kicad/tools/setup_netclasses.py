import pcbnew

PCB = "/home/samuel/Documents/TFC-Multicanal-Goma/kicad/multical/multical.kicad_pcb"

b = pcbnew.LoadBoard(PCB)
ncs = b.GetNetClasses()

ht = pcbnew.NETCLASS("HT_20A")
ht.SetTrackWidth(pcbnew.FromMM(6.0))
ht.SetClearance(pcbnew.FromMM(1.0))
ht.SetViaDiameter(pcbnew.FromMM(3.0))
ht.SetViaDrill(pcbnew.FromMM(1.6))
ncs["HT_20A"] = ht

alim = pcbnew.NETCLASS("Alim_5V3V3")
alim.SetTrackWidth(pcbnew.FromMM(0.6))
alim.SetClearance(pcbnew.FromMM(0.2))
ncs["Alim_5V3V3"] = alim

ht_nets = ["/PHASE_BUS", "/NEUTRE_BUS"]
for i in range(1, 9):
    ht_nets.append(f"/CANAL{i}_HT")
    ht_nets.append(f"/CANAL{i}_OUT")

alim_nets = ["/P5V", "/P3V3", "/GND"]

missing = []
applied_ht = 0
applied_alim = 0
for net_name in ht_nets:
    ni = b.FindNet(net_name)
    if ni is None:
        missing.append(net_name)
        continue
    ni.SetNetClass(ht)
    applied_ht += 1

for net_name in alim_nets:
    ni = b.FindNet(net_name)
    if ni is None:
        missing.append(net_name)
        continue
    ni.SetNetClass(alim)
    applied_alim += 1

print(f"HT_20A applique a {applied_ht}/{len(ht_nets)} nets")
print(f"Alim_5V3V3 applique a {applied_alim}/{len(alim_nets)} nets")
if missing:
    print("MANQUANTS:", missing)

b.Save(PCB)
print("SAVED")
