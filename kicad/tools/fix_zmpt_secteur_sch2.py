"""Schema (suite) : les broches L/N du module ZMPT101B (U12) ne sont plus sur la
carte (cablees depuis J27 vers le bornier du module) -> marqueurs "non connecte"
a la place des etiquettes PHASE_BUS / NEUTRE_BUS ; empreinte de J27 alignee
sur la bibliotheque locale du projet."""
import re, uuid
from pathlib import Path

SCH = Path(__file__).resolve().parents[1] / "multical" / "multical.kicad_sch"
s = SCH.read_text(encoding="utf-8")

for name, y in (("PHASE_BUS", "148.59"), ("NEUTRE_BUS", "151.13")):
    pat = re.compile(r'\t\(label "' + name + r'"\s+\(at 167\.64 ' + re.escape(y) + r' 0\).*?\n\t\)\n', re.S)
    m = pat.search(s)
    assert m, name
    nc = f'\t(no_connect\n\t\t(at 167.64 {y})\n\t\t(uuid "{uuid.uuid4()}")\n\t)\n'
    s = s[:m.start()] + nc + s[m.end():]

i = s.index('(property "Reference" "J27"')
st = s.rindex("\n\t(symbol", 0, i)
end = s.index("\n\t)\n", i)
blk = s[st:end]
blk2 = blk.replace('"TerminalBlock:TerminalBlock_MaiXu_MX126-5.0-02P_1x02_P5.00mm"',
                   '"multical_local:TerminalBlock_MaiXu_MX126-5.0-02P_1x02_P5.00mm"', 1)
s = s[:st] + blk2 + s[end:]
SCH.write_text(s, encoding="utf-8", newline="\n")
print("U12 L/N : non connecte ; J27 : multical_local")
