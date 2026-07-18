import re

DSN = "/home/samuel/Documents/TFC-Multicanal-Goma/kicad/multical/multical_v3.dsn"

with open(DSN, encoding="utf-8") as f:
    content = f.read()

ht_nets = ["/PHASE_BUS", "/NEUTRE_BUS", "/PHASE", "/NEUTRE"]
for i in range(1, 9):
    ht_nets.append(f"/CANAL{i}_HT")
    ht_nets.append(f"/CANAL{i}_OUT")

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
for net in ht_nets:
    pattern = re.compile(r'(?<![\w/])' + re.escape(net) + r'(?![\w])')
    new_block, n = pattern.subn("", class_block, count=1)
    if n == 1:
        class_block = new_block
        removed.append(net)

print(f"OK: {len(removed)}/{len(ht_nets)} nets retires de kicad_default")
missing = set(ht_nets) - set(removed)
if missing:
    print("MANQUANTS:", missing)

class_block = re.sub(r'[ \t]+', ' ', class_block)
class_block = re.sub(r' \n', '\n', class_block)

content = content[:start_idx] + class_block + content[end_idx:]

ht_class_block = (
    '\n    (class HT_20A ' + " ".join(ht_nets) + '\n'
    '      (circuit\n'
    '        (use_via "Via[0-1]_600:300_um")\n'
    '      )\n'
    '      (rule\n'
    '        (width 2500)\n'
    '        (clearance 800)\n'
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
content = content[:end_idx2] + ht_class_block + content[end_idx2:]

with open(DSN, "w", encoding="utf-8") as f:
    f.write(content)

print("SAVED")
