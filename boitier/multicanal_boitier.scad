// =============================================================================
// Boitier ergonomique - TFC Multicanal Goma
// PCB : kicad/multical/multical.kicad_pcb (138 x 349,5 mm, 8 canaux, 17 borniers)
//
// Vue de dessus, les borniers sont sur le bord DROIT de la carte. Le boitier a :
//   - une rampe inclinee cote borniers (lisible, tournevis accessible)
//   - un trou de tournevis au-dessus de chaque vis, avec etiquettes gravees
//   - une fente d'entree de fil dans la paroi droite, en face de chaque bornier
//   - "MULTICANAL" grave sur le couvercle
//
// PART : "assembly" (vue d'ensemble) | "base" | "lid" | "lid_print"
// Toutes les cotes sont en mm. Les positions des borniers sont en coordonnees
// KiCad : si tu deplaces un bornier dans le PCB, mets a jour le tableau
// `terminals` ci-dessous, rien d'autre.
// =============================================================================

PART    = "assembly";
explode = 0;              // ecart en Z du couvercle dans la vue "assembly"

// ---- PCB --------------------------------------------------------------------
pcb_w = 138;  pcb_l = 349.5;  pcb_t = 1.6;
kx0 = 14;                 // KiCad : x du bord gauche de la carte
ky1 = 368;                // KiCad : y du bord bas de la carte (axe Y KiCad vers le bas)
function bx(x) = x - kx0;         // repere carte : X vers la droite, Y vers le haut,
function by(y) = ky1 - y;         // meme orientation que la vue de dessus dans KiCad

// ---- Boitier ----------------------------------------------------------------
clr       = 2;            // jeu entre la carte et la paroi
wall      = 3;
floor_t   = 3;
lid_t     = 3;
standoff  = 6;            // hauteur des plots sous la carte (pattes traversantes)
comp_h    = 30;           // hauteur libre au-dessus de la carte (relais ~16, HLK ~15, ZMPT ~25)
r_out     = 8;            // rayon des coins exterieurs
term_h    = 11;           // hauteur bornier + vis au-dessus de la carte
ramp_gap  = 2;            // jeu entre le haut des vis et le dessous de la rampe
screw_d   = 7.5;          // trou de tournevis
font_b    = "Liberation Sans:style=Bold";

z_pcb_top = floor_t + standoff + pcb_t;
z_top     = z_pcb_top + comp_h + lid_t;
z_lo      = z_pcb_top + term_h + ramp_gap + lid_t;   // niveau plat de la rampe
z_split   = z_pcb_top + 12;                          // plan de joint base / couvercle
ramp_x0   = 110;          // debut de la pente (repere carte) - apres les relais et le HLK
ramp_x1   = 124;          // fin de la pente : les etiquettes sont sur la pente, les reperes P/N sur le plat
ramp_ang  = atan((z_top - z_lo) / (ramp_x1 - ramp_x0));

r_in  = r_out - wall;
in_w  = pcb_w + 2*clr;   in_l  = pcb_l + 2*clr;
out_w = in_w + 2*wall;   out_l = in_l + 2*wall;
cx = pcb_w/2;            cy = pcb_l/2;
x_out_r = cx + out_w/2;                  // face exterieure de la paroi droite

// ---- Borniers (coordonnees KiCad) --------------------------------------------
// [ref, x, y, rotation, type, canal]
//   type "SEC" : entree secteur (broche 1 = phase, broche 2 = neutre)
//   type "OUT" : sortie du canal (broche 1 = phase, broche 2 = neutre)
//   type "IN"  : entree phase du canal (seule la broche 1 est cablee)
// canal 1 = bailleur (BAI), canaux 2 a 8 = locataires LOC1 a LOC7
terminals = [
  ["J10", 146.88,  27.75, -90, "SEC", 0],
  ["J23", 146.81, 123.25,  90, "IN",  1],
  ["J11", 146.88, 132.75, -90, "OUT", 1],
  ["J24", 146.81, 153.25,  90, "IN",  2],
  ["J12", 146.88, 162.75, -90, "OUT", 2],
  ["J25", 146.81, 183.25,  90, "IN",  3],
  ["J13", 146.88, 192.75, -90, "OUT", 3],
  ["J26", 146.81, 213.25,  90, "IN",  4],
  ["J14", 146.88, 222.75, -90, "OUT", 4],
  ["J19", 146.81, 243.25,  90, "IN",  5],
  ["J15", 146.88, 252.75, -90, "OUT", 5],
  ["J20", 146.81, 273.25,  90, "IN",  6],
  ["J16", 146.81, 287.25,  90, "OUT", 6],
  ["J21", 146.81, 303.25,  90, "IN",  7],
  ["J17", 146.88, 312.75, -90, "OUT", 7],
  ["J22", 147.06, 333.25,  90, "IN",  8],
  ["J18", 146.88, 342.75, -90, "OUT", 8]
];

function ch_name(n)  = n == 1 ? "BAI" : str("LOC", n - 1);
function pin_y(t, n) = by(t[2] + (n == 1 ? 0 : (t[3] == -90 ? 5 : -5)));   // broche n (1 ou 2)
function pin_x(t)    = bx(t[1]);
function pins(t)     = t[4] == "IN" ? [1] : [1, 2];
function label(t)    = t[4] == "SEC" ? "SECTEUR" : (t[4] == "OUT" ? ch_name(t[5]) : str("IN ", ch_name(t[5])));
function pin_mark(t, n) = t[4] == "SEC" ? (n == 1 ? "PH" : "NEUTRE") : (n == 1 ? "P" : "N");
function t_yc(t)     = t[4] == "IN" ? pin_y(t, 1) : (pin_y(t, 1) + pin_y(t, 2)) / 2;

// ---- Fixations ---------------------------------------------------------------
// plots sous la carte : les 4 premiers sont les trous de fixation du PCB (M3),
// les suivants sont des appuis pleins places loin des composants.
pcb_mounts = [[bx(20), by(24.5)], [bx(128), by(112)], [bx(20), by(362)], [bx(128), by(362)]];
supports   = [[bx(20), by(200)], [bx(20), by(290)], [bx(60), by(108)], [bx(130), by(80)]];

// oreilles de fixation du couvercle (centre en repere carte)
ear_o = clr + wall + 3;
ears = [[-ear_o, 60], [-ear_o, 175], [-ear_o, 290],
        [pcb_w + ear_o, by(358)], [pcb_w + ear_o, by(75)],
        [pcb_w/2, -ear_o], [pcb_w/2, pcb_l + ear_o]];

// ---- Outils ------------------------------------------------------------------
module rr2d(w, l, r) {
  translate([cx, cy]) hull()
    for (sx = [-1, 1], sy = [-1, 1]) translate([sx*(w/2 - r), sy*(l/2 - r)]) circle(r = r, $fn = 24);
}

// boite dont le haut est arrondi (rayon r)
module rbox(w, l, z0, h, r) {
  hull() for (sx = [-1, 1], sy = [-1, 1])
    translate([cx + sx*(w/2 - r), cy + sy*(l/2 - r), z0]) {
      cylinder(r = r, h = h - r, $fn = 24);
      translate([0, 0, h - r]) sphere(r = r, $fn = 24);
    }
}

// prisme extrude le long de Y a partir d'un profil (x, z)
module xz_prism(pts, y0, y1) {
  translate([0, y1, 0]) rotate([90, 0, 0]) linear_extrude(y1 - y0) polygon(pts);
}

// volume au-dessus de la rampe (a retirer). dz = epaisseur decalee vers le bas.
module ramp_cut(dz) {
  x_end = x_out_r + 2;
  xz_prism([[ramp_x0, z_top + 5], [ramp_x0, z_top - dz], [ramp_x1, z_lo - dz],
            [x_end, z_lo - dz], [x_end, z_top + 5]], -20, pcb_l + 20);
}

// surface exterieure de la rampe
function z_surf(x) = x <= ramp_x0 ? z_top :
                     (x >= ramp_x1 ? z_lo : z_top - (x - ramp_x0)*(z_top - z_lo)/(ramp_x1 - ramp_x0));

// repere local pose sur la surface (x le long de la pente)
module on_surface(x, y) {
  translate([x, y, z_surf(x)]) rotate([0, (x >= ramp_x0 && x < ramp_x1) ? ramp_ang : 0, 0]) children();
}

module engrave(txt, size, x, y, ha = "left", depth = 0.8) {
  on_surface(x, y) translate([0, 0, -depth])
    linear_extrude(depth + 1) text(txt, size = size, halign = ha, valign = "center", font = font_b);
}

// ---- Coque -------------------------------------------------------------------
module shell() {
  difference() {
    difference() { rbox(out_w, out_l, 0, z_top, r_out); ramp_cut(0); }
    difference() { rbox(in_w, in_l, floor_t, z_top - lid_t - floor_t, r_in); ramp_cut(lid_t); }
  }
}

// fentes d'entree de fil dans la paroi droite, une par bornier
module wire_slots() {
  for (t = terminals) {
    ys = t[4] == "IN" ? [pin_y(t, 1)] : [pin_y(t, 1), pin_y(t, 2)];
    y0 = min(ys) - (t[4] == "IN" ? 3 : 5.3);
    y1 = max(ys) + (t[4] == "IN" ? 3 : 5.3);
    translate([pcb_w + clr - 1, y0, z_pcb_top + 1.5]) cube([wall + 4, y1 - y0, 8.5]);
  }
}

// trous de tournevis au-dessus de chaque vis + etiquettes sur la rampe
module terminal_marks() {
  for (t = terminals) {
    for (n = pins(t))
      translate([pin_x(t), pin_y(t, n), z_pcb_top + term_h]) cylinder(d = screw_d, h = 40, $fn = 24);
    // nom du bornier, en tete de rangee
    engrave(label(t), 3.5, 88, t_yc(t));
    // repere de chaque broche, juste avant le trou de tournevis
    for (n = pins(t))
      engrave(pin_mark(t, n), 3.2, pin_x(t) - 6, pin_y(t, n), ha = "right", depth = 0.6);
  }
}

// events au-dessus du convertisseur HLK-PM01 (KiCad : x 103, y 32)
module vents() {
  for (i = [0 : 5])
    translate([bx(103) - 11 + i*4.5, by(32) - 11, z_top - lid_t - 1]) cube([2, 22, lid_t + 2]);
}

module top_text() {
  engrave("MULTICANAL", 9, 46, 175, ha = "center", depth = 1);
  engrave("SOUS-COMPTAGE ELECTRIQUE", 3.6, 46, 160, ha = "center", depth = 0.8);
  engrave("8 CANAUX - BAILLEUR + 7 LOCATAIRES", 2.6, 46, 151, ha = "center", depth = 0.8);
}

// ---- Pieces ------------------------------------------------------------------
module post(p, hole) {
  translate([p[0], p[1], floor_t - 0.01]) difference() {
    cylinder(d = 8, h = standoff + 0.01, $fn = 24);
    if (hole) translate([0, 0, standoff - 6]) cylinder(d = 2.6, h = 7, $fn = 16);   // vis M3 (auto-taraudeuse)
  }
}

// Joint a recouvrement : le couvercle a une levre qui prend la moitie interieure
// de la paroi (epaisseur lap_t) sur lap_h de hauteur ; la base a la feuillure
// correspondante, avec un jeu lap_gap.
lap_t = 1.4;  lap_gap = 0.3;  lap_h = 4;

module base() {
  difference() {
    union() {
      intersection() {
        shell();
        translate([-50, -50, -1]) cube([out_w + 100, out_l + 100, z_split + 1]);
      }
      for (p = pcb_mounts) post(p, true);
      for (p = supports)   post(p, false);
      for (e = ears) translate([e[0], e[1], z_split - 8]) cylinder(d = 12, h = 8, $fn = 32);
    }
    wire_slots();
    // feuillure interieure
    translate([0, 0, z_split - lap_h]) linear_extrude(lap_h + 1)
      rr2d(in_w + 2*(lap_t + lap_gap), in_l + 2*(lap_t + lap_gap), r_in + lap_t + lap_gap);
    // pre-trou M3 pour la vis du couvercle
    for (e = ears) translate([e[0], e[1], z_split - 7.5]) cylinder(d = 2.6, h = 8, $fn = 16);
  }
}

module lid() {
  difference() {
    union() {
      intersection() {
        shell();
        translate([-50, -50, z_split]) cube([out_w + 100, out_l + 100, z_top + 10]);
      }
      // levre : moitie interieure de la paroi, sous le plan de joint
      translate([0, 0, z_split - lap_h]) linear_extrude(lap_h + 0.01) difference() {
        rr2d(in_w + 2*lap_t, in_l + 2*lap_t, r_in + lap_t);
        rr2d(in_w, in_l, r_in);
      }
      for (e = ears) translate([e[0], e[1], z_split]) cylinder(d = 12, h = 4, $fn = 32);
    }
    wire_slots();
    terminal_marks();
    top_text();
    vents();
    for (e = ears) translate([e[0], e[1], z_split - 1]) cylinder(d = 3.4, h = 8, $fn = 16);
  }
}

if (PART == "base")           base();
else if (PART == "lid")       lid();
else if (PART == "lid_print") translate([0, pcb_l, z_top]) rotate([180, 0, 0]) lid();
else { base(); translate([0, 0, explode]) lid(); }
