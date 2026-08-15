async function fetchEtat() {
  const res = await fetch("/api/etat");
  return res.json();
}

function ligneCanal(c) {
  const etat = c.relais_ferme
    ? '<span class="ferme">ALIMENTE</span>'
    : '<span class="ouvert">COUPE</span>';
  return `<tr>
    <td>${c.canal} (${c.role})</td>
    <td>${c.courant_A.toFixed(3)}</td>
    <td>${c.puissance_W.toFixed(2)}</td>
    <td>${c.energie_kWh.toFixed(5)}</td>
    <td>${c.credit_USD.toFixed(4)}</td>
    <td>${etat}</td>
    <td>${c.dernier_evenement}</td>
  </tr>`;
}

async function rafraichirAdmin() {
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
}

async function rafraichirLocataire() {
  const idx = parseInt(window.location.pathname.replace("/L", ""), 10);
  const data = await fetchEtat();
  const c = data.canaux.find((x) => x.canal === idx);
  if (!c) return;
  document.getElementById("titreCanal").textContent = `Canal ${c.canal} (${c.role})`;
  document.getElementById("credit").textContent = c.credit_USD.toFixed(4);
  document.getElementById("puissance").textContent = c.puissance_W.toFixed(2);
  document.getElementById("energie").textContent = c.energie_kWh.toFixed(5);
  const badge = document.getElementById("statut");
  badge.textContent = c.relais_ferme ? "ALIMENTE" : "COUPE";
  badge.className = c.relais_ferme ? "ferme" : "ouvert";
}

async function envoyerRecharge(ev) {
  ev.preventDefault();
  const canal = document.getElementById("selectCanal").value;
  const montant = document.getElementById("montant").value;
  await fetch(`/api/recharge?canal=${canal}&montant=${montant}`);
  rafraichirAdmin();
}
