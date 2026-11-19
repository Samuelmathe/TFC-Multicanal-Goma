"""Trace les figures du chapitre 3 a partir des fichiers .dat ecrits par ngspice."""
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

D = Path(__file__).resolve().parent
OUT = D / "figures"
OUT.mkdir(exist_ok=True)
plt.rcParams.update({"font.size": 10, "font.family": "DejaVu Sans", "axes.grid": True,
                     "grid.alpha": 0.3, "figure.dpi": 150})
BLEU, ORANGE, ROUGE, VERT = "#1f5fbf", "#e07b00", "#c62828", "#2e7d32"


def limites(ax):
    ax.axhline(3.6, color=ROUGE, ls="--", lw=1)
    ax.text(ax.get_xlim()[0], 3.65, " 3,6 V : maximum absolu GPIO ESP32", color=ROUGE, fontsize=8, va="bottom")
    ax.axhspan(0.15, 2.45, color=VERT, alpha=0.08)
    ax.text(ax.get_xlim()[0], 2.40, " plage utile ADC (atténuation 12 dB) : 0,15 - 2,45 V",
            color=VERT, fontsize=8, va="top")


# --- Figure A : transfert ACS712 ------------------------------------------------
d = np.loadtxt(D / "acs712_transfert.dat")
i, v_dir, v_div = d[:, 0], d[:, 1], d[:, 3]
m = np.abs(i) <= 20
fig, ax = plt.subplots(figsize=(6.4, 3.8))
ax.plot(i[m], v_dir[m], color=ORANGE, lw=2, label="sortie directe sur le GPIO (schéma actuel)")
ax.plot(i[m], v_div[m], color=BLEU, lw=2, label="avec pont diviseur 10 kΩ / 12 kΩ")
ax.set_xlim(-20, 20); ax.set_ylim(0, 5)
limites(ax)
ax.set_xlabel("Courant dans le conducteur primaire (A)")
ax.set_ylabel("Tension sur l'entrée ADC (V)")
ax.legend(loc="lower right", fontsize=8)
fig.tight_layout(); fig.savefig(OUT / "fig_acs712_transfert.png"); plt.close(fig)

# --- Figure B : acquisition 50 Hz -----------------------------------------------
d = np.loadtxt(D / "acquisition_ac.dat")
t = d[:, 0] * 1e3
fig, (a1, a2) = plt.subplots(2, 1, figsize=(6.4, 5.2), sharex=True)
a1.plot(t, d[:, 1], color=ORANGE, lw=1.6, label="direct")
a1.plot(t, d[:, 3], color=BLEU, lw=1.6, label="pont 10k / 12k")
a1.set_title("ACS712-20A, courant 50 Hz de 20 A crête (14,1 A efficaces)", fontsize=9)
a2.plot(t, d[:, 5], color=ORANGE, lw=1.6, label="direct")
a2.plot(t, d[:, 7], color=BLEU, lw=1.6, label="pont 10k / 12k")
a2.set_title("ZMPT101B, secteur 230 V efficaces", fontsize=9)
for a in (a1, a2):
    a.set_xlim(0, 40); a.set_ylim(0, 5); limites(a)
    a.set_ylabel("V sur le GPIO"); a.legend(loc="lower right", fontsize=8)
a2.set_xlabel("Temps (ms)")
fig.tight_layout(); fig.savefig(OUT / "fig_acquisition_ac.png"); plt.close(fig)

# --- Figure C : coupure du relais -------------------------------------------------
d = np.loadtxt(D / "relais_coupure.dat")
t = d[:, 0] * 1e3
fig, (a1, a2) = plt.subplots(1, 2, figsize=(6.6, 3.2))
a1.plot(t, d[:, 1], color=BLEU, lw=1.6, label="REL_DRV (avec diode)")
a1.plot(t, d[:, 5], color="grey", lw=1, ls=":", label="commande GPIO")
a1.set_xlim(0, 120); a1.set_ylim(-0.5, 7)
a1.set_title("Montage du PCB (diode 1N4007)", fontsize=9)
a1.set_xlabel("Temps (ms)"); a1.set_ylabel("Tension (V)")
a1.legend(loc="upper right", fontsize=7)
w = (t > 59.9) & (t < 60.6)
a2.plot(t[w], d[w, 3], color=ROUGE, lw=1.2)
a2.set_title("Sans aucune diode (référence)", fontsize=9)
a2.set_xlabel("Temps (ms)"); a2.set_ylabel("REL_DRV (V)")
fig.tight_layout(); fig.savefig(OUT / "fig_relais_coupure.png"); plt.close(fig)

print("Figures ecrites dans", OUT)
