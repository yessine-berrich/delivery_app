import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../globals.dart' as globals;
// Importez la classe Plat qui se trouve dans plat_list_page.dart
import 'plat_list_page.dart';

class PlatFormPage extends StatefulWidget {
  const PlatFormPage({super.key});

  @override
  State<PlatFormPage> createState() => _PlatFormPageState();
}

class _PlatFormPageState extends State<PlatFormPage> {
  final _formKey = GlobalKey<FormState>();

  // Contrôleurs pour les champs du formulaire (déclarés late)
  late TextEditingController _nomController;
  late TextEditingController _descriptionController;
  late TextEditingController _prixController;
  late TextEditingController _categorieController;

  // Variables d'état
  late Plat _initialPlat; // Sera initialisé dans didChangeDependencies
  bool _isEditing = false;
  bool _isSaving = false;
  // Nouveau drapeau pour s'assurer que l'initialisation n'a lieu qu'une seule fois
  bool _isInit = false;

  final Uri _apiUrl = Uri.parse("${globals.baseUrl}plat_api.php");

  File? _selectedImage;

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  // --------------------------------------------------------------------------
  // Utilitaire : Fenêtre Pop-up
  // --------------------------------------------------------------------------
  void _showPopUp(
    String title,
    String message, {
    Color color = Colors.blueAccent,
  }) {
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
                // Fermer la pop-up
                Navigator.of(context).pop();
                // Retourner à la page précédente (PlatListPage) avec le signal de rafraîchissement
                Navigator.pop(context, true);
              },
            ),
          ],
        );
      },
    );
  }

  String? _existingImageUrl;
  // Initialisation des contrôleurs avec les valeurs du Plat reçu
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Initialisation unique : évite LateInitializationError
    if (!_isInit) {
      // Récupérer l'objet Plat passé en argument lors de la navigation
      // Assurez-vous que l'argument n'est pas nul avant de le caster
      final args = ModalRoute.of(context)!.settings.arguments;
      final Plat plat =
          args is Plat
              ? args
              : Plat(
                id: '',
                nom: '',
                description: '',
                prix: 0.0,
                categorie: '',
                image: null,
              );

      // Configuration de l'état
      _isEditing = (plat.id.isNotEmpty);
      _initialPlat = plat;

      if (_isEditing && _initialPlat.image != null) {
        // Nous construisons l'URL complète pour l'affichage réseau
        _existingImageUrl = "${globals.baseUrl}uploads/${_initialPlat.image}";
      }

      // Initialisation des contrôleurs
      _nomController = TextEditingController(text: _initialPlat.nom);
      _descriptionController = TextEditingController(
        text: _initialPlat.description,
      );

      // Formatage du prix pour l'affichage
      final initialPrix = _initialPlat.prix;
      _prixController = TextEditingController(
        text: initialPrix > 0 ? initialPrix.toString() : '',
      );

      _categorieController = TextEditingController(
        text: _initialPlat.categorie,
      );

      _isInit =
          true; // Empêcher la réinitialisation et autoriser la construction du formulaire
    }
  }

  @override
  void dispose() {
    // S'assurer que les contrôleurs sont disposés
    _nomController.dispose();
    _descriptionController.dispose();
    _prixController.dispose();
    _categorieController.dispose();
    super.dispose();
  }

  Future<void> _submitPlat() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    if (_selectedImage == null && !_isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez sélectionner une image.")),
      );
      setState(() => _isSaving = false);
      return;
    }

    try {
      var request =
          _isEditing
              ? http.MultipartRequest('PUT', _apiUrl)
              : http.MultipartRequest('POST', _apiUrl);

      // Ajouter les champs du formulaire
      request.fields['nom'] = _nomController.text;
      request.fields['description'] = _descriptionController.text;
      request.fields['prix'] = (_prixController.text).toString();
      request.fields['categorie'] = _categorieController.text;

      // Ajouter l'ID si c'est une modification
      if (_isEditing) {
        request.fields['plat_id'] = _initialPlat.id;
      }

      // Ajouter l'image si sélectionnée
      if (_selectedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'item_image', // nom du champ côté serveur
            _selectedImage!.path,
          ),
        );
      }

      // Envoyer la requête
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      final responseBody = json.decode(response.body);
      if (response.statusCode == 200 && responseBody['status'] == 'success') {
        _showPopUp(
          'Opération réussie',
          _isEditing
              ? 'Plat modifié avec succès !'
              : 'Nouveau plat ajouté avec succès !',
          color: Colors.green,
        );
      } else {
        _showPopUp(
          'Erreur',
          responseBody['message'] ?? 'Échec de l’opération.',
          color: Colors.red,
        );
      }
    } catch (e) {
      _showPopUp(
        'Erreur réseau',
        'Impossible de contacter le serveur : $e',
        color: Colors.red,
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Le titre dépend de l'état d'édition
    final title = _isEditing ? 'Modifier le Plat' : 'Ajouter un Nouveau Plat';

    return Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: Colors.indigo),
      // On affiche un indicateur de chargement si l'initialisation n'est pas terminée
      body:
          _isInit
              ? SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // --- BLOC D'AFFICHAGE DE L'IMAGE CORRIGÉ ---
                      if (_selectedImage != null)
                        // 1. Si une NOUVELLE image est sélectionnée, l'afficher
                        Image.file(
                          _selectedImage!,
                          height: 200,
                          fit: BoxFit.cover,
                        )
                      else if (_isEditing && _existingImageUrl != null)
                        // 2. Si c'est une MODIFICATION et qu'il existe une image existante, l'afficher via NetworkImage
                        Image.network(
                          _existingImageUrl!,
                          height: 200,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const SizedBox(
                              height: 200,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox(
                              height: 200,
                              child: Center(
                                child: Icon(Icons.broken_image, size: 50),
                              ),
                            );
                          },
                        ),
                      TextButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image),
                        label: const Text('Choisir une image'),
                      ),

                      // Champ Nom
                      TextFormField(
                        controller: _nomController,
                        decoration: const InputDecoration(
                          labelText: 'Nom du Plat',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.food_bank),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer le nom du plat.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Champ Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer une description.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Champ Prix
                      TextFormField(
                        controller: _prixController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Prix (€)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.euro),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer le prix.';
                          }
                          // Regex plus précis pour les nombres décimaux
                          // Autorise des formats comme "10", "10.5", mais pas "." ou "10."
                          if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(value)) {
                            return 'Veuillez entrer un nombre valide pour le prix (ex: 10.50).';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Champ Catégorie
                      TextFormField(
                        controller: _categorieController,
                        decoration: const InputDecoration(
                          labelText: 'Catégorie (Ex: Entrée, Plat, Dessert)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer la catégorie.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 40),

                      // Bouton de Sauvegarde
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _submitPlat,
                        icon:
                            _isSaving
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.save),
                        label: Text(
                          _isEditing
                              ? 'ENREGISTRER LES MODIFICATIONS'
                              : 'AJOUTER LE PLAT',
                          style: const TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : const Center(child: CircularProgressIndicator()),
    );
  }
}
