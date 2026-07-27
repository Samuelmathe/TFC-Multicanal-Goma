import 'package:flutter/material.dart';
import '../api_client.dart';
import 'bailleur_home_screen.dart';
import 'canal_detail_screen.dart';
import 'electricien_screen.dart';

// Ecran de connexion : point d'entree unique de l'application. Les
// identifiants saisis determinent le role (bailleur ou tel locataire),
// verifie cote ESP32 via /api/moi - jamais devine cote app (cf. S2.9/S2.10).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _baseUrlController =
      TextEditingController(text: "http://192.168.4.1");
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _connexionEnCours = false;
  String? _erreur;
  bool _motDePasseVisible = false;

  @override
  void dispose() {
    _baseUrlController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    final baseUrl = _baseUrlController.text.trim();
    final user = _userController.text.trim();
    final pass = _passController.text;
    if (baseUrl.isEmpty || user.isEmpty || pass.isEmpty) {
      setState(() => _erreur = "Remplis tous les champs");
      return;
    }

    setState(() {
      _connexionEnCours = true;
      _erreur = null;
    });

    final api = ApiClient(baseUrl, username: user, password: pass);
    try {
      final identite = await api.connexion();
      if (!mounted) return;
      if (identite.estBailleur) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BailleurHomeScreen(
              baseUrl: baseUrl,
              username: user,
              password: pass,
            ),
          ),
        );
      } else if (identite.estElectricien) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ElectricienScreen(
              baseUrl: baseUrl,
              username: user,
              password: pass,
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CanalDetailScreen(
              baseUrl: baseUrl,
              username: user,
              password: pass,
              canal: identite.canal,
              modeBailleur: false,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = "Connexion impossible : $e");
    } finally {
      if (mounted) setState(() => _connexionEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // -- En-tete --
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary,
                          colorScheme.primary.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(Icons.bolt_rounded,
                        color: colorScheme.onPrimary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "TFC Multicanal",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          "Goma · Sous-comptage energie IoT",
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),

              Text(
                "Connexion",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Bailleur ou locataire : les memes identifiants ouvrent le "
                "bon ecran automatiquement.",
                style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _baseUrlController,
                      decoration: InputDecoration(
                        labelText: "Adresse du systeme",
                        prefixIcon: const Icon(Icons.wifi_rounded),
                        helperText:
                            "192.168.4.1 = point d'acces Wi-Fi de l'ESP32",
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _userController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: "Identifiant",
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passController,
                      obscureText: !_motDePasseVisible,
                      onSubmitted: (_) => _seConnecter(),
                      decoration: InputDecoration(
                        labelText: "Mot de passe",
                        prefixIcon: const Icon(Icons.lock_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_motDePasseVisible
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded),
                          onPressed: () => setState(
                              () => _motDePasseVisible = !_motDePasseVisible),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_erreur != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 18, color: colorScheme.onErrorContainer),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _erreur!,
                          style: TextStyle(color: colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _connexionEnCours ? null : _seConnecter,
                icon: _connexionEnCours
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.login_rounded),
                label: Text(_connexionEnCours ? "Connexion..." : "Se connecter"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
