// lib/screens/register_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../globals.dart' as globals; // Pour l'accès à globals.baseUrl

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Clé pour la validation du formulaire
  final _formKey = GlobalKey<FormState>();

  // Contrôleurs pour les champs de saisie
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _adresseController = TextEditingController();

  bool _isLoading = false;

  // --------------------------------------------------------------------------
  // Fonction d'Inscription (CREATE - POST)
  // --------------------------------------------------------------------------
  Future<void> _register() async {
    // 1. Validation des données
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Utilisation de votre nouveau fichier register.php
    var url = Uri.parse("${globals.baseUrl}register.php");

    try {
      var response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        // On envoie les données dans le corps de la requête POST
        body: json.encode({
          "nom": _nomController.text.trim(),
          "email": _emailController.text.trim(),
          "mot_de_passe":
              _passwordController.text
                  .trim(), // Le mot de passe clair sera haché par PHP
          "adresse": _adresseController.text.trim(),
        }),
      );

      var data = json.decode(response.body);

      // 2. Traitement de la réponse
      if (response.statusCode == 201 && data['status'] == 'success') {
        final userId = data['user_id'];

        // Afficher Pop-up de succès (Exigence Projet)
        _showPopUp(
          'Inscription Réussie 🎉',
          'Votre compte a été créé avec succès. ID: $userId. Vous pouvez maintenant vous connecter.',
          Colors.green,
        );

        // Retourner à la page de connexion après succès
        if (mounted) {
          // Utilisation de pop() pour retourner à LoginPage (qui est la route '/')
          Navigator.popUntil(context, ModalRoute.withName('/login'));
        }
      } else {
        // Échec de l'inscription (email déjà utilisé, erreur serveur, etc.)
        String message = data['message'] ?? "Erreur lors de l'inscription.";
        _showPopUp("Erreur d'Inscription", message, Colors.red);
      }
    } catch (e) {
      // Erreur réseau (très probablement un problème d'IP/CORS si vous voyez ce message)
      _showPopUp(
        "Erreur Serveur",
        "Impossible de contacter le serveur. Veuillez vérifier votre connexion.",
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
          title: Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
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
  void dispose() {
    _nomController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _adresseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("S'inscrire")),
      body: Center(
        child: Form(
          key: _formKey, // Clé de validation
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.person_add,
                    size: 80,
                    color: Colors.blueAccent,
                  ),
                  const Text(
                    "Créer un Compte",
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),

                  // Champ Nom Complet
                  TextFormField(
                    controller: _nomController,
                    decoration: _getInputDecoration(
                      'Nom Complet',
                      Icons.person,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Le nom est obligatoire.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // Champ Email (Validation)
                  TextFormField(
                    controller: _emailController,
                    decoration: _getInputDecoration('Email', Icons.email),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null ||
                          !value.contains('@') ||
                          value.length < 5) {
                        return 'Veuillez entrer un email valide.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // Champ Mot de passe (Validation)
                  TextFormField(
                    controller: _passwordController,
                    decoration: _getInputDecoration('Mot de passe', Icons.lock),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return 'Le mot de passe doit contenir au moins 6 caractères.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // Champ Adresse (Optionnel)
                  TextFormField(
                    controller: _adresseController,
                    decoration: _getInputDecoration(
                      'Adresse (Optionnel)',
                      Icons.location_on,
                    ),
                    keyboardType: TextInputType.streetAddress,
                  ),
                  const SizedBox(height: 30),

                  // Bouton d'inscription
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child:
                          _isLoading
                              ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                              : const Text(
                                "S'inscrire",
                                style: TextStyle(fontSize: 18),
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

  // Fonction utilitaire pour le style des champs
  InputDecoration _getInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.blueAccent),
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
    );
  }
}
