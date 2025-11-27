import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../globals.dart' as globals; // Assurez-vous d'avoir ce fichier

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Définition des couleurs pour la cohérence du thème
  static const Color primaryColor = Color(0xFF1E88E5); // Blue 600
  static const Color accentColor = Color(0xFF4FC3F7); // Light Blue 300

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // Fonction de Connexion (READ - POST)
  // --------------------------------------------------------------------------
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Utilisation de votre fichier login.php
    var url = Uri.parse("${globals.baseUrl}login.php");

    try {
      var response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "email": _emailController.text.trim(),
          "mot_de_passe":
              _passwordController.text.trim(), // Clé utilisée dans login.php
        }),
      );

      var data = json.decode(response.body);

      // Traitement de la réponse
      if (response.statusCode == 200 && data['status'] == 'success') {
        final userId = data['user_id'];
        // 🎯 NOUVEAU: Récupération du rôle
        final role = data['role'] ?? 'client'; // Assurez une valeur par défaut

        // Afficher Pop-up de succès (Exigence Projet)
        _showPopUp(
          'Connexion Réussie 👋',
          'Bienvenue, ${data['nom']}! (Rôle: ${role.toUpperCase()})',
          Colors.green,
        );

        // 🎯 LOGIQUE DE REDIRECTION BASÉE SUR LE RÔLE
        if (mounted) {
          // Attente optionnelle pour laisser le temps au Pop-up d'être vu (facultatif)
          // await Future.delayed(const Duration(seconds: 2));

          if (role == 'admin') {
            // Redirection Admin: vers le tableau de bord
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/admin_dashboard',
              (route) => false,
              arguments: userId, // Optionnel: pour la gestion admin
            );
          } else {
            // Redirection Client: vers la page Menu
            Navigator.pushReplacementNamed(
              context,
              '/menu',
              // Passage de l'ID utilisateur et du rôle au MenuPage
              arguments: {'userId': userId, 'role': role},
            );
          }
        }
      } else {
        // Échec de la connexion
        String message = data['message'] ?? "Erreur de connexion inconnue.";
        _showPopUp("Échec de la Connexion", message, Colors.red);
      }
    } catch (e) {
      // Erreur réseau (Gestion des Erreurs - Bonus)
      _showPopUp(
        "Erreur Serveur",
        "Impossible de contacter le serveur. Vérifiez XAMPP et votre adresse IP. Erreur: $e",
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --------------------------------------------------------------------------
  // Fenêtre Pop-up (Exigence Projet)
  // --------------------------------------------------------------------------
  void _showPopUp(String title, String message, Color color) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('OK', style: TextStyle(color: primaryColor)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // Design des Champs de Texte (Amélioré)
  // --------------------------------------------------------------------------
  InputDecoration _getInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: 'Entrez votre $label',
      prefixIcon: Icon(icon, color: primaryColor),
      fillColor: accentColor.withOpacity(0.1), // Arrière-plan coloré léger
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), // Coins arrondis
        borderSide: BorderSide.none, // Suppression du bord par défaut
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: primaryColor,
          width: 2,
        ), // Bordure bleue lors du focus
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Connexion",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Center(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(30.0), // Padding plus généreux
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icône
                  const Center(
                    child: Icon(
                      Icons.lock_open_outlined,
                      size: 90,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Titre
                  const Text(
                    "Connectez-vous à votre compte",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 40),

                  // Champ Email
                  TextFormField(
                    controller: _emailController,
                    decoration: _getInputDecoration(
                      'Email',
                      Icons.email_outlined,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null ||
                          !value.contains('@') ||
                          !value.contains('.')) {
                        return 'Veuillez entrer un email valide.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(
                    height: 20,
                  ), // Espace plus grand entre les champs
                  // Champ Mot de passe
                  TextFormField(
                    controller: _passwordController,
                    decoration: _getInputDecoration(
                      'Mot de passe',
                      Icons.lock_outline,
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty || value.length < 4) {
                        return 'Le mot de passe est obligatoire (minimum 4 caractères).';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 50),

                  // Bouton de connexion
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 5,
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                            : const Text(
                              "Se Connecter",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                  ),

                  // Lien vers l'inscription
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/register');
                    },
                    child: Text(
                      "Pas encore de compte ? S'inscrire",
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
