import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../globals.dart' as globals;
import 'plat_list_page.dart'; // Importation de la classe Plat

class PlatFormPage extends StatefulWidget {
  const PlatFormPage({super.key});

  @override
  State<PlatFormPage> createState() => _PlatFormPageState();
}

class _PlatFormPageState extends State<PlatFormPage> {
  final _formKey = GlobalKey<FormState>();

  // Contrôleurs pour les champs du formulaire
  late TextEditingController _nomController;
  late TextEditingController _descriptionController;
  late TextEditingController _prixController;
  late TextEditingController _categorieController;

  // Variables d'état
  late Plat _initialPlat; // Plat passé en argument
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isInit =
      false; // Pour s'assurer que l'initialisation a lieu une seule fois

  final Uri _apiUrl = Uri.parse("${globals.baseUrl}plat_api.php");

  // Image sélectionnée localement (nouvelle image)
  File? _selectedImage;
  // URL de l'image existante sur le serveur (pour l'affichage en mode édition)
  String? _existingImageUrl;

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // Optimisation de la qualité pour l'envoi
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          title: Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Fermer la pop-up
                // Si succès, retourner à la page précédente avec 'true' pour rafraîchir
                if (color == Colors.green) {
                  Navigator.pop(context, true);
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isInit) {
      // Récupérer l'objet Plat passé en argument
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
        // Construction de l'URL complète
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
        // Utiliser toStringAsFixed pour garantir deux décimales, puis replace la virgule
        text: initialPrix > 0 ? initialPrix.toStringAsFixed(2) : '',
      );

      _categorieController = TextEditingController(
        text: _initialPlat.categorie,
      );

      _isInit = true;
    }
  }

  @override
  void dispose() {
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

    // Validation d'image à la création
    if (_selectedImage == null && !_isEditing && _initialPlat.image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Veuillez sélectionner une image pour le nouveau plat.",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Utilisation de POST pour l'envoi de MultipartFile, avec simulation de PUT
      var request = http.MultipartRequest('POST', _apiUrl);

      if (_isEditing) {
        // Champ masqué pour simuler la méthode PUT côté PHP
        request.fields['_method'] = 'PUT';
        request.fields['plat_id'] = _initialPlat.id;
      }

      // Ajout des champs du formulaire
      request.fields['nom'] = _nomController.text;
      request.fields['description'] = _descriptionController.text;
      // S'assurer que le prix est au format décimal avec un point pour le serveur
      request.fields['prix'] = _prixController.text.replaceAll(',', '.');
      request.fields['categorie'] = _categorieController.text;

      // Ajouter l'image si sélectionnée
      if (_selectedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'item_image', // Nom du champ côté serveur
            _selectedImage!.path,
          ),
        );
      }

      // Envoyer la requête
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      final responseBody = json.decode(response.body);
      final message =
          responseBody['message'] ?? 'Opération terminée avec succès/échec.';

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          responseBody['status'] == 'success') {
        _showPopUp('Succès', message, color: Colors.green);
      } else {
        _showPopUp('Erreur', message, color: Colors.red);
      }
    } catch (e) {
      _showPopUp(
        'Erreur Réseau',
        'Impossible de contacter le serveur : $e',
        color: Colors.red,
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // --- WIDGET POUR L'AFFICHAGE DE L'IMAGE ---
  Widget _buildImageDisplay() {
    Widget imageWidget;
    Icon placeholderIcon = const Icon(
      Icons.ramen_dining,
      size: 100,
      color: Color.fromARGB(255, 179, 179, 179),
    );

    if (_selectedImage != null) {
      // Image sélectionnée (locale)
      imageWidget = Image.file(_selectedImage!, fit: BoxFit.cover);
    } else if (_isEditing && _existingImageUrl != null) {
      // Image existante (réseau)
      imageWidget = Image.network(
        _existingImageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value:
                  loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => placeholderIcon,
      );
    } else {
      // Aucun plat ou image
      imageWidget = Center(child: placeholderIcon);
    }

    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: imageWidget,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Le titre dépend de l'état d'édition
    final title = _isEditing ? 'Modifier le Plat' : 'Ajouter un Nouveau Plat';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body:
          _isInit
              ? SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          // --- AFFICHAGE ET SÉLECTION D'IMAGE ---
                          _buildImageDisplay(),

                          TextButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.camera_alt),
                            label: Text(
                              _selectedImage != null
                                  ? 'Changer l\'image'
                                  : (_isEditing && _existingImageUrl != null
                                      ? 'Remplacer l\'image'
                                      : 'Choisir une image'),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.indigo,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // --- Champ Nom ---
                          TextFormField(
                            controller: _nomController,
                            decoration: InputDecoration(
                              labelText: 'Nom du Plat',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.food_bank),
                              filled: true,
                              fillColor: Colors.indigo.shade50,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Veuillez entrer le nom du plat.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // --- Champ Description ---
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.description),
                            ),
                            maxLines: 3,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Veuillez entrer une description.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // --- Champ Prix ---
                          TextFormField(
                            controller: _prixController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Prix (€)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.euro),
                              hintText: 'Ex: 15.50 ou 15,50',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Veuillez entrer le prix.';
                              }
                              // Remplace la virgule par le point pour la vérification numérique
                              final cleanValue = value.replaceAll(',', '.');
                              final price = double.tryParse(cleanValue);

                              if (price == null || price <= 0) {
                                return 'Veuillez entrer un prix valide (> 0).';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // --- Champ Catégorie ---
                          TextFormField(
                            controller: _categorieController,
                            decoration: const InputDecoration(
                              labelText:
                                  'Catégorie (Ex: Entrée, Plat, Dessert)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.category),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Veuillez entrer la catégorie.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 40),

                          // --- Bouton de Sauvegarde ---
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
                                    : (_isEditing
                                        ? const Icon(Icons.save)
                                        : const Icon(Icons.add_box)),
                            label: Text(
                              _isEditing
                                  ? 'ENREGISTRER LES MODIFICATIONS'
                                  : 'AJOUTER LE PLAT',
                              style: const TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _isSaving
                                      ? Colors.grey
                                      : Colors.indigo.shade700,
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
                  ),
                ),
              )
              : const Center(child: CircularProgressIndicator()),
    );
  }
}
