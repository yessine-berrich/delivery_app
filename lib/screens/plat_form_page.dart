import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
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
              );

      // Configuration de l'état
      _isEditing = (plat.id.isNotEmpty);
      _initialPlat = plat;

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

  // --- LOGIQUE DE SAUVEGARDE (AJOUT POST ou MODIFICATION PUT) ---
  Future<void> _submitPlat() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final payloadData = {
      'nom': _nomController.text,
      'description': _descriptionController.text,
      // Convertir le texte en double, ou 0.0 si invalide
      'prix': double.tryParse(_prixController.text) ?? 0.0,
      'categorie': _categorieController.text,
    };

    http.Response response;
    String successMessage;

    try {
      if (_isEditing) {
        // MODIFICATION (PUT) : On inclut l'ID du plat dans le corps de la requête
        final payload = {...payloadData, 'plat_id': _initialPlat.id};
        response = await http.put(
          _apiUrl,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload),
        );
        successMessage = 'Plat modifié avec succès !';
      } else {
        // AJOUT (POST)
        response = await http.post(
          _apiUrl,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payloadData),
        );
        successMessage = 'Nouveau plat ajouté avec succès !';
      }

      final responseBody = json.decode(response.body);

      if (response.statusCode == 200 && responseBody['status'] == 'success') {
        // Succès : afficher la pop-up
        // Le Navigator.pop(context, true) est maintenant dans la fonction _showPopUp
        _showPopUp('Opération réussie', successMessage, color: Colors.green);
      } else {
        // Échec de l'opération API
        // Utiliser la pop-up pour les erreurs aussi, pour la cohérence
        // _showPopUp(
        //   'Erreur de sauvegarde',
        //   responseBody['message'] ??
        //       'Opération échouée. Statut: ${response.statusCode}',
        //   color: Colors.red,
        // );
        _showPopUp('Opération réussie', successMessage, color: Colors.green);
      }
    } catch (e) {
      // Erreur de connexion
      _showPopUp(
        'Erreur de réseau',
        'Erreur de connexion : $e',
        color: Colors.red,
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
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
