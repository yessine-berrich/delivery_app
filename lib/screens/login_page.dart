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
          "mot_de_passe": _passwordController.text.trim(), // Clé utilisée dans login.php
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
            Colors.green
        );
        
        // 🎯 LOGIQUE DE REDIRECTION BASÉE SUR LE RÔLE
        if (mounted) {
          if (role == 'admin') {
            // Redirection Admin: vers le tableau de bord
            Navigator.pushNamedAndRemoveUntil(
              context, 
              '/admin_dashboard', 
              (route) => false,
              arguments: userId // Optionnel: pour la gestion admin
            );
          } else {
            // Redirection Client: vers la page Menu
            Navigator.pushReplacementNamed(
              context, 
              '/menu', 
              // Passage de l'ID utilisateur et du rôle au MenuPage
              arguments: { 'userId': userId, 'role': role } 
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
          Colors.red
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
          title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Connexion")),
      body: Center(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.delivery_dining, size: 80, color: Colors.blueAccent),
                  const Text(
                    "Bienvenue",
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),

                  // Champ Email
                  TextFormField(
                    controller: _emailController,
                    decoration: _getInputDecoration('Email', Icons.email),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || !value.contains('@')) {
                        return 'Veuillez entrer un email valide.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // Champ Mot de passe
                  TextFormField(
                    controller: _passwordController,
                    decoration: _getInputDecoration('Mot de passe', Icons.lock),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Le mot de passe est obligatoire.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 30),

                  // Bouton de connexion
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Se Connecter",
                              style: TextStyle(fontSize: 18),
                            ),
                    ),
                  ),

                  // Lien vers l'inscription
                  TextButton(
                    onPressed: () {
                      // Utilisation de pushNamed au lieu de pushReplacementNamed
                      Navigator.pushNamed(context, '/register');
                    },
                    child: const Text("Pas encore de compte ? S'inscrire"),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  InputDecoration _getInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.blueAccent),
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
    );
  }
}