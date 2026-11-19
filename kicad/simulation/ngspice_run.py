"""Lance un netlist ngspice via la bibliotheque partagee livree avec KiCad
(ngspice.dll), sans interface graphique.

Usage : python ngspice_run.py <netlist.cir> [dossier_kicad_bin]
Le netlist doit contenir un bloc .control qui ecrit ses resultats (wrdata).
"""
import ctypes, os, sys
from pathlib import Path

KICAD_BIN = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(r"C:\Users\User\Tools\KiCad\bin")
os.add_dll_directory(str(KICAD_BIN))
ng = ctypes.CDLL(str(KICAD_BIN / "ngspice.dll"))

OUT = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_void_p)
EXIT = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_int, ctypes.c_bool, ctypes.c_bool, ctypes.c_int, ctypes.c_void_p)
errors = []


@OUT
def on_output(msg, _id, _user):
    s = msg.decode(errors="replace")
    if "rror" in s:
        errors.append(s)
    print(s)
    return 0


@EXIT
def on_exit(*_):
    return 0


ng.ngSpice_Init(on_output, None, on_exit, None, None, None, None)
netlist = Path(sys.argv[1]).resolve()
os.chdir(netlist.parent)                      # .include relatifs + fichiers wrdata
ng.ngSpice_Command(f"source {netlist.name}".encode())
sys.exit(1 if errors else 0)
