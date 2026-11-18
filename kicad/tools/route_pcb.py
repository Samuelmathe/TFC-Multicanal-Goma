"""Export Specctra DSN -> Freerouting (sans interface) -> import SES -> sauvegarde.

Usage (Python de KiCad) :
  "C:\\Program Files\\KiCad\\10.0\\bin\\python.exe" route_pcb.py <freerouting.jar> [java.exe] [passes]
"""
import subprocess, sys
from pathlib import Path
import pcbnew

MULTICAL = Path(__file__).resolve().parents[1] / "multical"
PCB = MULTICAL / "multical.kicad_pcb"
DSN = MULTICAL / "multical_compact.dsn"
SES = MULTICAL / "multical_compact.ses"

jar = sys.argv[1]
java = sys.argv[2] if len(sys.argv) > 2 else "java"
passes = sys.argv[3] if len(sys.argv) > 3 else "100"

board = pcbnew.LoadBoard(str(PCB))
assert pcbnew.ExportSpecctraDSN(board, str(DSN)), "export DSN echoue"
print("DSN exporte :", DSN)

if jar == "--import-only":
    print("Import seul du .ses existant :", SES)
else:
    if SES.exists():
        SES.unlink()
    cmd = [java, "-jar", jar, "-de", str(DSN), "-do", str(SES), "-mp", passes,
           "--gui.enabled=false"]
    print(" ".join(cmd), flush=True)
    subprocess.run(cmd, check=False)
assert SES.exists(), "Freerouting n'a pas produit de fichier .ses"

board = pcbnew.LoadBoard(str(PCB))
assert pcbnew.ImportSpecctraSES(board, str(SES)), "import SES echoue"
board.Save(str(PCB))
print("Routage importe et sauve :", PCB)
