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
  // Définition des couleurs pour la cohérence du thème
  static const Color primaryColor = Color(0xFF1E88E5); // Blue 600
  static const Color accentColor = Color(0xFF4FC3F7); // Light Blue 300

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
          // Le rôle sera 'client' par défaut côté PHP
        }),
      );

      var data = json.decode(response.body);

      // 2. Traitement de la réponse
      if (response.statusCode == 201 && data['status'] == 'success') {
        final userId = data['user_id'];

        // Afficher Pop-up de succès (Exigence Projet)
        _showPopUp(
          'Inscription Réussie 🎉',
          'Votre compte a été créé avec succès (ID: $userId). Vous pouvez maintenant vous connecter.',
          Colors.green,
        );

        // Retourner à la page de connexion après succès
        if (mounted) {
          // Utilisation de pop() pour retourner à LoginPage (qui est la route '/login')
          // Note : on utilise pop jusqu'à la route nommée '/login' pour éviter les problèmes si la navigation est profonde
          Navigator.popUntil(context, ModalRoute.withName('/login'));
        }
      } else {
        // Échec de l'inscription (email déjà utilisé, erreur serveur, etc.)
        String message = data['message'] ?? "Erreur lors de l'inscription.";
        _showPopUp("Erreur d'Inscription", message, Colors.red);
      }
    } catch (e) {
      // Erreur réseau
      _showPopUp(
        "Erreur Serveur",
        "Impossible de contacter le serveur. Veuillez vérifier votre connexion. Erreur: $e",
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
  // Fenêtre Pop-up (Améliorée)
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
              child: const Text('OK', style: TextStyle(color: primaryColor)),
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
  // Design des Champs de Texte (Cohérent avec LoginPage)
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
      appBar: AppBar(
        title: const Text(
          "Créer un Compte",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Center(
        child: Form(
          key: _formKey, // Clé de validation
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(30.0), // Padding généreux
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icône
                  const Center(
                    child: Icon(
                      Icons
                          .assignment_ind_outlined, // Icône d'inscription plus spécifique
                      size: 90,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Titre
                  const Text(
                    "Devenez membre en quelques secondes",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 40),

                  // Champ Nom Complet
                  TextFormField(
                    controller: _nomController,
                    decoration: _getInputDecoration(
                      'Nom Complet',
                      Icons.person_outline,
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.isEmpty || value.length < 3) {
                        return 'Veuillez entrer un nom complet valide.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Champ Email (Validation)
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
                  const SizedBox(height: 20),

                  // Champ Mot de passe (Validation)
                  TextFormField(
                    controller: _passwordController,
                    decoration: _getInputDecoration(
                      'Mot de passe',
                      Icons.lock_outline,
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return 'Le mot de passe doit contenir au moins 6 caractères.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Champ Adresse (Optionnel)
                  TextFormField(
                    controller: _adresseController,
                    decoration: _getInputDecoration(
                      'Adresse (Optionnel)',
                      Icons.location_on_outlined,
                    ),
                    keyboardType: TextInputType.streetAddress,
                  ),
                  const SizedBox(height: 50),

                  // Bouton d'inscription
                  ElevatedButton(
                    onPressed: _isLoading ? null : _register,
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
                              "S'inscrire",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                  ),

                  // Lien vers la connexion
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Retourne à la LoginPage
                    },
                    child: Text(
                      "Déjà un compte ? Se Connecter",
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
