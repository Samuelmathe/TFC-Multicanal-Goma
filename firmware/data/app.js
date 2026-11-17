async function fetchEtat() {
  const res = await fetch("/api/etat");
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

// Page d'accueil : remplace "Canal N" par le nom reel du locataire quand le
// bailleur l'a renseigne (cf. nom_affiche), pour que chacun reconnaisse son
// propre bouton au lieu de devoir se souvenir d'un numero de canal.
async function remplirListeCanaux() {
  const statut = document.getElementById("statutAccueil");
  try {
    const data = await fetchEtat();
    data.canaux.forEach((c) => {
      if (c.canal === 0) return; // bailleur : deja via "Acces administrateur"
      const lien = document.querySelector(`#listeCanaux a[href="/L${c.canal}"]`);
      if (lien && c.nom_affiche) {
        lien.textContent = c.nom_affiche;
      }
    });
    if (statut) {
      const alimentes = data.canaux.filter((c) => c.relais_ferme).length;
      statut.textContent =
        `Systeme en ligne · ${data.tension_secteur_V.toFixed(0)} V · ` +
        `${alimentes}/${data.canaux.length} canaux alimentes`;
      statut.className = "statut-accueil en-ligne";
    }
  } catch (err) {
    // Page d'accueil statique : si l'ESP32 ne repond pas encore, les
    // libelles generiques "Canal N" restent affiches, ce qui reste utilisable.
    if (statut) {
      statut.textContent = "Systeme injoignable pour le moment";
      statut.className = "statut-accueil hors-ligne";
    }
  }
}

// Bandeau "connexion perdue" partage par les deux pages (admin/locataire) :
// cree une seule fois, affiche/masque selon le resultat du dernier fetch.
// Les echecs intermittents (page juste chargee, coupure Wi-Fi passagere) ne
// doivent pas effacer les dernieres valeurs affichees, juste prevenir qu'elles
// ne sont plus a jour.
function afficherEtatConnexion(connecte) {
  let bandeau = document.getElementById("bandeauConnexion");
  if (connecte) {
    if (bandeau) bandeau.remove();
    return;
  }
  if (bandeau) return;
  bandeau = document.createElement("div");
  bandeau.id = "bandeauConnexion";
  bandeau.className = "bandeau-erreur";
  bandeau.innerHTML =
    "Connexion au systeme perdue &mdash; les valeurs affichees datent du dernier rafraichissement reussi.";
  document.querySelector("main").prepend(bandeau);
}

// Jauge semi-circulaire de puissance instantanee. Echelle fixee a 4400 W
// (20 A x 220 V, la plage reelle du capteur ACS712 20A - cf. rapport S1.3.1),
// pas une valeur arbitraire : la jauge reste correcte meme si l'usage reel
// observe reste bien en dessous la plupart du temps.
const JAUGE_PUISSANCE_MAX_W = 4400;
const JAUGE_LONGUEUR = 251.3; // perimetre du demi-cercle (pi * rayon 80)

function mettreAJourJauge(puissanceW) {
  const arc = document.querySelector("#jaugePuissance .jauge-valeur");
  if (!arc) return;
  const ratio = Math.max(0, Math.min(1, puissanceW / JAUGE_PUISSANCE_MAX_W));
  arc.style.strokeDashoffset = (JAUGE_LONGUEUR * (1 - ratio)).toFixed(1);
}

function ligneCanal(c) {
  const etat = c.relais_ferme
    ? '<span class="badge ferme">ALIMENTE</span>'
    : '<span class="badge ouvert">COUPE</span>';
  return `<tr>
    <td data-label="Canal">${c.canal} (${c.role})</td>
    <td data-label="Courant (A)">${c.courant_A.toFixed(3)}</td>
    <td data-label="Puissance (W)">${c.puissance_W.toFixed(2)}</td>
    <td data-label="Energie (kWh)">${c.energie_kWh.toFixed(5)}</td>
    <td data-label="Credit (USD)">${c.credit_USD.toFixed(4)}</td>
    <td data-label="Etat">${etat}</td>
    <td data-label="Dernier evenement">${c.dernier_evenement}</td>
  </tr>`;
}

async function rafraichirAdmin() {
  try {
    const data = await fetchEtat();
    const corps = document.getElementById("corpsTable");
    corps.innerHTML = data.canaux.map(ligneCanal).join("");
    document.getElementById("tensionSecteur").textContent = data.tension_secteur_V.toFixed(1);
    document.getElementById("tarif").textContent = data.tarif_usd_par_kwh.toFixed(2);

    const select = document.getElementById("selectCanal");
    if (select && select.options.length !== data.canaux.length) {
      select.innerHTML = data.canaux
        .map((c) => `<option value="${c.canal}">Canal ${c.canal} (${c.role})</option>`)
        .join("");
    }
    afficherEtatConnexion(true);
  } catch (err) {
    afficherEtatConnexion(false);
  }
}

async function rafraichirLocataire() {
  const idx = parseInt(window.location.pathname.replace("/L", ""), 10);
  try {
    const data = await fetchEtat();
    const c = data.canaux.find((x) => x.canal === idx);
    if (!c) return;
    document.getElementById("titreCanal").textContent = `Canal ${c.canal} (${c.role})`;
    document.getElementById("credit").textContent = c.credit_USD.toFixed(4);
    document.getElementById("puissance").textContent = c.puissance_W.toFixed(2);
    document.getElementById("energie").textContent = c.energie_kWh.toFixed(5);
    mettreAJourJauge(c.puissance_W);
    const badge = document.getElementById("statut");
    badge.textContent = c.relais_ferme ? "ALIMENTE" : "COUPE";
    badge.className = "statut-grand " + (c.relais_ferme ? "ferme" : "ouvert");
    afficherEtatConnexion(true);
  } catch (err) {
    afficherEtatConnexion(false);
  }
}

async function envoyerRecharge(ev) {
  ev.preventDefault();
  const bouton = ev.target.querySelector("button[type=submit]");
  const canal = document.getElementById("selectCanal").value;
  const montant = document.getElementById("montant").value;
  bouton.disabled = true;
  const libelleOriginal = bouton.textContent;
  bouton.textContent = "Recharge en cours...";
  try {
    const res = await fetch(`/api/recharge?canal=${canal}&montant=${montant}`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    document.getElementById("montant").value = "";
    await rafraichirAdmin();
  } catch (err) {
    afficherEtatConnexion(false);
  } finally {
    bouton.disabled = false;
    bouton.textContent = libelleOriginal;
  }
}
