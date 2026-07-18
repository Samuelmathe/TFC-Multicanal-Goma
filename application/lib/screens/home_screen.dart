import 'package:flutter/material.dart';
import 'tenant_screen.dart';
import 'admin_screen.dart';

// StatefulWidget = un ecran qui peut changer d'etat (ici : le texte tape
// dans le champ IP). Un StatelessWidget ne pourrait pas retenir cette valeur.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _baseUrlController =
      TextEditingController(text: "http://192.168.4.1");

  static const int nombreCanaux = 5; // NUM_CANAUX cote firmware (config.h)

  @override
  Widget build(BuildContext context) {
    final baseUrl = _baseUrlController.text.trim();

    return Scaffold(
      appBar: AppBar(title: const Text("TFC Multicanal - Goma")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Systeme embarque IoT multicanal - Sous-comptage energie",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _baseUrlController,
              decoration: const InputDecoration(
                labelText: "Adresse du serveur (IP de l'ESP32)",
                border: OutlineInputBorder(),
                helperText:
                    "192.168.4.1 = point d'acces Wi-Fi de l'ESP32. "
                    "Sur emulateur/PC, mets l'IP de ton serveur de test local.",
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminScreen(baseUrl: baseUrl),
                  ),
                );
              },
              child: const Text("Acces bailleur / administrateur"),
            ),
            const SizedBox(height: 16),
            const Text("Acces locataire :"),
            const SizedBox(height: 8),
            // Wrap = comme flex-wrap en CSS : les boutons passent a la
            // ligne suivante si la largeur de l'ecran ne suffit pas.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(nombreCanaux, (i) {
                return OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TenantScreen(
                          baseUrl: baseUrl,
                          canalIndex: i,
                        ),
                      ),
                    );
                  },
                  child: Text(i == 0 ? "Canal 0 (bailleur)" : "Canal $i"),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
