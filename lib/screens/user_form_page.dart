import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../globals.dart' as globals;
import 'user_list_page.dart'; // Pour utiliser le modèle User

// ----------------------------------------------------
// PAGE DE FORMULAIRE POUR AJOUTER/MODIFIER UN UTILISATEUR
// ----------------------------------------------------
class UserFormPage extends StatefulWidget {
  final User
  user; // L'utilisateur à éditer, ou un utilisateur vide pour l'ajout

  const UserFormPage({super.key, required this.user});

  @override
  State<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends State<UserFormPage> {
  final _formKey = GlobalKey<FormState>();
  late bool isEditing;

  // Contrôleurs et état pour les champs du formulaire
  late TextEditingController _nomController;
  late TextEditingController _emailController;
  late String _currentRole;

  final List<String> _roles = ['Client', 'Admin', 'Livreur', 'Manager'];

  final Uri _apiUrl = Uri.parse("${globals.baseUrl}users_api.php");

  @override
  void initState() {
    super.initState();
    isEditing =
        widget
            .user
            .id
            .isNotEmpty; // Si l'ID est présent, on est en mode édition

    _nomController = TextEditingController(text: widget.user.nom);
    _emailController = TextEditingController(text: widget.user.email);

    // Assurer que le rôle initial est valide ou prend la première valeur
    _currentRole =
        _roles.contains(widget.user.role) ? widget.user.role : _roles.first;
  }

  @override
  void dispose() {
    _nomController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // --- LOGIQUE DE SAUVEGARDE (POST ou PUT) ---
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Récupération des valeurs du formulaire
    final newUserData = User(
      id: isEditing ? widget.user.id : '', // Garder l'ID pour la modification
      nom: _nomController.text,
      email: _emailController.text,
      role: _currentRole,
    );

    // Créer le corps de la requête
    final Map<String, dynamic> requestBody = {
      'user_id': newUserData.id,
      'nom': newUserData.nom,
      'email': newUserData.email,
      'role': newUserData.role,
    };

    String action = isEditing ? 'Modification' : 'Ajout';
    http.Response response;

    try {
      if (isEditing) {
        // PUT (Modification)
        response = await http.put(
          _apiUrl,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(requestBody),
        );
      } else {
        // POST (Ajout)
        requestBody.remove(
          'user_id',
        ); // L'ID n'est pas envoyé lors de la création
        response = await http.post(
          _apiUrl,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(requestBody),
        );
      }

      final responseBody = json.decode(response.body);

      // Vérification des codes de statut
      bool success =
          (isEditing && response.statusCode == 200) ||
          (!isEditing && response.statusCode == 201);

      if (success && responseBody['status'] == 'success') {
        // Succès : Fermer la page et retourner 'true' pour rafraîchir la liste
        Navigator.of(context).pop(true);
      } else {
        // Échec de l'API : Afficher un message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Échec de l\'$action: ${responseBody['message'] ?? 'Erreur inconnue'}',
            ),
          ),
        );
      }
    } catch (e) {
      // Erreur de connexion
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de connexion lors de l\'$action: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Modifier l\'Utilisateur' : 'Ajouter un Utilisateur',
        ),
        backgroundColor: isEditing ? Colors.lightBlue : Colors.blueGrey,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Champ Nom
              TextFormField(
                controller: _nomController,
                decoration: const InputDecoration(
                  labelText: 'Nom Complet',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer le nom complet de l\'utilisateur.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Champ Email
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Adresse Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer une adresse email.';
                  }
                  // Validation simple d'email
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Veuillez entrer un email valide.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Sélecteur de Rôle
              DropdownButtonFormField<String>(
                value: _currentRole,
                decoration: const InputDecoration(
                  labelText: 'Rôle',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.supervised_user_circle),
                ),
                items:
                    _roles.map((String role) {
                      return DropdownMenuItem<String>(
                        value: role,
                        child: Text(role),
                      );
                    }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _currentRole = newValue!;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez sélectionner un rôle.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),

              // Bouton de Soumission
              ElevatedButton.icon(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isEditing ? Colors.lightBlue : Colors.blueGrey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: Icon(isEditing ? Icons.save : Icons.add_circle),
                label: Text(
                  isEditing
                      ? 'Sauvegarder les Modifications'
                      : 'Créer l\'Utilisateur',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
