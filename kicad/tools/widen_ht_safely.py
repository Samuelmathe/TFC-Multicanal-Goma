import re
import subprocess
import json
import shutil

FILE = "/home/samuel/Documents/TFC-Multicanal-Goma/kicad/multical/multical.kicad_pcb"
DRC_OUT = "/home/samuel/drc_widen_iter.json"

HT_NETS = ["/PHASE_BUS", "/NEUTRE_BUS"] + [
    f"/CANAL{i}_{suffix}" for i in range(1, 9) for suffix in ("HT", "OUT")
]

TARGET_WIDTH = 2.5
FALLBACK_WIDTHS = [1.5, 1.0, 0.6]

BASELINE_BAD_TYPES = {"shorting_items", "clearance", "courtyards_overlap", "solder_mask_bridge"}


def read_file():
    with open(FILE, encoding="utf-8") as f:
        return f.read()


def write_file(content):
    with open(FILE, "w", encoding="utf-8") as f:
        f.write(content)


def run_drc():
    subprocess.run(["rm", "-f", DRC_OUT])
    subprocess.run(
        ["flatpak", "run", "--command=kicad-cli", "org.kicad.KiCad",
         "pcb", "drc", "--format", "json", "-o", DRC_OUT, FILE],
        capture_output=True, text=True
    )
    with open(DRC_OUT) as f:
        d = json.load(f)
    bad_count = sum(1 for v in d.get("violations", []) if v["type"] in BASELINE_BAD_TYPES)
    return bad_count


def set_net_width(content, net_name, width):
    """Change (width X) for every segment whose net matches net_name, return new content + count."""
    pattern = re.compile(
        r'(\(segment\n\t\t\(start [^\n]+\n\t\t\(end [^\n]+\n\t\t\(width )[\d.]+(\)\n\t\t\(layer "[^"]+"\)\n\t\t\(net "'
        + re.escape(net_name) + r'"\)\n)',
    )
    new_content, n = pattern.subn(lambda m: m.group(1) + f"{width}" + m.group(2), content)
    return new_content, n


results = {}
baseline_bad = run_drc()
print(f"baseline (avant elargissement): {baseline_bad} violations problematiques")

for net in HT_NETS:
    content = read_file()
    success = False
    for w in [TARGET_WIDTH] + FALLBACK_WIDTHS:
        candidate, n = set_net_width(content, net, w)
        if n == 0:
            print(f"{net}: aucun segment/via trouve, ignore")
            success = True
            results[net] = "aucun segment"
            break
        write_file(candidate)
        bad = run_drc()
        if bad <= baseline_bad:
            print(f"{net}: OK a {w}mm ({n} elements)")
            results[net] = f"{w}mm"
            success = True
            break
        else:
            print(f"{net}: {w}mm cree {bad - baseline_bad} nouveau(x) probleme(s), on tente plus etroit")
    if not success:
        # restaurer la largeur d'origine (0.2) pour ce net si rien n'a marche
        content = read_file()
        reverted, n = set_net_width(content, net, 0.2)
        write_file(reverted)
        run_drc()
        print(f"{net}: ECHEC, laisse a 0.2mm ({n} elements) - a router manuellement")
        results[net] = "ECHEC - reste a 0.2mm"

print()
print("=== RESUME ===")
for net, res in results.items():
    print(f"{net}: {res}")
