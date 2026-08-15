import re

DSN = "/home/samuel/Documents/TFC-Multicanal-Goma/kicad/multical/multical.dsn"

with open(DSN, encoding="utf-8") as f:
    content = f.read()

canal_nets = []
for i in range(1, 9):
    canal_nets.append(f"/CANAL{i}_HT")
    canal_nets.append(f"/CANAL{i}_OUT")
bus_nets = ["/PHASE_BUS", "/NEUTRE_BUS"]
all_ht_nets = canal_nets + bus_nets

start_marker = "(class kicad_default"
start_idx = content.index(start_marker)
depth = 0
end_idx = None
for p in range(start_idx, len(content)):
    c = content[p]
    if c == "(":
        depth += 1
    elif c == ")":
        depth -= 1
        if depth == 0:
            end_idx = p + 1
            break
class_block = content[start_idx:end_idx]

removed = []
for net in all_ht_nets:
    pattern = re.compile(r'(?<![\w/])' + re.escape(net) + r'(?![\w])')
    new_block, n = pattern.subn("", class_block, count=1)
    if n == 1:
        class_block = new_block
        removed.append(net)

print(f"OK: {len(removed)}/{len(all_ht_nets)} nets retires de kicad_default")
missing = set(all_ht_nets) - set(removed)
if missing:
    print("MANQUANTS:", missing)

class_block = re.sub(r'[ \t]+', ' ', class_block)
class_block = re.sub(r' \n', '\n', class_block)

content = content[:start_idx] + class_block + content[end_idx:]

# Classe 1 : branches par canal, 20A max chacune (2oz, ~6.5mm @ IPC-2221 20C)
canal_class = (
    '\n    (class CANAL_20A ' + " ".join(canal_nets) + '\n'
    '      (circuit\n'
    '        (use_via "Via[0-1]_600:300_um")\n'
    '      )\n'
    '      (rule\n'
    '        (width 6500)\n'
    '        (clearance 3000)\n'
    '      )\n'
    '    )\n'
)

# Classe 2 : bus d'entree PHASE_BUS/NEUTRE_BUS. ATTENTION : meme a 10mm/2oz ceci ne
# supporte qu'environ 27A (IPC-2221) -- tres insuffisant si les 8 canaux tirent 20A
# simultanement (160A). Cette piste PCB n'est qu'un talon de connexion vers le
# bornier d'entree ; le vrai chemin 160A doit passer par une barre de cuivre ou un
# cable de forte section externe au PCB, en parallele de cette piste.
bus_class = (
    '\n    (class BUS_ENTREE ' + " ".join(bus_nets) + '\n'
    '      (circuit\n'
    '        (use_via "Via[0-1]_600:300_um")\n'
    '      )\n'
    '      (rule\n'
    '        (width 10000)\n'
    '        (clearance 3000)\n'
    '      )\n'
    '    )\n'
)

insert_at = content.index(start_marker)
depth = 0
end_idx2 = None
for p in range(insert_at, len(content)):
    c = content[p]
    if c == "(":
        depth += 1
    elif c == ")":
        depth -= 1
        if depth == 0:
            end_idx2 = p + 1
            break
content = content[:end_idx2] + canal_class + bus_class + content[end_idx2:]

with open(DSN, "w", encoding="utf-8") as f:
    f.write(content)

print("SAVED")
