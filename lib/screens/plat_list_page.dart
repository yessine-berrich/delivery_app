import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../globals.dart' as globals;
// Importation de PlatFormPage n'est pas nécessaire ici, seulement du modèle Plat

// ----------------------------------------------------
// 1. MODÈLE DE DONNÉES (MATCH PHP)
// ----------------------------------------------------
class Plat {
  final String id; // plat_id
  final String nom;
  final String description;
  final double prix;
  final String categorie;

  Plat({
    required this.id,
    required this.nom,
    required this.description,
    required this.prix,
    required this.categorie,
  });

  // Factory constructor pour créer un Plat à partir d'un map JSON
  factory Plat.fromJson(Map<String, dynamic> json) {
    return Plat(
      id:
          json['plat_id']?.toString() ??
          '', // Convertit l'ID en String, ou vide si null
      nom: json['nom'] ?? 'Nom Inconnu',
      description: json['description'] ?? '',
      prix: double.tryParse(json['prix']?.toString() ?? '0.0') ?? 0.0,
      categorie: json['categorie'] ?? 'Divers',
    );
  }
}

// ----------------------------------------------------
// 2. WIDGET D'ÉTAT
// ----------------------------------------------------
class PlatListPage extends StatefulWidget {
  const PlatListPage({super.key});

  @override
  State<PlatListPage> createState() => _PlatListPageState();
}

class _PlatListPageState extends State<PlatListPage> {
  List<Plat> _plats = [];
  bool _isLoading = true;
  String? _error;

  final Uri _apiUrl = Uri.parse("${globals.baseUrl}plat_api.php");

  @override
  void initState() {
    super.initState();
    _fetchPlats();
  }

  // --- LOGIQUE DE CHARGEMENT ---
  Future<void> _fetchPlats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(_apiUrl);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = json.decode(response.body);

        if (responseBody['status'] == 'success' &&
            responseBody['data'] is List) {
          final List data = responseBody['data'];
          setState(() {
            _plats = data.map((item) => Plat.fromJson(item)).toList();
          });
        } else {
          setState(() {
            _error =
                responseBody['message'] ??
                'Erreur inconnue lors du chargement des données.';
          });
        }
      } else {
        setState(() {
          _error = 'Échec du chargement. Statut: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur de connexion : $e';
      });
      print('Erreur lors du fetch: $e'); // Log l'erreur pour le débogage
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- LOGIQUE DE SUPPRESSION ---
  Future<void> _deletePlat(String id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: const Text(
            'Êtes-vous sûr de vouloir supprimer ce plat ? Cette action est irréversible.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Supprimer',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        final response = await http.delete(
          _apiUrl,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'plat_id': id}),
        );

        final Map<String, dynamic> responseBody = json.decode(response.body);

        if (response.statusCode == 200 && responseBody['status'] == 'success') {
          // Utiliser une SnackBar pour la suppression (car on reste sur la même page)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                responseBody['message'] ?? 'Plat supprimé avec succès.',
              ),
              backgroundColor: Colors.green,
            ),
          );
          _fetchPlats(); // Rafraîchir la liste après suppression
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Erreur de suppression: ${response.statusCode} - ${responseBody['message']}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de connexion lors de la suppression: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- LOGIQUE DE MODIFICATION ET D'AJOUT (Navigation) ---
  void _editPlat(Plat? plat) {
    // Crée un objet Plat par défaut si plat est null (pour un ajout)
    final Plat platToPass =
        plat ??
        Plat(id: '', nom: '', description: '', prix: 0.0, categorie: '');

    Navigator.pushNamed(context, '/plat_form', arguments: platToPass).then((
      result,
    ) {
      // Si le formulaire revient avec 'true', on rafraîchit la liste
      // Le message de succès sera affiché via la pop-up du formulaire AVANT le pop
      if (result == true) {
        _fetchPlats();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste et Gestion des Plats'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            tooltip: 'Ajouter un nouveau plat',
            onPressed:
                () => _editPlat(null), // Appel sans argument pour l'ajout
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Actualiser la liste',
            onPressed: _fetchPlats,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 10),
              Text('Erreur: $_error', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchPlats,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_plats.isEmpty) {
      return const Center(child: Text('Aucun plat disponible pour le moment.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10.0),
      itemCount: _plats.length,
      itemBuilder: (context, index) {
        final plat = _plats[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
          elevation: 3,
          child: ListTile(
            leading: const Icon(Icons.restaurant, color: Colors.indigo),
            title: Text(
              plat.nom,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${plat.categorie} | Prix: ${plat.prix.toStringAsFixed(2)} €',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bouton Modifier
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _editPlat(plat),
                  tooltip: 'Modifier',
                ),
                // Bouton Supprimer
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deletePlat(plat.id),
                  tooltip: 'Supprimer',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
