"""Dessin de principe : chemin de puissance d'un canal par barres de cuivre."""
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Rectangle, Circle

OUT = Path(__file__).resolve().parent / "figures"
OUT.mkdir(exist_ok=True)
CU, CU_E = "#c8732a", "#7a3e0e"          # cuivre
PCB, PCB_E = "#2f6b3a", "#1d4425"
BT = "#d9e6f5"

fig = plt.figure(figsize=(7.2, 6.4), dpi=150)
ax = fig.add_axes([0.02, 0.36, 0.96, 0.62])
ax.set_xlim(0, 160); ax.set_ylim(0, 80); ax.set_aspect("equal"); ax.axis("off")


def box(x, y, w, h, fc, ec, label, fs=8, tc="black"):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.4", fc=fc, ec=ec, lw=1.2))
    ax.text(x + w / 2, y + h / 2, label, ha="center", va="center", fontsize=fs, color=tc)


def pad(x, y, r=1.8):
    ax.add_patch(Circle((x, y), r, fc="#e0c060", ec="#8a6d10", lw=1, zorder=4))


def bar(pts, label=None, lx=None, ly=None):
    xs, ys = zip(*pts)
    ax.plot(xs, ys, color=CU_E, lw=9, solid_capstyle="round", zorder=5)
    ax.plot(xs, ys, color=CU, lw=7, solid_capstyle="round", zorder=6)
    if label:
        ax.text(lx, ly, label, fontsize=7.5, color=CU_E, ha="center", va="center",
                bbox=dict(fc="white", ec="none", alpha=0.85, pad=0.5), zorder=7)


# carte et zones
ax.add_patch(Rectangle((2, 4), 154, 72, fc=PCB, ec=PCB_E, lw=1.5))
ax.add_patch(Rectangle((4, 6), 44, 68, fc=BT, ec="#7a9cc6", lw=1, ls="--"))
ax.text(26, 70, "Zone basse tension\n(ESP32, ULN2003A, 5 V / 3,3 V)", ha="center", va="top", fontsize=7.5)
ax.plot([52, 52], [6, 74], color="white", lw=1, ls=(0, (4, 3)))
ax.text(53.5, 72, "≥ 3 mm d'isolement dans l'air", color="white", fontsize=7, va="top")

# composants
box(60, 28, 22, 24, "#e9e9e9", "#555", "ACS712\n(IP+ / IP−)", 8)
box(92, 22, 30, 36, "#4fc3f7", "#0277bd", "Relais\nSLA 30 A", 9)
box(138, 50, 14, 14, "#f2f2f2", "#555", "", 7.5); ax.text(145, 67, "Bornier IN", ha="center", fontsize=7.5, color="white")
box(138, 16, 14, 14, "#f2f2f2", "#555", "", 7.5); ax.text(145, 33, "Bornier OUT", ha="center", fontsize=7.5, color="white")

# signaux BT (fins)
ax.plot([48, 60], [36, 36], color="#1f5fbf", lw=1.2); ax.text(54, 37.5, "VIOUT", fontsize=6.5, ha="center", color="white")
ax.plot([48, 92], [16, 16, 16][:2] if False else [14, 14], color="#1f5fbf", lw=1.2)
ax.plot([92, 96], [14, 22], color="#1f5fbf", lw=1.2); ax.text(104, 16, "commande bobine (REL_DRV)", fontsize=6.5, ha="center", color="white")

# points d'accueil traversants (pastilles a trou, soudure de la barre)
P_IN, P_COM, P_NO = (145, 57), (118, 48), (118, 32)
P_ACSp, P_ACSm, P_OUT = (71, 55), (71, 25), (145, 23)
for p in (P_IN, P_COM, P_NO, P_ACSp, P_ACSm, P_OUT):
    pad(*p)

bar([P_IN, (132, 57), (132, 48), P_COM], "barre 1", 128, 53)
bar([P_NO, (88, 32), (88, 60), (71, 60), P_ACSp], "barre 2", 88, 65)
bar([P_ACSm, (71, 9), (132, 9), (132, 23), P_OUT], "barre 3", 102, 9)

ax.annotate("cuivre PCB court et large\n(plan 2 oz, vias de couture)", xy=(71, 40), xytext=(20, 40),
            fontsize=7, ha="center", arrowprops=dict(arrowstyle="->", color="black", lw=0.8),
            bbox=dict(fc="white", ec="#999", pad=2))
ax.text(80, 78, "Vue de dessus d'un canal (schéma de principe, échelle libre)", ha="center", fontsize=9, weight="bold")

# --- coupe ---------------------------------------------------------------------
bx = fig.add_axes([0.06, 0.03, 0.88, 0.30])
bx.set_xlim(0, 120); bx.set_ylim(-6, 22); bx.set_aspect("equal"); bx.axis("off")
bx.add_patch(Rectangle((0, 0), 120, 1.6, fc=PCB, ec=PCB_E))
bx.add_patch(Rectangle((0, 1.6), 120, 0.07 * 4, fc="#d4a017", ec="none"))
for x in (20, 100):
    bx.add_patch(Rectangle((x - 1.25, -2.5), 2.5, 4.4 + 8, fc=CU, ec=CU_E))   # patte de la barre dans le trou
    bx.add_patch(Rectangle((x - 3, 1.6), 6, 1.2, fc="#bdbdbd", ec="#777"))   # brasure
bx.add_patch(Rectangle((18.75, 9.9), 82.5, 3, fc=CU, ec=CU_E))
bx.add_patch(Rectangle((45, 1.9), 14, 5, fc="#e9e9e9", ec="#555"))
bx.text(52, 4.4, "composant", ha="center", va="center", fontsize=6.5)
bx.text(60, 15.5, "barre de cuivre étamé 6 x 1 mm (6 mm², ≈ 36 A à l'air libre), pliée en U", ha="center", fontsize=7.5, color=CU_E)
bx.text(60, -5, "PCB 1,6 mm, cuivre 2 oz ; pattes de 2 mm soudées dans des trous Ø 2,5 mm", ha="center", fontsize=7.5)
bx.annotate("≈ 8 mm au-dessus de la carte", xy=(108, 11.4), xytext=(108, 18), fontsize=7, ha="center",
            arrowprops=dict(arrowstyle="->", lw=0.8))
bx.text(60, 20.8, "Coupe : fixation d'une barre", ha="center", fontsize=9, weight="bold")

fig.savefig(OUT / "fig_barres_cuivre.png")
print("ok")
